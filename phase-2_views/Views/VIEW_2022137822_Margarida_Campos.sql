/******************************************************************************/
/************************** VIEW_J_2022137822 *********************************/
/************************** MARGARIDA CAMPOS **********************************/
/**************************** GROUP BY ****************************************/
/******************************************************************************/
CREATE OR REPLACE VIEW VIEW_J_2022137822 AS
WITH RecentSalesDetails AS (
    -- Passo 1, 2 e 3: Seleciona vendas dos �ltimos 30 dias, junta com produto e extrai a hora
    SELECT
        P.TIPO AS TIPO_PRODUTO,
        EXTRACT(HOUR FROM V.DATA_VENDA) AS HORA_VENDA, -- Extrai a hora (0-23)
        V.ID_VENDA,
        V.QUANTIDADE
    FROM
        Venda V
    JOIN
        Produto P ON V.ID_PRODUTO = P.ID_PRODUTO
    WHERE
        V.DATA_VENDA >= TRUNC(SYSDATE) - INTERVAL '30' DAY -- Filtra para os �ltimos 30 dias
)
-- Passo 4 e 5: Agrupa por tipo e hora, calcula m�tricas e ordena
SELECT
    RSD.TIPO_PRODUTO,
    RSD.HORA_VENDA,
    COUNT(RSD.ID_VENDA) AS TOTAL_TRANSACOES,
    SUM(RSD.QUANTIDADE) AS QUANTIDADE_TOTAL_VENDIDA
FROM
    RecentSalesDetails RSD
GROUP BY
    RSD.TIPO_PRODUTO,
    RSD.HORA_VENDA
ORDER BY
    RSD.TIPO_PRODUTO ASC, -- Ordena primeiro por tipo de produto
    RSD.HORA_VENDA ASC;   -- Depois por hora


SELECT * FROM VIEW_J_2022137822;
  






/******************************************************************************/
/*************************** VIEW_K_2022137822 ********************************/
/************************** MARGARIDA CAMPOS **********************************/
/************************ SELECT ENCADEADO ************************************/
/******************************************************************************/
CREATE OR REPLACE VIEW VIEW_K_2022137822 AS
WITH ActiveConfigs AS (
    -- 1. Seleciona configura��es ativas e a m�quina associada
    SELECT
        CC.ID_COMPARTIMENTO,
        CC.ID_PRODUTO,
        C.ID_MAQUINA
    FROM
        Configuracao_Compartimento CC
    JOIN
        Compartimento C ON CC.ID_COMPARTIMENTO = C.ID_COMPARTIMENTO
    WHERE
        CC.DATA_FIM_CONFIGURACAO IS NULL -- Apenas configura��es ativas
),
RecentRestocks AS (
    -- 2. Identifica combina��es (Compartimento, Produto) abastecidas no �ltimo m�s
    SELECT DISTINCT -- Apenas precisamos saber SE foi abastecido, n�o quantas vezes
        AD.ID_COMPARTIMENTO,
        AD.ID_PRODUTO
    FROM
        Abastecimento_Detalhe AD
    JOIN
        Paragem P ON AD.ID_PARAGEM = P.ID_PARAGEM
    WHERE
        -- Considera abastecimentos ocorridos desde 1 m�s atr�s at� agora
        P.DATA_HORA_SAIDA >= TRUNC(SYSDATE) - INTERVAL '1' MONTH
        AND P.DATA_HORA_SAIDA IS NOT NULL -- Garante que a data de sa�da � v�lida
)
-- 3. Seleciona configura��es ativas que N�O est�o na lista de abastecimentos recentes
SELECT
    AC.ID_MAQUINA,
    M.LOCAL AS LOCAL_MAQUINA,
    AC.ID_COMPARTIMENTO,
    AC.ID_PRODUTO,
    PR.NOME AS NOME_PRODUTO
FROM
    ActiveConfigs AC -- Come�a com todas as configura��es ativas
LEFT JOIN -- Tenta encontrar um abastecimento recente para a configura��o ativa
    RecentRestocks RR ON AC.ID_COMPARTIMENTO = RR.ID_COMPARTIMENTO AND AC.ID_PRODUTO = RR.ID_PRODUTO
JOIN -- Junta para obter detalhes (INNER JOIN pois m�quina e produto devem existir para uma config ativa)
    Maquina M ON AC.ID_MAQUINA = M.ID_MAQUINA
JOIN
    Produto PR ON AC.ID_PRODUTO = PR.ID_PRODUTO
WHERE
    RR.ID_COMPARTIMENTO IS NULL -- Condi��o principal: N�O houve abastecimento recente (o LEFT JOIN falhou)
ORDER BY
    AC.ID_MAQUINA,
    AC.ID_COMPARTIMENTO,
    AC.ID_PRODUTO;

-- Para testar a vista depois de criada:
 SELECT * FROM VIEW_K_2022137822;









