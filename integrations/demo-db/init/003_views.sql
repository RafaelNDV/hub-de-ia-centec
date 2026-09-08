CREATE VIEW vw_ocupacao_turmas AS
SELECT
    t.id AS turma_id,
    t.codigo AS turma_codigo,
    c.nome AS curso,
    c.area,
    u.nome AS unidade,
    t.turno,
    t.data_inicio,
    t.data_fim,
    t.status,
    t.vagas,
    count(m.id) FILTER (WHERE m.status IN ('confirmada', 'concluida')) AS matriculas_ativas,
    count(m.id) FILTER (WHERE m.status = 'lista_espera') AS lista_espera,
    count(m.id) FILTER (WHERE m.status = 'cancelada') AS matriculas_canceladas,
    greatest(
        t.vagas - count(m.id) FILTER (WHERE m.status IN ('confirmada', 'concluida')),
        0
    ) AS vagas_disponiveis,
    round(
        100.0 * count(m.id) FILTER (WHERE m.status IN ('confirmada', 'concluida')) / t.vagas,
        1
    ) AS percentual_ocupacao
FROM turmas t
JOIN cursos c ON c.id = t.curso_id
JOIN unidades u ON u.id = t.unidade_id
LEFT JOIN matriculas m ON m.turma_id = t.id
GROUP BY t.id, c.nome, c.area, u.nome;

CREATE VIEW vw_resumo_unidades AS
SELECT
    u.codigo AS unidade_codigo,
    u.nome AS unidade,
    u.municipio_ficticio,
    count(DISTINCT t.id) AS quantidade_turmas,
    count(DISTINCT t.id) FILTER (WHERE t.status IN ('inscricoes', 'em_andamento')) AS turmas_ativas,
    count(m.id) FILTER (WHERE m.status IN ('confirmada', 'concluida')) AS matriculas_ativas
FROM unidades u
LEFT JOIN turmas t ON t.unidade_id = u.id
LEFT JOIN matriculas m ON m.turma_id = t.id
GROUP BY u.id;

GRANT SELECT ON vw_ocupacao_turmas, vw_resumo_unidades TO cora_demo_reader;
