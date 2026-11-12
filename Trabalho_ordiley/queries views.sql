-- =====================================================================
-- ESTACIONA AÍ - Views (consultas recorrentes simplificadas)
-- =====================================================================

-- Veículos com os dados do proprietário
CREATE OR REPLACE VIEW vw_veiculos_clientes AS
SELECT ve.id_veiculo, ve.placa, ve.modelo, ve.cor,
       c.nome AS nome_cliente, c.cpf, c.telefone
  FROM veiculo ve
  JOIN cliente c ON c.id_cliente = ve.id_cliente;

-- Situação atual de cada vaga, com setor e veículo que a ocupa (se houver)
CREATE OR REPLACE VIEW vw_situacao_vagas AS
SELECT va.numero, s.nome AS setor, va.tipo_vaga, va.status,
       ve.placa, c.nome AS nome_cliente, r.data_entrada
  FROM vaga va
  JOIN setor s          ON s.id_setor = va.id_setor
  LEFT JOIN registro r  ON r.id_vaga = va.id_vaga AND r.data_saida IS NULL
  LEFT JOIN veiculo ve  ON ve.id_veiculo = r.id_veiculo
  LEFT JOIN cliente c   ON c.id_cliente = ve.id_cliente
 ORDER BY va.numero;

-- Movimentação completa: quem, onde, quando, quanto e como pagou
CREATE OR REPLACE VIEW vw_movimentacao_detalhada AS
SELECT r.id_registro, ve.placa, c.nome AS nome_cliente,
       va.numero AS numero_vaga, va.tipo_vaga,
       fe.nome AS operador_entrada, fs.nome AS operador_saida,
       r.data_entrada, r.data_saida,
       ROUND(EXTRACT(EPOCH FROM (r.data_saida - r.data_entrada)) / 3600, 2) AS horas_permanencia,
       t.valor_hora, r.valor_pago, p.forma_pagamento
  FROM registro r
  JOIN veiculo ve      ON ve.id_veiculo = r.id_veiculo
  JOIN cliente c       ON c.id_cliente  = ve.id_cliente
  JOIN vaga va         ON va.id_vaga    = r.id_vaga
  JOIN funcionario fe  ON fe.id_funcionario = r.id_funcionario_entrada
  LEFT JOIN funcionario fs ON fs.id_funcionario = r.id_funcionario_saida
  LEFT JOIN tarifa t       ON t.id_tarifa = r.id_tarifa
  LEFT JOIN pagamento p    ON p.id_registro = r.id_registro;

-- Manutenções de vagas (auditoria de bloqueios)
CREATE OR REPLACE VIEW vw_manutencao_vagas AS
SELECT va.numero, m.motivo, m.data_inicio, m.data_fim,
       f.nome AS responsavel,
       CASE WHEN m.data_fim IS NULL THEN 'em andamento' ELSE 'concluída' END AS situacao
  FROM manutencao_vaga m
  JOIN vaga va         ON va.id_vaga = m.id_vaga
  JOIN funcionario f   ON f.id_funcionario = m.id_funcionario
 ORDER BY m.data_inicio;

-- Faturamento agrupado por forma de pagamento
CREATE OR REPLACE VIEW vw_faturamento_forma AS
SELECT forma_pagamento, COUNT(*) AS quantidade, SUM(valor) AS total
  FROM pagamento
 GROUP BY forma_pagamento
 ORDER BY total DESC;

-- Histórico de mudanças de status por vaga (auditoria)
CREATE OR REPLACE VIEW vw_historico_vagas AS
SELECT va.numero, h.status_anterior, h.status_novo, h.data_alteracao, h.usuario
  FROM historico_status_vaga h
  JOIN vaga va ON va.id_vaga = h.id_vaga
 ORDER BY h.data_alteracao, h.id_historico;