-- =====================================================================
-- ESTACIONA AÍ - Demonstração das procedures
-- Executar depois de queries_insert.sql
-- =====================================================================

-- 1) Entrada: o carro DEF3G45 para na vaga 4, registrado pelo funcionário 1
CALL sp_registrar_entrada('DEF3G45', 4, 1);

-- Confira: a trigger deixou a vaga ocupada
SELECT numero, status FROM vaga WHERE numero = 4;                 -- ocupada

-- Descubra o id do registro aberto (deve ser o 11)
SELECT id_registro FROM registro WHERE id_vaga = 4 AND data_saida IS NULL;

-- 2) Saída: encerra o registro 11 com pagamento em dinheiro, pelo funcionário 2
CALL sp_registrar_saida(11, 'dinheiro', 2);

-- Confira: valor calculado, pagamento gravado e vaga liberada
SELECT placa, numero_vaga, horas_permanencia, valor_hora, valor_pago, forma_pagamento
FROM vw_movimentacao_detalhada
WHERE id_registro = 11;                                           -- valor_pago 10.00, dinheiro

SELECT numero, status FROM vaga WHERE numero = 4;                 -- livre