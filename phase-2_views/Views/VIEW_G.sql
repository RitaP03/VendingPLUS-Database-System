CREATE OR REPLACE VIEW VIEW_G AS
WITH Trips_Gt3_Machines AS (
    -- Identifica viagens em 2024 com mais de 3 máquinas distintas visitadas
    SELECT par.ID_VIAGEM
    FROM Paragem par
    JOIN Viagem v ON par.ID_VIAGEM = v.ID_VIAGEM
    WHERE EXTRACT(YEAR FROM v.DATA_HORA_INICIO) = EXTRACT(YEAR FROM SYSDATE) - 1 -- Ano passado
    GROUP BY par.ID_VIAGEM
    HAVING COUNT(DISTINCT par.ID_MAQUINA) > 3
),
AbastecimentosCoimbra2024 AS (
    -- Detalhes dos abastecimentos feitos em Coimbra nessas viagens válidas
    SELECT
        ad.ID_PRODUTO,
        ad.QUANTIDADE_ABASTECIDA,
        par.ID_MAQUINA,
        par.ID_VIAGEM -- Manter ID_VIAGEM para contagem
    FROM Abastecimento_Detalhe ad
    JOIN Paragem par ON ad.ID_PARAGEM = par.ID_PARAGEM
    JOIN Maquina m ON par.ID_MAQUINA = m.ID_MAQUINA
    WHERE par.ID_VIAGEM IN (SELECT ID_VIAGEM FROM Trips_Gt3_Machines)
      AND m.CIDADE = 'Coimbra'
)
-- Seleciona o top 2 final, agregado por tipo de produto
SELECT NUM_VIAGENS_ENVOLVIDAS, TIPO_PRODUTO, QUANT_ABASTECIDA, NUM_MAQ_ABASTECIDAS
FROM (
    -- Subconsulta para calcular totais por tipo e ordenar
    SELECT
        p.TIPO as TIPO_PRODUTO,
        SUM(a.QUANTIDADE_ABASTECIDA) as QUANT_ABASTECIDA,          -- Soma total da quantidade para este tipo
        COUNT(DISTINCT a.ID_MAQUINA) as NUM_MAQ_ABASTECIDAS, -- Conta máquinas distintas abastecidas com este tipo
        COUNT(DISTINCT a.ID_VIAGEM) as NUM_VIAGENS_ENVOLVIDAS -- Conta viagens distintas onde este tipo foi abastecido
    FROM AbastecimentosCoimbra2024 a
    JOIN Produto p ON a.ID_PRODUTO = p.ID_PRODUTO
    GROUP BY p.TIPO -- Agrega TUDO por tipo de produto
    ORDER BY QUANT_ABASTECIDA DESC -- Ordena pela quantidade total
)
WHERE ROWNUM <= 2; -- Filtra os 2 tipos de topo



SELECT * FROM VIEW_G;
