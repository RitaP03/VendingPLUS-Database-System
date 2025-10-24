
-- =============================================================================
-- Sec��o 2: Cria��o da Estrutura (Tabelas, Fun��o, �ndice, Sequ�ncias)
-- =============================================================================

CREATE TABLE Armazem (
    ID_ARMAZEM NUMBER(8,0) NOT NULL,
    NOME VARCHAR2(100 BYTE),
    LOCAL VARCHAR2(100 BYTE),
    CIDADE VARCHAR2(50 BYTE),
    LATITUDE NUMBER(10,6),
    LONGITUDE NUMBER(10,6),
    CONSTRAINT pk_armazem PRIMARY KEY (ID_ARMAZEM)
);
COMMENT ON TABLE Armazem IS 'Armaz�ns onde os produtos ficam estocados.';
COMMENT ON COLUMN Armazem.ID_ARMAZEM IS 'Identificador �nico do armaz�m.';

CREATE TABLE Veiculo (
    MATRICULA VARCHAR2(10 BYTE) NOT NULL,
    MARCA VARCHAR2(50 BYTE),
    MODELO VARCHAR2(50 BYTE),
    TARA NUMBER(10,0),
    AUTONOMIA_MAX_KM NUMBER(5,0) DEFAULT 300,
    ESTADO_VEICULO VARCHAR2(15 BYTE),
    ID_ARMAZEM_BASE NUMBER(8,0),
    CONSTRAINT pk_veiculo PRIMARY KEY (MATRICULA),
    CONSTRAINT fk_veiculo_armazem FOREIGN KEY (ID_ARMAZEM_BASE) REFERENCES Armazem(ID_ARMAZEM),
    CONSTRAINT chk_veiculo_estado CHECK (ESTADO_VEICULO IN ('Dispon�vel', 'Em Viagem', 'Manuten��o', 'Indispon�vel'))
);
COMMENT ON TABLE Veiculo IS 'Ve�culos utilizados nas viagens de abastecimento.';
COMMENT ON COLUMN Veiculo.AUTONOMIA_MAX_KM IS 'Autonomia m�xima em KMs (default 300).';

CREATE TABLE Funcionario (
    ID_FUNCIONARIO NUMBER(8,0) NOT NULL,
    NOME VARCHAR2(100 BYTE),
    CONTATO VARCHAR2(15 BYTE),
    ESTADO VARCHAR2(20 BYTE),
    CONSTRAINT pk_funcionario PRIMARY KEY (ID_FUNCIONARIO),
    CONSTRAINT chk_funcionario_estado CHECK (ESTADO IN ('Ativo', 'Inativo'))
);
COMMENT ON TABLE Funcionario IS 'Funcion�rios que realizam as viagens ou manuten��es.';

CREATE TABLE Estado_Maquina (
    ID_ESTADO NUMBER(8,0) NOT NULL,
    DESCRICAO VARCHAR2(50 BYTE) UNIQUE,
    CONSTRAINT pk_estado_maquina PRIMARY KEY (ID_ESTADO)
);
COMMENT ON TABLE Estado_Maquina IS 'Tabela de dom�nio para os poss�veis estados de uma m�quina.';

CREATE TABLE Maquina (
    ID_MAQUINA NUMBER(10,0) NOT NULL,
    LOCAL VARCHAR2(100 BYTE),
    CIDADE VARCHAR2(50 BYTE),
    LATITUDE NUMBER(10,6),
    LONGITUDE NUMBER(10,6),
    DATA_INSTALACAO DATE,
    ULTIMA_ATUALIZACAO_STATUS TIMESTAMP,
    ID_ESTADO_ATUAL NUMBER(8,0),
    CONSTRAINT pk_maquina PRIMARY KEY (ID_MAQUINA),
    CONSTRAINT fk_maquina_estado FOREIGN KEY (ID_ESTADO_ATUAL) REFERENCES Estado_Maquina(ID_ESTADO)
);
COMMENT ON TABLE Maquina IS 'M�quinas de venda autom�tica.';
COMMENT ON COLUMN Maquina.ULTIMA_ATUALIZACAO_STATUS IS 'Timestamp da �ltima comunica��o recebida da m�quina (ping ou altera��o de estado). Essencial para detetar estado Offline.';

CREATE TABLE Compartimento (
    ID_COMPARTIMENTO NUMBER(8,0) NOT NULL,
    ID_MAQUINA NUMBER(10,0) NOT NULL,
    POSICAO_NA_MAQUINA VARCHAR2(10 BYTE),
    CONSTRAINT pk_compartimento PRIMARY KEY (ID_COMPARTIMENTO),
    CONSTRAINT fk_comp_maquina FOREIGN KEY (ID_MAQUINA) REFERENCES Maquina(ID_MAQUINA) ON DELETE CASCADE
);
COMMENT ON TABLE Compartimento IS 'Compartimentos f�sicos dentro de cada m�quina.';
COMMENT ON COLUMN Compartimento.POSICAO_NA_MAQUINA IS 'C�digo ou descri��o da posi��o (ex: A1, B3).';

CREATE TABLE Produto (
    ID_PRODUTO NUMBER(8,0) NOT NULL,
    NOME VARCHAR2(100 BYTE),
    TIPO VARCHAR2(20 BYTE),
    DESCRICAO VARCHAR2(255 BYTE),
    CONSTRAINT pk_produto PRIMARY KEY (ID_PRODUTO)
);
COMMENT ON TABLE Produto IS 'Produtos dispon�veis para venda nas m�quinas.';

CREATE OR REPLACE FUNCTION get_maquina_id_func (p_id_compartimento IN NUMBER)
  RETURN NUMBER DETERMINISTIC
AS
  v_id_maquina NUMBER;
BEGIN
  IF p_id_compartimento IS NULL THEN
      RETURN NULL;
  END IF;
  SELECT c.ID_MAQUINA INTO v_id_maquina
  FROM Compartimento c
  WHERE c.ID_COMPARTIMENTO = p_id_compartimento;
  RETURN v_id_maquina;
EXCEPTION
  WHEN NO_DATA_FOUND THEN
    RAISE_APPLICATION_ERROR(-20001, 'Fun��o get_maquina_id_func: Compartimento inexistente ID=' || p_id_compartimento);
END;
/

CREATE TABLE Configuracao_Compartimento (
    ID_CONFIGURACAO NUMBER(10,0) NOT NULL,
    ID_COMPARTIMENTO NUMBER(8,0) NOT NULL,
    ID_PRODUTO NUMBER(8,0) NOT NULL,
    PRECO_VENDA NUMBER(5,2) NOT NULL,
    CODIGO_CLIENTE VARCHAR2(10 BYTE),
    CAPACIDADE_PRODUTO NUMBER(4,0) NOT NULL,
    QTD_MINIMA NUMBER(4,0) DEFAULT 0,
    STOCK_ATUAL NUMBER(4,0) DEFAULT 0,
    DATA_CONFIGURACAO DATE DEFAULT SYSDATE,
    DATA_FIM_CONFIGURACAO DATE DEFAULT NULL,
    CONSTRAINT pk_config_comp PRIMARY KEY (ID_CONFIGURACAO),
    CONSTRAINT fk_confcomp_comp FOREIGN KEY (ID_COMPARTIMENTO) REFERENCES Compartimento(ID_COMPARTIMENTO) ON DELETE CASCADE,
    CONSTRAINT fk_confcomp_prod FOREIGN KEY (ID_PRODUTO) REFERENCES Produto(ID_PRODUTO),
    CONSTRAINT chk_confcomp_stock CHECK (STOCK_ATUAL >= 0 AND STOCK_ATUAL <= CAPACIDADE_PRODUTO)
);
COMMENT ON TABLE Configuracao_Compartimento IS 'Configura��o de qual produto est� em qual compartimento, a que pre�o, capacidade e stock.';
COMMENT ON COLUMN Configuracao_Compartimento.CODIGO_CLIENTE IS 'C�digo que o cliente digita na m�quina para selecionar o produto neste compartimento.';
COMMENT ON COLUMN Configuracao_Compartimento.QTD_MINIMA IS 'Quantidade m�nima desejada para este produto neste compartimento (para alertas de reposi��o).';
COMMENT ON COLUMN Configuracao_Compartimento.STOCK_ATUAL IS 'Quantidade atual do produto neste compartimento.';
COMMENT ON COLUMN Configuracao_Compartimento.DATA_FIM_CONFIGURACAO IS 'Data em que esta configura��o deixou de ser ativa (para hist�rico - Q12). NULL significa ativa.';

CREATE UNIQUE INDEX uk_confcomp_maq_codcliente_fbi
  ON Configuracao_Compartimento (get_maquina_id_func(ID_COMPARTIMENTO), CODIGO_CLIENTE);
-- Garante que um CODIGO_CLIENTE (tecla digitada) � �nico por m�quina.

CREATE TABLE Rota (
    ID_ROTA NUMBER(8,0) NOT NULL,
    NOME_ROTA VARCHAR2(100 BYTE) UNIQUE,
    DESCRICAO VARCHAR2(255 BYTE),
    ID_ARMAZEM_ORIGEM NUMBER(8,0),
    DISTANCIA_TOTAL_KM NUMBER(10,2),
    ATIVO CHAR(1) DEFAULT 'S',
    CONSTRAINT pk_rota PRIMARY KEY (ID_ROTA),
    CONSTRAINT fk_rota_armazem FOREIGN KEY (ID_ARMAZEM_ORIGEM) REFERENCES Armazem(ID_ARMAZEM),
    CONSTRAINT chk_rota_ativo CHECK (ATIVO IN ('S', 'N'))
);
COMMENT ON TABLE Rota IS 'Rotas pr�-definidas para as viagens de abastecimento.';
COMMENT ON COLUMN Rota.DISTANCIA_TOTAL_KM IS 'Dist�ncia total estimada da rota (para Q22). Precisa ser calculada externamente ou por fun��o.';

CREATE TABLE Detalhe_Rota (
    ID_ROTA NUMBER(8,0) NOT NULL,
    ID_MAQUINA NUMBER(10,0) NOT NULL,
    ORDEM_VISITA NUMBER(4,0) NOT NULL,
    CONSTRAINT pk_detalhe_rota PRIMARY KEY (ID_ROTA, ORDEM_VISITA),
    CONSTRAINT fk_detrota_rota FOREIGN KEY (ID_ROTA) REFERENCES Rota(ID_ROTA) ON DELETE CASCADE,
    CONSTRAINT fk_detrota_maq FOREIGN KEY (ID_MAQUINA) REFERENCES Maquina(ID_MAQUINA),
    CONSTRAINT uk_detrota_maq UNIQUE (ID_ROTA, ID_MAQUINA)
);
COMMENT ON TABLE Detalhe_Rota IS 'Define a sequ�ncia de m�quinas para cada rota pr�-definida.';

CREATE TABLE Viagem (
    ID_VIAGEM NUMBER(15,0) NOT NULL,
    ID_FUNCIONARIO NUMBER(8,0),
    MATRICULA_VEICULO VARCHAR2(10 BYTE),
    ID_ARMAZEM_ORIGEM NUMBER(8,0),
    ID_ARMAZEM_FIM NUMBER(8,0),
    ID_ROTA NUMBER(8,0) DEFAULT NULL,
    DATA_HORA_INICIO TIMESTAMP,
    DATA_HORA_FIM TIMESTAMP,
    DISTANCIA_TOTAL_KM NUMBER(10,2),
    ESTADO_VIAGEM VARCHAR2(20 BYTE),
    CONSTRAINT pk_viagem PRIMARY KEY (ID_VIAGEM),
    CONSTRAINT fk_viagem_func FOREIGN KEY (ID_FUNCIONARIO) REFERENCES Funcionario(ID_FUNCIONARIO),
    CONSTRAINT fk_viagem_veic FOREIGN KEY (MATRICULA_VEICULO) REFERENCES Veiculo(MATRICULA),
    CONSTRAINT fk_viagem_arm_orig FOREIGN KEY (ID_ARMAZEM_ORIGEM) REFERENCES Armazem(ID_ARMAZEM),
    CONSTRAINT fk_viagem_arm_fim FOREIGN KEY (ID_ARMAZEM_FIM) REFERENCES Armazem(ID_ARMAZEM),
    CONSTRAINT fk_viagem_rota FOREIGN KEY (ID_ROTA) REFERENCES Rota(ID_ROTA)
);
COMMENT ON TABLE Viagem IS 'Registo de cada viagem de abastecimento/manuten��o realizada.';
COMMENT ON COLUMN Viagem.ID_ROTA IS 'Refer�ncia opcional � rota pr�-definida seguida (para Q27).';
COMMENT ON COLUMN Viagem.DISTANCIA_TOTAL_KM IS 'Dist�ncia real percorrida na viagem (pode ser calculada no fim ou via GPS).';

CREATE TABLE Paragem (
    ID_PARAGEM NUMBER(15,0) NOT NULL,
    ID_VIAGEM NUMBER(15,0) NOT NULL,
    ID_MAQUINA NUMBER(10,0) NOT NULL,
    ORDEM_VISITA NUMBER(4,0) NOT NULL,
    DATA_HORA_CHEGADA TIMESTAMP,
    DATA_HORA_SAIDA TIMESTAMP,
    TIPO_VISITA VARCHAR2(30 BYTE) DEFAULT 'Abastecimento',
    DISTANCIA_PERCORRIDA_KM NUMBER(10,2),
    CONSTRAINT pk_paragem PRIMARY KEY (ID_PARAGEM),
    CONSTRAINT fk_paragem_viagem FOREIGN KEY (ID_VIAGEM) REFERENCES Viagem(ID_VIAGEM) ON DELETE CASCADE,
    CONSTRAINT fk_paragem_maq FOREIGN KEY (ID_MAQUINA) REFERENCES Maquina(ID_MAQUINA),
    CONSTRAINT uk_paragem_viag_ordem UNIQUE (ID_VIAGEM, ORDEM_VISITA)
);
COMMENT ON TABLE Paragem IS 'Registo de cada paragem efetuada numa m�quina durante uma viagem.';
COMMENT ON COLUMN Paragem.TIPO_VISITA IS 'Indica o prop�sito principal da paragem (Abastecimento, Manutencao, etc.).';
COMMENT ON COLUMN Paragem.DISTANCIA_PERCORRIDA_KM IS 'Dist�ncia percorrida desde a �ltima paragem ou origem (para Q34). Precisa ser calculada/registada.';

CREATE TABLE Abastecimento_Detalhe (
    ID_ABASTECIMENTO NUMBER(15,0) NOT NULL,
    ID_PARAGEM NUMBER(15,0) NOT NULL,
    ID_PRODUTO NUMBER(8,0) NOT NULL,
    ID_COMPARTIMENTO NUMBER(8,0) NOT NULL, -- Tornada NOT NULL explicitamente
    QUANTIDADE_ABASTECIDA NUMBER(5,0) NOT NULL,
    STOCK_ANTES_ABAST NUMBER(5,0),
    STOCK_DEPOIS_ABAST NUMBER(5,0),
    CONSTRAINT pk_abastecimento PRIMARY KEY (ID_ABASTECIMENTO),
    CONSTRAINT fk_abast_paragem FOREIGN KEY (ID_PARAGEM) REFERENCES Paragem(ID_PARAGEM) ON DELETE CASCADE,
    CONSTRAINT fk_abast_prod FOREIGN KEY (ID_PRODUTO) REFERENCES Produto(ID_PRODUTO),
    CONSTRAINT fk_abast_comp FOREIGN KEY (ID_COMPARTIMENTO) REFERENCES Compartimento(ID_COMPARTIMENTO),
    CONSTRAINT chk_abast_qtd CHECK (QUANTIDADE_ABASTECIDA >= 0)
);
COMMENT ON TABLE Abastecimento_Detalhe IS 'Detalhe dos produtos abastecidos numa paragem.';
COMMENT ON COLUMN Abastecimento_Detalhe.ID_COMPARTIMENTO IS 'Identifica o compartimento espec�fico que foi abastecido (para Q35).';
COMMENT ON COLUMN Abastecimento_Detalhe.STOCK_ANTES_ABAST IS 'Stock registado no in�cio da interven��o no compartimento.';
COMMENT ON COLUMN Abastecimento_Detalhe.STOCK_DEPOIS_ABAST IS 'Stock registado no fim da interven��o no compartimento.';

CREATE TABLE Encomenda (
    ID_ENCOMENDA NUMBER(15,0) NOT NULL,
    ID_ARMAZEM NUMBER(8,0) NOT NULL,
    DATA_ENCOMENDA DATE DEFAULT SYSDATE,
    DATA_PREV_ENTREGA DATE,
    DATA_ENTREGA_REAL DATE, -- [SUGEST�O]
    ESTADO_ENCOMENDA VARCHAR2(20 BYTE),
    CONSTRAINT pk_encomenda_aabd PRIMARY KEY (ID_ENCOMENDA),
    CONSTRAINT fk_enc_arm_aabd FOREIGN KEY (ID_ARMAZEM) REFERENCES Armazem(ID_ARMAZEM)
);
COMMENT ON TABLE Encomenda IS 'Encomendas de produtos feitas aos fornecedores para um armaz�m.';
COMMENT ON COLUMN Encomenda.DATA_ENTREGA_REAL IS '[SUGEST�O] Data em que a encomenda foi efetivamente recebida no armaz�m.';

CREATE TABLE Detalhe_Encomenda (
    ID_ENCOMENDA NUMBER(15,0) NOT NULL,
    ID_PRODUTO NUMBER(8,0) NOT NULL,
    QUANTIDADE_ENCOMENDADA NUMBER(6,0) NOT NULL,
    QUANTIDADE_RECEBIDA NUMBER(6,0) DEFAULT 0, -- [SUGEST�O]
    CONSTRAINT pk_detalhe_encomenda PRIMARY KEY (ID_ENCOMENDA, ID_PRODUTO),
    CONSTRAINT fk_detenc_enc FOREIGN KEY (ID_ENCOMENDA) REFERENCES Encomenda(ID_ENCOMENDA) ON DELETE CASCADE,
    CONSTRAINT fk_detenc_prod FOREIGN KEY (ID_PRODUTO) REFERENCES Produto(ID_PRODUTO),
    CONSTRAINT chk_detenc_qtd_rec CHECK (QUANTIDADE_RECEBIDA >= 0 AND QUANTIDADE_RECEBIDA <= QUANTIDADE_ENCOMENDADA) -- [SUGEST�O]
);
COMMENT ON TABLE Detalhe_Encomenda IS 'Detalhe dos produtos e quantidades de cada encomenda.';
COMMENT ON COLUMN Detalhe_Encomenda.QUANTIDADE_RECEBIDA IS '[SUGEST�O] Quantidade efetivamente recebida para este produto nesta encomenda.';

CREATE TABLE Stock_Armazem (
    ID_ARMAZEM NUMBER(8,0) NOT NULL,
    ID_PRODUTO NUMBER(8,0) NOT NULL,
    STOCK_ATUAL NUMBER(6,0) DEFAULT 0 NOT NULL,
    QTD_MINIMA_STOCK NUMBER(6,0) DEFAULT 50,
    DATA_ULTIMA_ENTRADA DATE,
    DATA_ULTIMA_SAIDA DATE, -- [SUGEST�O]
    CONSTRAINT pk_stock_arm PRIMARY KEY (ID_ARMAZEM, ID_PRODUTO),
    CONSTRAINT fk_stockarm_arm FOREIGN KEY (ID_ARMAZEM) REFERENCES Armazem(ID_ARMAZEM),
    CONSTRAINT fk_stockarm_prod FOREIGN KEY (ID_PRODUTO) REFERENCES Produto(ID_PRODUTO)
);
COMMENT ON TABLE Stock_Armazem IS 'Stock atual de cada produto em cada armaz�m.';
COMMENT ON COLUMN Stock_Armazem.DATA_ULTIMA_ENTRADA IS 'Data da �ltima rece��o deste produto (via Encomenda).';
COMMENT ON COLUMN Stock_Armazem.DATA_ULTIMA_SAIDA IS '[SUGEST�O] Data da �ltima sa�da deste produto para uma Carga_Viagem.';

CREATE TABLE Log_Estado_Maquina (
    ID_LOG_ESTADO NUMBER(15,0) NOT NULL,
    ID_MAQUINA NUMBER(10,0) NOT NULL,
    ID_ESTADO NUMBER(8,0) NOT NULL,
    DATA_INICIO_ESTADO TIMESTAMP DEFAULT SYSTIMESTAMP NOT NULL,
    DATA_FIM_ESTADO TIMESTAMP,
    ORIGEM_ALTERACAO VARCHAR2(50 BYTE), -- [SUGEST�O]
    CONSTRAINT pk_log_estado PRIMARY KEY (ID_LOG_ESTADO),
    CONSTRAINT fk_logestado_maq FOREIGN KEY (ID_MAQUINA) REFERENCES Maquina(ID_MAQUINA) ON DELETE CASCADE,
    CONSTRAINT fk_logestado_est FOREIGN KEY (ID_ESTADO) REFERENCES Estado_Maquina(ID_ESTADO)
);
COMMENT ON TABLE Log_Estado_Maquina IS 'Hist�rico das mudan�as de estado de cada m�quina.';
COMMENT ON COLUMN Log_Estado_Maquina.ORIGEM_ALTERACAO IS '[SUGEST�O] Indica o que despoletou a mudan�a de estado (ex: comunica��o da m�quina, interven��o manual, trigger).';

CREATE TABLE Carga_Viagem (
    ID_CARGA NUMBER(15,0) NOT NULL,
    ID_VIAGEM NUMBER(15,0) NOT NULL,
    ID_PRODUTO NUMBER(8,0) NOT NULL,
    QUANTIDADE_CARREGADA NUMBER(6,0) NOT NULL,
    QUANTIDADE_ATUAL_VEICULO NUMBER(6,0),      -- << ALTERA��O (Q32) >>
    CONSTRAINT pk_carga_viagem PRIMARY KEY (ID_CARGA),
    CONSTRAINT fk_carga_viag_viag FOREIGN KEY (ID_VIAGEM) REFERENCES Viagem(ID_VIAGEM) ON DELETE CASCADE,
    CONSTRAINT fk_carga_viag_prod FOREIGN KEY (ID_PRODUTO) REFERENCES Produto(ID_PRODUTO),
    CONSTRAINT uk_carga_viag_prod UNIQUE (ID_VIAGEM, ID_PRODUTO),
    CONSTRAINT chk_carga_viag_qtd CHECK (QUANTIDADE_CARREGADA >= 0),
    CONSTRAINT chk_carga_viag_qtd_atual CHECK (QUANTIDADE_ATUAL_VEICULO >= 0 AND QUANTIDADE_ATUAL_VEICULO <= QUANTIDADE_CARREGADA) -- << ALTERA��O >>
);
COMMENT ON TABLE Carga_Viagem IS 'Registo dos produtos carregados no ve�culo no in�cio da viagem (para Q31).';
COMMENT ON COLUMN Carga_Viagem.QUANTIDADE_CARREGADA IS 'Quantidade do produto carregada no ve�culo no in�cio da viagem.';
COMMENT ON COLUMN Carga_Viagem.QUANTIDADE_ATUAL_VEICULO IS 'Quantidade do produto que permanece no ve�culo. Inicialmente = Qtd Carregada, decrementada pelo Trigger update_viagem. (Para Q32)';

CREATE TABLE Venda (
    ID_VENDA NUMBER(15,0) NOT NULL,
    ID_MAQUINA NUMBER(10,0) NOT NULL,
    ID_PRODUTO NUMBER(8,0) NOT NULL,
    ID_COMPARTIMENTO NUMBER(8,0) NOT NULL,
    DATA_VENDA TIMESTAMP DEFAULT SYSTIMESTAMP NOT NULL,
    QUANTIDADE NUMBER(3,0) DEFAULT 1 NOT NULL,
    PRECO_UNITARIO_REGISTADO NUMBER(5,2),
    VALOR_TOTAL NUMBER(10,2),
    TIPO_PAGAMENTO VARCHAR2(20 BYTE),
    ESTADO_VENDA VARCHAR2(20 BYTE),
    ID_TRANSACAO_PAGAMENTO VARCHAR2(100 BYTE), -- [SUGEST�O]
    CONSTRAINT pk_venda_aabd PRIMARY KEY (ID_VENDA),
    CONSTRAINT fk_venda_maq_aabd FOREIGN KEY (ID_MAQUINA) REFERENCES Maquina(ID_MAQUINA),
    CONSTRAINT fk_venda_prod_aabd FOREIGN KEY (ID_PRODUTO) REFERENCES Produto(ID_PRODUTO),
    CONSTRAINT fk_venda_comp_aabd FOREIGN KEY (ID_COMPARTIMENTO) REFERENCES Compartimento(ID_COMPARTIMENTO)
);
COMMENT ON TABLE Venda IS 'Registo de cada venda efetuada numa m�quina.';
COMMENT ON COLUMN Venda.ID_COMPARTIMENTO IS 'Identifica o compartimento de onde o produto foi retirado.';
COMMENT ON COLUMN Venda.PRECO_UNITARIO_REGISTADO IS 'Pre�o unit�rio do produto no momento exato da venda.';
COMMENT ON COLUMN Venda.TIPO_PAGAMENTO IS 'M�todo de pagamento usado (Multibanco, MBWay).';
COMMENT ON COLUMN Venda.ID_TRANSACAO_PAGAMENTO IS '[SUGEST�O] Identificador �nico da transa��o no sistema de pagamentos externo.';

CREATE TABLE Manutencao ( -- << ALTERA��O (Q39, Q40) >>
    ID_MANUTENCAO NUMBER(15,0) NOT NULL,
    ID_MAQUINA NUMBER(10,0) NOT NULL,
    ID_FUNCIONARIO NUMBER(8,0),
    ID_PARAGEM NUMBER(15,0) DEFAULT NULL,
    DATA_HORA_INICIO TIMESTAMP DEFAULT SYSTIMESTAMP,
    DATA_HORA_FIM TIMESTAMP,
    TIPO_MANUTENCAO VARCHAR2(20 BYTE),
    DESCRICAO_SERVICO VARCHAR2(500 BYTE),
    PECAS_USADAS VARCHAR2(500 BYTE),
    ESTADO_MAQUINA_ANTES NUMBER(8,0),
    ESTADO_MAQUINA_DEPOIS NUMBER(8,0),
    CONSTRAINT pk_manutencao PRIMARY KEY (ID_MANUTENCAO),
    CONSTRAINT fk_manut_maq FOREIGN KEY (ID_MAQUINA) REFERENCES Maquina(ID_MAQUINA),
    CONSTRAINT fk_manut_func FOREIGN KEY (ID_FUNCIONARIO) REFERENCES Funcionario(ID_FUNCIONARIO),
    CONSTRAINT fk_manut_paragem FOREIGN KEY (ID_PARAGEM) REFERENCES Paragem(ID_PARAGEM),
    CONSTRAINT fk_manut_est_antes FOREIGN KEY (ESTADO_MAQUINA_ANTES) REFERENCES Estado_Maquina(ID_ESTADO),
    CONSTRAINT fk_manut_est_depois FOREIGN KEY (ESTADO_MAQUINA_DEPOIS) REFERENCES Estado_Maquina(ID_ESTADO),
    CONSTRAINT chk_manut_datas CHECK (DATA_HORA_FIM IS NULL OR DATA_HORA_FIM >= DATA_HORA_INICIO)
);
COMMENT ON TABLE Manutencao IS 'Registo detalhado das interven��es de manuten��o realizadas nas m�quinas (para Q39, Q40).';
COMMENT ON COLUMN Manutencao.ID_PARAGEM IS 'Refer�ncia opcional � paragem da viagem durante a qual a manuten��o foi feita.';
COMMENT ON COLUMN Manutencao.TIPO_MANUTENCAO IS 'Classifica��o da manuten��o realizada.';
COMMENT ON COLUMN Manutencao.DESCRICAO_SERVICO IS 'Descri��o detalhada dos trabalhos efetuados.';
COMMENT ON COLUMN Manutencao.PECAS_USADAS IS 'Descri��o ou refer�ncia das pe�as substitu�das/utilizadas.';
COMMENT ON COLUMN Manutencao.ESTADO_MAQUINA_ANTES IS 'Estado da m�quina registado no in�cio da manuten��o.';
COMMENT ON COLUMN Manutencao.ESTADO_MAQUINA_DEPOIS IS 'Estado da m�quina registado no fim da manuten��o.';

CREATE SEQUENCE seq_config_comp START WITH 10000 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE seq_viagem START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE seq_paragem START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE seq_abastecimento START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE seq_encomenda START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE seq_log_estado START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE seq_carga_viagem START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE seq_venda_aabd START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE seq_manutencao START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE; -- << ALTERA��O >>

COMMIT; -- Commit da estrutura
