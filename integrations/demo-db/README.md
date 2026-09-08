# Banco demonstrativo da Cora

Base PostgreSQL local com dados 100% sinteticos para testar ferramentas e
modelos em nuvem. Nenhuma unidade, pessoa ou operacao representa dados reais.

## Conteudo

- 6 unidades ficticias
- 12 cursos
- 12 instrutores ficticios
- 24 turmas em diferentes estados
- centenas de matriculas geradas deterministicamente
- visoes prontas de ocupacao de turmas e resumo por unidade

O administrador local e usado apenas para manutencao. O futuro servidor MCP
conecta como `cora_demo_reader`, que possui somente permissao de leitura.

## Servidor MCP

O servico `demo-db-mcp` expoe ferramentas de consulta em tempo real:

- `resumo_geral`
- `listar_cursos`
- `buscar_turmas`
- `obter_turma`
- `resumir_unidades`
- `listar_unidades`
- `listar_instrutores`
- `listar_matriculas`
- `resumir_matriculas`

O servidor nao oferece SQL livre nem operacoes de escrita. Dentro das redes
Docker da Cora, seu endpoint e `http://cora-demo-db-mcp:8001/mcp`. Para testes
locais no Windows, tambem esta disponivel em `http://127.0.0.1:8001/mcp`.

## Iniciar e verificar

```powershell
docker compose -f docker-compose.demo-db.yaml up -d
docker compose -f docker-compose.demo-db.yaml ps
```

O PostgreSQL fica acessivel apenas neste computador em `127.0.0.1:5433`.
Os scripts da pasta `init` sao executados somente quando o volume e criado pela
primeira vez.
