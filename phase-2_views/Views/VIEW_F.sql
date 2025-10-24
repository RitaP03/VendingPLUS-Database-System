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
    -- Identify the top machine ID using ROWNUM for compatibility/simplicity
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
    -- Join TopMachineInfo here instead of subquery in WHERE
    JOIN TopMachineInfo tm ON v.ID_MAQUINA = tm.ID_MAQUINA
),
AguaSalesFebTopMachine AS (
    SELECT
        v.ID_PRODUTO,
        SUM(v.QUANTIDADE) AS QuantVendidaFeb
    FROM Venda v
    JOIN Produto p ON v.ID_PRODUTO = p.ID_PRODUTO
    JOIN FebBounds fb ON v.DATA_VENDA >= fb.StartOfFeb AND v.DATA_VENDA < fb.EndOfFeb
    JOIN TopMachineInfo tm ON v.ID_MAQUINA = tm.ID_MAQUINA -- Join TopMachineInfo
    WHERE p.TIPO = 'AGUA'
    GROUP BY v.ID_PRODUTO
),
AguaRestockFebTopMachine AS (
    SELECT
        ad.ID_PRODUTO,
        SUM(ad.QUANTIDADE_ABASTECIDA) AS QuantReabastecidaFeb
    FROM Abastecimento_Detalhe ad
    JOIN Paragem pg ON ad.ID_PARAGEM = pg.ID_PARAGEM
    JOIN Produto p ON ad.ID_PRODUTO = p.ID_PRODUTO
    JOIN FebBounds fb ON pg.DATA_HORA_SAIDA >= fb.StartOfFeb AND pg.DATA_HORA_SAIDA < fb.EndOfFeb
    JOIN TopMachineInfo tm ON pg.ID_MAQUINA = tm.ID_MAQUINA -- Join TopMachineInfo
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
    TopMachineInfo tm -- Start with the ID of the top machine
CROSS JOIN
    TotalSalesFebTopMachine tsf -- Cross join the total sales (should be single row based on tm)
JOIN
    AguaSalesFebTopMachine asf ON 1=1 -- Join sales details for that machine's AGUA products
LEFT JOIN
    AguaRestockFebTopMachine arf ON asf.ID_PRODUTO = arf.ID_PRODUTO -- Left join restock details
ORDER BY
    asf.ID_PRODUTO;
    
    
    
    
    
SELECT * FROM VIEW_F;
