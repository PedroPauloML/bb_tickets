require 'httparty'
require 'uri'

class BBTickets
  attr_accessor(:verbose)
  attr_reader(:enviroment, :developer_application_key, :numero_convenio)

  BASE_URL = {
    homologation: 'https://api.hm.bb.com.br/cobrancas/v2',
    production: 'https://api.bb.com.br/cobrancas/v2'
  }
  O_AUTH_URL = {
    homologation: 'https://oauth.sandbox.bb.com.br',
    production: 'https://oauth.bb.com.br'
  }

  def initialize(developer_application_key, basic_auth, attrs = {})
    # Set enviroment
    valid_enviroments = [:homologation, :production]
    if attrs.key?(:enviroment)
      if (
          [String, Symbol].include?(attrs[:enviroment].class) and
          valid_enviroments.include?(attrs[:enviroment].to_sym)
        )
        @enviroment = attrs[:enviroment].to_sym
      else
        raise "Invalid enviroment. Valid options: 'homologation', 'production'"
      end
    else
      @enviroment = :homologation
    end

    # Set basic_auth to request access_token
    @basic_auth = basic_auth

    # Set options to each request to API
    @http_options = {
      headers: {
        "Content-Type" => 'application/json'
      },
      query: {
        "gw-dev-app-key" => developer_application_key
      }
    }

    # Config HTTParty to ignore validation of SSL certificate
    HTTParty::Basement.default_options.update(verify: false, verify_peer: false)

    # Data to register ticket
    @numero_convenio = attrs[:numero_convenio] || nil

    # Verbose is the flag to print requests comments
    @verbose = attrs[:verbose] || false
  end

  # Change enviroment
  def homologation!
    @enviroment = :homologation
  end

  def production!
    @enviroment = :production
  end

  # Actions
  def index(status, beneficiary_agency, beneficiary_account, filters = {})
    # Validate status
    valid_statuses = %w[A B]
    invalid_status_message = "'status' is invalid. Valid options: 'A', 'B'"

    unless status.class == String
      raise invalid_status_message
    end

    status.upcase!

    unless valid_statuses.include?(status.upcase)
      raise invalid_status_message
    end

    query = {
      indicadorSituacao: status,
      agenciaBeneficiario: beneficiary_agency,
      contaBeneficiario: beneficiary_account,
    }

    # Add extra filters
    filters = JSON.parse(filters.to_json, symbolize_names: true)
    allowed_extra_filters = %i(
      contaCaucao
      carteiraConvenio
      variacaoCarteiraConvenio
      modalidadeCobranca
      cnpjPagador
      digitoCNPJPagador
      cpfPagador
      digitoCPFPagador
      dataInicioVencimento
      dataFimVencimento
      dataInicioRegistro
      dataFimRegistro
      dataInicioMovimento
      dataFimMovimento
      codigoEstadoTituloCobranca
      boletoVencido
      indice
    )
    extra_filters_keys = filters.keys & allowed_extra_filters

    extra_filters_keys.each do |key|
      query.merge!(key => filters[key])
    end

    verbose_output('Fetching', 'starting')

    check_authentication

    options = @http_options.clone
    options[:query].merge!(query)

    response = HTTParty.get("#{base_url_by_enviroment}/boletos", options)

    if response.code == 200
      verbose_output('Fetching', 'done')
    else
      output_request_error(response)

      verbose_output('Fetching', 'error')
    end

    response
  end

  def show(numero_convenio, system_identifier)
    id = "000#{numero_convenio}#{'%010d' % system_identifier.to_i}"

    verbose_output('Fetching', 'starting')

    check_authentication

    options = @http_options.clone
    options[:query].merge!({ numeroConvenio: numero_convenio })

    response = HTTParty.get("#{base_url_by_enviroment}/boletos/#{id}", options)

    if response.code == 200
      verbose_output('Fetching', 'done')
    else
      output_request_error(response)

      verbose_output('Fetching', 'error')
    end

    response
  end

  def create(params)
    raise "Params should be a Hash" unless params.class == Hash

    params = JSON.parse(params.to_json, symbolize_names: true)

    params[:numeroConvenio] ||= @numero_convenio

    validate_params_to_create(params)

    verbose_output('Creating', 'starting')

    check_authentication

    options = @http_options.merge({ body: params.to_json })

    response = HTTParty.post("#{base_url_by_enviroment}/boletos", options)

    if response.code == 201
      verbose_output('Creating', 'done')
    else
      output_request_error(response)

      verbose_output('Creating', 'error')
    end

    response
  end

  def destroy(numero_convenio, system_identifier)
    id = "000#{numero_convenio}#{'%010d' % system_identifier.to_i}"

    verbose_output('Destroying', 'starting')

    check_authentication

    options = @http_options.clone
    options[:query].merge!({ numeroConvenio: numero_convenio })

    response = HTTParty.post("#{base_url_by_enviroment}/boletos/#{id}/baixar", options)

    if response.code == 200
      verbose_output('Destroying', 'done')
    else
      output_request_error(response)

      verbose_output('Destroying', 'error')
    end

    response
  end

  private

  def o_auth_url_by_enviroment
    O_AUTH_URL[@enviroment]
  end

  def base_url_by_enviroment
    BASE_URL[@enviroment]
  end

  def output_request_error(response)
    puts "\n[#{response.code}] Request error: #{response.body}\n\n"
  end

  def verbose_output(message, action = nil)
    return unless @verbose
    valid_actions = %i(starting done error)

    case action
    when 'starting'
      suffix = '[...]'
    when 'done'
      suffix = '[OK]'
    when 'error'
      suffix = '[ERROR]'
    else
      suffix = nil
    end

    if suffix
      puts "#{message} #{suffix}"
    else
      puts message
    end
  end

  def authenticate
    verbose_output('Authenticating', 'starting')

    body = URI.encode_www_form({
      grant_type: 'client_credentials',
      scope: 'cobrancas.boletos-info cobrancas.boletos-requisicao'
    })
    options = {
      headers: {
        Authorization: @basic_auth,
        'Content-Type': 'application/x-www-form-urlencoded'
      },
      body: body,
      query: @http_options[:query]
    }

    response = HTTParty.post("#{o_auth_url_by_enviroment}/oauth/token", options)

    if response.code == 201
      body_parsed = JSON.parse(response.body)
      @access_token_expires_at = Time.now + body_parsed['expires_in'].to_i

      @http_options[:headers].merge!({
        Authorization: "Bearer #{body_parsed['access_token']}"
      })

      verbose_output("Access token expires at #{@access_token_expires_at.strftime('%T')}")
      verbose_output('Authenticating', 'done')
    else
      output_request_error(response)

      verbose_output('Authenticating', 'error')
    end

    response
  end

  def check_authentication
    unless @access_token_expires_at and Time.now < @access_token_expires_at
      authenticate
    end
  end

  def validate_params_to_create(params)
    required_params = %i(
      numeroConvenio
      dataVencimento
      valorOriginal
      numeroCarteira
      numeroVariacaoCarteira
      codigoModalidade
      dataEmissao
      codigoAceite
      codigoTipoTitulo
      indicadorPermissaoRecebimentoParcial
      numeroTituloCliente
      pagador
      beneficiarioFinal
    )
    nested_required_params = {
      pagador: %i(
        tipoInscricao
        numeroInscricao
        nome
        endereco
        cep
        cidade
        bairro
        uf
      ),
      beneficiarioFinal: %i(
        tipoInscricao
        numeroInscricao
        nome
      )
    }

    params_not_present = required_params - params.keys

    present_nested_attributes = (
      nested_required_params.keys - params_not_present
    )
    nested_params_not_present = []
    if present_nested_attributes.count > 0
      present_nested_attributes.each do |key|
        not_present = nested_required_params[key] - params[key].keys
        not_present.each { |nested_params_key|
          nested_params_not_present.push(:"#{key}.#{nested_params_key}")
        }
      end
    end

    params_not_present.push(nested_params_not_present)
    params_not_present.flatten!

    if params_not_present.count > 0
      raise "Required params was not informed: #{params_not_present.join(', ')}"
    end
  end
end