CREATE OR REPLACE VIEW VIEW_E AS
WITH MachineRestockCounts AS (
    -- Passo 1a: Conta paragens distintas COM abastecimento por máquina (vida útil)
    SELECT
        pg.ID_MAQUINA,
        COUNT(DISTINCT pg.ID_PARAGEM) AS RestockCount
    FROM Paragem pg
    WHERE EXISTS (SELECT 1 FROM Abastecimento_Detalhe ad WHERE ad.ID_PARAGEM = pg.ID_PARAGEM) -- Garante que houve abastecimento
    GROUP BY pg.ID_MAQUINA
),
AvgRestocks AS (
    -- Passo 1b: Calcula a média geral de abastecimentos por máquina
    SELECT AVG(NVL(mrc.RestockCount, 0)) AS AvgRestockCount -- Usa NVL caso haja máquinas sem abastecimentos
    FROM Maquina m
    LEFT JOIN MachineRestockCounts mrc ON m.ID_MAQUINA = mrc.ID_MAQUINA -- LEFT JOIN para incluir todas as máquinas na média
),
QualifyingMachines AS (
    -- Passo 2: Seleciona máquinas ATUALMENTE operacionais E com abastecimentos acima da média
    SELECT
        m.ID_MAQUINA
    FROM Maquina m
    JOIN Estado_Maquina em ON m.ID_ESTADO_ATUAL = em.ID_ESTADO
    LEFT JOIN MachineRestockCounts mrc ON m.ID_MAQUINA = mrc.ID_MAQUINA
    CROSS JOIN AvgRestocks ar -- Junta a média global
    WHERE em.DESCRICAO = 'Operacional'                  -- Filtro: Estado atual operacional ([source: 258])
      AND NVL(mrc.RestockCount, 0) > ar.AvgRestockCount -- Filtro: Abastecimentos > Média ([source: 258])
),
MonthlySales AS (
    -- Passo 3: Calcula SUM(Quantidade) por Produto, Ano, Mês para máquinas qualificadas em 2023-2024
    SELECT
        v.ID_PRODUTO,
        EXTRACT(YEAR FROM v.DATA_VENDA) AS SaleYear,
        EXTRACT(MONTH FROM v.DATA_VENDA) AS SaleMonth,
        SUM(v.QUANTIDADE) AS MonthlyQuantity
    FROM Venda v
    WHERE v.ID_MAQUINA IN (SELECT ID_MAQUINA FROM QualifyingMachines) -- Filtro: Apenas máquinas qualificadas
      AND EXTRACT(YEAR FROM v.DATA_VENDA) IN (2023, 2024)             -- Filtro: Anos 2023 e 2024 ([source: 257])
    GROUP BY
        v.ID_PRODUTO,
        EXTRACT(YEAR FROM v.DATA_VENDA),
        EXTRACT(MONTH FROM v.DATA_VENDA)
),
AvgMonthlySalesPerProduct AS (
    -- Passo 4: Calcula a média das vendas mensais para cada produto
    SELECT
        ms.ID_PRODUTO,
        AVG(ms.MonthlyQuantity) AS AvgMonthlyQuantity
    FROM MonthlySales ms
    GROUP BY ms.ID_PRODUTO
)
-- Passo 5: Junção Final, Seleção e Ordenação
SELECT
    -- Nota: IDMAQUINA do exemplo [source: 260] omitido pois a média é POR PRODUTO, agregando várias máquinas.
    p.NOME AS PRODUTO,
    ROUND(amsp.AvgMonthlyQuantity) AS MEDIAMENSAL -- Arredondado para inteiro como no exemplo [source: 260]
FROM AvgMonthlySalesPerProduct amsp
JOIN Produto p ON amsp.ID_PRODUTO = p.ID_PRODUTO
ORDER BY
    MEDIAMENSAL DESC, -- Ordena pela média descendente ([source: 259])
    PRODUTO ASC;      -- Depois pelo nome do produto ascendente ([source: 259])

-- Comentários Opcionais
COMMENT ON TABLE VIEW_E IS 'Média mensal de vendas por produto (anos 2023-2024) considerando apenas máquinas operacionais com nº de abastecimentos acima da média.';
-- COMMENT ON COLUMN VIEW_E.PRODUTO IS 'Nome do Produto';
-- COMMENT ON COLUMN VIEW_E.MEDIAMENSAL IS 'Média arredondada da quantidade vendida por mês nesse período';


SELECT * FROM VIEW_E;





