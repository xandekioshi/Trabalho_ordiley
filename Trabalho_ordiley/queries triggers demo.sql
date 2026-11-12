-- =====================================================================
-- ESTACIONA AÍ - Demonstração das triggers e das funções de trigger
-- Executar depois de queries_insert.sql.
-- Supõe a vaga 7 livre e a vaga 8 em manutenção (estado da carga inicial).
-- =====================================================================

-- =====================================================================
-- PARTE 1 - QUANDO (as triggers): desligar e ligar para provar o efeito
-- =====================================================================

-- 1.1) trg_registro_vaga: sem a trigger, o registro não ocupa a vaga
ALTER TABLE registro DISABLE TRIGGER trg_registro_vaga;
INSERT INTO registro (id_veiculo, id_vaga, id_funcionario_entrada)
VALUES (4, 7, 1);
SELECT numero, status FROM vaga WHERE numero = 7;                 -- livre: trigger desligada

ALTER TABLE registro ENABLE TRIGGER trg_registro_vaga;        -- trigger ativada
DELETE FROM registro WHERE id_vaga = 7 AND data_saida IS NULL;    -- limpa o teste
SELECT numero, status FROM vaga WHERE numero = 7;                 -- livre

-- 1.2) trg_manutencao_vaga: sem a trigger, a manutenção não bloqueia a vaga
ALTER TABLE manutencao_vaga DISABLE TRIGGER trg_manutencao_vaga;
INSERT INTO manutencao_vaga (id_vaga, motivo, id_funcionario)
VALUES (7, 'Teste com trigger desligada', 2);
SELECT numero, status FROM vaga WHERE numero = 7;                 -- livre: trigger desligada

ALTER TABLE manutencao_vaga ENABLE TRIGGER trg_manutencao_vaga;   -- trigger ativada
UPDATE manutencao_vaga SET data_fim = LOCALTIMESTAMP
WHERE id_vaga = 7 AND data_fim IS NULL;                           -- limpa o teste
SELECT numero, status FROM vaga WHERE numero = 7;                 -- livre

-- =====================================================================
-- PARTE 2 - O QUÊ (as funções de trigger): código e ramos
-- =====================================================================

-- 2.0) Mapa: qual trigger chama qual função
SELECT t.tgname AS trigger, c.relname AS tabela, p.proname AS funcao
FROM pg_trigger t
JOIN pg_class c     ON c.oid = t.tgrelid
JOIN pg_namespace n ON n.oid = c.relnamespace
JOIN pg_proc p      ON p.oid = t.tgfoid
WHERE n.nspname = 'estaciona' AND NOT t.tgisinternal
ORDER BY t.tgname;

-- Código de uma função (resultado longo: é o código completo)
SELECT pg_get_functiondef('fn_trg_registro_vaga'::regproc);

-- 2.1) fn_trg_registro_vaga: ramos INSERT, UPDATE, DELETE e erro
CALL sp_registrar_entrada('GHI4J56', 7, 1);                       -- INSERT
SELECT numero, status FROM vaga WHERE numero = 7;                 -- ocupada

UPDATE registro SET data_saida = LOCALTIMESTAMP
WHERE id_vaga = 7 AND data_saida IS NULL;                         -- UPDATE
SELECT numero, status FROM vaga WHERE numero = 7;                 -- livre

CALL sp_registrar_entrada('GHI4J56', 7, 1);
DELETE FROM registro WHERE id_vaga = 7 AND data_saida IS NULL;    -- DELETE
SELECT numero, status FROM vaga WHERE numero = 7;                 -- livre

CALL sp_registrar_entrada('GHI4J56', 8, 1);   -- erro: "A vaga 8 não está livre (status atual: manutencao)"

-- 2.2) fn_trg_manutencao_vaga: ramos INSERT em aberto, UPDATE e INSERT já concluída
INSERT INTO manutencao_vaga (id_vaga, motivo, id_funcionario)
VALUES (7, 'Teste da função de manutenção', 2);                   -- INSERT em aberto
SELECT numero, status FROM vaga WHERE numero = 7;                 -- manutencao

UPDATE manutencao_vaga SET data_fim = LOCALTIMESTAMP
WHERE id_vaga = 7 AND data_fim IS NULL;                           -- UPDATE
SELECT numero, status FROM vaga WHERE numero = 7;                 -- livre

INSERT INTO manutencao_vaga (id_vaga, motivo, data_inicio, data_fim, id_funcionario)
VALUES (7, 'Manutenção já concluída', '2026-11-01 08:00', '2026-11-01 09:00', 2);
SELECT numero, status FROM vaga WHERE numero = 7;                 -- livre: a função não mexe

-- 2.3) fn_trg_vaga_historico: ramos UPDATE (mudança de status) e INSERT (criação)
UPDATE vaga SET status = 'manutencao' WHERE numero = 7;
UPDATE vaga SET status = 'livre'      WHERE numero = 7;
SELECT numero, status_anterior, status_novo
FROM vw_historico_vagas
WHERE numero = 7
ORDER BY data_alteracao DESC
LIMIT 2;


INSERT INTO vaga (numero, tipo_vaga, status, id_setor) VALUES (11, 'comum', 'livre', 2);
SELECT numero, status_anterior, status_novo
FROM vw_historico_vagas
WHERE numero = 11;                                                -- status_anterior vazio

-- 2.4) fn_trg_log_registro: ramos INSERT, UPDATE e DELETE
SELECT operacao, dados_antes IS NULL AS sem_antes, dados_depois->>'id_vaga' AS vaga
FROM log_auditoria
WHERE tabela = 'registro' AND operacao = 'INSERT'
ORDER BY id_log DESC
LIMIT 1;

UPDATE registro SET valor_pago = valor_pago WHERE id_registro = 2;
SELECT operacao, dados_antes->>'valor_pago' AS antes, dados_depois->>'valor_pago' AS depois
FROM log_auditoria
WHERE tabela = 'registro' AND operacao = 'UPDATE'
ORDER BY id_log DESC
LIMIT 1;

SELECT operacao, dados_antes->>'id_vaga' AS vaga_apagada, dados_depois IS NULL AS sem_depois
FROM log_auditoria
WHERE tabela = 'registro' AND operacao = 'DELETE'
ORDER BY id_log DESC
LIMIT 1;