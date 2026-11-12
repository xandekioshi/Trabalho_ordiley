-- =====================================================================
-- ESTACIONA AÍ - Exclusões (respeitando a integridade referencial)
-- Regra: dependentes primeiro (pagamento -> registro -> veículo -> cliente).
-- =====================================================================

-- 1) Exclui o pagamento e depois o registro encerrado
DELETE FROM pagamento WHERE id_registro = 4;
DELETE FROM registro  WHERE id_registro = 4;

-- 2) Exclui um registro em aberto: a trigger libera a vaga automaticamente
DELETE FROM registro WHERE id_registro = 10;

-- 3) Exclui o veículo e depois o cliente
DELETE FROM veiculo WHERE id_veiculo = 5;
DELETE FROM cliente WHERE id_cliente = 4;

-- 4) Tentativas bloqueadas pela integridade referencial (erro esperado; deixe comentado)
-- DELETE FROM cliente     WHERE id_cliente = 1;
-- DELETE FROM funcionario WHERE id_funcionario = 1;