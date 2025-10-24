/******************************************************************************/
/*************************** VIEW_J_2023154006 ********************************/
/************************** MANUEL FURTADO ************************************/
/**************************** GROUP BY ****************************************/
/******************************************************************************/
CREATE OR REPLACE VIEW VIEW_J_2023154006 AS
WITH RecentSalesAgg AS (
    -- Passo 1, 2 e 3: Filtrar vendas recentes e agregar por máquina
    SELECT
        V.ID_MAQUINA,
        SUM(V.VALOR_TOTAL) AS RECEITA_TOTAL,
        AVG(V.VALOR_TOTAL) AS MEDIA_POR_TRANSACAO
    FROM
        Venda V
    WHERE
        V.DATA_VENDA >= TRUNC(SYSDATE) - INTERVAL '21' DAY -- Vendas desde há 21 dias (inclusive)
        -- Alternativa: V.DATA_VENDA >= SYSDATE - 21 (inclui a hora atual)
    GROUP BY
        V.ID_MAQUINA
)
-- Passo 4 e 5: Juntar com Máquina para obter o local e ordenar
SELECT
    M.ID_MAQUINA,
    M.LOCAL,
    NVL(RSA.RECEITA_TOTAL, 0) AS RECEITA_TOTAL, -- NVL caso uma máquina exista mas não tenha vendas recentes
    ROUND(NVL(RSA.MEDIA_POR_TRANSACAO, 0), 2) AS MEDIA_FATURACAO_TRANSACAO -- NVL e arredondamento
FROM
    Maquina M
LEFT JOIN -- Usar LEFT JOIN para incluir máquinas sem vendas recentes (mostrarão 0)
    RecentSalesAgg RSA ON M.ID_MAQUINA = RSA.ID_MAQUINA
-- Filtro opcional para excluir máquinas inativas, se necessário
-- WHERE M.ID_ESTADO_ATUAL <> 0 -- Descomentar se quiser excluir máquinas com estado 0 ('Inativa')
ORDER BY
    RECEITA_TOTAL DESC, -- Ordena pela receita total descendente
    M.ID_MAQUINA;       -- Critério de desempate

-- Para testar a vista depois de criada:
SELECT * FROM VIEW_J_2023154006;



/******************************************************************************/
/************************** VIEW_K_2023154006 *********************************/
/************************** MANUEL FURTADO ************************************/
/************************* SELECT ENCADEADO ***********************************/
/******************************************************************************/

CREATE OR REPLACE VIEW VIEW_K_2023154006 AS
WITH BelowMinimumStock AS (
    -- 1. Identifica configurações ativas com stock atual < quantidade mínima
    SELECT
        CC.ID_COMPARTIMENTO,
        CC.ID_PRODUTO,
        C.ID_MAQUINA,
        CC.STOCK_ATUAL,
        CC.QTD_MINIMA,
        CC.CAPACIDADE_PRODUTO
    FROM
        Configuracao_Compartimento CC
    JOIN
        Compartimento C ON CC.ID_COMPARTIMENTO = C.ID_COMPARTIMENTO
    WHERE
        CC.DATA_FIM_CONFIGURACAO IS NULL
        AND CC.STOCK_ATUAL < CC.QTD_MINIMA
),
LastRestock AS (
    -- 2. Encontra a data/hora do último abastecimento para cada compartimento/produto
    SELECT
        AD.ID_COMPARTIMENTO,
        AD.ID_PRODUTO,
        MAX(P.DATA_HORA_SAIDA) AS DATA_ULTIMO_ABASTECIMENTO_TS -- Renomeado para clareza (Timestamp original)
    FROM
        Abastecimento_Detalhe AD
    JOIN
        Paragem P ON AD.ID_PARAGEM = P.ID_PARAGEM
    WHERE
        P.DATA_HORA_SAIDA IS NOT NULL
    GROUP BY
        AD.ID_COMPARTIMENTO,
        AD.ID_PRODUTO
)
-- 3. Combina as informações e formata a data/hora
SELECT
    BMS.ID_MAQUINA,
    M.LOCAL AS LOCAL_MAQUINA,
    BMS.ID_COMPARTIMENTO,
    BMS.ID_PRODUTO,
    PR.NOME AS NOME_PRODUTO,
    BMS.STOCK_ATUAL,
    BMS.QTD_MINIMA,
    BMS.CAPACIDADE_PRODUTO,
    -- Formata o timestamp para string sem casas decimais
    TO_CHAR(LR.DATA_ULTIMO_ABASTECIMENTO_TS, 'YYYY-MM-DD HH24:MI:SS') AS DATA_ULTIMO_ABASTECIMENTO
FROM
    BelowMinimumStock BMS
LEFT JOIN
    LastRestock LR ON BMS.ID_COMPARTIMENTO = LR.ID_COMPARTIMENTO AND BMS.ID_PRODUTO = LR.ID_PRODUTO
JOIN
    Maquina M ON BMS.ID_MAQUINA = M.ID_MAQUINA
JOIN
    Produto PR ON BMS.ID_PRODUTO = PR.ID_PRODUTO
ORDER BY
    LR.DATA_ULTIMO_ABASTECIMENTO_TS ASC NULLS FIRST, -- Ordena pelo timestamp original
    BMS.ID_MAQUINA,
    BMS.ID_COMPARTIMENTO;




SELECT * FROM VIEW_K_2023154006;
  

