CREATE OR REPLACE VIEW VIEW_C AS
WITH MonthBounds AS (
    -- Define start e end do mês calendário anterior
    SELECT
        TRUNC(ADD_MONTHS(SYSDATE, -1), 'MM') AS StartOfMonth,
        TRUNC(SYSDATE, 'MM') AS EndOfMonth
    FROM dual
),
SalesLastMonth AS (
    -- Calcula vendas totais por máquina/produto no mês anterior
    SELECT
        v.ID_MAQUINA,
        v.ID_PRODUTO,
        SUM(NVL(v.QUANTIDADE, 0)) AS QUANT_VENDIDA_MES
    FROM Venda v
    JOIN MonthBounds mb ON v.DATA_VENDA >= mb.StartOfMonth AND v.DATA_VENDA < mb.EndOfMonth
    GROUP BY v.ID_MAQUINA, v.ID_PRODUTO
),
RankedSales AS (
    -- Ranking dos produtos por vendas dentro de cada máquina
    SELECT
        slm.ID_MAQUINA,
        slm.ID_PRODUTO,
        slm.QUANT_VENDIDA_MES,
        RANK() OVER (PARTITION BY slm.ID_MAQUINA ORDER BY slm.QUANT_VENDIDA_MES DESC, slm.ID_PRODUTO ASC) as SalesRank -- ID_PRODUTO para desempate
    FROM SalesLastMonth slm
),
TopSellerInfo AS (
    -- Seleciona apenas o produto Rank=1 (mais vendido) por máquina
    SELECT
        rs.ID_MAQUINA,
        rs.ID_PRODUTO,
        rs.QUANT_VENDIDA_MES
    FROM RankedSales rs
    WHERE rs.SalesRank = 1
),
LastRestockDate AS (
    -- Encontra data/hora do último abastecimento do produto top seller na máquina
    SELECT
        c.ID_MAQUINA,
        ad.ID_PRODUTO,
        MAX(pg.DATA_HORA_SAIDA) AS LAST_RESTOCK_TS
    FROM Abastecimento_Detalhe ad
    JOIN Paragem pg ON ad.ID_PARAGEM = pg.ID_PARAGEM
    JOIN Compartimento c ON ad.ID_COMPARTIMENTO = c.ID_COMPARTIMENTO
    -- Otimização: Apenas para os top sellers
    WHERE EXISTS (SELECT 1 FROM TopSellerInfo tsi WHERE tsi.ID_MAQUINA = c.ID_MAQUINA AND tsi.ID_PRODUTO = ad.ID_PRODUTO)
    GROUP BY c.ID_MAQUINA, ad.ID_PRODUTO
),
SalesSinceLastRestock AS (
    -- Calcula vendas do top seller desde o último abastecimento
    SELECT
        tsi.ID_MAQUINA,
        tsi.ID_PRODUTO,
        NVL(SUM(v.QUANTIDADE), 0) AS QUANT_VEND_DESDE_ULTIMO
    FROM TopSellerInfo tsi
    LEFT JOIN LastRestockDate lrd ON tsi.ID_MAQUINA = lrd.ID_MAQUINA AND tsi.ID_PRODUTO = lrd.ID_PRODUTO
    LEFT JOIN Venda v ON tsi.ID_MAQUINA = v.ID_MAQUINA
                     AND tsi.ID_PRODUTO = v.ID_PRODUTO
                     -- Vendas APÓS a data do último abastecimento (ou todas se nunca abastecido)
                     AND v.DATA_VENDA > NVL(lrd.LAST_RESTOCK_TS, TO_TIMESTAMP('1900-01-01', 'YYYY-MM-DD'))
                     AND v.DATA_VENDA < SYSTIMESTAMP -- Apenas vendas passadas
    GROUP BY tsi.ID_MAQUINA, tsi.ID_PRODUTO
),
StockCapacityCheck AS (
    -- Verifica se o stock total atual <= 50% da capacidade total para o produto top seller na máquina
    SELECT
      tsi.ID_MAQUINA,
      tsi.ID_PRODUTO,
      CASE
        WHEN SUM(NVL(cc.CAPACIDADE_PRODUTO, 0)) = 0 THEN 'KEEP' -- Mantém se capacidade for 0
        WHEN SUM(NVL(cc.STOCK_ATUAL, 0)) <= (0.5 * SUM(NVL(cc.CAPACIDADE_PRODUTO, 0))) THEN 'KEEP' -- Mantém se stock <= 50%
        ELSE 'EXCLUDE' -- Exclui se stock > 50%
      END AS KeepOrExclude
    FROM TopSellerInfo tsi
    JOIN Compartimento c ON tsi.ID_MAQUINA = c.ID_MAQUINA
    -- Junta todas as configurações ATIVAS para o produto top seller nesta máquina
    JOIN Configuracao_Compartimento cc ON c.ID_COMPARTIMENTO = cc.ID_COMPARTIMENTO
                                       AND cc.ID_PRODUTO = tsi.ID_PRODUTO
                                       AND cc.DATA_FIM_CONFIGURACAO IS NULL
    GROUP BY tsi.ID_MAQUINA, tsi.ID_PRODUTO -- Agrupa para somar stock/capacidade total
)
-- Montagem Final da View
SELECT
    tsi.ID_MAQUINA,
    m.LOCAL,
    tsi.ID_PRODUTO AS REF_PRODUTO,
    p.NOME AS PRODUTO,
    tsi.QUANT_VENDIDA_MES,
    sslr.QUANT_VEND_DESDE_ULTIMO
FROM TopSellerInfo tsi
JOIN Maquina m ON tsi.ID_MAQUINA = m.ID_MAQUINA
JOIN Produto p ON tsi.ID_PRODUTO = p.ID_PRODUTO
JOIN SalesSinceLastRestock sslr ON tsi.ID_MAQUINA = sslr.ID_MAQUINA AND tsi.ID_PRODUTO = sslr.ID_PRODUTO
JOIN StockCapacityCheck scc ON tsi.ID_MAQUINA = scc.ID_MAQUINA AND tsi.ID_PRODUTO = scc.ID_PRODUTO
WHERE scc.KeepOrExclude = 'KEEP' -- Aplica o filtro de exclusão stock/capacidade
ORDER BY
    tsi.QUANT_VENDIDA_MES ASC; -- Ordena pelos menos vendidos no mês anterior primeiro

-- Comentários Opcionais
COMMENT ON TABLE VIEW_C IS 'Mostra, por máquina, o produto mais vendido no mês anterior, quantidade vendida nesse mês e desde último abastecimento. Exclui produtos com stock atual > 50% da capacidade total na máquina.';

SELECT * FROM VIEW_C;