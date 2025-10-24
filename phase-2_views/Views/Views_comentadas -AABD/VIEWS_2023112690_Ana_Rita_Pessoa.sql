/*****************************************************************************/
/************************** VIEW_J_2023112690 ********************************/
/************************** ANA RITA PESSOA **********************************/
/**************************** GROUP BY ***************************************/
/*****************************************************************************/



CREATE OR REPLACE VIEW VIEW_J_2023112690 AS
WITH NonOperationalTime AS (
    --Cálculo do tempo total não operacional de cada máquina
    SELECT
        LEM.ID_MAQUINA,
        SUM(
            -- Converte timestamps para DATE para subtração direta
            CAST(NVL(LEM.DATA_FIM_ESTADO, SYSTIMESTAMP) AS DATE) - CAST(LEM.DATA_INICIO_ESTADO AS DATE)
           ) AS TOTAL_DIAS_NAO_OPERACIONAL
    FROM
        Log_Estado_Maquina LEM
    WHERE
        LEM.ID_ESTADO IN (0, 2, 3, 4, 5, 6) --Considera apenas os estados não operacionais
        -- 0 = Inativa, 2 = Manutenção, 3 = Erro, 4 = Bloqueada, 5 = Offline, 6 = Sem Stock
    GROUP BY
        LEM.ID_MAQUINA
)
SELECT
    M.ID_MAQUINA,
    M.LOCAL,
    EM_Atual.DESCRICAO AS ESTADO_ATUAL,
    -- Contagem de frequência de cada estado 
    COUNT(CASE WHEN LEM_Hist.ID_ESTADO = 1 THEN 1 END) AS Freq_Operacional,
    COUNT(CASE WHEN LEM_Hist.ID_ESTADO = 2 THEN 1 END) AS Freq_Manutencao,
    COUNT(CASE WHEN LEM_Hist.ID_ESTADO = 3 THEN 1 END) AS Freq_Erro,
    COUNT(CASE WHEN LEM_Hist.ID_ESTADO = 4 THEN 1 END) AS Freq_Bloqueada,
    COUNT(CASE WHEN LEM_Hist.ID_ESTADO = 5 THEN 1 END) AS Freq_Offline,
    COUNT(CASE WHEN LEM_Hist.ID_ESTADO = 6 THEN 1 END) AS Freq_SemStock,
    COUNT(CASE WHEN LEM_Hist.ID_ESTADO = 0 THEN 1 END) AS Freq_Inativa,
    -- Tempo total não operacional
    ROUND(NVL(NOTime.TOTAL_DIAS_NAO_OPERACIONAL, 0), 2) AS TOTAL_DIAS_NAO_OPERACIONAL
FROM
    Maquina M
LEFT JOIN
    Estado_Maquina EM_Atual ON M.ID_ESTADO_ATUAL = EM_Atual.ID_ESTADO
LEFT JOIN
    Log_Estado_Maquina LEM_Hist ON M.ID_MAQUINA = LEM_Hist.ID_MAQUINA 
LEFT JOIN
    NonOperationalTime NOTime ON M.ID_MAQUINA = NOTime.ID_MAQUINA 
GROUP BY
    M.ID_MAQUINA,
    M.LOCAL,
    EM_Atual.DESCRICAO,
    NOTime.TOTAL_DIAS_NAO_OPERACIONAL 
ORDER BY
    M.ID_MAQUINA;


 SELECT * FROM VIEW_J_2023112690;





  
/******************************************************************************/
/*************************** VIEW_K_2023112690 ********************************/
/************************** ANA RITA PESSOA ***********************************/
/************************ SELECT ENCADEADO ************************************/
/******************************************************************************/
CREATE OR REPLACE VIEW VIEW_K_2023112690 AS
WITH StopsWithRestocking AS (
    -- Identifica paragens únicas onde ocorreu abastecimento e calcula a sua duração EM MINUTOS (NUMBER)
    SELECT DISTINCT 
        P.ID_VIAGEM,
        P.ID_MAQUINA,
        P.ID_PARAGEM,
        -- Calcula a duração da paragem diretamente em minutos 
        (EXTRACT(DAY FROM (P.DATA_HORA_SAIDA - P.DATA_HORA_CHEGADA)) * 1440) +
        (EXTRACT(HOUR FROM (P.DATA_HORA_SAIDA - P.DATA_HORA_CHEGADA)) * 60) +
         EXTRACT(MINUTE FROM (P.DATA_HORA_SAIDA - P.DATA_HORA_CHEGADA)) +
        (EXTRACT(SECOND FROM (P.DATA_HORA_SAIDA - P.DATA_HORA_CHEGADA)) / 60)
         AS StopDurationMinutes 
    FROM
        Paragem P
    JOIN
        Abastecimento_Detalhe AD ON P.ID_PARAGEM = AD.ID_PARAGEM
    WHERE
        P.DATA_HORA_SAIDA IS NOT NULL
        AND P.DATA_HORA_CHEGADA IS NOT NULL
        AND P.DATA_HORA_SAIDA >= P.DATA_HORA_CHEGADA 
),
TripMetrics AS (

    SELECT
        SWR.ID_VIAGEM,
        -- Conta máquinas visitadas COM abastecimento
        COUNT(DISTINCT SWR.ID_MAQUINA) AS N_MAQ_VISIT_ABAST,
        -- Calcula a  duração média das paragens
        AVG(SWR.StopDurationMinutes) AS AvgStopDurationMinutes
    FROM
        StopsWithRestocking SWR
    GROUP BY
        SWR.ID_VIAGEM
),
TripTotalQuantity AS (
    -- Calcula a quantidade total abastecida por cada viagem
    SELECT
        P.ID_VIAGEM,
        SUM(NVL(AD.QUANTIDADE_ABASTECIDA, 0)) AS QUANT_TOTAL_ABASTECIDA
    FROM
        Paragem P
    JOIN
        Abastecimento_Detalhe AD ON P.ID_PARAGEM = AD.ID_PARAGEM
    GROUP BY
        P.ID_VIAGEM
)

SELECT
    V.ID_VIAGEM,
    R.NOME_ROTA, 
    NVL(TM.N_MAQ_VISIT_ABAST, 0) AS N_MAQ_VISIT_ABAST,
  
    ROUND(NVL(TM.AvgStopDurationMinutes, 0), 2) AS TEMPO_MEDIO_PARAGEM_MIN,
    V.DISTANCIA_TOTAL_KM,
    NVL(TTQ.QUANT_TOTAL_ABASTECIDA, 0) AS QUANT_TOTAL_ABASTECIDA
FROM
    Viagem V
LEFT JOIN
    Rota R ON V.ID_ROTA = R.ID_ROTA 
LEFT JOIN
    TripMetrics TM ON V.ID_VIAGEM = TM.ID_VIAGEM 
LEFT JOIN
    TripTotalQuantity TTQ ON V.ID_VIAGEM = TTQ.ID_VIAGEM 
ORDER BY
    V.ID_VIAGEM; 




SELECT * FROM VIEW_K_2023112690;