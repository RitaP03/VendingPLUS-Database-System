CREATE OR REPLACE VIEW VIEW_F AS
WITH TimeBounds72h AS (
    SELECT SYSTIMESTAMP - INTERVAL '72' HOUR AS StartTime72h FROM dual
),
AguaSales72h AS (
    SELECT
        v.ID_MAQUINA,
        SUM(v.QUANTIDADE) AS TotalAguaSold72h
    FROM Venda v
    JOIN Produto p ON v.ID_PRODUTO = p.ID_PRODUTO
    JOIN TimeBounds72h tb ON v.DATA_VENDA >= tb.StartTime72h
    WHERE p.TIPO = 'AGUA'
    GROUP BY v.ID_MAQUINA
),
TopMachineInfo AS (
    -- Identifica o id da maquina em primeiro lugar usando ROWNUM 
    SELECT ID_MAQUINA
    FROM (
        SELECT ID_MAQUINA
        FROM AguaSales72h
        ORDER BY TotalAguaSold72h DESC
    )
    WHERE ROWNUM = 1
),
FebBounds AS (
    SELECT TO_DATE('2025-02-01', 'YYYY-MM-DD') AS StartOfFeb,
           TO_DATE('2025-03-01', 'YYYY-MM-DD') AS EndOfFeb
    FROM dual
),
TotalSalesFebTopMachine AS (
    SELECT
        NVL(SUM(v.QUANTIDADE), 0) AS TotalQuantityFeb
    FROM Venda v
    JOIN FebBounds fb ON v.DATA_VENDA >= fb.StartOfFeb AND v.DATA_VENDA < fb.EndOfFeb
    JOIN TopMachineInfo tm ON v.ID_MAQUINA = tm.ID_MAQUINA
),
AguaSalesFebTopMachine AS (
-- Calcula a quantidade de produtos do tipo 'AGUA' vendidos pela máquina principal no mês de fevereiro
    SELECT
        v.ID_PRODUTO,
        SUM(v.QUANTIDADE) AS QuantVendidaFeb
    FROM Venda v
    JOIN Produto p ON v.ID_PRODUTO = p.ID_PRODUTO
    JOIN FebBounds fb ON v.DATA_VENDA >= fb.StartOfFeb AND v.DATA_VENDA < fb.EndOfFeb
    JOIN TopMachineInfo tm ON v.ID_MAQUINA = tm.ID_MAQUINA 
    WHERE p.TIPO = 'AGUA'
    GROUP BY v.ID_PRODUTO
),
AguaRestockFebTopMachine AS (
 -- Calcula a quantidade de produtos do tipo 'AGUA' reabastecidos pela máquina principal no mês de fevereiro
    SELECT
        ad.ID_PRODUTO,
        SUM(ad.QUANTIDADE_ABASTECIDA) AS QuantReabastecidaFeb
    FROM Abastecimento_Detalhe ad
    JOIN Paragem pg ON ad.ID_PARAGEM = pg.ID_PARAGEM
    JOIN Produto p ON ad.ID_PRODUTO = p.ID_PRODUTO
    JOIN FebBounds fb ON pg.DATA_HORA_SAIDA >= fb.StartOfFeb AND pg.DATA_HORA_SAIDA < fb.EndOfFeb
    JOIN TopMachineInfo tm ON pg.ID_MAQUINA = tm.ID_MAQUINA 
    WHERE p.TIPO = 'AGUA'
    GROUP BY ad.ID_PRODUTO
)
-- Final Assembly
SELECT
    tm.ID_MAQUINA                               AS IDMAQUINA,
    asf.ID_PRODUTO                              AS REFPRODUTO,
    asf.QuantVendidaFeb                         AS QUANT_VENDIDA,
    CASE
        WHEN tsf.TotalQuantityFeb = 0 THEN 0
        ELSE ROUND((asf.QuantVendidaFeb / tsf.TotalQuantityFeb) * 100)
    END                                         AS PERCENTAGEM,
    NVL(arf.QuantReabastecidaFeb, 0)            AS QUANT_REABASTECIDA
FROM
    TopMachineInfo tm 
CROSS JOIN
    TotalSalesFebTopMachine tsf 
JOIN
    AguaSalesFebTopMachine asf ON 1=1 
LEFT JOIN
    AguaRestockFebTopMachine arf ON asf.ID_PRODUTO = arf.ID_PRODUTO 
ORDER BY
    asf.ID_PRODUTO;
    
    
    
    
    
SELECT * FROM VIEW_F;
