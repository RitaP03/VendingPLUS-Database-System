CREATE OR REPLACE VIEW VIEW_H AS
WITH ViagensMesDist AS (
    -- Passo 1: Identificar viagens do mês passado (> 50km)
    SELECT ID_VIAGEM, MATRICULA_VEICULO
    FROM Viagem
    WHERE DISTANCIA_TOTAL_KM > 50
      AND TRUNC(DATA_HORA_INICIO, 'MM') = TRUNC(ADD_MONTHS(SYSDATE, -1), 'MM')
),
ViagensQualificadas AS (
    -- Passo 2: Filtrar viagens onde >= 3 máquinas distintas foram abastecidas com 'AGUA'
    SELECT VMD.ID_VIAGEM, VMD.MATRICULA_VEICULO
    FROM ViagensMesDist VMD
    JOIN Paragem P ON VMD.ID_VIAGEM = P.ID_VIAGEM
    JOIN Abastecimento_Detalhe AD ON P.ID_PARAGEM = AD.ID_PARAGEM
    JOIN Produto PR ON AD.ID_PRODUTO = PR.ID_PRODUTO
    WHERE PR.TIPO = 'AGUA'
    GROUP BY VMD.ID_VIAGEM, VMD.MATRICULA_VEICULO
    HAVING COUNT(DISTINCT P.ID_MAQUINA) >= 3
),
ContagemViagensPorVeiculo AS (
    -- Passo 3: Contar quantas viagens qualificadas cada veículo realizou
    SELECT
        MATRICULA_VEICULO,
        COUNT(DISTINCT ID_VIAGEM) AS NUM_VIAGENS_QUALIFICADAS
    FROM ViagensQualificadas
    GROUP BY MATRICULA_VEICULO
)
-- Passo 4: Selecionar detalhes dos 5 veículos de topo (Usando ROWNUM)
SELECT
    MATRICULA,
    MARCA,
    MODELO,
    NUM_VIAGENS_QUALIFICADAS
FROM (
    -- Subconsulta interna para aplicar a ordenação PRIMEIRO
    SELECT
        VE.MATRICULA,
        VE.MARCA,
        VE.MODELO,
        CVPV.NUM_VIAGENS_QUALIFICADAS
    FROM ContagemViagensPorVeiculo CVPV
    JOIN Veiculo VE ON CVPV.MATRICULA_VEICULO = VE.MATRICULA
    ORDER BY CVPV.NUM_VIAGENS_QUALIFICADAS DESC -- Ordena aqui
)
-- Consulta externa filtra as primeiras 5 linhas do resultado JÁ ordenado
WHERE ROWNUM <= 5;

SELECT * FROM VIEW_H;