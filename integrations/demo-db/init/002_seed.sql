INSERT INTO unidades (codigo, nome, municipio_ficticio, quantidade_salas, ativa) VALUES
    ('UNI-AUR', 'Unidade Aurora', 'Cidade Aurora', 12, true),
    ('UNI-HOR', 'Unidade Horizonte', 'Nova Esperanca', 8, true),
    ('UNI-LAG', 'Unidade Lagoa Azul', 'Vale Azul', 10, true),
    ('UNI-SER', 'Unidade Serra Clara', 'Serra Clara', 6, true),
    ('UNI-SOL', 'Unidade Sol Nascente', 'Vila do Sol', 9, true),
    ('UNI-JAR', 'Unidade Jardim Digital', 'Jardim Novo', 5, false);

INSERT INTO cursos (codigo, nome, area, modalidade, carga_horaria, ativo) VALUES
    ('CUR-WEB', 'Desenvolvimento Web', 'Tecnologia', 'hibrido', 160, true),
    ('CUR-DADOS', 'Analise de Dados', 'Tecnologia', 'online', 120, true),
    ('CUR-REDES', 'Fundamentos de Redes', 'Tecnologia', 'presencial', 100, true),
    ('CUR-IA', 'Introducao a Inteligencia Artificial', 'Tecnologia', 'hibrido', 80, true),
    ('CUR-DESIGN', 'Design de Interfaces', 'Design', 'presencial', 96, true),
    ('CUR-MKT', 'Marketing Digital', 'Gestao', 'online', 72, true),
    ('CUR-EXCEL', 'Planilhas para Negocios', 'Gestao', 'presencial', 40, true),
    ('CUR-PROJ', 'Gestao de Projetos', 'Gestao', 'hibrido', 60, true),
    ('CUR-ENERG', 'Energia Solar Basica', 'Industria', 'presencial', 120, true),
    ('CUR-LOG', 'Logistica e Estoques', 'Industria', 'hibrido', 80, true),
    ('CUR-ATEND', 'Atendimento ao Publico', 'Servicos', 'presencial', 36, true),
    ('CUR-EMP', 'Empreendedorismo Pratico', 'Negocios', 'online', 48, false);

INSERT INTO instrutores (codigo, nome_ficticio, especialidade, unidade_base_id)
SELECT dados.codigo, dados.nome, dados.especialidade, u.id
FROM (VALUES
    ('INS-001', 'Instrutora Demo Aline', 'Desenvolvimento Web', 'UNI-AUR'),
    ('INS-002', 'Instrutor Demo Bruno', 'Ciencia de Dados', 'UNI-HOR'),
    ('INS-003', 'Instrutora Demo Carla', 'Redes e Infraestrutura', 'UNI-LAG'),
    ('INS-004', 'Instrutor Demo Daniel', 'Inteligencia Artificial', 'UNI-AUR'),
    ('INS-005', 'Instrutora Demo Elisa', 'Design de Interfaces', 'UNI-SER'),
    ('INS-006', 'Instrutor Demo Fabio', 'Marketing Digital', 'UNI-SOL'),
    ('INS-007', 'Instrutora Demo Gabriela', 'Gestao e Planilhas', 'UNI-HOR'),
    ('INS-008', 'Instrutor Demo Henrique', 'Gestao de Projetos', 'UNI-LAG'),
    ('INS-009', 'Instrutora Demo Iris', 'Energia Renovavel', 'UNI-SER'),
    ('INS-010', 'Instrutor Demo Jonas', 'Logistica', 'UNI-SOL'),
    ('INS-011', 'Instrutora Demo Larissa', 'Atendimento', 'UNI-AUR'),
    ('INS-012', 'Instrutor Demo Marcos', 'Negocios', 'UNI-HOR')
) AS dados(codigo, nome, especialidade, unidade_codigo)
JOIN unidades u ON u.codigo = dados.unidade_codigo;

INSERT INTO turmas
    (codigo, curso_id, unidade_id, instrutor_id, turno, data_inicio, data_fim, vagas, status)
SELECT dados.codigo, c.id, u.id, i.id, dados.turno, dados.inicio, dados.fim,
       dados.vagas, dados.status
FROM (VALUES
    ('TUR-2601', 'CUR-WEB',    'UNI-AUR', 'INS-001', 'noite',    DATE '2026-08-03', DATE '2026-12-18', 30, 'em_andamento'),
    ('TUR-2602', 'CUR-DADOS',  'UNI-HOR', 'INS-002', 'flexivel', DATE '2026-08-10', DATE '2026-11-20', 40, 'em_andamento'),
    ('TUR-2603', 'CUR-REDES',  'UNI-LAG', 'INS-003', 'tarde',    DATE '2026-07-13', DATE '2026-10-30', 24, 'em_andamento'),
    ('TUR-2604', 'CUR-IA',     'UNI-AUR', 'INS-004', 'manha',    DATE '2026-09-21', DATE '2026-11-27', 28, 'inscricoes'),
    ('TUR-2605', 'CUR-DESIGN', 'UNI-SER', 'INS-005', 'tarde',    DATE '2026-09-28', DATE '2026-12-18', 22, 'inscricoes'),
    ('TUR-2606', 'CUR-MKT',    'UNI-SOL', 'INS-006', 'flexivel', DATE '2026-10-05', DATE '2026-12-04', 45, 'inscricoes'),
    ('TUR-2607', 'CUR-EXCEL',  'UNI-HOR', 'INS-007', 'noite',    DATE '2026-09-14', DATE '2026-10-16', 25, 'inscricoes'),
    ('TUR-2608', 'CUR-PROJ',   'UNI-LAG', 'INS-008', 'noite',    DATE '2026-10-19', DATE '2026-12-11', 30, 'planejada'),
    ('TUR-2609', 'CUR-ENERG',  'UNI-SER', 'INS-009', 'manha',    DATE '2026-09-07', DATE '2026-12-18', 20, 'em_andamento'),
    ('TUR-2610', 'CUR-LOG',    'UNI-SOL', 'INS-010', 'tarde',    DATE '2026-10-26', DATE '2027-01-22', 26, 'planejada'),
    ('TUR-2611', 'CUR-ATEND',  'UNI-AUR', 'INS-011', 'manha',    DATE '2026-09-15', DATE '2026-10-02', 35, 'inscricoes'),
    ('TUR-2612', 'CUR-WEB',    'UNI-HOR', 'INS-001', 'tarde',    DATE '2026-10-05', DATE '2027-02-19', 25, 'inscricoes'),
    ('TUR-2613', 'CUR-DADOS',  'UNI-LAG', 'INS-002', 'noite',    DATE '2026-11-09', DATE '2027-02-19', 35, 'planejada'),
    ('TUR-2614', 'CUR-IA',     'UNI-SOL', 'INS-004', 'noite',    DATE '2026-11-16', DATE '2027-01-22', 24, 'planejada'),
    ('TUR-2615', 'CUR-DESIGN', 'UNI-AUR', 'INS-005', 'manha',    DATE '2026-05-04', DATE '2026-07-24', 20, 'concluida'),
    ('TUR-2616', 'CUR-MKT',    'UNI-HOR', 'INS-006', 'flexivel', DATE '2026-04-06', DATE '2026-06-05', 40, 'concluida'),
    ('TUR-2617', 'CUR-EXCEL',  'UNI-LAG', 'INS-007', 'tarde',    DATE '2026-06-01', DATE '2026-07-03', 22, 'concluida'),
    ('TUR-2618', 'CUR-PROJ',   'UNI-SOL', 'INS-008', 'noite',    DATE '2026-06-08', DATE '2026-07-31', 28, 'concluida'),
    ('TUR-2619', 'CUR-ENERG',  'UNI-SER', 'INS-009', 'tarde',    DATE '2026-03-02', DATE '2026-06-19', 18, 'concluida'),
    ('TUR-2620', 'CUR-LOG',    'UNI-AUR', 'INS-010', 'manha',    DATE '2026-05-11', DATE '2026-08-07', 24, 'concluida'),
    ('TUR-2621', 'CUR-ATEND',  'UNI-HOR', 'INS-011', 'noite',    DATE '2026-10-13', DATE '2026-10-30', 32, 'inscricoes'),
    ('TUR-2622', 'CUR-REDES',  'UNI-AUR', 'INS-003', 'noite',    DATE '2026-11-03', DATE '2027-02-12', 20, 'planejada'),
    ('TUR-2623', 'CUR-WEB',    'UNI-LAG', 'INS-001', 'manha',    DATE '2026-09-01', DATE '2027-01-15', 28, 'cancelada'),
    ('TUR-2624', 'CUR-DADOS',  'UNI-SOL', 'INS-002', 'flexivel', DATE '2026-09-22', DATE '2027-01-08', 38, 'inscricoes')
) AS dados(codigo, curso_codigo, unidade_codigo, instrutor_codigo, turno, inicio, fim, vagas, status)
JOIN cursos c ON c.codigo = dados.curso_codigo
JOIN unidades u ON u.codigo = dados.unidade_codigo
JOIN instrutores i ON i.codigo = dados.instrutor_codigo;

-- Quantidades variadas criam turmas vazias, parcialmente ocupadas, lotadas e
-- com lista de espera. Os aliases nao correspondem a pessoas reais.
WITH ocupacao(codigo_turma, quantidade) AS (VALUES
    ('TUR-2601', 28), ('TUR-2602', 43), ('TUR-2603', 19), ('TUR-2604', 31),
    ('TUR-2605', 12), ('TUR-2606', 18), ('TUR-2607', 24), ('TUR-2608', 4),
    ('TUR-2609', 20), ('TUR-2610', 0),  ('TUR-2611', 37), ('TUR-2612', 16),
    ('TUR-2613', 7),  ('TUR-2614', 3),  ('TUR-2615', 20), ('TUR-2616', 36),
    ('TUR-2617', 18), ('TUR-2618', 27), ('TUR-2619', 17), ('TUR-2620', 22),
    ('TUR-2621', 9),  ('TUR-2622', 2),  ('TUR-2623', 11), ('TUR-2624', 29)
), geradas AS (
    SELECT
        t.id AS turma_id,
        t.vagas,
        t.status AS turma_status,
        t.data_inicio,
        numero,
        row_number() OVER (ORDER BY t.id, numero) AS sequencia
    FROM ocupacao o
    JOIN turmas t ON t.codigo = o.codigo_turma
    CROSS JOIN LATERAL generate_series(1, o.quantidade) AS numero
)
INSERT INTO matriculas (codigo, turma_id, aluno_alias, status, data_matricula)
SELECT
    'MAT-' || to_char(sequencia, 'FM00000'),
    turma_id,
    'Aluno Demo ' || to_char(sequencia, 'FM0000'),
    CASE
        WHEN turma_status = 'concluida' AND numero <= vagas THEN 'concluida'
        WHEN numero > vagas THEN 'lista_espera'
        WHEN numero % 17 = 0 THEN 'cancelada'
        ELSE 'confirmada'
    END,
    data_inicio - (10 + (numero % 35))
FROM geradas;
