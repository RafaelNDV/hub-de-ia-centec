from __future__ import annotations

import asyncio
import json
import os

from mcp import ClientSession
from mcp.client.streamable_http import streamablehttp_client


async def main() -> None:
    url = os.getenv("MCP_TEST_URL", "http://127.0.0.1:8001/mcp")
    async with streamablehttp_client(url) as (read_stream, write_stream, _):
        async with ClientSession(read_stream, write_stream) as session:
            await session.initialize()
            listed = await session.list_tools()
            print("TOOLS=" + ",".join(tool.name for tool in listed.tools))

            for name, arguments in (
                ("resumo_geral", {}),
                ("listar_cursos", {"area": "Tecnologia", "limite": 3}),
                ("obter_turma", {"codigo": "TUR-2604"}),
                ("buscar_turmas", {"status": "inscricoes", "limite": 3}),
                ("resumir_unidades", {"limite": 3}),
                ("listar_unidades", {"limite": 3}),
                ("listar_instrutores", {"limite": 3}),
                (
                    "listar_matriculas",
                    {"ordenar_por": "data_matricula", "ordem": "asc", "limite": 3},
                ),
                (
                    "resumir_matriculas",
                    {"agrupar_por": "aluno", "ordem": "asc", "limite": 3},
                ),
            ):
                result = await session.call_tool(name, arguments)
                if result.isError:
                    raise RuntimeError(f"Tool {name} failed: {result.content}")
                print(name.upper() + "=" + json.dumps(result.structuredContent, ensure_ascii=False))


if __name__ == "__main__":
    asyncio.run(main())
