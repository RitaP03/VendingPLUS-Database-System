CREATE OR REPLACE VIEW VIEW_B AS
SELECT
    m.ID_MAQUINA,
    m.LOCAL,
    p.ID_PRODUTO        AS REF_PRODUTO,
    p.NOME              AS PRODUTO,
    ad.STOCK_ANTES_ABAST AS QUANT_EXISTENTE,
    ad.QUANTIDADE_ABASTECIDA,
    cc.CAPACIDADE_PRODUTO AS CAPACIDADE
FROM
    -- Come�a pelo detalhe do abastecimento, pois queremos info por produto abastecido
    Abastecimento_Detalhe ad
JOIN
    -- Junta a paragem para saber onde/quando ocorreu e filtrar pela viagem
    Paragem pg ON ad.ID_PARAGEM = pg.ID_PARAGEM
JOIN
    -- Junta a m�quina para obter o ID e Local
    Maquina m ON pg.ID_MAQUINA = m.ID_MAQUINA
JOIN
    -- Junta o produto para obter a Ref e Nome
    Produto p ON ad.ID_PRODUTO = p.ID_PRODUTO
LEFT JOIN -- LEFT JOIN para o caso (improv�vel) de n�o haver config ativa
    -- Junta a configura��o do compartimento para obter a capacidade
    Configuracao_Compartimento cc ON ad.ID_COMPARTIMENTO = cc.ID_COMPARTIMENTO
                                  AND cc.ID_PRODUTO = ad.ID_PRODUTO -- Garante que � a config do produto certo
                                  AND cc.DATA_FIM_CONFIGURACAO IS NULL -- Garante que a configura��o est� ativa
WHERE
    -- Filtra pela viagem espec�fica encontrada no Passo 1
    pg.ID_VIAGEM = 3 -- <<< SUBSTITUA AQUI o ID !!!
ORDER BY
    pg.ORDEM_VISITA ASC,              -- Ordena pela ordem da visita na viagem
    ad.QUANTIDADE_ABASTECIDA DESC;    -- Depois pela quantidade abastecida (descendente)

-- Coment�rios Opcionais
COMMENT ON TABLE VIEW_B IS 'Detalhe cronol�gico de abastecimentos para a viagem espec�fica ID = <ID_VIAGEM_CORRETO> (substituir ID). Mostra stock antes, quantidade abastecida e capacidade.';
-- COMMENT ON COLUMN VIEW_B.ID_MAQUINA IS 'ID da M�quina visitada';
-- ... (outros coment�rios de coluna)






SELECT * FROM VIEW_B;
