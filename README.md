# BB Tickets

Serviço auxiliador para uso da API de geração de boletos do Banco do Brasil.

A documentação oficial para uso da API está disponível nesse [link](https://apoio.developers.bb.com.br/referency/post/5f9c2149f39b8500120ab13c).

## Dependências

Para funcionamento do serviço, alguns dependências são necessárias. Dentre elas:

1. [HTTParty](https://github.com/jnunemaker/httparty) (requisições HTTP);
1. [BRCobranca](https://github.com/kivanio/brcobranca) (Emissão de bloquetos de cobrança para bancos brasileiros);

## Como usar?

O serviço é disponibilizado através do arquivo `bb_tickets`. Nele é disponibilizado as seguintes ações:

1. Autenticação;
2. Registro (create);
3. Listagem (index);
4. Visualização (show);
5. Baixa/cancelamento (destroy);
6. Geração do layout do boleto (generate_layout).

Para auxiliar no uso, está disponível testes no diretório `/examples`.

## Coreção de erros

1. RGhost::RenderException: Error: /invalidfileaccess in --run--

   **Descrição do erro**

   ```sh
     RGhost::RenderException: Error: /invalidfileaccess in --run--
     Operand stack:
         (/Users/pedropaulomarquesdelima/.rvm/gems/ruby-2.7.2/gems/brcobranca-9.2.4/lib/brcobranca/boleto/template/../../arquivos/templates/modelo_generico.eps)   (r)
     Execution stack:
         %interp_exit   .runexec2   --nostringval--   run   --nostringval--   2   %stopped_push   --nostringval--   run   run   false   1   %stopped_push   1990   1   3   %oparray_pop   1989   1   3   %oparray_pop   1977   1   3   %oparray_pop   1833   1   3   %oparray_pop   --nostringval--   %errorexec_pop   .runexec2   --nostringval--   run   --nostringval--   2   %stopped_push   --nostringval--   run   1990   1   3   %oparray_pop   run
     Dictionary stack:
         --dict:732/1123(ro)(G)--   --dict:0/20(G)--   --dict:244/300(L)--
     Current allocation mode is local
     Last OS error: Permission denied
     Current file position is 3917

     from /Users/pedropaulomarquesdelima/.rvm/gems/ruby-2.7.2/gems/rghost-0.9.7/lib/rghost/ruby_ghost_engine.rb:88:in `render'
   ```

   **Solução**

   Esse erro foi corrigido no commit `https://github.com/kivanio/brcobranca/commit/c5bb8ab493bee3bc072e857fd8629673e911aba6`. Mas, caso o erro persista, insira a linha de código abaixo no arquivo `/path/to/gems/brcobranca-9.2.4/lib/brcobranca/boleto/template/rghost.rb`, na linha 27.

   ```ruby
     RGhost::Config::GS[:default_params] << '-dNOSAFER'
   ```
