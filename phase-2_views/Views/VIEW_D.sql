/*******************************************************************************/
/********************************** FUN��O *************************************/
/*******************************************************************************/
CREATE OR REPLACE FUNCTION distancia_linear (
    lat1 IN NUMBER,
    long1 IN NUMBER,
    lat2 IN NUMBER,
    long2 IN NUMBER
) RETURN NUMBER
AS
    -- Constantes
    PI_CONST CONSTANT NUMBER := ACOS(-1); -- Valor de PI
    RAIO_TERRA_KM CONSTANT NUMBER := 6371; -- Raio m�dio da Terra em KM

    -- Vari�veis para c�lculos em radianos
    lat1_rad NUMBER;
    long1_rad NUMBER;
    lat2_rad NUMBER;
    long2_rad NUMBER;
    delta_lat NUMBER;
    delta_long NUMBER;

    -- Vari�veis para f�rmula de Haversine
    a NUMBER;
    c NUMBER;
    distancia NUMBER;

BEGIN
    -- Verifica se alguma coordenada � nula
    IF lat1 IS NULL OR long1 IS NULL OR lat2 IS NULL OR long2 IS NULL THEN
        RETURN NULL; -- Retorna nulo se faltar alguma coordenada
    END IF;

    -- Converter graus para radianos
    lat1_rad := lat1 * PI_CONST / 180;
    long1_rad := long1 * PI_CONST / 180;
    lat2_rad := lat2 * PI_CONST / 180;
    long2_rad := long2 * PI_CONST / 180;

    -- Diferen�a das latitudes e longitudes em radianos
    delta_lat := lat2_rad - lat1_rad;
    delta_long := long2_rad - long1_rad;

    -- C�lculo da f�rmula de Haversine
    a := POWER(SIN(delta_lat / 2), 2) +
         COS(lat1_rad) * COS(lat2_rad) *
         POWER(SIN(delta_long / 2), 2);

    -- C�lculo intermedi�rio 'c'
    -- ATAN2(y, x) � prefer�vel a ATAN(y/x) para evitar divis�o por zero e obter o quadrante correto
    c := 2 * ATAN2(SQRT(a), SQRT(1 - a));

    -- C�lculo final da dist�ncia
    distancia := RAIO_TERRA_KM * c;

    RETURN distancia;

EXCEPTION
    -- Tratamento de exce��es gen�rico (pode ser mais espec�fico se necess�rio)
    WHEN OTHERS THEN
        -- Log do erro ou tratamento espec�fico pode ser adicionado aqui
        RETURN NULL; -- Retorna nulo em caso de erro matem�tico ou outro
END;
/






/*******************************************************************************/
/********************************** VIEW ***************************************/
/*******************************************************************************/
-- ====================================================================
--  SCRIPT PARA CRIAR VIEW_D
-- ====================================================================
-- NOTA: Esta view assume a exist�ncia de uma fun��o distancia_linear(lat1, lon1, lat2, lon2)
--       que calcula a dist�ncia em KM. Se n�o existir, crie-a conforme o requisito 'o'
--       do Checkpoint 3 ([source: 603]) ou substitua a chamada pela f�rmula Haversine.
-- ====================================================================

CREATE OR REPLACE VIEW VIEW_D AS
WITH TaveiroCoords AS (
    -- Coordenadas do Armazem 1 (Taveiro)
    SELECT LATITUDE, LONGITUDE
    FROM Armazem
    WHERE ID_ARMAZEM = 1
),
MachinesNearTaveiro AS (
    -- Seleciona m�quinas num raio de 30km de Taveiro e calcula a dist�ncia
    SELECT
        m.ID_MAQUINA,
        m.LOCAL,
        -- Substitua ou use a fun��o PL/SQL aqui:
        distancia_linear(m.LATITUDE, m.LONGITUDE, tc.LATITUDE, tc.LONGITUDE) AS DISTANCIA_LINEAR
    FROM Maquina m, TaveiroCoords tc -- Cross join para acesso f�cil �s coords de Taveiro
    WHERE distancia_linear(m.LATITUDE, m.LONGITUDE, tc.LATITUDE, tc.LONGITUDE) <= 30 -- Filtra por dist�ncia ([source: 254])
),
MachinesWithKitKat AS (
    -- Filtra as m�quinas pr�ximas que t�m KitKat (ID 9930) ativo ([source: 254])
    SELECT
        mnt.ID_MAQUINA,
        mnt.LOCAL,
        mnt.DISTANCIA_LINEAR
    FROM MachinesNearTaveiro mnt -- J� filtrado por dist�ncia
    WHERE EXISTS ( -- Verifica se existe config ativa para KitKat
        SELECT 1
        FROM Compartimento c
        JOIN Configuracao_Compartimento cc ON c.ID_COMPARTIMENTO = cc.ID_COMPARTIMENTO
        WHERE c.ID_MAQUINA = mnt.ID_MAQUINA
          AND cc.ID_PRODUTO = 9930 -- ID para KitKat Classic
          AND cc.DATA_FIM_CONFIGURACAO IS NULL
    )
),
MachineTotalStock AS (
    -- Calcula stock total atual (todos produtos ativos) para as m�quinas filtradas ([source: 255])
    SELECT
        c.ID_MAQUINA,
        NVL(SUM(cc.STOCK_ATUAL), 0) AS QUANT_TOTAL_PRODUTOS
    FROM Compartimento c
    JOIN Configuracao_Compartimento cc ON c.ID_COMPARTIMENTO = cc.ID_COMPARTIMENTO
                                       AND cc.DATA_FIM_CONFIGURACAO IS NULL -- Apenas configs ativas
    WHERE c.ID_MAQUINA IN (SELECT ID_MAQUINA FROM MachinesWithKitKat) -- Otimiza��o
    GROUP BY c.ID_MAQUINA
),
LastRestockTimestamp AS (
    -- Encontra timestamp da �ltima paragem com QUALQUER abastecimento para as m�quinas filtradas ([source: 255])
    SELECT
        p.ID_MAQUINA,
        MAX(p.DATA_HORA_SAIDA) AS DATA_ULT_ABAST -- Usar DATA_HORA_SAIDA como no exemplo [source: 256]
    FROM Paragem p
    WHERE p.ID_MAQUINA IN (SELECT ID_MAQUINA FROM MachinesWithKitKat) -- Otimiza��o
      AND EXISTS ( -- Garante que a paragem teve algum abastecimento
            SELECT 1
            FROM Abastecimento_Detalhe ad
            WHERE ad.ID_PARAGEM = p.ID_PARAGEM
          )
    GROUP BY p.ID_MAQUINA
)
-- Jun��o Final
SELECT
    mwk.ID_MAQUINA AS MAQUINAID, -- Alias como no exemplo [source: 256]
    mwk.LOCAL,
    ROUND(mwk.DISTANCIA_LINEAR, 1) AS DISTANCIA_LINEAR, -- Arredonda para 1 casa decimal [source: 256]
    -- Formatar data/hora para corresponder ao exemplo 'DD/MM/YYYY HH24"H"MI' [source: 256]
    TO_CHAR(lrt.DATA_ULT_ABAST, 'DD/MM/YYYY HH24"H"MI') AS DATA_ULT_ABAST,
    mts.QUANT_TOTAL_PRODUTOS
FROM MachinesWithKitKat mwk
LEFT JOIN MachineTotalStock mts ON mwk.ID_MAQUINA = mts.ID_MAQUINA -- LEFT JOIN por seguran�a
LEFT JOIN LastRestockTimestamp lrt ON mwk.ID_MAQUINA = lrt.ID_MAQUINA -- LEFT JOIN por seguran�a
ORDER BY
    mwk.DISTANCIA_LINEAR ASC; -- Ordena pela dist�ncia [source: 256]

-- Coment�rios Opcionais
COMMENT ON TABLE VIEW_D IS 'M�quinas num raio de 30km de Taveiro (Armazem 1) com KitKat, mostrando dist�ncia, �ltimo abastecimento (formatado) e stock total.';
-- COMMENT ON COLUMN VIEW_D.MAQUINAID IS 'ID da M�quina';
-- ... (etc.)





SELECT * FROM VIEW_D;

