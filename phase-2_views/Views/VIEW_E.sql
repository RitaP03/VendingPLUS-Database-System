CREATE OR REPLACE VIEW VIEW_E AS
WITH MachineRestockCounts AS (
    -- Passo 1a: Conta paragens distintas COM abastecimento por m�quina (vida �til)
    SELECT
        pg.ID_MAQUINA,
        COUNT(DISTINCT pg.ID_PARAGEM) AS RestockCount
    FROM Paragem pg
    WHERE EXISTS (SELECT 1 FROM Abastecimento_Detalhe ad WHERE ad.ID_PARAGEM = pg.ID_PARAGEM) -- Garante que houve abastecimento
    GROUP BY pg.ID_MAQUINA
),
AvgRestocks AS (
    -- Passo 1b: Calcula a m�dia geral de abastecimentos por m�quina
    SELECT AVG(NVL(mrc.RestockCount, 0)) AS AvgRestockCount -- Usa NVL caso haja m�quinas sem abastecimentos
    FROM Maquina m
    LEFT JOIN MachineRestockCounts mrc ON m.ID_MAQUINA = mrc.ID_MAQUINA -- LEFT JOIN para incluir todas as m�quinas na m�dia
),
QualifyingMachines AS (
    -- Passo 2: Seleciona m�quinas ATUALMENTE operacionais E com abastecimentos acima da m�dia
    SELECT
        m.ID_MAQUINA
    FROM Maquina m
    JOIN Estado_Maquina em ON m.ID_ESTADO_ATUAL = em.ID_ESTADO
    LEFT JOIN MachineRestockCounts mrc ON m.ID_MAQUINA = mrc.ID_MAQUINA
    CROSS JOIN AvgRestocks ar -- Junta a m�dia global
    WHERE em.DESCRICAO = 'Operacional'                  -- Filtro: Estado atual operacional ([source: 258])
      AND NVL(mrc.RestockCount, 0) > ar.AvgRestockCount -- Filtro: Abastecimentos > M�dia ([source: 258])
),
MonthlySales AS (
    -- Passo 3: Calcula SUM(Quantidade) por Produto, Ano, M�s para m�quinas qualificadas em 2023-2024
    SELECT
        v.ID_PRODUTO,
        EXTRACT(YEAR FROM v.DATA_VENDA) AS SaleYear,
        EXTRACT(MONTH FROM v.DATA_VENDA) AS SaleMonth,
        SUM(v.QUANTIDADE) AS MonthlyQuantity
    FROM Venda v
    WHERE v.ID_MAQUINA IN (SELECT ID_MAQUINA FROM QualifyingMachines) -- Filtro: Apenas m�quinas qualificadas
      AND EXTRACT(YEAR FROM v.DATA_VENDA) IN (2023, 2024)             -- Filtro: Anos 2023 e 2024 ([source: 257])
    GROUP BY
        v.ID_PRODUTO,
        EXTRACT(YEAR FROM v.DATA_VENDA),
        EXTRACT(MONTH FROM v.DATA_VENDA)
),
AvgMonthlySalesPerProduct AS (
    -- Passo 4: Calcula a m�dia das vendas mensais para cada produto
    SELECT
        ms.ID_PRODUTO,
        AVG(ms.MonthlyQuantity) AS AvgMonthlyQuantity
    FROM MonthlySales ms
    GROUP BY ms.ID_PRODUTO
)
-- Passo 5: Jun��o Final, Sele��o e Ordena��o
SELECT
    -- Nota: IDMAQUINA do exemplo [source: 260] omitido pois a m�dia � POR PRODUTO, agregando v�rias m�quinas.
    p.NOME AS PRODUTO,
    ROUND(amsp.AvgMonthlyQuantity) AS MEDIAMENSAL -- Arredondado para inteiro como no exemplo [source: 260]
FROM AvgMonthlySalesPerProduct amsp
JOIN Produto p ON amsp.ID_PRODUTO = p.ID_PRODUTO
ORDER BY
    MEDIAMENSAL DESC, -- Ordena pela m�dia descendente ([source: 259])
    PRODUTO ASC;      -- Depois pelo nome do produto ascendente ([source: 259])

-- Coment�rios Opcionais
COMMENT ON TABLE VIEW_E IS 'M�dia mensal de vendas por produto (anos 2023-2024) considerando apenas m�quinas operacionais com n� de abastecimentos acima da m�dia.';
-- COMMENT ON COLUMN VIEW_E.PRODUTO IS 'Nome do Produto';
-- COMMENT ON COLUMN VIEW_E.MEDIAMENSAL IS 'M�dia arredondada da quantidade vendida por m�s nesse per�odo';


SELECT * FROM VIEW_E;





