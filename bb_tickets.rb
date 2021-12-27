require 'httparty'
require 'uri'
require 'brcobranca'
require 'date'
require 'tempfile'

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
      },
      verify: false,
      verify_peer: false
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

    self.class.validate_params_to_create(params)

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
    options.merge!({ body: { numeroConvenio: numero_convenio }.to_json })

    response = HTTParty.post("#{base_url_by_enviroment}/boletos/#{id}/baixar", options)

    if response.code == 200
      verbose_output('Destroying', 'done')
    else
      output_request_error(response)

      verbose_output('Destroying', 'error')
    end

    response
  end

  def self.generate_layout(params)
    raise "Params should be a Hash" unless params.class == Hash

    params = JSON.parse(params.to_json, symbolize_names: true)

    self.validate_params_to_create(params)

    # To more details, read this page https://rubydoc.info/github/kivanio/brcobranca/Brcobranca/Boleto/Base
    layout = Brcobranca::Boleto::BancoBrasil.new

    # REQUERIDO: Informa se o banco deve aceitar o boleto após o vencimento ou não( S ou N, quase sempre S)
    layout.aceite = params[:codigoAceite]

    # REQUERIDO: Número da agencia sem Digito Verificador
    layout.agencia = '452'

    # OPCIONAL: Nome do avalista
    layout.avalista = params[:beneficiarioFinal][:nome]

    # OPCIONAL: Documento do avalista
    layout.avalista_documento = params[:beneficiarioFinal][:numeroInscricao]

    # REQUERIDO: Carteira utilizada
    layout.carteira = params[:numeroCarteira]

    # OPCIONAL: Variacao da carteira(opcional para a maioria dos bancos)
    layout.carteira_label = params[:numeroVariacaoCarteira]

    # REQUERIDO: Nome do beneficiário
    layout.cedente = params[:beneficiarioFinal][:nome]

    # OPCIONAL: Endereço do beneficiário
    layout.cedente_endereco = 'Av. Estreita do Largo, 123, São Paulo/SP'

    # OPCIONAL: Código utilizado para identificar o tipo de serviço cobrado
    # layout.codigo_servico =

    # REQUERIDO: Número da conta corrente sem Digito Verificador
    layout.conta_corrente = '123873'

    # REQUERIDO: Número do convênio/contrato do cliente junto ao banco emissor
    layout.convenio = params[:numeroConvenio]

    # REQUERIDO: Data de pedido, Nota fiscal ou documento que originou o boleto
    # layout.data_documento = params[:']

    # OPCIONAL: Data de processamento do boleto
    # layout.data_processamento = params[:']

    # REQUERIDO: Data de vencimento do boleto
    layout.data_vencimento = Date.parse(params[:dataVencimento].gsub('.', '/'))

    # OPCIONAL: Utilizado para mostrar alguma informação ao sacado
    # layout.demonstrativo =

    # REQUERIDO: Documento do beneficiário (CPF ou CNPJ)
    layout.documento_cedente = params[:beneficiarioFinal][:numeroInscricao]

    # OPCIONAL: Número de pedido, Nota fiscal ou documento que originou o boleto
    # layout.documento_numero =

    # REQUERIDO: Símbolo da moeda utilizada (R$ no brasil)
    layout.especie = 'R$'

    # REQUERIDO: Tipo do documento (Geralmente DM que quer dizer Duplicata Mercantil)
    layout.especie_documento = params[:descricaoTipoTitulo] || 'DM'

    # OPCIONAL: Utilizado para mostrar alguma informação ao caixa
    # layout.instrucao1 = params[:mensagemBloquetoOcorrencia]

    # OPCIONAL: Utilizado para mostrar alguma informação ao caixa
    # layout.instrucao2 = params[:']

    # OPCIONAL: Utilizado para mostrar alguma informação ao caixa
    # layout.instrucao3 = params[:']

    # OPCIONAL: Utilizado para mostrar alguma informação ao caixa
    # layout.instrucao4 = params[:']

    # OPCIONAL: Utilizado para mostrar alguma informação ao caixa
    # layout.instrucao5 = params[:']

    # OPCIONAL: Utilizado para mostrar alguma informação ao caixa
    # layout.instrucao6 = params[:']

    # OPCIONAL: Utilizado para mostrar alguma informação ao caixa
    # layout.instrucao7 = params[:']

    # OPCIONAL: Utilizado para mostrar alguma informação ao caixa
    layout.instrucoes = params[:mensagemBloquetoOcorrencia]

    # REQUERIDO: Informação sobre onde o sacado podera efetuar o pagamento
    layout.local_pagamento = 'QUALQUER BANCO OU LOTÉRICA ATÉ O VENCIMENTO'

    # REQUERIDO: Tipo de moeda utilizada (Real(R$) e igual a 9)
    layout.moeda = '9'

    # OPCIONAL: Número sequencial utilizado para identificar o boleto
    layout.nosso_numero = params[:numeroTituloCliente][-10..-1]

    # REQUERIDO: Quantidade de boleto(padrão = 1)
    layout.quantidade = '1'

    # REQUERIDO: Nome do pagador
    layout.sacado = params[:pagador][:nome]

    # REQUERIDO: Documento do pagador
    layout.sacado_documento = params[:pagador][:numeroInscricao]

    # OPCIONAL: Endereco do pagador
    # layout.sacado_endereco = params[:pagador][:endereco]

    # REQUERIDO: Valor do boleto
    layout.valor = params[:valorOriginal]

    # OPCIONAL: Rótulo da Carteira, RG ou SR, somente para impressão no boleto.
    # layout.variacao =

    # ticket_layout = layout.to(:pdf)

    # ticket_layout
    layout
  end

  def self.validate_params_to_create(params)
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
end