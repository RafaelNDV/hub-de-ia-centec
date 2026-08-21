# Desenvolvimento local

Este ambiente separa a versao original da aplicacao e o codigo em desenvolvimento:

- `http://localhost:3000`: Open WebUI original, executado pela imagem oficial.
- `http://localhost:5173`: frontend local com hot reload em um container Node 22.
- `http://localhost:8080`: backend de desenvolvimento com reload automatico.

O backend de desenvolvimento reutiliza o Python e as dependencias da imagem oficial
`v0.11.0`, mas executa os arquivos da pasta local `backend`. O frontend usa a imagem
oficial `node:22-bookworm-slim` e executa o Vite diretamente sobre os arquivos locais.
Nenhuma imagem personalizada e construida durante o desenvolvimento.

## Iniciar

No PowerShell, a partir da raiz do repositorio:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\dev-start.ps1
```

Na primeira execucao, o container frontend instala as dependencias Node em um volume
Docker. Depois, essa etapa so e repetida quando `package-lock.json` mudar. Fechar o
terminal nao interrompe o frontend ou o backend.

## Parar o ambiente de desenvolvimento

Para parar os dois containers de desenvolvimento, execute:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\dev-stop.ps1
```

O comando nao apaga os volumes. Usuarios, configuracoes, banco de dados, dependencias
Node e cache do npm permanecem salvos.

O script inicia um container Ollama existente com `docker start`, quando necessario,
mas nunca executa `docker compose up` no ambiente original. Se o Ollama nao existir,
frontend e backend ainda iniciam normalmente para uso com APIs externas.

## O que atualiza automaticamente

- Alteracoes em `src` sao atualizadas pelo Vite no navegador.
- Alteracoes em `backend/open_webui` reiniciam o Uvicorn automaticamente.
- Alteracoes no Dockerfile ou nas dependencias ainda exigem uma nova imagem ou uma
  reinstalacao de dependencias.

## Ver logs do backend

```powershell
docker compose -f docker-compose.dev.yaml logs -f backend
```

## Dados separados

O ambiente original usa o volume `hub-ia_open-webui`. O ambiente de desenvolvimento
usa `hub-ia-dev_open-webui-dev`. Essa separacao evita que uma mudanca de backend ou
uma migracao em desenvolvimento afete o banco usado na demonstracao original.
