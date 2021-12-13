# BB Tickets

Serviço auxiliador para uso da API de geração de boletos do Banco do Brasil.

A documentação oficial para uso da API está disponível nesse [link](https://apoio.developers.bb.com.br/referency/post/5f9c2149f39b8500120ab13c).

## Dependências

Para funcionamento do serviço, alguns dependências são necessárias. Dentre elas:

1. [HTTParty](https://github.com/jnunemaker/httparty) (requisições HTTP);

## Como usar?

O serviço é disponibilizado através do arquivo `bb_tickets`. Nele é disponibilizado as seguintes ações:

1. Autenticação;
2. Registro (create);
3. Listagem (index);
4. Visualização (show).

Para auxiliar no uso, está disponível testes no diretório `/examples`.
