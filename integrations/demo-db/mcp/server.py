from __future__ import annotations

import os
from contextlib import contextmanager
from datetime import date, datetime
from decimal import Decimal
from typing import Any, Iterator

import psycopg
from mcp.server.fastmcp import FastMCP
from psycopg.rows import dict_row
from starlette.requests import Request
from starlette.responses import JSONResponse


DATABASE_URL = os.environ["DATABASE_URL"]
MCP_HOST = os.getenv("MCP_HOST", "127.0.0.1")
MCP_PORT = int(os.getenv("MCP_PORT", "8001"))
MAX_RESULTS = 50

mcp = FastMCP(
    "Cora - Banco Demonstrativo",
    instructions=(
        "Ferramentas somente de leitura para consultar a base educacional "
        "sintetica da Cora. Todos os dados sao ficticios. Nunca afirme que "
        "unidades, instrutores ou alunos representam pessoas ou locais reais. "
        "Para pedidos sobre alunos ou matriculas, use listar_matriculas ou "
        "resumir_matriculas. Consulte uma ferramenta antes de afirmar que uma "
        "informacao nao existe."
    ),
    host=MCP_HOST,
    port=MCP_PORT,
    stateless_http=True,
    json_response=True,
)


@contextmanager
def database() -> Iterator[psycopg.Connection[dict[str, Any]]]:
    """Open a short-lived, read-only database connection for one tool call."""
    with psycopg.connect(DATABASE_URL, row_factory=dict_row) as connection:
        connection.execute("SET TRANSACTION READ ONLY")
        yield connection


def rows_to_json(rows: list[dict[str, Any]]) -> list[dict[str, Any]]:
    return [{key: json_value(value) for key, value in row.items()} for row in rows]


def json_value(value: Any) -> Any:
    if isinstance(value, (date, datetime)):
        return value.isoformat()
    if isinstance(value, Decimal):
        return float(value)
    return value


def safe_limit(value: int) -> int:
    if value < 1:
        return 1
    return min(value, MAX_RESULTS)


def safe_offset(value: int) -> int:
    return max(value, 0)


def sort_direction(value: str) -> str:
    normalized = value.strip().lower()
    if normalized not in {"asc", "desc"}:
        raise ValueError("ordem deve ser asc ou desc")
    return normalized.upper()


def optional_date(value: str | None, field_name: str) -> date | None:
    if not value:
        return None
    try:
        return date.fromisoformat(value)
    except ValueError as error:
        raise ValueError(f"{field_name} deve usar o formato AAAA-MM-DD") from error


@mcp.custom_route("/health", methods=["GET"])
async def health(_: Request) -> JSONResponse:
    try:
        with database() as connection:
            connection.execute("SELECT 1").fetchone()
        return JSONResponse({"status": "ok", "database": "connected"})
    except Exception:
        return JSONResponse({"status": "error", "database": "unavailable"}, status_code=503)


@mcp.tool()
def resumo_geral() -> dict[str, Any]:
    """Retorna totais atuais da base ficticia: unidades, cursos, turmas, matriculas e vagas."""
    query = """
        SELECT
            (SELECT count(*) FROM unidades WHERE ativa) AS unidades_ativas,
            (SELECT count(*) FROM cursos WHERE ativo) AS cursos_ativos,
            (SELECT count(*) FROM turmas) AS total_turmas,
            (SELECT count(*) FROM turmas WHERE status = 'inscricoes') AS turmas_com_inscricoes,
            (SELECT count(*) FROM turmas WHERE status = 'em_andamento') AS turmas_em_andamento,
            (SELECT count(*) FROM matriculas WHERE status IN ('confirmada', 'concluida')) AS matriculas_ativas,
            (SELECT coalesce(sum(vagas_disponiveis), 0)
               FROM vw_ocupacao_turmas
              WHERE status IN ('inscricoes', 'em_andamento')) AS vagas_disponiveis
    """
    with database() as connection:
        row = connection.execute(query).fetchone()
    return {key: json_value(value) for key, value in (row or {}).items()}


@mcp.tool()
def listar_cursos(
    area: str | None = None,
    somente_ativos: bool = True,
    limite: int = 20,
) -> dict[str, Any]:
    """Lista cursos ficticios. Pode filtrar pela area e incluir ou nao cursos inativos."""
    query = """
        SELECT
            c.codigo,
            c.nome,
            c.area,
            c.modalidade,
            c.carga_horaria,
            c.ativo,
            count(DISTINCT t.id) AS quantidade_turmas,
            count(DISTINCT t.id) FILTER (
                WHERE t.status IN ('inscricoes', 'em_andamento')
            ) AS turmas_ativas
        FROM cursos c
        LEFT JOIN turmas t ON t.curso_id = c.id
        WHERE (%s::text IS NULL OR c.area ILIKE '%%' || %s::text || '%%')
          AND (%s::boolean = false OR c.ativo = true)
        GROUP BY c.id
        ORDER BY c.area, c.nome
        LIMIT %s
    """
    with database() as connection:
        rows = connection.execute(
            query,
            (area, area, somente_ativos, safe_limit(limite)),
        ).fetchall()
    return {"quantidade": len(rows), "cursos": rows_to_json(rows)}


@mcp.tool()
def listar_unidades(
    somente_ativas: bool = False,
    limite: int = 20,
    deslocamento: int = 0,
) -> dict[str, Any]:
    """Lista todos os dados das unidades ficticias, incluindo totais de turmas e matriculas."""
    query = """
        SELECT
            u.codigo,
            u.nome,
            u.municipio_ficticio,
            u.quantidade_salas,
            u.ativa,
            coalesce(v.quantidade_turmas, 0) AS quantidade_turmas,
            coalesce(v.turmas_ativas, 0) AS turmas_ativas,
            coalesce(v.matriculas_ativas, 0) AS matriculas_ativas,
            count(*) OVER () AS total_encontrado
        FROM unidades u
        LEFT JOIN vw_resumo_unidades v ON v.unidade_codigo = u.codigo
        WHERE (%s::boolean = false OR u.ativa = true)
        ORDER BY u.nome
        LIMIT %s OFFSET %s
    """
    with database() as connection:
        rows = connection.execute(
            query,
            (somente_ativas, safe_limit(limite), safe_offset(deslocamento)),
        ).fetchall()
    total = int(rows[0]["total_encontrado"]) if rows else 0
    cleaned = [{key: value for key, value in row.items() if key != "total_encontrado"} for row in rows]
    return {
        "total_encontrado": total,
        "quantidade_retornada": len(cleaned),
        "proximo_deslocamento": safe_offset(deslocamento) + len(cleaned),
        "unidades": rows_to_json(cleaned),
    }


@mcp.tool()
def listar_instrutores(
    especialidade: str | None = None,
    unidade: str | None = None,
    limite: int = 20,
    deslocamento: int = 0,
) -> dict[str, Any]:
    """Lista instrutores ficticios com especialidade, unidade base e quantidade de turmas."""
    query = """
        SELECT
            i.codigo,
            i.nome_ficticio,
            i.especialidade,
            u.codigo AS unidade_codigo,
            u.nome AS unidade_base,
            count(t.id) AS quantidade_turmas,
            count(t.id) FILTER (
                WHERE t.status IN ('inscricoes', 'em_andamento')
            ) AS turmas_ativas,
            count(*) OVER () AS total_encontrado
        FROM instrutores i
        JOIN unidades u ON u.id = i.unidade_base_id
        LEFT JOIN turmas t ON t.instrutor_id = i.id
        WHERE (%s::text IS NULL OR i.especialidade ILIKE '%%' || %s::text || '%%')
          AND (%s::text IS NULL OR u.nome ILIKE '%%' || %s::text || '%%')
        GROUP BY i.id, u.codigo, u.nome
        ORDER BY i.nome_ficticio
        LIMIT %s OFFSET %s
    """
    params = (
        especialidade,
        especialidade,
        unidade,
        unidade,
        safe_limit(limite),
        safe_offset(deslocamento),
    )
    with database() as connection:
        rows = connection.execute(query, params).fetchall()
    total = int(rows[0]["total_encontrado"]) if rows else 0
    cleaned = [{key: value for key, value in row.items() if key != "total_encontrado"} for row in rows]
    return {
        "total_encontrado": total,
        "quantidade_retornada": len(cleaned),
        "proximo_deslocamento": safe_offset(deslocamento) + len(cleaned),
        "instrutores": rows_to_json(cleaned),
    }


@mcp.tool()
def buscar_turmas(
    curso: str | None = None,
    unidade: str | None = None,
    status: str | None = None,
    inicio_de: str | None = None,
    inicio_ate: str | None = None,
    limite: int = 20,
) -> dict[str, Any]:
    """Busca turmas atuais por nome do curso, unidade, status e intervalo de inicio (AAAA-MM-DD)."""
    status_validos = {
        "planejada",
        "inscricoes",
        "em_andamento",
        "concluida",
        "cancelada",
    }
    if status and status not in status_validos:
        raise ValueError("status deve ser planejada, inscricoes, em_andamento, concluida ou cancelada")

    data_de = optional_date(inicio_de, "inicio_de")
    data_ate = optional_date(inicio_ate, "inicio_ate")
    if data_de and data_ate and data_de > data_ate:
        raise ValueError("inicio_de nao pode ser posterior a inicio_ate")

    query = """
        SELECT
            turma_codigo,
            curso,
            area,
            unidade,
            turno,
            data_inicio,
            data_fim,
            status,
            vagas,
            matriculas_ativas,
            lista_espera,
            vagas_disponiveis,
            percentual_ocupacao
        FROM vw_ocupacao_turmas
        WHERE (%s::text IS NULL OR curso ILIKE '%%' || %s::text || '%%')
          AND (%s::text IS NULL OR unidade ILIKE '%%' || %s::text || '%%')
          AND (%s::text IS NULL OR status = %s::text)
          AND (%s::date IS NULL OR data_inicio >= %s::date)
          AND (%s::date IS NULL OR data_inicio <= %s::date)
        ORDER BY data_inicio, turma_codigo
        LIMIT %s
    """
    params = (
        curso,
        curso,
        unidade,
        unidade,
        status,
        status,
        data_de,
        data_de,
        data_ate,
        data_ate,
        safe_limit(limite),
    )
    with database() as connection:
        rows = connection.execute(query, params).fetchall()
    return {"quantidade": len(rows), "turmas": rows_to_json(rows)}


@mcp.tool()
def obter_turma(codigo: str) -> dict[str, Any]:
    """Consulta uma turma ficticia pelo codigo exato, por exemplo TUR-2604, incluindo ocupacao e instrutor."""
    query = """
        SELECT
            v.turma_codigo,
            v.curso,
            v.area,
            v.unidade,
            i.nome_ficticio AS instrutor,
            v.turno,
            v.data_inicio,
            v.data_fim,
            v.status,
            v.vagas,
            v.matriculas_ativas,
            v.lista_espera,
            v.matriculas_canceladas,
            v.vagas_disponiveis,
            v.percentual_ocupacao
        FROM vw_ocupacao_turmas v
        JOIN turmas t ON t.codigo = v.turma_codigo
        JOIN instrutores i ON i.id = t.instrutor_id
        WHERE upper(v.turma_codigo) = upper(%s)
    """
    with database() as connection:
        row = connection.execute(query, (codigo.strip(),)).fetchone()
    if row is None:
        return {"encontrada": False, "codigo": codigo}
    return {"encontrada": True, "turma": rows_to_json([row])[0]}


@mcp.tool()
def listar_matriculas(
    aluno: str | None = None,
    turma: str | None = None,
    curso: str | None = None,
    unidade: str | None = None,
    status: str | None = None,
    ordenar_por: str = "matricula_codigo",
    ordem: str = "asc",
    limite: int = 50,
    deslocamento: int = 0,
) -> dict[str, Any]:
    """Lista matriculas e alunos ficticios em detalhe, com filtros, ordenacao e paginacao."""
    status_validos = {"confirmada", "lista_espera", "cancelada", "concluida"}
    if status and status not in status_validos:
        raise ValueError("status deve ser confirmada, lista_espera, cancelada ou concluida")

    colunas_ordenacao = {
        "matricula_codigo": "m.codigo",
        "aluno": "m.aluno_alias",
        "data_matricula": "m.data_matricula",
        "status": "m.status",
        "turma": "t.codigo",
        "curso": "c.nome",
        "unidade": "u.nome",
    }
    if ordenar_por not in colunas_ordenacao:
        raise ValueError(
            "ordenar_por deve ser matricula_codigo, aluno, data_matricula, status, turma, curso ou unidade"
        )
    order_column = colunas_ordenacao[ordenar_por]
    direction = sort_direction(ordem)

    query = f"""
        SELECT
            m.codigo AS matricula_codigo,
            m.aluno_alias,
            m.status AS matricula_status,
            m.data_matricula,
            t.codigo AS turma_codigo,
            t.status AS turma_status,
            t.turno,
            t.data_inicio,
            t.data_fim,
            c.codigo AS curso_codigo,
            c.nome AS curso,
            c.area,
            c.modalidade,
            u.codigo AS unidade_codigo,
            u.nome AS unidade,
            i.codigo AS instrutor_codigo,
            i.nome_ficticio AS instrutor,
            count(*) OVER () AS total_encontrado
        FROM matriculas m
        JOIN turmas t ON t.id = m.turma_id
        JOIN cursos c ON c.id = t.curso_id
        JOIN unidades u ON u.id = t.unidade_id
        JOIN instrutores i ON i.id = t.instrutor_id
        WHERE (%s::text IS NULL OR m.aluno_alias ILIKE '%%' || %s::text || '%%')
          AND (%s::text IS NULL OR t.codigo ILIKE '%%' || %s::text || '%%')
          AND (%s::text IS NULL OR c.nome ILIKE '%%' || %s::text || '%%')
          AND (%s::text IS NULL OR u.nome ILIKE '%%' || %s::text || '%%')
          AND (%s::text IS NULL OR m.status = %s::text)
        ORDER BY {order_column} {direction}, m.codigo ASC
        LIMIT %s OFFSET %s
    """
    params = (
        aluno,
        aluno,
        turma,
        turma,
        curso,
        curso,
        unidade,
        unidade,
        status,
        status,
        safe_limit(limite),
        safe_offset(deslocamento),
    )
    with database() as connection:
        rows = connection.execute(query, params).fetchall()
    total = int(rows[0]["total_encontrado"]) if rows else 0
    cleaned = [{key: value for key, value in row.items() if key != "total_encontrado"} for row in rows]
    return {
        "total_encontrado": total,
        "quantidade_retornada": len(cleaned),
        "deslocamento": safe_offset(deslocamento),
        "proximo_deslocamento": safe_offset(deslocamento) + len(cleaned),
        "matriculas": rows_to_json(cleaned),
    }


@mcp.tool()
def resumir_matriculas(
    agrupar_por: str = "aluno",
    ordem: str = "asc",
    limite: int = 50,
    deslocamento: int = 0,
) -> dict[str, Any]:
    """Conta matriculas agrupadas por aluno, turma, curso, unidade ou status, em ordem crescente ou decrescente."""
    dimensoes = {
        "aluno": ("m.aluno_alias", "aluno"),
        "turma": ("t.codigo", "turma"),
        "curso": ("c.nome", "curso"),
        "unidade": ("u.nome", "unidade"),
        "status": ("m.status", "status"),
    }
    if agrupar_por not in dimensoes:
        raise ValueError("agrupar_por deve ser aluno, turma, curso, unidade ou status")
    expression, label = dimensoes[agrupar_por]
    direction = sort_direction(ordem)

    query = f"""
        SELECT
            {expression} AS grupo,
            count(*) AS quantidade_matriculas,
            count(*) FILTER (WHERE m.status IN ('confirmada', 'concluida')) AS matriculas_ativas,
            count(*) OVER () AS total_grupos
        FROM matriculas m
        JOIN turmas t ON t.id = m.turma_id
        JOIN cursos c ON c.id = t.curso_id
        JOIN unidades u ON u.id = t.unidade_id
        GROUP BY {expression}
        ORDER BY quantidade_matriculas {direction}, grupo ASC
        LIMIT %s OFFSET %s
    """
    with database() as connection:
        rows = connection.execute(
            query,
            (safe_limit(limite), safe_offset(deslocamento)),
        ).fetchall()
    total = int(rows[0]["total_grupos"]) if rows else 0
    cleaned = [{key: value for key, value in row.items() if key != "total_grupos"} for row in rows]
    return {
        "agrupado_por": label,
        "ordem": direction.lower(),
        "total_grupos": total,
        "quantidade_retornada": len(cleaned),
        "proximo_deslocamento": safe_offset(deslocamento) + len(cleaned),
        "grupos": rows_to_json(cleaned),
    }


@mcp.tool()
def resumir_unidades(limite: int = 20) -> dict[str, Any]:
    """Resume turmas e matriculas por unidade ficticia, ordenando pelas unidades com mais matriculas."""
    query = """
        SELECT
            unidade_codigo,
            unidade,
            municipio_ficticio,
            quantidade_turmas,
            turmas_ativas,
            matriculas_ativas
        FROM vw_resumo_unidades
        ORDER BY matriculas_ativas DESC, unidade
        LIMIT %s
    """
    with database() as connection:
        rows = connection.execute(query, (safe_limit(limite),)).fetchall()
    return {"quantidade": len(rows), "unidades": rows_to_json(rows)}


if __name__ == "__main__":
    mcp.run(transport="streamable-http")
