-- Banco exclusivamente demonstrativo. Nenhum registro representa pessoa,
-- unidade ou operacao real.

CREATE TABLE unidades (
    id integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    codigo varchar(12) NOT NULL UNIQUE,
    nome varchar(120) NOT NULL,
    municipio_ficticio varchar(120) NOT NULL,
    quantidade_salas smallint NOT NULL CHECK (quantidade_salas > 0),
    ativa boolean NOT NULL DEFAULT true
);

CREATE TABLE cursos (
    id integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    codigo varchar(12) NOT NULL UNIQUE,
    nome varchar(160) NOT NULL,
    area varchar(80) NOT NULL,
    modalidade varchar(20) NOT NULL CHECK (modalidade IN ('presencial', 'online', 'hibrido')),
    carga_horaria smallint NOT NULL CHECK (carga_horaria > 0),
    ativo boolean NOT NULL DEFAULT true
);

CREATE TABLE instrutores (
    id integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    codigo varchar(12) NOT NULL UNIQUE,
    nome_ficticio varchar(120) NOT NULL,
    especialidade varchar(120) NOT NULL,
    unidade_base_id integer NOT NULL REFERENCES unidades(id)
);

CREATE TABLE turmas (
    id integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    codigo varchar(16) NOT NULL UNIQUE,
    curso_id integer NOT NULL REFERENCES cursos(id),
    unidade_id integer NOT NULL REFERENCES unidades(id),
    instrutor_id integer NOT NULL REFERENCES instrutores(id),
    turno varchar(12) NOT NULL CHECK (turno IN ('manha', 'tarde', 'noite', 'flexivel')),
    data_inicio date NOT NULL,
    data_fim date NOT NULL CHECK (data_fim >= data_inicio),
    vagas smallint NOT NULL CHECK (vagas > 0),
    status varchar(16) NOT NULL CHECK (status IN ('planejada', 'inscricoes', 'em_andamento', 'concluida', 'cancelada')),
    criado_em timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE matriculas (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    codigo varchar(20) NOT NULL UNIQUE,
    turma_id integer NOT NULL REFERENCES turmas(id),
    aluno_alias varchar(80) NOT NULL,
    status varchar(18) NOT NULL CHECK (status IN ('confirmada', 'lista_espera', 'cancelada', 'concluida')),
    data_matricula date NOT NULL
);

CREATE INDEX idx_turmas_curso ON turmas(curso_id);
CREATE INDEX idx_turmas_unidade ON turmas(unidade_id);
CREATE INDEX idx_turmas_status_inicio ON turmas(status, data_inicio);
CREATE INDEX idx_matriculas_turma_status ON matriculas(turma_id, status);

COMMENT ON DATABASE cora_demo IS 'Base sintetica e descartavel para demonstracoes da Cora';
COMMENT ON TABLE matriculas IS 'Dados 100% ficticios gerados para testes; nao representam pessoas reais';

-- Usuario que o futuro MCP usara. Mesmo se o modelo produzir uma operacao de
-- escrita, o PostgreSQL recusara porque este papel possui apenas SELECT.
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'cora_demo_reader') THEN
        CREATE ROLE cora_demo_reader LOGIN PASSWORD 'cora_demo_reader_local';
    END IF;
END
$$;

GRANT CONNECT ON DATABASE cora_demo TO cora_demo_reader;
GRANT USAGE ON SCHEMA public TO cora_demo_reader;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO cora_demo_reader;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO cora_demo_reader;
