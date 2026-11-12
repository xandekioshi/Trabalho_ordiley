-- =====================================================================
-- ESTACIONA AÍ - Triggers
-- =====================================================================

-- Mantém a situação da vaga sincronizada com a movimentação
CREATE TRIGGER trg_registro_vaga
AFTER INSERT OR UPDATE OR DELETE ON registro
FOR EACH ROW
EXECUTE FUNCTION fn_trg_registro_vaga();

-- Mantém a situação da vaga sincronizada com as manutenções
CREATE TRIGGER trg_manutencao_vaga
AFTER INSERT OR UPDATE OF data_fim ON manutencao_vaga
FOR EACH ROW
EXECUTE FUNCTION fn_trg_manutencao_vaga();

-- Auditoria: toda mudança de status de vaga (inclusive a criação) é registrada
CREATE TRIGGER trg_vaga_historico
AFTER INSERT OR UPDATE OF status ON vaga
FOR EACH ROW
EXECUTE FUNCTION fn_trg_vaga_historico();

-- Auditoria: toda alteração em registro é gravada em log_auditoria
CREATE TRIGGER trg_log_registro
AFTER INSERT OR UPDATE OR DELETE ON registro
FOR EACH ROW
EXECUTE FUNCTION fn_trg_log_registro();