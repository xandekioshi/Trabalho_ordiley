-- =====================================================================
-- ESTACIONA AÍ - Demonstração das funções (sem triggers)
-- Executar depois de queries_insert.sql. Só faz SELECT: pode repetir à vontade.
-- =====================================================================

-- 1) fn_calcular_valor: cobra por hora iniciada (2h30 -> 3h x 10,00 = 30.00)
SELECT fn_calcular_valor('2026-11-12 08:00', '2026-11-12 10:30', 10.00);

-- 2) fn_calcular_valor: mínimo de 1 hora (20 min -> 1h x 5,00 = 5.00)
SELECT fn_calcular_valor('2026-11-12 08:00', '2026-11-12 08:20', 5.00);

-- 3) fn_tarifa_vigente: a tarifa comum muda em 01/11/2026
SELECT fn_tarifa_vigente('comum', '2026-10-31 12:00');   -- 1 (R$ 8,00)
SELECT fn_tarifa_vigente('comum', '2026-11-02 12:00');   -- 2 (R$ 10,00)

-- 4) fn_validar_funcionario: funcionário ativo não mostra nada (VOID)
SELECT fn_validar_funcionario(1);

-- 5) fn_validar_funcionario: funcionário inativo gera erro (esperado)
SELECT fn_validar_funcionario(3);