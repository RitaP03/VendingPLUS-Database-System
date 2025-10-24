CREATE OR REPLACE VIEW VIEW_I AS
WITH BusiestWarehouse AS (
    -- Passo 1: Identificar o armazém com mais viagens desde o início do ano (compatível com Oracle 11g+)
    SELECT ID_ARMAZEM_ORIGEM
    FROM (
        SELECT ID_ARMAZEM_ORIGEM
        FROM Viagem
        WHERE DATA_HORA_INICIO >= TRUNC(SYSDATE, 'YYYY') -- Desde 1 de Janeiro do ano corrente
        GROUP BY ID_ARMAZEM_ORIGEM
        ORDER BY COUNT(*) DESC
    )
    WHERE ROWNUM = 1 -- Equivalente a FETCH FIRST 1 ROW ONLY para versões < 12c
),
RelevantTrips AS (
    -- Passo 2: Filtrar viagens do armazém mais movimentado desde o início do ano
    SELECT v.ID_VIAGEM, v.ID_ARMAZEM_ORIGEM
    FROM Viagem v
    JOIN BusiestWarehouse bw ON v.ID_ARMAZEM_ORIGEM = bw.ID_ARMAZEM_ORIGEM
    WHERE v.DATA_HORA_INICIO >= TRUNC(SYSDATE, 'YYYY')
),
VisitDetails AS (
    -- Passo 3 e 4: Detalhes das paragens e abastecimentos relevantes
    SELECT
        rt.ID_ARMAZEM_ORIGEM,
        p.ID_MAQUINA,
        p.ID_PARAGEM,
        ad.ID_PRODUTO,
        ad.QUANTIDADE_ABASTECIDA
    FROM RelevantTrips rt
    JOIN Paragem p ON rt.ID_VIAGEM = p.ID_VIAGEM
    LEFT JOIN Abastecimento_Detalhe ad ON p.ID_PARAGEM = ad.ID_PARAGEM -- LEFT JOIN para contar visitas mesmo sem abastecimento
),
VisitAggregates AS (
    -- Passo 5: Calcular métricas por visita individual (paragem)
    SELECT
        ID_ARMAZEM_ORIGEM,
        ID_MAQUINA,
        ID_PARAGEM,
        COUNT(DISTINCT ID_PRODUTO) as DistinctProductsPerVisit, -- Conta produtos distintos abastecidos na visita
        SUM(NVL(QUANTIDADE_ABASTECIDA, 0)) as QuantityPerVisit -- Soma quantidade abastecida na visita
    FROM VisitDetails
    GROUP BY ID_ARMAZEM_ORIGEM, ID_MAQUINA, ID_PARAGEM
),
MachineAggregates AS (
    -- Passo 6: Agregar métricas por máquina
    SELECT
        ID_ARMAZEM_ORIGEM,
        ID_MAQUINA,
        COUNT(ID_PARAGEM) as N_VISITAS,
        SUM(QuantityPerVisit) as QUANT_TOTAL,
        AVG(DistinctProductsPerVisit) as N_PROD_DIF_AVG -- Média dos produtos distintos por visita
    FROM VisitAggregates
    GROUP BY ID_ARMAZEM_ORIGEM, ID_MAQUINA
),
RankedMachines AS (
    -- Passo 7: Classificar as máquinas por número de visitas
    SELECT
        ma.*,
        RANK() OVER (ORDER BY N_VISITAS DESC) as RankByVisits
    FROM MachineAggregates ma
)
-- Passo 8 e 9: Selecionar Top 3, juntar nomes e ordenar
SELECT
    a.NOME AS ARMAZEM,
    m.LOCAL AS MAQUINA,
    rm.N_VISITAS,
    rm.QUANT_TOTAL,
    -- Calcula a média dividindo o total pelo número de visitas. Usa NULLIF para evitar divisão por zero, embora improvável aqui.
    ROUND(rm.QUANT_TOTAL / NULLIF(rm.N_VISITAS, 0), 2) AS QUANT_MEDIA_VISITA,
    ROUND(rm.N_PROD_DIF_AVG, 2) AS N_PROD_DIF
FROM RankedMachines rm
JOIN Armazem a ON rm.ID_ARMAZEM_ORIGEM = a.ID_ARMAZEM
JOIN Maquina m ON rm.ID_MAQUINA = m.ID_MAQUINA
WHERE rm.RankByVisits <= 3
ORDER BY rm.N_VISITAS DESC;












SELECT * FROM VIEW_I;