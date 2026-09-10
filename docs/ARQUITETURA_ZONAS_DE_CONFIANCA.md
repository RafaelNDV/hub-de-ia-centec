# Arquitetura de zonas de confiança do Cora

> Status: plano técnico de referência — ainda não implementado integralmente.
>
> Última revisão: 9 de setembro de 2026.
>
> Este documento descreve a direção aprovada para separar modelos, conversas,
> arquivos, memórias e ferramentas entre uma zona Cloud e uma zona Segura. Ele
> deve ser lido antes de qualquer mudança estrutural relacionada a modelos,
> histórico, MCP, RAG, áudio, autenticação ou implantação.

## 1. Propósito

O Cora deve oferecer uma única experiência para o usuário, mas operar sobre
dois domínios de confiança realmente distintos:

- **Cloud:** modelos externos aprovados, usados somente com dados permitidos
  para processamento fora da infraestrutura institucional.
- **Segura:** modelos locais ou institucionais e integrações autorizadas,
  destinadas a dados internos ou sensíveis.

A separação não pode depender apenas de uma cor na interface, de uma instrução
ao modelo ou da atenção do usuário. O servidor precisa impedir tecnicamente que
o conteúdo de uma conversa segura seja enviado a um modelo Cloud.

Este documento transforma essa intenção em:

- invariantes de segurança;
- arquitetura recomendada;
- fluxo de dados;
- responsabilidades de cada componente;
- mudanças previstas no código e no banco;
- estratégia de migração;
- testes de não vazamento;
- etapas de implementação e critérios de aceite.

## 2. O que este plano não afirma

Os arquivos <code>docker-compose.cloud.yaml</code> e
<code>docker-compose.secure.yaml</code> existentes são uma base útil, mas não
significam que a separação de produção já esteja pronta.

No estado atual:

- a POC principal continua sendo um ambiente de desenvolvimento misto;
- o Open WebUI ainda permite selecionar modelos sem um vínculo imutável entre
  conversa e zona;
- memória, arquivos, ferramentas e tarefas auxiliares ainda não foram
  classificados integralmente por zona;
- redes Docker, sozinhas, não comprovam bloqueio de saída na máquina host;
- SSO, HTTPS institucional, cofre de segredos, backup, monitoramento e regras de
  firewall ainda precisam ser projetados e validados no ambiente de destino.

Até a conclusão dos critérios deste documento, não se deve colocar dados
sigilosos na POC nem apresentar os dois arquivos de Compose como uma garantia de
isolamento.

## 3. Decisões fundamentais

As seguintes regras são invariantes. Mudá-las exige uma decisão arquitetural
registrada.

### 3.1 Uma conversa pertence a exatamente uma zona

Cada conversa persistida terá um campo servidor-controlado
<code>execution_zone</code>, com os valores:

- <code>cloud</code>;
- <code>secure</code>.

O valor nasce antes do primeiro processamento que possa enviar dados para um
modelo e não muda durante a vida da conversa.

### 3.2 O servidor determina a zona

O navegador pode solicitar um modelo, mas não tem autoridade para declarar a
zona. O backend consulta um catálogo de políticas, identifica a zona do modelo
e valida a operação.

Campos enviados pelo cliente, metadados editáveis do modelo ou parâmetros de
URL nunca são a fonte final de autorização.

### 3.3 Troca entre zonas cria conversa vazia

É permitido trocar de modelo dentro da mesma zona.

Ao tentar trocar de Cloud para Segura ou de Segura para Cloud, o sistema:

1. bloqueia a continuação da conversa atual;
2. explica por que a troca foi bloqueada;
3. oferece criar uma nova conversa vazia na zona escolhida;
4. não copia mensagens, resumo, memória, anexos, resultados de ferramentas ou
   identificadores de respostas anteriores.

A regra será inicialmente simétrica. Mesmo a direção Cloud para Segura será
bloqueada para manter um modelo mental simples e evitar comportamentos
especiais difíceis de auditar.

### 3.4 Segurança é aplicada em camadas

A proteção deve existir simultaneamente em:

- banco e armazenamento separados;
- catálogos de modelos e ferramentas separados;
- validação em todos os caminhos de inferência;
- credenciais distintas;
- redes e regras de saída distintas;
- interface com sinalização clara;
- testes automáticos de não vazamento;
- logs e auditoria sem conteúdo sensível.

Se uma camada falhar, as demais ainda devem impedir ou revelar o erro.

### 3.5 Negar por padrão

Recurso sem classificação, conversa antiga sem zona, modelo desconhecido,
ferramenta sem política ou arquivo sem origem conhecida deve ser tratado como
<code>secure</code> ou bloqueado até classificação explícita.

### 3.6 Administrador não ignora isolamento

Ser administrador do Open WebUI não concede automaticamente permissão para
misturar zonas. Uma eventual função de emergência precisa ser separada,
temporária, justificada e auditada. Ela não faz parte do MVP.

## 4. Vocabulário

| Termo | Significado |
| --- | --- |
| Zona | Domínio de execução e armazenamento de uma conversa. |
| Cloud | Zona que pode chamar provedores externos aprovados. |
| Segura | Zona que não envia prompts a provedores públicos de IA. |
| Catálogo de política | Registro mantido pelo servidor que classifica modelos e recursos. |
| Recurso derivado | Dado criado a partir de outro dado, como embedding, resumo, título ou transcrição. |
| MCP | Protocolo pelo qual um modelo recebe ferramentas estruturadas para consultar ou executar ações. |
| BFF | Backend for Frontend; camada fina que autentica, agrega e roteia chamadas da interface. |
| Plano de dados | Componentes que processam conteúdo de conversas. |
| Plano de controle | Componentes que guardam configuração e metadados mínimos, sem conteúdo. |
| Canary | Marcador sintético usado para provar que um dado não atravessou uma fronteira. |

“Segura” não significa obrigatoriamente “sem internet”. Uma ferramenta
institucional pode precisar acessar Gmail, calendário ou outro SaaS aprovado.
Nesse caso, apenas os destinos estritamente necessários devem ser liberados.
O que a zona Segura não pode fazer é enviar conteúdo a um modelo Cloud.

## 5. Escopo de ameaça

### 5.1 Erros que a arquitetura deve impedir

- o usuário selecionar um modelo Cloud dentro de uma conversa Segura;
- o frontend reenviar o histórico Seguro ao endpoint Cloud;
- uma memória criada na zona Segura ser injetada em uma conversa Cloud;
- um resultado do MCP de banco ou Gmail chegar a um modelo Cloud;
- um anexo Seguro ser indexado por um serviço externo;
- título, tags, sugestões ou resumo de uma conversa Segura serem gerados por um
  modelo Cloud;
- áudio Seguro ser transcrito ou sintetizado por uma API externa;
- uma configuração administrativa expor ferramentas Seguras no catálogo Cloud;
- um container Seguro alcançar acidentalmente um endpoint público de IA;
- logs, traces ou métricas centralizadas armazenarem prompts e respostas;
- importação, duplicação, compartilhamento ou fork removerem a classificação.

### 5.2 Limites conhecidos

Nenhuma arquitetura do aplicativo impede totalmente que um usuário autorizado
copie manualmente um dado e o cole em uma nova conversa Cloud. A separação aqui
protege contra vazamento provocado pelo sistema, por configuração incorreta e
por uso acidental.

Proteções contra exfiltração deliberada exigem controles adicionais, como DLP,
políticas institucionais, restrição de copiar e colar, gestão do dispositivo e
auditoria. DLP pode complementar a arquitetura, mas não deve ser a fronteira
principal.

Também ficam fora deste primeiro escopo:

- proteger uma máquina já comprometida por malware ou administrador hostil;
- prometer confidencialidade contra um operador com acesso irrestrito ao host;
- permitir compartilhamento de contexto entre zonas;
- classificar automaticamente todo dado institucional com precisão perfeita.

## 6. Estado atual e lacunas técnicas

O Cora é derivado do Open WebUI. Hoje, uma conversa armazena mensagens e a lista
de modelos escolhidos, mas não possui uma coluna explícita e imutável de zona.

Pontos relevantes do código atual:

- <code>backend/open_webui/models/chats.py</code> define a persistência de
  conversas;
- <code>backend/open_webui/main.py</code> recebe a geração e atualiza os modelos
  associados à conversa;
- <code>backend/open_webui/utils/middleware.py</code> recompõe o histórico,
  carrega ferramentas, memórias e tarefas auxiliares;
- <code>backend/open_webui/routers/openai.py</code> constrói chamadas para
  modelos compatíveis com OpenAI;
- <code>backend/open_webui/utils/memory.py</code> pode buscar memórias por
  usuário e inseri-las no contexto;
- <code>backend/open_webui/utils/task.py</code> escolhe modelos para títulos,
  sugestões e outras tarefas;
- <code>src/lib/components/chat/Chat.svelte</code> controla modelos,
  ferramentas e recursos escolhidos no chat;
- <code>backend/open_webui/config.py</code> contém configurações de memória,
  áudio, embeddings e provedores.

Consequências:

1. trocar o modelo na mesma conversa pode reaproveitar o histórico;
2. memória global do usuário pode atravessar conversas;
3. recursos auxiliares podem usar um modelo diferente do modelo visível;
4. ferramentas são filtradas principalmente por acesso do usuário, não pela
   compatibilidade com a zona;
5. as URLs e chaves de STT/TTS podem herdar configuração de OpenAI;
6. um embedding externo, pesquisa Web ou ferramenta remota também pode revelar
   dados mesmo que o modelo principal seja local.

Esses pontos não são defeitos isolados. São caminhos de dados que precisam ser
incluídos no mesmo mecanismo central de política.

## 7. Arquitetura alvo

~~~text
                              Usuário
                                 |
                         HTTPS + SSO/OIDC
                                 |
                    Frontend único do Cora (SPA)
                                 |
                  Gateway/BFF de política e roteamento
                         /                 \
                /api/cloud/*          /api/secure/*
                    |                       |
          Backend Cora Cloud       Backend Cora Seguro
             |          |             |            |
        DB/arquivos   Gateway IA   DB/arquivos   Inferência local
          Cloud         Cloud        Seguros        / institucional
                          |                           |
                 Provedores aprovados         MCPs institucionais
                                                 e egressos aprovados
~~~

### 7.1 Princípio de implantação

Os dois backends usam o mesmo código e, de preferência, a mesma versão de
imagem. O comportamento muda por configuração assinada/controlada e pelo
ambiente:

- <code>EXECUTION_ZONE=cloud</code> no backend Cloud;
- <code>EXECUTION_ZONE=secure</code> no backend Seguro.

Cada backend expõe apenas modelos e recursos da própria zona. Assim, mesmo um
erro no roteamento da interface não transforma o backend Cloud em uma ponte
para o banco Seguro, nem dá ao backend Seguro uma chave de provedor externo.

### 7.2 Um frontend, dois planos de dados

O frontend é um único artefato estático. Ele apresenta as duas zonas, mas não
guarda segredos e não aplica sozinho a segurança.

O proxy publica rotas de mesma origem:

- <code>/api/cloud/...</code> para o backend Cloud;
- <code>/api/secure/...</code> para o backend Seguro;
- <code>/api/control/...</code> para autenticação e agregação mínima, se essa
  camada for necessária.

Isso evita CORS complexo e permite um domínio institucional único.

### 7.3 Papel do gateway

O gateway:

- valida a sessão institucional;
- resolve a zona a partir de identificadores e políticas do servidor;
- encaminha apenas para o backend correto;
- rejeita combinações incoerentes;
- registra auditoria sem corpo de prompt;
- agrega listas mínimas para a interface.

Ele não deve:

- manter uma cópia central dos históricos;
- guardar anexos;
- possuir credenciais de MCP;
- acessar diretamente os bancos de conteúdo;
- registrar corpo de requisição ou resposta em logs.

O gateway inevitavelmente pode observar dados em trânsito se encaminhar
requisições. Portanto, é um componente confiável, deve rodar na infraestrutura
institucional e não deve persistir os corpos.

### 7.4 Contenção própria de cada backend

Além do gateway, cada backend valida sua configuração:

- o backend Cloud rejeita modelos, chats e ferramentas Seguras;
- o backend Seguro rejeita modelos Cloud;
- IDs de recursos são resolvidos no banco local daquele backend;
- nenhuma chamada aceita um histórico completo fornecido pelo browser como
  substituto do histórico persistido;
- para chat existente, o servidor recompõe o contexto do próprio banco.

Essa segunda validação reduz o impacto de bugs no frontend ou no proxy.

## 8. Catálogo de política

O servidor precisa de uma fonte autoritativa para classificar modelos e
recursos. O catálogo não deve ser um campo livre editável por qualquer
administrador da interface.

Uma representação conceitual:

~~~json
{
  "models": {
    "gpt-5-mini-institucional": {
      "zone": "cloud",
      "provider": "openai-approved",
      "enabled": true,
      "capabilities": ["chat", "tools", "stt", "tts"],
      "allowed_data_classes": ["public", "approved_internal"],
      "allowed_tool_ids": ["public_web_search"]
    },
    "modelo-local-institucional": {
      "zone": "secure",
      "provider": "local-inference",
      "enabled": true,
      "capabilities": ["chat", "tools"],
      "allowed_data_classes": ["public", "internal", "restricted"],
      "allowed_tool_ids": ["academic_database_readonly"]
    }
  },
  "tools": {
    "academic_database_readonly": {
      "zone": "secure",
      "side_effect": "read",
      "data_class": "restricted"
    }
  }
}
~~~

Campos mínimos de um modelo:

- ID interno estável;
- zona;
- provedor;
- endpoint permitido;
- capacidades habilitadas;
- classes de dados aceitas;
- ferramentas autorizadas;
- política de retenção;
- estado ativo/inativo;
- versão e data da aprovação.

Campos mínimos de uma ferramenta:

- ID estável;
- zona;
- servidor MCP de origem;
- leitura ou escrita;
- tipo de dado;
- necessidade de confirmação;
- destinos de rede necessários;
- versão do contrato;
- responsável pela aprovação.

O catálogo pode começar como configuração versionada e evoluir para um serviço
de política. Mesmo quando houver interface administrativa, alterações precisam
de validação, auditoria e princípio de menor privilégio.

## 9. Modelo de dados

### 9.1 Conversa

Adicionar uma coluna real em <code>Chat</code>:

~~~text
execution_zone: enum("cloud", "secure"), NOT NULL, imutável
~~~

Não guardar essa informação apenas dentro do JSON de <code>meta</code>. Uma
coluna explícita permite constraint, índice, migração, consulta e auditoria.

Campos complementares recomendados:

- <code>policy_version</code>: versão do catálogo usada na criação;
- <code>created_by_subject</code>: identificador institucional estável;
- <code>classification</code>: classificação de dados, separada da zona;
- <code>origin</code>: normal, import, fork ou migração;
- <code>retention_policy_id</code>: política aplicável.

### 9.2 Identificadores

IDs não devem permitir colisão entre os dois bancos. Há duas opções:

1. UUID global e a zona guardada em índice de controle;
2. identificador opaco com namespace interno, sem confiar no prefixo para
   autorização.

O prefixo pode ajudar na depuração, mas o servidor sempre consulta a origem
autoritativa.

### 9.3 Recursos derivados

Todo recurso derivado herda a zona da origem:

~~~text
mensagem segura
  -> título seguro
  -> resumo seguro
  -> embedding seguro
  -> memória segura
  -> arquivo extraído seguro
  -> resultado de ferramenta seguro
~~~

Mover um derivado para outra zona exige um processo futuro de revisão e
desclassificação. Não haverá promoção automática no MVP.

## 10. Máquina de estados da conversa

Estados conceituais:

~~~text
RASCUNHO SEM CONTEÚDO
       | escolha de modelo/arquivo/ferramenta
       v
  CLOUD ou SECURE  ----------------------+
       |                                 |
       | modelo da mesma zona            | modelo de outra zona
       v                                 v
  permanece na zona              409 ZONE_MISMATCH
                                      |
                                      v
                            nova conversa vazia
~~~

Regras:

- a zona deve ser definida antes do primeiro upload ou uso de ferramenta;
- selecionar um modelo da mesma zona não altera a conversa;
- remover o modelo não remove a zona;
- uma conversa temporária também recebe zona durante sua existência;
- fork e duplicação preservam a zona;
- importação sem classificação entra em quarentena Segura;
- conversa legada sem zona é migrada para Segura por padrão;
- exclusão remove dados apenas do armazenamento correspondente;
- restauração de backup não pode reclassificar a conversa.

## 11. Fluxo de uma mensagem

Para cada envio:

1. o gateway autentica o usuário;
2. resolve o backend dono do chat;
3. o backend carrega a conversa e seu <code>execution_zone</code>;
4. verifica propriedade ou permissão de acesso;
5. resolve o modelo solicitado no catálogo servidor-controlado;
6. compara zona do chat, backend e modelo;
7. resolve arquivos, memórias e coleções;
8. resolve ferramentas e servidores MCP permitidos;
9. escolhe STT/TTS, embeddings e tarefas auxiliares da mesma zona;
10. recompõe o histórico no servidor;
11. remove parâmetros não autorizados enviados pelo cliente;
12. envia a solicitação somente ao destino permitido;
13. registra metadados de auditoria sem conteúdo;
14. persiste resposta e derivados no mesmo domínio.

Qualquer falha de classificação interrompe o fluxo antes da inferência.

### 11.1 Contrato de erro sugerido

~~~json
{
  "error": {
    "code": "ZONE_MISMATCH",
    "message": "Esta conversa pertence à zona Segura.",
    "chat_zone": "secure",
    "requested_model_zone": "cloud",
    "allowed_action": "CREATE_EMPTY_CHAT",
    "request_id": "opaque-id"
  }
}
~~~

Status recomendado: <code>409 Conflict</code> para troca incompatível e
<code>403 Forbidden</code> quando o usuário não possui acesso ao recurso.

Erros internos não devem devolver endpoint, chave, prompt completo ou detalhes
da rede.

## 12. Histórico e contexto

Um provedor de IA recebe apenas o conteúdo colocado na requisição feita pelo
backend. Ele não adquire acesso automático a todas as outras conversas do
usuário.

O risco de contexto cruzado vem do próprio aplicativo quando ele injeta:

- histórico da conversa;
- memória global;
- documentos recuperados;
- resultados de ferramentas;
- resumo de mensagens antigas;
- títulos ou metadados;
- identificadores de estado do provedor.

Portanto:

- o histórico é carregado somente do banco da zona;
- a requisição do browser não pode fornecer arbitrariamente mensagens antigas;
- identificadores como <code>previous_response_id</code> não atravessam zonas;
- cache de prompt e cache de resposta precisam incluir a zona na chave;
- filas de geração precisam carregar e validar a zona;
- retries não podem cair em provedor de outra zona;
- fallback automático entre Cloud e Segura é proibido.

## 13. Memória

Memória global por usuário é incompatível com o isolamento se não for
particionada.

Para o MVP:

- memória Cloud e memória Segura ficam em bancos separados;
- consultas de memória sempre incluem a zona;
- memória Segura nunca é sincronizada com a Cloud;
- desabilitar memória é a opção segura até o particionamento estar testado;
- exclusão e retenção funcionam separadamente em cada zona.

Uma preferência aparentemente inocente também pode ter sido derivada de uma
conversa sensível. Por isso, não haverá lista global compartilhada por padrão.

Evolução possível:

- categoria explícita “preferência não sensível”;
- revisão do usuário antes de copiar;
- registro de origem e consentimento;
- cópia, e não referência, para evitar leitura cruzada.

## 14. Arquivos, documentos e RAG

O usuário escolhe a zona antes do upload. O arquivo é enviado diretamente ao
armazenamento daquela zona.

Cada etapa herda a zona:

- upload;
- antivírus;
- extração de texto;
- OCR;
- divisão em trechos;
- embeddings;
- banco vetorial;
- reranking;
- recuperação;
- citações;
- arquivos temporários.

Requisitos:

- buckets, volumes ou namespaces e chaves separados;
- URLs assinadas emitidas pelo backend correto;
- modelo de embedding Seguro executado localmente;
- OCR e reranker Seguros não podem chamar API externa;
- limpeza garantida de temporários;
- checksum e origem auditáveis;
- nenhuma indexação global compartilhada;
- coleta de lixo e backup independentes.

Se o modelo de embedding ou reranker não tiver zona conhecida, a operação é
bloqueada.

## 15. Ferramentas e MCP

MCP não é uma fronteira de segurança por si só. Ele expõe ao modelo descrições
de funções e devolve resultados que podem entrar no contexto.

### 15.1 Regras

- ferramentas são filtradas no servidor antes de serem mostradas ao modelo;
- ferramenta Segura nunca aparece no schema enviado a modelo Cloud;
- resultado de ferramenta herda a zona da chamada;
- tokens OAuth e chaves ficam apenas no backend/MCP correspondente;
- um MCP de escrita exige confirmação humana e idempotência;
- timeouts, limites de linhas e paginação evitam consultas sem controle;
- argumentos são validados por schema;
- consultas ao banco usam usuário de menor privilégio;
- logs não guardam resultados completos;
- prompt injection vindo de e-mail, documento ou banco é tratado como dado, não
  como instrução de sistema.

### 15.2 Banco acadêmico

Para acesso de leitura:

- MCP na zona Segura;
- credencial somente leitura;
- views ou funções aprovadas quando possível;
- limites de resultado;
- paginação e ordenação explícitas;
- máscara de campos conforme perfil;
- timeout de consulta;
- trilha de auditoria por usuário e ferramenta.

Dar ao MCP acesso a SQL arbitrário pode ser útil para analistas autorizados,
mas amplia muito o risco. Se for necessário, usar réplica somente leitura,
statement timeout, allowlist de schemas, bloqueio de comandos de escrita e
limite de custo.

### 15.3 Gmail e serviços externos

O Gmail é um serviço externo, mesmo quando usado pela zona Segura. Antes de
conectar e-mail corporativo, confirmar autorização institucional, escopos,
retenção e finalidade.

Quando aprovado:

- liberar somente endpoints Google necessários por proxy de saída;
- usar OAuth por usuário, com escopos mínimos;
- separar leitura de ações de envio/exclusão;
- exigir confirmação antes de enviar, apagar ou alterar;
- não expor o MCP ao backend Cloud;
- não armazenar corpo de e-mail em logs;
- registrar apenas evento, usuário, horário, ferramenta e resultado resumido.

## 16. Recursos que também precisam de zona

O modelo principal não é o único caminho de saída. A política deve cobrir:

| Recurso | Cloud | Segura |
| --- | --- | --- |
| Modelo de chat | Provedor aprovado | Local/institucional |
| Títulos e tags | Mesmo domínio Cloud | Modelo Seguro |
| Sugestões/follow-ups | Mesmo domínio Cloud | Modelo Seguro |
| Resumo/compactação | Mesmo domínio Cloud | Modelo Seguro |
| Embeddings/reranking | Aprovado para Cloud | Local |
| STT/TTS | Cloud aprovado | Browser ou serviço local |
| Pesquisa Web | Serviço aprovado | Desligada ou proxy controlado |
| Imagem | Provedor aprovado | Local ou desligada |
| Execução de código | Sandbox Cloud isolada | Sandbox Segura isolada |
| Terminal | Sem acesso à rede Segura | Política institucional |
| Subagentes | Somente recursos Cloud | Somente recursos Seguros |
| Webhooks/automações | Destinos Cloud aprovados | Destinos Seguros aprovados |

### 16.1 Áudio

Na zona Segura:

- preferir reconhecimento no browser ou serviço STT local;
- usar TTS local;
- não herdar automaticamente URL ou chave global da OpenAI;
- marcar temporários de áudio como Seguros;
- apagar gravações conforme retenção;
- mostrar ao usuário qual motor está ativo.

Na zona Cloud, STT/TTS externos só podem ser usados quando aprovados e devem
seguir a mesma classificação da conversa.

### 16.2 Pesquisa Web

A própria consulta de busca pode revelar informação. A pesquisa Web Segura deve
ficar desabilitada no MVP ou passar por serviço institucional que:

- remova dados desnecessários;
- limite destinos;
- registre apenas metadados;
- trate páginas retornadas como conteúdo não confiável;
- não permita que uma página altere a política do agente.

### 16.3 Tarefas em segundo plano

Título, tags, resumo, sugestões, memória automática, avaliação, moderação e
compactação devem receber <code>execution_zone</code> explicitamente. Não podem
usar um “modelo padrão” global.

Jobs precisam conter:

- ID do chat;
- zona;
- versão da política;
- usuário;
- tipo de tarefa;
- ID de correlação.

O worker valida novamente esses campos antes de processar.

## 17. Identidade, sessão e autorização

### 17.1 SSO

Recomendação:

- provedor OIDC institucional;
- ambos os backends validam o mesmo emissor e o identificador estável
  <code>sub</code>;
- chaves públicas são usadas para validação;
- grupos/claims são convertidos em papéis do Cora;
- sessões têm expiração curta e renovação controlada.

Alternativamente, o gateway pode trocar o token externo por tokens internos
específicos de zona. Essa opção aumenta o controle, mas também a complexidade.

### 17.2 Separação de segredos

- não compartilhar <code>WEBUI_SECRET_KEY</code> entre zonas;
- chaves de modelo Cloud existem apenas no ambiente Cloud;
- credenciais de banco/MCP Seguro existem apenas no ambiente Seguro;
- frontend nunca recebe segredos;
- segredos vêm de cofre, não do Git;
- rotação e revogação são testadas;
- backups não contêm arquivos <code>.env</code> em claro.

### 17.3 Autorização

A decisão final é a interseção de:

~~~text
permissão do usuário
AND zona da conversa
AND zona do backend
AND política do modelo
AND política da ferramenta/recurso
AND classificação do dado
~~~

Uma permissão de administrador não substitui essas condições.

## 18. Experiência do usuário

O frontend único deve reduzir enganos:

- badge persistente “Cloud” ou “Segura” no cabeçalho;
- cores e ícones diferentes, acompanhados de texto;
- modelos agrupados por zona;
- explicação curta sobre quais dados são permitidos;
- escolha de zona antes de anexar arquivo;
- confirmação para ações externas;
- bloqueio visual e servidor ao tentar cruzar zona;
- botão “Abrir nova conversa vazia nesta zona”;
- nunca oferecer “continuar levando o contexto”;
- indicação do motor de voz, busca e ferramentas ativos;
- acessibilidade sem depender apenas de cor.

Texto sugerido para a troca:

> Esta conversa é Segura e contém contexto que não pode ser enviado ao modelo
> Cloud escolhido. Abra uma nova conversa vazia na zona Cloud para continuar.

### 18.1 Lista unificada

O usuário pode visualizar conversas das duas zonas em uma barra lateral única,
mas os dados permanecem separados.

Estratégia recomendada:

1. cada backend fornece uma lista autorizada de suas próprias conversas;
2. o gateway agrega resultados paginados;
3. a interface ordena e mostra o badge da zona;
4. abrir uma conversa direciona as chamadas para o backend dono.

Para maior isolamento, títulos Seguros não devem ser copiados para um banco
Cloud. O plano de controle pode guardar somente:

- ID opaco;
- zona;
- usuário institucional;
- timestamp;
- estado de exclusão.

Se a pesquisa global exigir títulos ou trechos, ela deve ocorrer dentro da
infraestrutura institucional e respeitar a zona. No MVP, pesquisas podem ser
executadas separadamente e os resultados mesclados na interface.

### 18.2 Compartilhamento, exportação e importação

Política inicial:

- compartilhamento público de conversa Segura desligado;
- exportação Segura exige aviso e permissão;
- exportação inclui a classificação;
- importação sem metadado entra na zona Segura;
- conteúdo exportado da Segura não pode ser importado automaticamente na Cloud;
- links compartilhados não revelam título antes da autenticação;
- cópia/fork conserva a zona.

## 19. Rede e implantação

### 19.1 Redes

O backend Cloud:

- acessa apenas seu banco, armazenamento, gateway de IA e serviços autorizados;
- não resolve nem alcança banco, MCP ou rede interna Segura.

O backend Seguro:

- acessa seu banco, armazenamento, inferência e MCPs;
- não possui rota nem credenciais para provedores públicos de IA;
- usa allowlist de saída para serviços institucionais estritamente necessários.

O gateway:

- alcança as APIs HTTP dos dois backends;
- não alcança diretamente bancos nem MCPs;
- recebe somente as portas necessárias.

### 19.2 Docker local versus produção

Redes Docker ajudam no desenvolvimento, mas o host normalmente ainda possui
saída para a internet. Produção precisa de:

- firewall do host ou da rede;
- NetworkPolicy, security groups ou equivalente;
- proxy de saída com allowlist;
- DNS controlado;
- TLS interno;
- bloqueio testado, não apenas documentado.

### 19.3 Persistência

Cada zona possui:

- banco próprio;
- volume de arquivos próprio;
- banco vetorial próprio;
- fila/cache próprios ou particionados com chave de zona;
- política de backup e restauração própria.

Nunca montar o mesmo volume gravável nos dois backends.

## 20. Provedores Cloud e privacidade

Antes de usar um provedor externo, registrar:

- quais endpoints são utilizados;
- quais dados são enviados;
- região e residência de dados;
- retenção;
- uso ou não para treinamento;
- suporte a desativação de armazenamento;
- contratos institucionais;
- suboperadores;
- processo de exclusão.

No caso da API da OpenAI, a documentação oficial informa que dados da API não
são usados para treinamento por padrão, salvo adesão, mas existem diferenças de
retenção entre endpoints e configurações. Por exemplo, fluxos stateful podem
reter estado de aplicação, enquanto chamadas stateless têm comportamento
diferente. A configuração deve ser verificada novamente antes do deploy:

- https://developers.openai.com/api/docs/guides/your-data

Diretrizes para o Cora Cloud:

- preferir chamadas stateless quando o produto não precisar de estado remoto;
- enviar <code>store: false</code> quando suportado e exigido pela política;
- desabilitar conexões diretas configuradas pelo usuário que contornem o
  gateway institucional;
- não confiar apenas em um parâmetro: validar contrato, projeto e endpoint;
- usar dados sintéticos nos testes locais.

## 21. Observabilidade e auditoria

Registrar:

- request ID;
- sujeito institucional;
- chat ID opaco;
- zona;
- modelo e ferramenta por ID;
- decisão da política;
- duração, status e quantidade aproximada;
- confirmação humana de ação;
- versão da aplicação e da política.

Não registrar por padrão:

- prompt;
- resposta;
- corpo de e-mail;
- linhas do banco;
- texto extraído de documento;
- áudio;
- token OAuth;
- chave de API;
- cabeçalho de autorização.

Métricas devem ser separadas por zona sem labels de alta cardinalidade que
contenham conteúdo. Traces precisam de redaction antes da exportação.

Alertas relevantes:

- tentativa de <code>ZONE_MISMATCH</code>;
- modelo ou ferramenta desconhecidos;
- bloqueio de saída de rede;
- chamadas Cloud originadas do namespace Seguro;
- falha repetida de validação;
- crescimento anormal de logs ou filas;
- restauração com dados sem classificação.

## 22. Estratégia de implementação

O trabalho deve ser incremental. Cada fase precisa poder ser validada e
revertida sem destruir a POC.

### Fase 0 — registrar decisões e congelar a linha de base

Entregas:

- este documento aprovado;
- diagrama de fluxo;
- lista de dados permitidos em cada zona;
- ameaça e limitações confirmadas;
- inventário de modelos, ferramentas e integrações;
- backup verificado antes de migrações.

Critério de aceite:

- equipe concorda com as invariantes;
- dúvidas abertas têm responsável;
- nenhum dado sensível é usado na POC.

### Fase 1 — catálogo servidor-controlado

Entregas:

- enum de zona;
- configuração validada de modelos;
- configuração validada de ferramentas;
- endpoint somente leitura para a interface;
- rejeição de itens sem classificação.

Critério de aceite:

- editar uma requisição no navegador não altera a zona;
- modelo desconhecido é bloqueado;
- catálogo tem testes unitários.

Rollback:

- feature flag mantém a UI antiga apenas no ambiente de teste, sem dados
  sensíveis.

### Fase 2 — persistência da zona

Entregas:

- migration de <code>Chat.execution_zone</code>;
- índice e constraint;
- API criando chat com zona;
- regra para legados;
- zona preservada em fork, importação e duplicação.

Critério de aceite:

- toda conversa nova possui zona não nula;
- atualização comum não consegue mudar a coluna;
- conversas legadas ficam Seguras ou em quarentena.

Rollback:

- preservar a coluna e desativar a nova UX; não apagar classificação já
  gravada.

### Fase 3 — motor central de política

Criar uma função/serviço único, usado por todas as entradas:

~~~text
authorize_execution(
  user,
  chat,
  backend_zone,
  model,
  tools,
  files,
  features,
  task_type
) -> Allow | Deny(reason)
~~~

Entregas:

- validação antes de montar o payload;
- contrato de erro estável;
- auditoria sem conteúdo;
- nenhuma regra duplicada apenas no frontend.

Critério de aceite:

- testes de integração cobrem adulteração de payload;
- nenhum adaptador de modelo contorna o motor.

### Fase 4 — histórico e inferência

Entregas:

- histórico reconstruído no servidor;
- modelo validado contra chat;
- bloqueio de fallback entre zonas;
- cache e estado remoto particionados;
- caminhos Chat Completions e Responses cobertos;
- streaming e retry preservam zona.

Critério de aceite:

- canary Seguro nunca aparece no gravador Cloud;
- troca incompatível retorna 409 antes de qualquer chamada externa.

### Fase 5 — recursos derivados

Separar e validar:

- memória;
- arquivos e RAG;
- embeddings/reranking/OCR;
- títulos/tags/sugestões/resumos;
- áudio;
- pesquisa Web;
- geração de imagem;
- execução de código/terminal;
- subagentes e automações.

Critério de aceite:

- cada recurso possui política explícita;
- recurso sem política é negado;
- testes incluem tarefas invisíveis ao usuário.

### Fase 6 — interface única

Entregas:

- seletor e badges;
- aviso de classificação;
- modal de nova conversa vazia;
- seleção de zona antes de upload;
- lista unificada;
- acessibilidade;
- indicação de ferramentas e voz.

Critério de aceite:

- o fluxo normal deixa a zona evidente;
- o usuário não consegue continuar levando contexto ao trocar de zona;
- manipulação manual da UI continua bloqueada pelo backend.

### Fase 7 — topologia local de duas zonas

Entregas:

- Compose específico de teste;
- frontend único;
- dois backends;
- dois bancos/volumes;
- modelo local ou mock;
- gravador Cloud falso;
- MCP ligado somente à Segura;
- regras de rede testáveis.

Critério de aceite:

- toda a matriz da seção 24 passa com dados sintéticos;
- reinício conserva zona e dados no local correto.

### Fase 8 — SSO e plano de controle

Entregas:

- OIDC;
- mapeamento de papéis;
- sessão por zona;
- lista agregada sem copiar conteúdo;
- logout e revogação;
- auditoria.

Critério de aceite:

- usuário desativado perde acesso às duas zonas;
- IDs iguais ou adulterados não cruzam backends;
- títulos Seguros não aparecem em armazenamento Cloud.

### Fase 9 — staging institucional

Entregas:

- firewall e egress proxy;
- HTTPS;
- cofre de segredos;
- backups;
- monitoramento;
- teste de restauração;
- avaliação de desempenho;
- revisão de privacidade e segurança.

Critério de aceite:

- saída do Seguro para provedores de IA falha tecnicamente;
- Cloud não alcança MCP/banco Seguro;
- restore mantém classificação;
- responsáveis institucionais aprovam os dados permitidos.

### Fase 10 — produção gradual

Sequência:

1. usuários técnicos e dados sintéticos;
2. grupo piloto com dados classificados;
3. observação de falhas e auditoria;
4. expansão por unidade;
5. revisão periódica de modelos e ferramentas.

Não habilitar uma integração só porque o código funciona. Ela precisa de dono,
escopo, classificação, política de retenção e procedimento de revogação.

## 23. Ambiente local de validação

O notebook não precisa de um modelo local poderoso para testar isolamento.
Pode-se usar um mock determinístico ou um Ollama pequeno.

Topologia sugerida:

~~~text
cora-frontend
cora-gateway
cora-cloud-backend
cora-cloud-db
cora-cloud-request-recorder
cora-secure-backend
cora-secure-db
cora-secure-model-mock
cora-secure-mcp-demo
~~~

O gravador Cloud falso registra hashes e metadados de payload somente no
ambiente sintético. Ele serve para provar que um canary Seguro não foi enviado.
Não deve ser habilitado com dados reais.

Dados de teste:

- banco acadêmico demonstrativo;
- e-mails falsos;
- documentos artificiais;
- marcadores exclusivos, por exemplo
  <code>DADO_SEGURO_CORA_91827</code>;
- usuários e grupos fictícios.

O ambiente local comprova lógica de aplicação, roteamento e persistência. Ele
não substitui testes de firewall, DNS, SSO, TLS, backup e carga no staging.

## 24. Matriz mínima de testes

| Caso | Resultado obrigatório |
| --- | --- |
| Chat Seguro solicita modelo Cloud | 409; zero chamadas Cloud. |
| Chat Cloud solicita modelo Seguro | 409; nova conversa vazia oferecida. |
| Payload adulterado no DevTools | Backend ignora/rejeita a zona do cliente. |
| Canary em memória Segura | Não aparece em requisição Cloud. |
| Resultado de MCP Seguro | Nunca é enviado ao modelo Cloud. |
| Arquivo Seguro | Existe apenas no armazenamento Seguro. |
| Embedding de arquivo Seguro | Executado somente localmente. |
| Título de chat Seguro | Gerado por modelo Seguro. |
| Resumo/compactação Segura | Não usa tarefa Cloud. |
| STT/TTS Seguro | Nenhuma chamada a API externa. |
| Busca Web Segura desligada | Requisição bloqueada com explicação. |
| Reinício dos serviços | Zona continua igual. |
| Fork/duplicação | Zona é preservada. |
| Import sem zona | Classificado como Seguro/quarentena. |
| Compartilhamento Seguro | Negado no MVP. |
| Admin tenta cruzar zona | Negado e auditado. |
| Backend Cloud tenta alcançar MCP | Conexão falha na rede. |
| Backend Seguro tenta alcançar provedor IA | Conexão falha na rede. |
| Retry/fallback | Permanece na mesma zona. |
| Modelo removido do catálogo | Chat preservado; nova geração bloqueada. |
| Backup e restore | Zona e recursos continuam associados. |
| Exclusão do usuário | Dados removidos segundo retenção nas duas zonas. |

Além de unitários e integração, manter testes end-to-end no browser e testes de
rede executados no staging.

## 25. Mapeamento inicial para o código

Este mapa orienta a investigação; nomes e linhas podem mudar com atualizações
do upstream.

| Área | Arquivos iniciais |
| --- | --- |
| Schema/migration de chat | <code>backend/open_webui/models/chats.py</code>, migrations do backend |
| Entrada de geração | <code>backend/open_webui/main.py</code> |
| Histórico, memória e ferramentas | <code>backend/open_webui/utils/middleware.py</code> |
| Adaptador OpenAI | <code>backend/open_webui/routers/openai.py</code> |
| Seleção de tarefas | <code>backend/open_webui/utils/task.py</code> |
| Memória | <code>backend/open_webui/utils/memory.py</code> |
| Configuração de áudio/RAG | <code>backend/open_webui/config.py</code> |
| Metadados de modelos | <code>backend/open_webui/models/models.py</code> |
| Estado e UX do chat | <code>src/lib/components/chat/Chat.svelte</code> |
| Capacidades padrão | <code>src/lib/constants.ts</code> |
| Implantação inicial | <code>docker-compose.cloud.yaml</code>, <code>docker-compose.secure.yaml</code> |

Antes de editar, localizar todos os caminhos de inferência e tarefas com busca
no repositório. A proteção não estará completa se apenas a tela principal do
chat for alterada.

## 26. Migração e compatibilidade

### 26.1 Conversas existentes

Plano conservador:

1. backup;
2. adicionar coluna anulável;
3. gravar zona em novas conversas;
4. classificar legadas como Seguras;
5. validar contagem e amostras;
6. tornar a coluna não nula;
7. criar constraint de imutabilidade na aplicação e, se viável, no banco.

Não inferir Cloud apenas pelo último modelo, pois a conversa pode ter usado
modelo local, ferramenta ou memória sensível anteriormente.

### 26.2 Modelos removidos

O chat continua visível. Nova geração fica bloqueada até o usuário escolher
outro modelo da mesma zona. Nunca escolher automaticamente um modelo de outra
zona.

### 26.3 Atualizações do Open WebUI

Como o Cora deriva de um projeto upstream:

- manter mudanças de segurança em módulos pequenos e testáveis;
- documentar pontos de integração;
- fixar versões em produção;
- atualizar primeiro em branch;
- executar a matriz de não vazamento;
- comparar migrations;
- revisar novos recursos que enviam dados;
- somente depois promover para staging e produção.

Uma atualização que adiciona nova capacidade deve começar desabilitada até ser
classificada por zona.

## 27. Operação, backup e resposta a incidente

### 27.1 Backup

- criptografia em trânsito e repouso;
- chaves distintas por zona;
- acesso mínimo;
- retenção documentada;
- restore testado periodicamente;
- inventário do que está incluído;
- validação de que zona e metadados são restaurados juntos.

### 27.2 Incidente

Se houver suspeita de vazamento:

1. desabilitar o modelo, ferramenta ou rota afetada;
2. revogar credenciais;
3. preservar logs de auditoria sem ampliar a exposição;
4. identificar request IDs e usuários afetados;
5. consultar retenção do provedor;
6. acionar responsáveis institucionais;
7. corrigir e adicionar teste de regressão;
8. reabilitar somente após revisão.

### 27.3 Revisão periódica

Revisar trimestralmente, ou após atualização relevante:

- catálogo de modelos;
- endpoints e retenção;
- escopos OAuth;
- ferramentas MCP;
- regras de firewall;
- usuários e papéis;
- backups;
- testes de isolamento;
- dependências e vulnerabilidades.

## 28. Decisões ainda abertas

Estas decisões devem virar ADRs antes da implementação correspondente:

1. gateway apenas de roteamento ou BFF com índice global de chats;
2. formato e armazenamento do catálogo de política;
3. tecnologia de inferência institucional;
4. banco e armazenamento de objetos de produção;
5. STT/TTS locais;
6. política de pesquisa Web Segura;
7. classes de dados reconhecidas pela instituição;
8. retenção por zona;
9. modelo de acesso ao banco acadêmico;
10. compartilhamento interno de conversas Seguras;
11. egressos permitidos para Gmail e calendário;
12. tratamento de conversas e arquivos existentes;
13. requisitos de alta disponibilidade e recuperação;
14. limites de custo, latência e concorrência.

Formato sugerido de ADR:

~~~text
Título
Status
Contexto
Decisão
Alternativas consideradas
Consequências
Riscos
Como validar
Como reverter
Responsável e data
~~~

## 29. Definition of Done da separação

A arquitetura só pode ser considerada pronta quando:

- toda conversa possui zona imutável;
- servidor, e não frontend, decide e valida;
- modelos e ferramentas têm catálogo autoritativo;
- histórico, memória, arquivos, RAG, áudio e tarefas estão separados;
- nenhuma credencial Cloud existe na zona Segura;
- nenhuma credencial Segura existe na zona Cloud;
- regras de rede impedem os acessos proibidos;
- interface deixa a zona evidente;
- troca de zona cria chat vazio;
- matriz de testes passa localmente e em staging;
- logs e backups foram revisados;
- SSO, revogação e papéis foram testados;
- documentação operacional existe;
- responsáveis por segurança, privacidade e negócio aprovaram o uso;
- um teste independente confirma que o canary Seguro não chegou ao Cloud.

## 30. Próxima ação recomendada

Não iniciar pela duplicação completa da infraestrutura. A próxima ação de
desenvolvimento, quando houver tempo reservado, deve ser:

1. aprovar as invariantes e decisões abertas mais urgentes;
2. criar o catálogo servidor-controlado;
3. adicionar <code>execution_zone</code> ao domínio de chat;
4. implementar o motor central de política;
5. provar o bloqueio com mocks e canaries;
6. só então separar todos os serviços e preparar o deploy.

Essa ordem cria primeiro a regra que protege o dado e depois amplia a
infraestrutura ao redor dela.
