CREATE OR REPLACE VIEW VIEW_A AS
WITH CandidateMachines AS (
    -- Passo 1: Encontra máquinas ATIVAS em COIMBRA com Stock TOTAL de Snacks = 0 AGORA
    SELECT
        m.ID_MAQUINA,
        m.LOCAL
    FROM Maquina m
    JOIN Estado_Maquina em ON m.ID_ESTADO_ATUAL = em.ID_ESTADO
    WHERE m.CIDADE = 'Coimbra'
      AND em.DESCRICAO != 'Inativa'
      AND ( -- Subquery para verificar o stock total atual de Snacks
            SELECT NVL(SUM(cc.STOCK_ATUAL), 0)
            FROM Compartimento c
            JOIN Configuracao_Compartimento cc ON c.ID_COMPARTIMENTO = cc.ID_COMPARTIMENTO AND cc.DATA_FIM_CONFIGURACAO IS NULL
            JOIN Produto p ON cc.ID_PRODUTO = p.ID_PRODUTO
            WHERE c.ID_MAQUINA = m.ID_MAQUINA -- Verifica para esta máquina específica
            AND p.TIPO = 'Snacks'
          ) = 0
),
YesterdaySnackRestockDetails AS (
    -- Passo 2: Agrega detalhes de abastecimento de Snacks ocorridos ONTEM para CADA máquina
    SELECT
        p.ID_MAQUINA,
        MAX(p.DATA_HORA_SAIDA) AS LATEST_RESTOCK_TIME, -- Hora do último abastecimento ontem
        SUM(ad.QUANTIDADE_ABASTECIDA) AS TOTAL_QUANT_ABASTECIDA,
        COUNT(DISTINCT ad.ID_PRODUTO) AS NUM_DISTINCT_PRODUCTS
    FROM Paragem p
    JOIN Abastecimento_Detalhe ad ON p.ID_PARAGEM = ad.ID_PARAGEM
    JOIN Produto pr ON ad.ID_PRODUTO = pr.ID_PRODUTO
    WHERE pr.TIPO = 'Snacks'
      AND p.DATA_HORA_SAIDA >= TRUNC(SYSDATE) - 1 -- Filtra paragens de ontem
      AND p.DATA_HORA_SAIDA < TRUNC(SYSDATE)
    GROUP BY p.ID_MAQUINA -- Agrupa por máquina para obter totais diários
)
-- Passo 3: Junção Final - Seleciona apenas máquinas que estão em AMBOS os conjuntos
SELECT
    cm.ID_MAQUINA,
    cm.LOCAL,
    -- >> ALTERAÇÃO AQUI: Aplicar TO_CHAR <<
    TO_CHAR(yrd.LATEST_RESTOCK_TIME, 'DD/MM/YYYY HH24:MI:SS') AS DATA_HORA_ABAST,
    yrd.TOTAL_QUANT_ABASTECIDA AS QUANT_ABASTECIDA,
    yrd.NUM_DISTINCT_PRODUCTS AS NUM_PRODUTOS_DIFERENTES
FROM CandidateMachines cm
INNER JOIN YesterdaySnackRestockDetails yrd ON cm.ID_MAQUINA = yrd.ID_MAQUINA -- INNER JOIN garante que a máquina cumpre tudo
ORDER BY
    yrd.TOTAL_QUANT_ABASTECIDA ASC; -- Passo 4: Ordenar

-- Comentários (Opcional)
COMMENT ON TABLE VIEW_A IS 'Máquinas em Coimbra reabastecidas com Snacks ontem e atualmente sem stock desses produtos (excluindo inativas), com data/hora formatada.';

SELECT * FROM VIEW_A;


