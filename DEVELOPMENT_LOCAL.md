# Desenvolvimento local

Este ambiente separa a versao original da aplicacao e o codigo em desenvolvimento:

- `http://localhost:3000`: Open WebUI original, executado pela imagem oficial.
- `http://localhost:5173`: frontend local com hot reload.
- `http://localhost:8080`: backend de desenvolvimento com reload automatico.

O backend de desenvolvimento reutiliza o Python e as dependencias da imagem oficial
`v0.11.0`, mas executa os arquivos da pasta local `backend`. Nenhuma imagem nova e
construida durante o desenvolvimento.

## Iniciar

No PowerShell, a partir da raiz do repositorio:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\dev-start.ps1
```

Na primeira execucao, o script instala as dependencias Node com `npm ci`. Depois,
essa etapa so e repetida quando `package-lock.json` mudar.

Mantenha o terminal aberto enquanto estiver usando o frontend. Use `Ctrl+C` para
parar o servidor do frontend.

## Parar o backend de desenvolvimento

Depois de interromper o frontend com `Ctrl+C`, execute:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\dev-stop.ps1
```

O comando nao apaga o volume `hub-ia-dev_open-webui-dev`. Usuarios, configuracoes
e banco de dados do ambiente de desenvolvimento permanecem salvos.

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
