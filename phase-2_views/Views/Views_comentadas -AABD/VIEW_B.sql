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
    
    Abastecimento_Detalhe ad
JOIN
   
    Paragem pg ON ad.ID_PARAGEM = pg.ID_PARAGEM
JOIN
    
    Maquina m ON pg.ID_MAQUINA = m.ID_MAQUINA
JOIN
    
    Produto p ON ad.ID_PRODUTO = p.ID_PRODUTO
LEFT JOIN 
    
    Configuracao_Compartimento cc ON ad.ID_COMPARTIMENTO = cc.ID_COMPARTIMENTO
                                  AND cc.ID_PRODUTO = ad.ID_PRODUTO 
                                  AND cc.DATA_FIM_CONFIGURACAO IS NULL 
WHERE
    
    pg.ID_VIAGEM = 3 
ORDER BY
    pg.ORDEM_VISITA ASC,              
    ad.QUANTIDADE_ABASTECIDA DESC;    

-- Comentários 
COMMENT ON TABLE VIEW_B IS 'Detalhe cronológico de abastecimentos para a viagem específica ID = <ID_VIAGEM_CORRETO> (substituir ID). Mostra stock antes, quantidade abastecida e capacidade.';


SELECT * FROM VIEW_B;
