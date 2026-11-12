-- =====================================================================
-- ESTACIONA AÍ - Funções (regras de cálculo, validação e funções de trigger)
-- =====================================================================

-- Retorna o id da tarifa vigente para um tipo de vaga em um dado momento
CREATE OR REPLACE FUNCTION fn_tarifa_vigente(p_tipo_vaga VARCHAR, p_momento TIMESTAMP)
RETURNS INTEGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_id_tarifa INTEGER;
BEGIN
    SELECT t.id_tarifa
      INTO v_id_tarifa
      FROM tarifa t
     WHERE t.tipo_vaga = p_tipo_vaga
       AND p_momento >= t.vigencia_inicio
       AND (t.vigencia_fim IS NULL OR p_momento < t.vigencia_fim)
     ORDER BY t.vigencia_inicio DESC
     LIMIT 1;

    IF v_id_tarifa IS NULL THEN
        RAISE EXCEPTION 'Nenhuma tarifa vigente para o tipo % em %', p_tipo_vaga, p_momento;
    END IF;

    RETURN v_id_tarifa;
END;
$$;

-- Calcula o valor: cobra por hora iniciada, com mínimo de 1 hora
CREATE OR REPLACE FUNCTION fn_calcular_valor(p_entrada TIMESTAMP, p_saida TIMESTAMP, p_valor_hora DECIMAL)
RETURNS DECIMAL(10,2)
LANGUAGE plpgsql
AS $$
DECLARE
    v_horas INTEGER;
BEGIN
    IF p_saida <= p_entrada THEN
        RAISE EXCEPTION 'A data de saída deve ser posterior à data de entrada';
    END IF;

    v_horas := GREATEST(CEIL(EXTRACT(EPOCH FROM (p_saida - p_entrada)) / 3600), 1);

    RETURN ROUND(v_horas * p_valor_hora, 2);
END;
$$;

-- Valida se o funcionário existe e está ativo (usada pelas procedures)
CREATE OR REPLACE FUNCTION fn_validar_funcionario(p_id_funcionario INTEGER)
RETURNS VOID
LANGUAGE plpgsql
AS $$
BEGIN
    PERFORM 1 FROM funcionario WHERE id_funcionario = p_id_funcionario AND ativo;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Funcionário % não existe ou está inativo', p_id_funcionario;
    END IF;
END;
$$;

-- Trigger function: situação da vaga conforme a movimentação
--   INSERT -> vaga vai a 'ocupada' (só se estava 'livre')
--   UPDATE -> registro encerrado: vaga volta a 'livre'
--   DELETE -> registro em aberto excluído: vaga volta a 'livre'
CREATE OR REPLACE FUNCTION fn_trg_registro_vaga()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_status VARCHAR(20);
BEGIN
    IF TG_OP = 'INSERT' THEN
        IF NEW.data_saida IS NULL THEN
            SELECT status INTO v_status FROM vaga WHERE id_vaga = NEW.id_vaga FOR UPDATE;
            IF v_status <> 'livre' THEN
                RAISE EXCEPTION 'A vaga % não está livre (status atual: %)', NEW.id_vaga, v_status;
            END IF;
            UPDATE vaga SET status = 'ocupada' WHERE id_vaga = NEW.id_vaga;
        END IF;
        RETURN NEW;

    ELSIF TG_OP = 'UPDATE' THEN
        IF OLD.data_saida IS NULL AND NEW.data_saida IS NOT NULL THEN
            UPDATE vaga SET status = 'livre' WHERE id_vaga = NEW.id_vaga;
        END IF;
        RETURN NEW;

    ELSE -- DELETE
        IF OLD.data_saida IS NULL THEN
            UPDATE vaga SET status = 'livre' WHERE id_vaga = OLD.id_vaga;
        END IF;
        RETURN OLD;
    END IF;
END;
$$;

-- Trigger function: situação da vaga conforme a manutenção
--   INSERT com manutenção em aberto -> vaga vai a 'manutencao' (só se estava 'livre')
--   UPDATE que fecha a manutenção   -> vaga volta a 'livre'
CREATE OR REPLACE FUNCTION fn_trg_manutencao_vaga()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_status VARCHAR(20);
BEGIN
    IF TG_OP = 'INSERT' THEN
        IF NEW.data_fim IS NULL THEN
            SELECT status INTO v_status FROM vaga WHERE id_vaga = NEW.id_vaga FOR UPDATE;
            IF v_status <> 'livre' THEN
                RAISE EXCEPTION 'Não é possível iniciar manutenção: a vaga % está %', NEW.id_vaga, v_status;
            END IF;
            UPDATE vaga SET status = 'manutencao' WHERE id_vaga = NEW.id_vaga;
        END IF;

    ELSIF OLD.data_fim IS NULL AND NEW.data_fim IS NOT NULL THEN
        UPDATE vaga SET status = 'livre' WHERE id_vaga = NEW.id_vaga AND status = 'manutencao';
    END IF;

    RETURN NEW;
END;
$$;

-- Trigger function: histórico de status de cada vaga (inclui a criação)
CREATE OR REPLACE FUNCTION fn_trg_vaga_historico()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        INSERT INTO historico_status_vaga (id_vaga, status_anterior, status_novo)
        VALUES (NEW.id_vaga, NULL, NEW.status);

    ELSIF NEW.status IS DISTINCT FROM OLD.status THEN
        INSERT INTO historico_status_vaga (id_vaga, status_anterior, status_novo)
        VALUES (NEW.id_vaga, OLD.status, NEW.status);
    END IF;

    RETURN NEW;
END;
$$;

-- Trigger function: log de auditoria de registro (antes e depois em JSONB)
CREATE OR REPLACE FUNCTION fn_trg_log_registro()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        INSERT INTO log_auditoria (tabela, operacao, id_afetado, dados_antes, dados_depois)
        VALUES ('registro', 'INSERT', NEW.id_registro, NULL, to_jsonb(NEW));
        RETURN NEW;

    ELSIF TG_OP = 'UPDATE' THEN
        INSERT INTO log_auditoria (tabela, operacao, id_afetado, dados_antes, dados_depois)
        VALUES ('registro', 'UPDATE', NEW.id_registro, to_jsonb(OLD), to_jsonb(NEW));
        RETURN NEW;

    ELSE -- DELETE
        INSERT INTO log_auditoria (tabela, operacao, id_afetado, dados_antes, dados_depois)
        VALUES ('registro', 'DELETE', OLD.id_registro, to_jsonb(OLD), NULL);
        RETURN OLD;
    END IF;
END;
$$;