-- =====================================================================
-- ESTACIONA AÍ - Carga inicial de dados (dados fictícios)
-- Ids fixos para facilitar os exemplos. Após cada carga com id explícito,
-- a sequência é reposicionada com setval().
-- =====================================================================

-- Tarifas: a vaga comum mudou de preço em 01/11/2026 (demonstra a vigência)
INSERT INTO tarifa (id_tarifa, tipo_vaga, valor_hora, vigencia_inicio, vigencia_fim) VALUES
    (1, 'comum', 8.00,  '2026-01-01 00:00:00', '2026-11-01 00:00:00'),
    (2, 'comum', 10.00, '2026-11-01 00:00:00', NULL),
    (3, 'idoso', 6.00,  '2026-01-01 00:00:00', NULL),
    (4, 'pcd',   5.00,  '2026-01-01 00:00:00', NULL),
    (5, 'moto',  4.00,  '2026-01-01 00:00:00', NULL);
SELECT setval(pg_get_serial_sequence('tarifa', 'id_tarifa'), (SELECT MAX(id_tarifa) FROM tarifa));

-- Clientes
INSERT INTO cliente (id_cliente, nome, cpf, telefone) VALUES
    (1, 'Ana Paula Ribeiro',    '123.456.789-01', '(11) 91234-5678'),
    (2, 'Carlos Eduardo Souza', '234.567.890-12', '(11) 92345-6789'),
    (3, 'Mariana Lopes Silva',  '345.678.901-23', NULL),
    (4, 'João Pedro Almeida',   '456.789.012-34', '(11) 94567-8901'),
    (5, 'Fernanda Costa Lima',  '567.890.123-45', '(11) 95678-9012');
SELECT setval(pg_get_serial_sequence('cliente', 'id_cliente'), (SELECT MAX(id_cliente) FROM cliente));

-- Veículos
INSERT INTO veiculo (id_veiculo, placa, modelo, cor, id_cliente) VALUES
    (1, 'ABC1D23', 'Fiat Argo',        'Branca',   1),
    (2, 'BRA2E19', 'Honda Civic',      'Preta',    1),
    (3, 'DEF3G45', 'Volkswagen Gol',   'Prata',    2),
    (4, 'GHI4J56', 'Yamaha Fazer 250', 'Azul',     3),
    (5, 'JKL5M67', 'Toyota Corolla',   'Cinza',    4),
    (6, 'MNO6P78', 'Chevrolet Onix',   'Vermelha', 5);
SELECT setval(pg_get_serial_sequence('veiculo', 'id_veiculo'), (SELECT MAX(id_veiculo) FROM veiculo));

-- Funcionários (o 3 está inativo: a procedure deve recusar suas operações)
INSERT INTO funcionario (id_funcionario, nome, cargo, usuario, ativo) VALUES
    (1, 'Roberto Alves',      'operador',   'roberto.alves',   TRUE),
    (2, 'Juliana Martins',    'supervisor', 'juliana.martins', TRUE),
    (3, 'Paulo Henrique Dias','operador',   'paulo.dias',      FALSE);
SELECT setval(pg_get_serial_sequence('funcionario', 'id_funcionario'), (SELECT MAX(id_funcionario) FROM funcionario));

-- Setores
INSERT INTO setor (id_setor, nome, descricao, coberto) VALUES
    (1, 'Subsolo 1', 'Vagas cobertas no subsolo', TRUE),
    (2, 'Térreo',    'Vagas descobertas na entrada', FALSE);
SELECT setval(pg_get_serial_sequence('setor', 'id_setor'), (SELECT MAX(id_setor) FROM setor));

-- Vagas (todas entram livres; as mudanças de status são feitas pelas triggers)
INSERT INTO vaga (id_vaga, numero, tipo_vaga, status, id_setor) VALUES
    (1,  1, 'comum', 'livre', 1),
    (2,  2, 'comum', 'livre', 1),
    (3,  3, 'comum', 'livre', 1),
    (4,  4, 'comum', 'livre', 2),
    (5,  5, 'idoso', 'livre', 2),
    (6,  6, 'pcd',   'livre', 2),
    (7,  7, 'moto',  'livre', 1),
    (8,  8, 'comum', 'livre', 2),
    (9,  9, 'comum', 'livre', 1),
    (10, 10, 'comum', 'livre', 2);
SELECT setval(pg_get_serial_sequence('vaga', 'id_vaga'), (SELECT MAX(id_vaga) FROM vaga));

-- Registros já encerrados (histórico). valor_pago = horas cobradas (arredondadas
-- para cima) x valor da tarifa vigente. Não alteram a situação da vaga.
INSERT INTO registro (id_registro, id_veiculo, id_vaga, id_tarifa, id_funcionario_entrada, id_funcionario_saida, data_entrada, data_saida, valor_pago) VALUES
    (1, 1, 1,  1, 1, 1, '2026-10-20 14:00:00', '2026-10-20 16:10:00', 24.00),  -- 3h x 8,00
    (2, 3, 2,  2, 1, 2, '2026-11-02 08:00:00', '2026-11-02 10:30:00', 30.00),  -- 3h x 10,00
    (3, 4, 7,  5, 2, 2, '2026-11-03 09:00:00', '2026-11-03 09:45:00',  4.00),  -- mínimo 1h x 4,00
    (4, 5, 5,  3, 1, 1, '2026-11-04 13:00:00', '2026-11-04 15:00:00', 12.00),  -- 2h x 6,00
    (5, 2, 9,  2, 2, 2, '2026-11-05 07:30:00', '2026-11-05 19:10:00', 120.00), -- 12h x 10,00
    (6, 6, 6,  4, 1, 2, '2026-11-06 10:00:00', '2026-11-06 10:20:00',  5.00),  -- mínimo 1h x 5,00
    (7, 1, 10, 2, 2, 2, '2026-11-07 18:00:00', '2026-11-07 21:30:00', 40.00);  -- 4h x 10,00
SELECT setval(pg_get_serial_sequence('registro', 'id_registro'), (SELECT MAX(id_registro) FROM registro));

-- Pagamentos dos registros encerrados
INSERT INTO pagamento (id_pagamento, id_registro, forma_pagamento, valor, data_pagamento, id_funcionario) VALUES
    (1, 1, 'pix',             24.00, '2026-10-20 16:12:00', 1),
    (2, 2, 'cartao_credito',  30.00, '2026-11-02 10:32:00', 2),
    (3, 3, 'dinheiro',         4.00, '2026-11-03 09:46:00', 2),
    (4, 4, 'cartao_debito',   12.00, '2026-11-04 15:02:00', 1),
    (5, 5, 'pix',            120.00, '2026-11-05 19:12:00', 2),
    (6, 6, 'pix',              5.00, '2026-11-06 10:21:00', 2),
    (7, 7, 'cartao_credito',  40.00, '2026-11-07 21:31:00', 2);
SELECT setval(pg_get_serial_sequence('pagamento', 'id_pagamento'), (SELECT MAX(id_pagamento) FROM pagamento));

-- Manutenções: uma concluída (vaga 4) e uma em andamento (vaga 8, que a trigger põe em 'manutencao')
INSERT INTO manutencao_vaga (id_manutencao, id_vaga, motivo, data_inicio, data_fim, id_funcionario) VALUES
    (1, 4, 'Troca de iluminação do térreo',               '2026-10-25 08:00:00', '2026-10-27 17:00:00', 2),
    (2, 8, 'Reparo no piso e refazimento da demarcação',  '2026-11-10 08:00:00', NULL,                  2);
SELECT setval(pg_get_serial_sequence('manutencao_vaga', 'id_manutencao'), (SELECT MAX(id_manutencao) FROM manutencao_vaga));

-- Entradas em aberto feitas pela procedure (as triggers ocupam as vagas)
CALL sp_registrar_entrada('ABC1D23', 1, 1);   -- registro 8: vaga 1 fica 'ocupada'
CALL sp_registrar_entrada('MNO6P78', 2, 1);   -- registro 9: vaga 2 fica 'ocupada'
CALL sp_registrar_entrada('BRA2E19', 9, 2);   -- registro 10: vaga 9 fica 'ocupada'

-- Para encerrar uma entrada em aberto:
-- CALL sp_registrar_saida(8, 'pix', 1);