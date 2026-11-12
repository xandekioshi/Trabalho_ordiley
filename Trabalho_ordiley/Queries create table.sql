-- Active: 1791565324654@@127.0.0.1@5432@estaciona_ai@estaciona_ai
-- Active: 1791565324654@@127.0.0.1@5432@trabalho_odirley@trabalho_odirley
-- =====================================================================
-- ESTACIONA AÍ - Criação das tabelas (PostgreSQL)
-- Ordem de execução: 1) create_tables  2) function  3) procedure
--                    4) triggers       5) views     6) insert  7) delete
-- =====================================================================

DROP TABLE IF EXISTS log_auditoria         CASCADE;
DROP TABLE IF EXISTS historico_status_vaga CASCADE;
DROP TABLE IF EXISTS pagamento             CASCADE;
DROP TABLE IF EXISTS manutencao_vaga       CASCADE;
DROP TABLE IF EXISTS registro              CASCADE;
DROP TABLE IF EXISTS veiculo               CASCADE;
DROP TABLE IF EXISTS vaga                  CASCADE;
DROP TABLE IF EXISTS setor                 CASCADE;
DROP TABLE IF EXISTS funcionario           CASCADE;
DROP TABLE IF EXISTS cliente               CASCADE;
DROP TABLE IF EXISTS tarifa                CASCADE;

-- Tarifa (preço por hora, com vigência)
CREATE TABLE tarifa (
    id_tarifa        SERIAL,
    tipo_vaga        VARCHAR(20)   NOT NULL,
    valor_hora       DECIMAL(10,2) NOT NULL,
    vigencia_inicio  TIMESTAMP     NOT NULL,
    vigencia_fim     TIMESTAMP,
    CONSTRAINT pk_tarifa            PRIMARY KEY (id_tarifa),
    CONSTRAINT ck_tarifa_tipo       CHECK (tipo_vaga IN ('comum', 'idoso', 'pcd', 'moto')),
    CONSTRAINT ck_tarifa_valor      CHECK (valor_hora > 0),
    CONSTRAINT ck_tarifa_vigencia   CHECK (vigencia_fim IS NULL OR vigencia_fim > vigencia_inicio)
);

-- Cliente
CREATE TABLE cliente (
    id_cliente   SERIAL,
    nome         VARCHAR(100) NOT NULL,
    cpf          VARCHAR(14)  NOT NULL,
    telefone     VARCHAR(20),
    CONSTRAINT pk_cliente       PRIMARY KEY (id_cliente),
    CONSTRAINT uq_cliente_cpf   UNIQUE (cpf)
);

-- Funcionário (operador ou supervisor que registra as movimentações)
CREATE TABLE funcionario (
    id_funcionario   SERIAL,
    nome             VARCHAR(100) NOT NULL,
    cargo            VARCHAR(20)  NOT NULL,
    usuario          VARCHAR(30)  NOT NULL,
    ativo            BOOLEAN      NOT NULL DEFAULT TRUE,
    CONSTRAINT pk_funcionario           PRIMARY KEY (id_funcionario),
    CONSTRAINT uq_funcionario_usuario   UNIQUE (usuario),
    CONSTRAINT ck_funcionario_cargo     CHECK (cargo IN ('operador', 'supervisor', 'administrador'))
);

-- Setor (andar ou área do estacionamento)
CREATE TABLE setor (
    id_setor    SERIAL,
    nome        VARCHAR(50)  NOT NULL,
    descricao   VARCHAR(100),
    coberto     BOOLEAN      NOT NULL DEFAULT FALSE,
    CONSTRAINT pk_setor         PRIMARY KEY (id_setor),
    CONSTRAINT uq_setor_nome    UNIQUE (nome)
);

-- Vaga (física), pertence a um setor
CREATE TABLE vaga (
    id_vaga     SERIAL,
    numero      INTEGER      NOT NULL,
    tipo_vaga   VARCHAR(20)  NOT NULL DEFAULT 'comum',
    status      VARCHAR(20)  NOT NULL DEFAULT 'livre',
    id_setor    INTEGER      NOT NULL,
    CONSTRAINT pk_vaga            PRIMARY KEY (id_vaga),
    CONSTRAINT uq_vaga_numero     UNIQUE (numero),
    CONSTRAINT ck_vaga_tipo       CHECK (tipo_vaga IN ('comum', 'idoso', 'pcd', 'moto')),
    CONSTRAINT ck_vaga_status     CHECK (status IN ('livre', 'ocupada', 'manutencao')),
    CONSTRAINT fk_vaga_setor      FOREIGN KEY (id_setor) REFERENCES setor (id_setor)
);

-- Veículo (pertence a um cliente)
CREATE TABLE veiculo (
    id_veiculo   SERIAL,
    placa        VARCHAR(10)  NOT NULL,
    modelo       VARCHAR(50)  NOT NULL,
    cor          VARCHAR(30),
    id_cliente   INTEGER      NOT NULL,
    CONSTRAINT pk_veiculo           PRIMARY KEY (id_veiculo),
    CONSTRAINT uq_veiculo_placa     UNIQUE (placa),
    CONSTRAINT fk_veiculo_cliente   FOREIGN KEY (id_cliente) REFERENCES cliente (id_cliente)
);

-- Registro de movimentação (entrada e saída)
CREATE TABLE registro (
    id_registro              SERIAL,
    id_veiculo               INTEGER       NOT NULL,
    id_vaga                  INTEGER       NOT NULL,
    id_tarifa                INTEGER,
    id_funcionario_entrada   INTEGER       NOT NULL,
    id_funcionario_saida     INTEGER,
    data_entrada             TIMESTAMP     NOT NULL DEFAULT LOCALTIMESTAMP,
    data_saida               TIMESTAMP,
    valor_pago               DECIMAL(10,2),
    CONSTRAINT pk_registro                  PRIMARY KEY (id_registro),
    CONSTRAINT fk_registro_veiculo          FOREIGN KEY (id_veiculo)             REFERENCES veiculo (id_veiculo),
    CONSTRAINT fk_registro_vaga             FOREIGN KEY (id_vaga)                REFERENCES vaga (id_vaga),
    CONSTRAINT fk_registro_tarifa           FOREIGN KEY (id_tarifa)              REFERENCES tarifa (id_tarifa),
    CONSTRAINT fk_registro_func_entrada     FOREIGN KEY (id_funcionario_entrada) REFERENCES funcionario (id_funcionario),
    CONSTRAINT fk_registro_func_saida       FOREIGN KEY (id_funcionario_saida)   REFERENCES funcionario (id_funcionario),
    CONSTRAINT ck_registro_saida            CHECK (data_saida IS NULL OR data_saida > data_entrada),
    CONSTRAINT ck_registro_valor            CHECK (valor_pago IS NULL OR valor_pago >= 0)
);

-- Só pode haver UM registro em aberto por vaga e UM por veículo ao mesmo tempo
CREATE UNIQUE INDEX uq_registro_aberto_vaga    ON registro (id_vaga)    WHERE data_saida IS NULL;
CREATE UNIQUE INDEX uq_registro_aberto_veiculo ON registro (id_veiculo) WHERE data_saida IS NULL;

-- Pagamento de um registro encerrado (um pagamento por registro)
CREATE TABLE pagamento (
    id_pagamento     SERIAL,
    id_registro      INTEGER       NOT NULL,
    forma_pagamento  VARCHAR(20)   NOT NULL,
    valor            DECIMAL(10,2) NOT NULL,
    data_pagamento   TIMESTAMP     NOT NULL DEFAULT LOCALTIMESTAMP,
    id_funcionario   INTEGER       NOT NULL,
    CONSTRAINT pk_pagamento             PRIMARY KEY (id_pagamento),
    CONSTRAINT uq_pagamento_registro    UNIQUE (id_registro),
    CONSTRAINT ck_pagamento_forma       CHECK (forma_pagamento IN ('dinheiro', 'pix', 'cartao_debito', 'cartao_credito')),
    CONSTRAINT ck_pagamento_valor       CHECK (valor > 0),
    CONSTRAINT fk_pagamento_registro    FOREIGN KEY (id_registro)    REFERENCES registro (id_registro),
    CONSTRAINT fk_pagamento_funcionario FOREIGN KEY (id_funcionario) REFERENCES funcionario (id_funcionario)
);

-- Períodos de manutenção de uma vaga (auditoria de bloqueios)
CREATE TABLE manutencao_vaga (
    id_manutencao   SERIAL,
    id_vaga         INTEGER       NOT NULL,
    motivo          VARCHAR(200)  NOT NULL,
    data_inicio     TIMESTAMP     NOT NULL DEFAULT LOCALTIMESTAMP,
    data_fim        TIMESTAMP,
    id_funcionario  INTEGER       NOT NULL,
    CONSTRAINT pk_manutencao_vaga           PRIMARY KEY (id_manutencao),
    CONSTRAINT fk_manutencao_vaga           FOREIGN KEY (id_vaga)        REFERENCES vaga (id_vaga),
    CONSTRAINT fk_manutencao_funcionario    FOREIGN KEY (id_funcionario) REFERENCES funcionario (id_funcionario),
    CONSTRAINT ck_manutencao_periodo        CHECK (data_fim IS NULL OR data_fim > data_inicio)
);

-- Só pode haver UMA manutenção em andamento por vaga
CREATE UNIQUE INDEX uq_manutencao_aberta_vaga ON manutencao_vaga (id_vaga) WHERE data_fim IS NULL;

-- Auditoria: histórico de mudanças de status de cada vaga
CREATE TABLE historico_status_vaga (
    id_historico     SERIAL,
    id_vaga          INTEGER      NOT NULL,
    status_anterior  VARCHAR(20),
    status_novo      VARCHAR(20)  NOT NULL,
    data_alteracao   TIMESTAMP    NOT NULL DEFAULT LOCALTIMESTAMP,
    usuario          VARCHAR(63)  NOT NULL DEFAULT CURRENT_USER,
    CONSTRAINT pk_historico_status_vaga PRIMARY KEY (id_historico),
    CONSTRAINT fk_historico_vaga        FOREIGN KEY (id_vaga) REFERENCES vaga (id_vaga)
);

-- Auditoria: log genérico de INSERT / UPDATE / DELETE em registro (antes e depois em JSONB)
CREATE TABLE log_auditoria (
    id_log         SERIAL,
    tabela         VARCHAR(50)  NOT NULL,
    operacao       VARCHAR(10)  NOT NULL,
    id_afetado     INTEGER      NOT NULL,
    dados_antes    JSONB,
    dados_depois   JSONB,
    usuario        VARCHAR(63)  NOT NULL DEFAULT CURRENT_USER,
    data_evento    TIMESTAMP    NOT NULL DEFAULT LOCALTIMESTAMP,
    CONSTRAINT pk_log_auditoria     PRIMARY KEY (id_log),
    CONSTRAINT ck_log_operacao      CHECK (operacao IN ('INSERT', 'UPDATE', 'DELETE'))
);