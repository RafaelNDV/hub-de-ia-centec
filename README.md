# Hub de IA Centec

Prova de conceito institucional baseada no Open WebUI. O projeto oferece uma
interface unica para modelos locais e APIs de IA, com integracoes que serao
separadas por nivel de sensibilidade antes da implantacao em producao.

> [!IMPORTANT]
> O ambiente atual e uma POC mista e contem configuracoes pessoais de teste.
> Nao envie informacoes sigilosas para modelos de nuvem. Os arquivos de
> implantacao `cloud` e `secure` sao a base da arquitetura futura; firewall,
> HTTPS, SSO, cofre de segredos e backups ainda precisam ser configurados no
> ambiente institucional.

## Objetivo do produto

O objetivo e entregar um unico aplicativo institucional de IA, acessado por um
unico endereco e um unico login. O usuario podera escolher modelos locais e de
nuvem no mesmo seletor, sem precisar conhecer a infraestrutura que existe por
baixo da interface.

A experiencia sera unica, mas a execucao sera separada em duas zonas:

- `cloud`: modelos externos aprovados, sem acesso a dados ou ferramentas
  institucionais sigilosas;
- `secure`: modelos executados na infraestrutura do Centec, com acesso
  controlado a Gmail, documentos, bancos e outros sistemas internos.

Cada conversa pertence a apenas uma zona. Uma conversa cloud pode alternar
entre modelos cloud e uma conversa segura pode alternar entre modelos locais.
Para cruzar de uma zona para a outra, o usuario deve iniciar uma conversa nova,
sem transferir automaticamente o historico anterior.

## Ambientes do projeto

| Ambiente | Arquivo | Portas padrao | Finalidade |
| --- | --- | --- | --- |
| POC atual | `docker-compose.yaml` | `3000` | Testes locais com Open WebUI e Ollama |
| Desenvolvimento | `docker-compose.dev.yaml` | `5173` e `8080` | Frontend e backend com hot reload |
| Integracao Gmail | `docker-compose.gmail-mcp.yaml` | `8000` local | Gmail MCP usado pela POC |
| Producao cloud | `docker-compose.cloud.yaml` | `3100` local | Somente modelos e APIs de nuvem |
| Producao segura | `docker-compose.secure.yaml` | `3200` e `8000` locais | Modelo local e integracoes institucionais |

Os arquivos de producao vinculam as portas apenas a `127.0.0.1`. Em um
servidor, um proxy reverso com HTTPS publica os servicos para os usuarios.

## Inventario dos arquivos Compose

Um arquivo Compose e uma declaracao de servicos, redes e volumes. Ele nao e um
container por si so e nem todos os arquivos abaixo devem ser iniciados juntos.

| Arquivo | Origem | Uso |
| --- | --- | --- |
| `docker-compose.yaml` | Base atual | POC estavel com Open WebUI e Ollama |
| `docker-compose.dev.yaml` | Centec | Frontend e backend de desenvolvimento com hot reload |
| `docker-compose.gmail-mcp.yaml` | Centec | Gmail MCP e proxy local usados na POC |
| `docker-compose.cloud.yaml` | Centec | Esqueleto da futura implantacao cloud |
| `docker-compose.secure.yaml` | Centec | Esqueleto da futura implantacao segura |
| `docker-compose.gpu.yaml` | Open WebUI | Complemento para GPU NVIDIA |
| `docker-compose.amdgpu.yaml` | Open WebUI | Complemento para GPU AMD/ROCm |
| `docker-compose.api.yaml` | Open WebUI | Complemento que publica a API do Ollama |
| `docker-compose.data.yaml` | Open WebUI | Complemento que guarda modelos Ollama em uma pasta escolhida |
| `docker-compose.otel.yaml` | Open WebUI | Observabilidade com OpenTelemetry e Grafana |
| `docker-compose.playwright.yaml` | Open WebUI | Navegador automatizado para ferramentas e testes |
| `docker-compose.a1111-test.yaml` | Open WebUI | Teste de integracao com geracao de imagens |

Arquivos de complemento podem ser combinados com o principal. Por exemplo, o
suporte a uma GPU NVIDIA seria ativado com:

```powershell
docker compose -f docker-compose.yaml -f docker-compose.gpu.yaml up -d
```

## Arquitetura

```text
                           Usuarios
                              |
                      HTTPS + SSO Centec
                              |
                    Proxy reverso / router
                        /             \
                       /               \
              Ambiente cloud      Ambiente seguro
              Open WebUI Cloud     Open WebUI Seguro
                       |               |          |
               Gateway de IA       Modelo local  Gmail MCP
                       |               |          |
               Provedor externo   Servidor GPU   Google APIs
```

O desenho acima representa as zonas de execucao. A experiencia final desejada
adiciona um unico frontend e um roteador de seguranca na frente delas:

```text
                     https://ia.centec.org.br
                               |
                    Frontend unico + SSO
                               |
                  Roteador de politica e chats
                     /                    \
                    /                      \
             Backend cloud            Backend seguro
                VM cloud                 VM segura
                    |                  /            \
             Gateway externo     Modelo local     Gmail MCP
                    |                  |              |
             APIs aprovadas      Servidor GPU     Google APIs
```

O navegador nao recebe chaves de provedores e nao decide sozinho para onde
enviar uma mensagem. O backend valida a zona da conversa, as permissoes do
usuario, o modelo escolhido, os anexos e as ferramentas solicitadas.

O codigo da aplicacao e unico. A pipeline gera uma imagem versionada, por
exemplo `hub-ia-centec:v1.2.0`, e as duas implantacoes executam essa mesma
imagem com configuracoes, redes, segredos e dados diferentes.

```text
Repositorio -> testes -> docker build -> registry
                                      |-> VM cloud
                                      `-> VM segura
```

### Ambiente cloud

- Habilita apenas uma API compativel com OpenAI.
- Nao habilita Ollama nem conectores de dados institucionais.
- Deve acessar o provedor somente por um gateway controlado.
- Possui banco, historico, segredos e volume exclusivos.

### Ambiente seguro

- Desabilita as APIs OpenAI no backend.
- Executa inferencia local com Ollama na POC e vLLM ou equivalente no servidor.
- Hospeda Gmail MCP e futuros conectores institucionais.
- Deve ter firewall bloqueando provedores de IA externos e liberando somente
  destinos necessarios, como os endpoints autorizados do Google.
- Possui banco, historico, credenciais e volumes exclusivos.

Uma conversa que recebeu dados sigilosos deve permanecer no ambiente seguro.
Para usar um modelo de nuvem, o usuario inicia uma conversa nova e sem contexto
sensivel. A interface pode ser visualmente unica, mas os backends e os dados
continuam separados.

## Experiencia do usuario

O usuario acessara somente `https://ia.centec.org.br`. O seletor de modelos
podera apresentar opcoes como:

```text
gpt-4o-mini                  Cloud
Outro modelo aprovado       Cloud
Llama Centec                 Local seguro
Qwen Centec                  Local seguro
```

Ao criar uma conversa, o primeiro modelo e a politica de dados definem a zona.
O comportamento esperado e:

- permitir troca entre modelos da mesma zona;
- oferecer `Iniciar nova conversa` ao escolher um modelo de outra zona;
- nunca copiar automaticamente o historico entre zonas;
- mostrar Gmail, documentos e ferramentas internas somente na zona segura;
- bloquear conteudo sensivel enviado para cloud e orientar o usuario a abrir
  uma conversa segura;
- mostrar chats cloud e seguros na mesma barra lateral, com identificacao
  visual clara;
- usar o mesmo SSO institucional nos dois backends.

A seguranca nao pode depender apenas de botoes ou avisos no frontend. As regras
devem ser aplicadas no servidor, no gateway e no firewall, pois requisicoes HTTP
podem ser feitas sem usar a interface.

Os Composes `cloud` e `secure` atuais iniciam instancias completas do Open WebUI
e representam a separacao da infraestrutura. Antes da producao, eles evoluirao
para trabalhar atras do frontend e do roteador unicos descritos acima.

## Docker em uma frase

- `Dockerfile`: receita usada para construir a aplicacao.
- Build: processo que executa a receita.
- Imagem: pacote versionado e imutavel produzido pela build.
- Container: instancia em execucao de uma imagem.
- Volume: armazenamento persistente que sobrevive a recriacao do container.
- Rede: controla quais servicos conseguem se comunicar diretamente.

Recriar um container normalmente preserva os volumes. Nao execute
`docker compose down -v` sem confirmar que os dados podem ser apagados.

## Uso atual da POC

Aplicacao estavel:

```powershell
docker compose up -d
docker compose ps
```

Desenvolvimento com hot reload:

```powershell
docker compose -f docker-compose.dev.yaml up -d
docker compose -f docker-compose.dev.yaml ps
```

Integracao Gmail, depois de criar `.env.gmail-mcp` a partir do exemplo:

```powershell
docker compose -f docker-compose.gmail-mcp.yaml up -d
```

O primeiro download ou build pode demorar. Os comandos seguintes reutilizam
imagens, caches e volumes sempre que possivel.

## Implantacoes futuras

As implantacoes cloud e segura ainda nao substituem a POC. Elas exigem uma
imagem local ou publicada e segredos fornecidos fora do repositorio.

```powershell
docker build -t hub-ia-centec:local .
```

Exemplo conceitual para a implantacao cloud:

```powershell
$env:CLOUD_WEBUI_SECRET_KEY = '<segredo>'
$env:CLOUD_LLM_API_KEY = '<segredo>'
docker compose -f docker-compose.cloud.yaml up -d
```

Exemplo conceitual para a implantacao segura:

```powershell
$env:SECURE_WEBUI_SECRET_KEY = '<segredo>'
docker compose -f docker-compose.secure.yaml up -d
```

Em producao, os segredos devem vir de um cofre de segredos ou da plataforma de
implantacao, e nao de arquivos versionados. O `.env.gmail-mcp` real e ignorado
pelo Git; somente `.env.gmail-mcp.example` pode ser publicado.

## Persistencia

| Volume | Conteudo |
| --- | --- |
| `open-webui` | Usuarios, configuracoes e chats da POC atual |
| `ollama` | Modelos locais da POC atual |
| `open-webui-dev` | Dados separados do ambiente de desenvolvimento |
| `cloud-open-webui-data` | Dados futuros do ambiente cloud |
| `secure-open-webui-data` | Dados futuros do ambiente seguro |
| `secure-model-data` | Pesos dos modelos locais do ambiente seguro |
| `secure-google-workspace-creds` | Autorizacoes Google do ambiente seguro |

Para producao institucional, a evolucao prevista inclui PostgreSQL, backups
criptografados, auditoria, SSO, proxy HTTPS, regras de saida de rede e CI/CD.

## Caminho de evolucao

1. Manter a POC mista para aprendizado e testes sem dados sigilosos reais.
2. Consolidar identidade visual, fluxos de usuario e integracoes necessarias.
3. Criar perfis logicos `Cloud` e `Local seguro` ainda no ambiente de teste.
4. Implementar a propriedade imutavel de zona em cada conversa.
5. Implementar o frontend unico e o roteador de politica no backend.
6. Adicionar classificacao de dados, DLP, autorizacao por grupos e auditoria.
7. Publicar uma imagem institucional versionada em um registry controlado.
8. Implantar a zona cloud e a zona segura com bancos, redes e segredos separados.
9. Bloquear por firewall o acesso da zona segura a provedores de IA externos.
10. Migrar GitHub, Google Cloud, OpenAI, dominio e segredos para contas do Centec.
11. Adicionar PostgreSQL, backups criptografados, monitoramento e CI/CD.
12. Validar seguranca, recuperacao de dados, desempenho e experiencia antes de
    liberar o sistema para usuarios reais.

O codigo-fonte permanece unico. A tendencia e gerar uma versao da aplicacao por
release e implanta-la nas duas zonas com configuracoes diferentes. Servicos de
apoio, como inferencia local, gateway e Gmail MCP, possuem suas proprias imagens.

## Contexto para outros assistentes

O arquivo [`docs/PROMPT_CONTEXTO_PROJETO.md`](docs/PROMPT_CONTEXTO_PROJETO.md)
contem um prompt completo e sem segredos para apresentar o projeto a outro GPT.
Ele registra o estado atual, a arquitetura alvo, as decisoes de seguranca, o
roadmap e a forma esperada de colaboracao.

## Base Open WebUI

O restante deste documento e a documentacao original do projeto utilizado como
base. Ela continua disponivel como referencia tecnica e de instalacao.

---

# Open WebUI 👋

![GitHub stars](https://img.shields.io/github/stars/open-webui/open-webui?style=social)
![GitHub forks](https://img.shields.io/github/forks/open-webui/open-webui?style=social)
![GitHub watchers](https://img.shields.io/github/watchers/open-webui/open-webui?style=social)
![GitHub repo size](https://img.shields.io/github/repo-size/open-webui/open-webui)
![GitHub language count](https://img.shields.io/github/languages/count/open-webui/open-webui)
![GitHub top language](https://img.shields.io/github/languages/top/open-webui/open-webui)
![GitHub last commit](https://img.shields.io/github/last-commit/open-webui/open-webui?color=red)
[![Discord](https://img.shields.io/badge/Discord-Open_WebUI-blue?logo=discord&logoColor=white)](https://discord.gg/5rJgQTnV4s)
[![](https://img.shields.io/static/v1?label=Sponsor&message=%E2%9D%A4&logo=GitHub&color=%23fe8e86)](https://github.com/sponsors/open-webui)

![Open WebUI Banner](./banner.png)

**Open WebUI is an [extensible](https://docs.openwebui.com/features/extensibility/plugin), feature-rich, and user-friendly self-hosted AI platform designed to operate entirely offline.** It supports various LLM runners like **Ollama** and **OpenAI-compatible APIs**, with **built-in inference engine** for RAG, making it a **powerful AI deployment solution**.

Passionate about open-source AI? [Join our team →](https://careers.openwebui.com/)

![Open WebUI Demo](./demo.png)

> [!TIP]  
> **Looking for an [Enterprise Plan](https://docs.openwebui.com/enterprise)?** – **[Speak with Our Sales Team Today!](https://docs.openwebui.com/enterprise)**
>
> Get **enhanced capabilities**, including **custom theming and branding**, **Service Level Agreement (SLA) support**, **Long-Term Support (LTS) versions**, and **more!**

For more information, be sure to check out our [Open WebUI Documentation](https://docs.openwebui.com/).

## Key Features of Open WebUI ⭐

- 🚀 **Effortless Setup**: Install seamlessly via pip, uv, Docker, or Kubernetes (kubectl, kustomize, or helm), with `:ollama` and `:cuda` tagged images available for container deployments.

- 🤝 **Broad Model & API Integration**: Connect any OpenAI-compatible API alongside local Ollama models. Point the API URL at **LMStudio, GroqCloud, Mistral, OpenRouter, vLLM, and more** to mix and match providers freely.

- 🔐 **Granular RBAC & User Groups**: Administrators define detailed roles, groups, and permissions, giving each user exactly the access they need. Secure by default, with tailored experiences per group.

- 🧩 **Plugin Support**: Extend Open WebUI with **Filters**, **Actions**, **Pipes**, **Tools**, and **Skills**. Connect external services through **MCP**, **MCPO**, and **OpenAPI tool servers**. Build custom integrations, rate limits, approval flows, data connections, and more.

- 🤖 **Models & Agents**: Wrap any base model with custom instructions, tools, and knowledge to build specialized agents. Supports dynamic variables, per-user/group access control, and community preset imports via [Open WebUI Community](https://openwebui.com/).

- 📝 **Notes**: A dedicated workspace for content outside conversations. Draft with a rich editor, use AI to rewrite selected text, and attach notes to any chat for full-context injection.

- 📢 **Channels**: Real-time shared spaces where your team and AI models collaborate in one timeline. Tag models to draft or critique, with threads, reactions, pins, and access control.

- 🧠 **Persistent Memory**: The AI remembers facts about you across conversations, carrying context from one chat to the next.

- ✅ **Live Workflow & Message Flow**: Watch the AI build and work through checklists in real time. Queue messages while the AI is still responding; they send automatically when it's ready.

- 📅 **Calendar & AI Scheduling**: Built-in personal and shared calendars with month/week/day views, recurring events, color coding, attendees, and reminders. Models manage your schedule conversationally through native function calling.

- ⏱️ **Automations**: Schedule prompts to run on recurring schedules, with runs surfaced on your calendar and each completed run linking back to the chat it produced.

- 📱 **Responsive Design & PWA**: Seamless experience across desktop, laptop, and mobile, with a Progressive Web App for native app-like feel and offline access on localhost.

- ✒️🔢 **Full Markdown and LaTeX Support**: Comprehensive Markdown and LaTeX capabilities for enriched interaction.

- 🎤📹 **Hands-Free Voice/Video Call**: Integrated voice and video calls with multiple Speech-to-Text providers (Local Whisper, OpenAI, Deepgram, Azure) and Text-to-Speech engines (Azure, ElevenLabs, OpenAI, Transformers, WebAPI).

- 💾 **Persistent Artifact Storage**: Built-in key-value storage API for artifacts, enabling journals, trackers, leaderboards, and collaborative tools with personal and shared data scopes.

- 📚 **Local RAG Integration**: Retrieval Augmented Generation backed by 9 vector databases and multiple content-extraction engines (Tika, Docling, Document Intelligence, Mistral OCR, PaddleOCR-vl, external loaders). Supports hybrid search (BM25 + vector) with reranking and full-context mode. Load documents into chat or pull them from your library with the `#` command.

- 🔍 **Web Search for RAG**: Search the web through dozens of providers including `SearXNG`, `Google PSE`, `Brave Search`, `Kagi`, `Mojeek`, `Tavily`, `Perplexity`, `Firecrawl`, `serpstack`, `serper`, `Serply`, `DuckDuckGo`, `SearchApi`, `SerpApi`, `Bing`, `Jina`, `Exa`, `Sougou`, `Azure AI Search`, and `Ollama Cloud`, injecting results directly into the conversation.

- 🌐 **Web Browsing Capability**: Pull websites into chat with the `#` command followed by a URL, or let the model fetch them on its own when needed.

- 🎨 **Image Generation & Editing**: Create and edit images with multiple engines including OpenAI DALL·E, Gemini, ComfyUI (local), and AUTOMATIC1111 (local), supporting both generation and prompt-based editing.

- ⚙️ **Multi-Model Conversations**: Engage several models at once, harnessing their individual strengths in parallel for the best possible responses.

- 📊 **Usage Analytics & Model Evaluation**: Admin dashboards track message volume, token consumption, and cost across users and models. Evaluate models with a built-in arena, A/B testing, and ELO-based leaderboards.

- 🗄️ **Flexible Database & Storage**: Choose SQLite (with optional encryption) or PostgreSQL, and store files locally or on S3, Google Cloud Storage, or Azure Blob Storage.

- 🧬 **Advanced Vector Database Support**: Pick from 9 vector databases: ChromaDB, PGVector, Qdrant, Milvus, Elasticsearch, OpenSearch, Pinecone, S3Vector, and Oracle 23ai.

- 🪪 **Enterprise Authentication & Provisioning**: Full LDAP/Active Directory integration, SSO via trusted headers and OAuth providers, and SCIM 2.0 automated provisioning for identity providers like Okta, Azure AD, and Google Workspace.

- ☁️ **Cloud-Native File Integration**: Native Google Drive and OneDrive/SharePoint file picking for seamless document import from enterprise cloud storage.

- 🔭 **Production Observability**: Built-in OpenTelemetry support for traces, metrics, and logs, plugging into your existing monitoring stack.

- ⚖️ **Horizontal Scalability**: Redis-backed session management and WebSocket support for multi-worker, multi-node deployments behind load balancers.

- 🌐🌍 **Multilingual Support**: Use Open WebUI in your preferred language with i18n support. We're actively seeking contributors to expand language coverage!

- 🌟 **Continuous Updates**: We're committed to improving Open WebUI with regular updates, fixes, and new features.

- 🛡️ **Transparent Security Process**: Security reports are triaged, fixed, and published as open advisories through a documented responsible-disclosure process. See our [Security Policy](https://github.com/open-webui/open-webui/security).

Want to learn more about Open WebUI's features? Check out our [Open WebUI documentation](https://docs.openwebui.com/features) for a comprehensive overview!

## The Open WebUI Ecosystem 🌐

Open WebUI is the core, surrounded by companion apps and infrastructure that extend what your AI can do, where it can reach, and how you run it:

- 💻 **Open WebUI Computer** ([open-webui/computer](https://github.com/open-webui/computer)): A standalone, mobile-first computer and coding agent that runs on the machine you own. Files, terminal, and git in a browser tab, reachable from your phone. Connect it into Open WebUI as a model, or reach it from Telegram, WhatsApp, and more.

- ⚡ **Open Terminal** and **Terminals (Enterprise)** ([open-webui/open-terminal](https://github.com/open-webui/open-terminal) & [open-webui/terminals](https://github.com/open-webui/terminals)): A self-hosted computing environment that plugs into Open WebUI, giving the AI a place to write code, run it, read output, fix errors, and iterate inside the chat. Terminals gives you per-user isolated containers with separate credentials, resource limits, and network rules. Automatic lifecycle management on Docker or Kubernetes.

- 🔄 **oikb** ([open-webui/oikb](https://github.com/open-webui/oikb)): Feed your Knowledge Bases from 45+ sources (GitHub, Confluence, ServiceNow, Salesforce, Jira, Slack, SharePoint, Notion, and more), keeping the tools your team already uses continuously in sync.

- 🖥️ **Native Desktop App** ([open-webui/desktop](https://github.com/open-webui/desktop)): Run Open WebUI as a native app on macOS, Windows, and Linux. System-wide Spotlight chat bar with screenshot capture, push-to-talk voice, and optional fully-local inference via a built-in llama.cpp engine.

Want to learn more? Check out our [Open WebUI documentation](https://docs.openwebui.com) for more details!

---

We are incredibly grateful for the generous support of our sponsors. Their contributions help us to maintain and improve our project, ensuring we can continue to deliver quality work to our community. Thank you!

## How to Install 🚀

### Installation via Python pip 🐍

Open WebUI can be installed using pip, the Python package installer. Before proceeding, ensure you're using **Python 3.11** to avoid compatibility issues.

1. **Install Open WebUI**:
   Open your terminal and run the following command to install Open WebUI:

   ```bash
   pip install open-webui
   ```

2. **Running Open WebUI**:
   After installation, you can start Open WebUI by executing:

   ```bash
   open-webui serve
   ```

This will start the Open WebUI server, which you can access at [http://localhost:8080](http://localhost:8080)

### Quick Start with Docker 🐳

> [!NOTE]  
> Please note that for certain Docker environments, additional configurations might be needed. If you encounter any connection issues, our detailed guide on [Open WebUI Documentation](https://docs.openwebui.com/) is ready to assist you.

> [!WARNING]
> When using Docker to install Open WebUI, make sure to include the `-v open-webui:/app/backend/data` in your Docker command. This step is crucial as it ensures your database is properly mounted and prevents any loss of data.

> [!TIP]  
> If you wish to utilize Open WebUI with Ollama included or CUDA acceleration, we recommend utilizing our official images tagged with either `:cuda` or `:ollama`. To enable CUDA, you must install the [Nvidia CUDA container toolkit](https://docs.nvidia.com/dgx/nvidia-container-runtime-upgrade/) on your Linux/WSL system.

### Installation with Default Configuration

- **If Ollama is on your computer**, use this command:

  ```bash
  docker run -d -p 3000:8080 --add-host=host.docker.internal:host-gateway -v open-webui:/app/backend/data --name open-webui --restart always ghcr.io/open-webui/open-webui:main
  ```

- **If Ollama is on a Different Server**, use this command:

  To connect to Ollama on another server, change the `OLLAMA_BASE_URL` to the server's URL:

  ```bash
  docker run -d -p 3000:8080 -e OLLAMA_BASE_URL=https://example.com -v open-webui:/app/backend/data --name open-webui --restart always ghcr.io/open-webui/open-webui:main
  ```

- **To run Open WebUI with Nvidia GPU support**, use this command:

  ```bash
  docker run -d -p 3000:8080 --gpus all --add-host=host.docker.internal:host-gateway -v open-webui:/app/backend/data --name open-webui --restart always ghcr.io/open-webui/open-webui:cuda
  ```

### Installation for OpenAI API Usage Only

- **If you're only using OpenAI API**, use this command:

  ```bash
  docker run -d -p 3000:8080 -e OPENAI_API_KEY=your_secret_key -v open-webui:/app/backend/data --name open-webui --restart always ghcr.io/open-webui/open-webui:main
  ```

### Installing Open WebUI with Bundled Ollama Support

This installation method uses a single container image that bundles Open WebUI with Ollama, allowing for a streamlined setup via a single command. Choose the appropriate command based on your hardware setup:

- **With GPU Support**:
  Utilize GPU resources by running the following command:

  ```bash
  docker run -d -p 3000:8080 --gpus=all -v ollama:/root/.ollama -v open-webui:/app/backend/data --name open-webui --restart always ghcr.io/open-webui/open-webui:ollama
  ```

- **For CPU Only**:
  If you're not using a GPU, use this command instead:

  ```bash
  docker run -d -p 3000:8080 -v ollama:/root/.ollama -v open-webui:/app/backend/data --name open-webui --restart always ghcr.io/open-webui/open-webui:ollama
  ```

Both commands facilitate a built-in, hassle-free installation of both Open WebUI and Ollama, ensuring that you can get everything up and running swiftly.

After installation, you can access Open WebUI at [http://localhost:3000](http://localhost:3000). Enjoy! 😄

### Other Installation Methods

We offer various installation alternatives, including non-Docker native installation methods, Docker Compose, Kustomize, and Helm. Visit our [Open WebUI Documentation](https://docs.openwebui.com/getting-started/) or join our [Discord community](https://discord.gg/5rJgQTnV4s) for comprehensive guidance.

### Troubleshooting

Encountering connection issues? Our [Open WebUI Documentation](https://docs.openwebui.com/troubleshooting/) has got you covered. For further assistance and to join our vibrant community, visit the [Open WebUI Discord](https://discord.gg/5rJgQTnV4s).

#### Open WebUI: Server Connection Error

If you're experiencing connection issues, it’s often due to the WebUI docker container not being able to reach the Ollama server at 127.0.0.1:11434 (host.docker.internal:11434) inside the container . Use the `--network=host` flag in your docker command to resolve this. Note that the port changes from 3000 to 8080, resulting in the link: `http://localhost:8080`.

**Example Docker Command**:

```bash
docker run -d --network=host -v open-webui:/app/backend/data -e OLLAMA_BASE_URL=http://127.0.0.1:11434 --name open-webui --restart always ghcr.io/open-webui/open-webui:main
```

### Keeping Your Docker Installation Up-to-Date

Check our Updating Guide available in our [Open WebUI Documentation](https://docs.openwebui.com/getting-started/updating).

### Using the Dev Branch 🌙

> [!WARNING]
> The `:dev` branch contains the latest unstable features and changes. Use it at your own risk as it may have bugs or incomplete features.

If you want to try out the latest bleeding-edge features and are okay with occasional instability, you can use the `:dev` tag like this:

```bash
docker run -d -p 3000:8080 -v open-webui:/app/backend/data --name open-webui --add-host=host.docker.internal:host-gateway --restart always ghcr.io/open-webui/open-webui:dev
```

### Offline Mode

If you are running Open WebUI in an offline environment, you can set the `HF_HUB_OFFLINE` environment variable to `1` to prevent attempts to download models from the internet.

```bash
export HF_HUB_OFFLINE=1
```

## What's Next? 🌟

Discover upcoming features on our roadmap in the [Open WebUI Documentation](https://docs.openwebui.com/roadmap/).

## License 📜

This project contains code under multiple licenses. The current codebase includes components licensed under the Open WebUI License with an additional requirement to preserve the "Open WebUI" branding, as well as prior contributions under their respective original licenses. For a detailed record of license changes and the applicable terms for each section of the code, please refer to [LICENSE_HISTORY](./LICENSE_HISTORY). For complete and updated licensing details, please see the [LICENSE](./LICENSE) and [LICENSE_HISTORY](./LICENSE_HISTORY) files.

## Support 💬

If you have any questions, suggestions, or need assistance, please open an issue or join our
[Open WebUI Discord community](https://discord.gg/5rJgQTnV4s) to connect with us! 🤝

## Security 🛡️

If you believe you've found a security vulnerability, or something that shouldn't be disclosed publicly, please [reach out confidentially through our responsible disclosure program on GitHub](https://github.com/open-webui/open-webui/security). We accept reports only through GitHub, not through any other platform. Thank you for helping us keep Open WebUI secure!

## Star History

<a href="https://star-history.com/#open-webui/open-webui&Date">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="https://api.star-history.com/svg?repos=open-webui/open-webui&type=Date&theme=dark" />
    <source media="(prefers-color-scheme: light)" srcset="https://api.star-history.com/svg?repos=open-webui/open-webui&type=Date" />
    <img alt="Star History Chart" src="https://api.star-history.com/svg?repos=open-webui/open-webui&type=Date" />
  </picture>
</a>

---

Created by [Timothy Jaeryang Baek](https://github.com/tjbck) - Let's make Open WebUI even more amazing together! 💪
