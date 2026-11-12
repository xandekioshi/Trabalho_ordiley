-- =====================================================================
-- ESTACIONA AÍ - Procedures (operações do dia a dia)
-- =====================================================================

-- Registra a ENTRADA de um veículo (pela placa) em uma vaga (pelo número)
CREATE OR REPLACE PROCEDURE sp_registrar_entrada(p_placa VARCHAR, p_numero_vaga INTEGER, p_id_funcionario INTEGER)
LANGUAGE plpgsql
AS $$
DECLARE
    v_id_veiculo INTEGER;
    v_id_vaga    INTEGER;
BEGIN
    PERFORM fn_validar_funcionario(p_id_funcionario);

    SELECT id_veiculo INTO v_id_veiculo FROM veiculo WHERE placa = p_placa;
    IF v_id_veiculo IS NULL THEN
        RAISE EXCEPTION 'Veículo com placa % não está cadastrado', p_placa;
    END IF;

    SELECT id_vaga INTO v_id_vaga FROM vaga WHERE numero = p_numero_vaga;
    IF v_id_vaga IS NULL THEN
        RAISE EXCEPTION 'A vaga número % não existe', p_numero_vaga;
    END IF;

    -- A trigger trg_registro_vaga valida se a vaga está livre e a marca como ocupada
    INSERT INTO registro (id_veiculo, id_vaga, id_funcionario_entrada)
    VALUES (v_id_veiculo, v_id_vaga, p_id_funcionario);
END;
$$;

-- Registra a SAÍDA: calcula a tarifa e o valor, encerra o registro e grava o pagamento
-- A trigger trg_registro_vaga libera a vaga automaticamente
CREATE OR REPLACE PROCEDURE sp_registrar_saida(p_id_registro INTEGER, p_forma_pagamento VARCHAR, p_id_funcionario INTEGER)
LANGUAGE plpgsql
AS $$
DECLARE
    v_entrada     TIMESTAMP;
    v_tipo        VARCHAR(20);
    v_saida       TIMESTAMP;
    v_id_tarifa   INTEGER;
    v_valor_hora  DECIMAL(10,2);
    v_valor       DECIMAL(10,2);
BEGIN
    PERFORM fn_validar_funcionario(p_id_funcionario);

    SELECT r.data_entrada, va.tipo_vaga
      INTO v_entrada, v_tipo
      FROM registro r
      JOIN vaga va ON va.id_vaga = r.id_vaga
     WHERE r.id_registro = p_id_registro
       AND r.data_saida IS NULL
       FOR UPDATE OF r;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Registro % não existe ou já foi encerrado', p_id_registro;
    END IF;

    v_saida     := LOCALTIMESTAMP;
    v_id_tarifa := fn_tarifa_vigente(v_tipo, v_entrada);

    SELECT valor_hora INTO v_valor_hora FROM tarifa WHERE id_tarifa = v_id_tarifa;
    v_valor := fn_calcular_valor(v_entrada, v_saida, v_valor_hora);

    UPDATE registro
       SET data_saida             = v_saida,
           id_tarifa              = v_id_tarifa,
           valor_pago             = v_valor,
           id_funcionario_saida   = p_id_funcionario
     WHERE id_registro = p_id_registro;

    INSERT INTO pagamento (id_registro, forma_pagamento, valor, id_funcionario)
    VALUES (p_id_registro, p_forma_pagamento, v_valor, p_id_funcionario);
END;
$$;