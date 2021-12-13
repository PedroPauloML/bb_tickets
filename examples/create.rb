require_relative('../bb_tickets.rb')

bb = BBTickets.new(
  'd27bc77908ffabb01362e17d10050f56b971a5be',
  'Basic ZXlKcFpDSTZJalV5WVRVeVl6VXRZekF3TkMwMFlpSXNJbU52WkdsbmIxQjFZbXhwWTJGa2IzSWlPakFzSW1OdlpHbG5iMU52Wm5SM1lYSmxJam95TlRZMk15d2ljMlZ4ZFdWdVkybGhiRWx1YzNSaGJHRmpZVzhpT2pGOTpleUpwWkNJNklqa3hOek0xWldFdE5EZzVZeTAwTmprMkxXRTRORGt0TkdaaFlpSXNJbU52WkdsbmIxQjFZbXhwWTJGa2IzSWlPakFzSW1OdlpHbG5iMU52Wm5SM1lYSmxJam95TlRZMk15d2ljMlZ4ZFdWdVkybGhiRWx1YzNSaGJHRmpZVzhpT2pFc0luTmxjWFZsYm1OcFlXeERjbVZrWlc1amFXRnNJam94TENKaGJXSnBaVzUwWlNJNkltaHZiVzlzYjJkaFkyRnZJaXdpYVdGMElqb3hOak0zTnpZMk16Z3dNakEyZlE=',
  verbose: true
)

numero_convenio = 3128557
system_identifier = "0000003337"
params = {
  "numeroConvenio": numero_convenio,
  "dataVencimento": (Time.now + (60 * 60 * 24 * 5)).strftime('%d.%m.%Y'),
  "valorOriginal": Random.rand(10.0..500.0).round(2),
  "numeroCarteira": 17,
  "numeroVariacaoCarteira": 35,
  "codigoModalidade": 1,
  "dataEmissao": Time.now.strftime('%d.%m.%Y'),
  "codigoAceite": "S",
  "codigoTipoTitulo": 2,
  "indicadorPermissaoRecebimentoParcial": "N",
  "numeroTituloCliente": "000#{numero_convenio}#{system_identifier}",
  "pagador": {
    "tipoInscricao": 1,
    "numeroInscricao": 97965940132,
    "nome": "Odorico Paraguassu",
    "endereco": "Avenida Dias Gomes 1970",
    "cep": 77458000,
    "cidade": "Sucupira",
    "bairro": "Centro",
    "uf": "TO",
    "telefone": "63987654321"
  },
  "beneficiarioFinal": {
    "tipoInscricao": 2,
    "numeroInscricao": 98959112000179,
    "nome": "Dirceu Borboleta"
  }
}

begin
  bb.create(params)
rescue => ex
  puts "[ERROR] #{ex.message}"
end