CREATE OR REPLACE TRIGGER AD_TRG_TGFPROCAB
BEFORE INSERT OR UPDATE OR DELETE
ON AD_TGFPROCAB
REFERENCING NEW AS NEW OLD AS OLD
FOR EACH ROW

DECLARE
    V_MAILBODY CLOB;
    V_CODFILA INT;
    V_ALTERA INT;
    V_CODPROD INT;
    V_NOMEUSU VARCHAR2(4000);
    V_MSGERR VARCHAR2(4000);
    V_USUARIO_BANCO VARCHAR2(60);
    V_USUARIO_REDE  VARCHAR2(60);
    V_NOMEMAQUINA   VARCHAR2(60);
    V_IPMAQUINA     VARCHAR2(60);
    V_PROGRAMA      VARCHAR2(60);
    /*----------------------------------------------------------------------------------------------------
      %proposito:   Validar informações de cadastro de produtos.
      %observacao: trigger faz parte do projeto de substituição do MITRA.   
      %historia: Criada para atendimento do briefing:
      https://docs.google.com/document/d/1o-U5oKX5WiKUQrP1IGEyA3LInDaipLJYVz4Vtunuji0/edit?tab=t.0
      * 01.00.0 29/10/2024 Diego.Alves
      - versao inicial
      ----------------------------------------------------------------------------------------------------*/

BEGIN 
    IF INSERTING AND :NEW.CODPROD IS NULL THEN
        /*INSERE AS INFORMAÇÕES DE INCLUSÃO DO REGISTRO.*/
        :NEW.CODUSUINCLUSAO := STP_GET_CODUSULOGADO;
        :NEW.DHINCLUSAO := SYSDATE;
        :NEW.CODPROD := NULL;
        :NEW.DHAPROVACAO := NULL;
        :NEW.DHALTERACAO := NULL;
        :NEW.CODUSUALTER := NULL;
        :NEW.REPROCESSAR := 'N';
        :NEW.APROVAFIS := 0;

        /*Envia email de notificação.*/
        SELECT NOMEUSU 
        INTO V_NOMEUSU
        FROM TSIUSU
        WHERE CODUSU = STP_GET_CODUSULOGADO;

        V_MAILBODY :='<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <title>Notificação de Cadastro de Parceiros</title>
  <style>
    body {
      font-family: sans-serif;
    }

    .header {
      background-color: #42f569; /* Cor chamativa */
      padding: 20px;
      text-align: center;
      font-size: 24px;
      font-weight: bold;
    }

    .container {
      display: flex;
      justify-content: space-around;
      margin: 20px;
    }

    .section {
      width: 30%; 
      border: 1px solid #ccc;
      padding: 10px;
    }

    .section h2 {
      margin-top: 0;
    }

    ul {
      list-style: none;
      padding: 0;
    }

    li {
      margin-bottom: 10px;
      padding: 10px;
      border: 1px solid #eee;
    }
  </style>
</head>
<body>

  <div class="header">
    Notificação automática de cadastro de produtos
  </div>

  <div class="container">

    <div class="section">
      <h2>Novos Cadastros Pendentes</h2>
      <ul>
        <!-- Loop para cada cadastro pendente -->
        <li>
          <p>O usuário <strong>'||V_NOMEUSU||'</strong> incluiu um cadastro de produto que precisa da sua atenção:</p>
          <h3>'||:NEW.DESCRPROD||' - Número único da inclusão: '||:NEW.NUNICO||'</h3>
                  </li>
        <!-- Fim do loop -->
      </ul>
    </div>
  </div>

</body>
</html>';

        SELECT MAX(CODFILA) INTO V_CODFILA FROM TMDFMG;

        FOR EMAIL IN (
            SELECT CAB.CODUSU, USU.EMAIL, ROWNUM SEQ
            FROM AD_LIBCADUSU CAB
            LEFT JOIN AD_LIBCADUSUPRO PRO ON CAB.NUNICO = PRO.NUNICO
            LEFT JOIN TSIUSU USU ON USU.CODUSU = CAB.CODUSU
            WHERE CAB.ATIVO = 'S'
            AND PRO.APROVAFIS = 'S'
        ) LOOP
            INSERT INTO TMDFMG(CODFILA, ASSUNTO, DTENTRADA, STATUS, CODCON, TENTENVIO, MENSAGEM, TIPOENVIO, MAXTENTENVIO, EMAIL, MIMETYPE, CODUSU, CODSMTP)
            VALUES (V_CODFILA+EMAIL.SEQ, 'Inclusão de novos produtos Sankhya', SYSDATE, 'Pendente', 0, 1, V_MAILBODY, 'E', 3, EMAIL.EMAIL, 'text/html', 0, 1);
        END LOOP; 
    END IF;

    /*Bloco de validação de permissões de usuário.*/
    SELECT COUNT(1)
    INTO V_ALTERA
    FROM AD_LIBCADUSU USU 
    LEFT JOIN AD_LIBCADUSUPRO PRO 
        ON PRO.NUNICO = USU.NUNICO
    WHERE CODUSU = STP_GET_CODUSULOGADO
    AND NVL(PRO.TGFPROCAB,'N') = 'S'
    AND USU.ATIVO = 'S';

    IF V_ALTERA = 0 AND UPDATING THEN 
        V_MSGERR := 'Não é possível ALTERAR o cadastro';
    ELSIF V_ALTERA = 0 AND INSERTING THEN 
        V_MSGERR := 'Não é possível INCLUIR o cadastro';
    ELSIF V_ALTERA = 0 AND DELETING THEN 
        V_MSGERR := 'Não é possível DELETAR o cadastro';
    END IF;

    IF V_ALTERA = 0 THEN 
        raise_application_error(-20101,
        fc_formatahtml(p_mensagem => V_MSGERR,
        p_motivo   => 'Seu usuário não possuí permissões para executar a ação',
        p_solucao  => 'Solicitar a atribuição do acesso ou procurar pelo responsável pelos cadastros'));
    END IF;

    /*Bloco de inserção da TGFPRO após a aprovação*/
    IF (:OLD.APROVAFIS = 0 AND :NEW.APROVAFIS = 1) THEN  
        /*VALIDA SE O PRODUTO VEIO DA INTEGRACAO SAP*/  
        IF :NEW.CODPROD IS NOT NULL THEN
            V_CODPROD := :NEW.CODPROD;
        ELSE
            SELECT MAX(CODPROD)+1
            INTO V_CODPROD
            FROM TGFPRO;
        END IF;

        INSERT INTO TGFPRO (CODPROD, USOPROD, AD_CODEND, AD_DESCRICAOCOMEX, AD_IMPRIMEETIQUETA, AD_KITFANTASMA, AD_OBSNF, AD_QTDMINVENDA, AD_SEPARAPROD, CARACTERISTICAS, CODGRUPOPROD,
        CODLOCALPADRAO, CODVOL, DESCRPROD, FABRICANTE, ORIGPROD, AD_PALLET, AD_PESAGEM, AD_SEPARACAO, AD_VOLUMETRIA, ALTURA, DECQTD, DECVLR, ESPESSURA,
        ESTMIN, LARGURA, LEADTIME, M3, PERMCOMPPROD, PESOBRUTO, PESOLIQ, PRAZOVAL, QTDEMB, RASTRESTOQUE, AD_GRAMAMLPMPF, AD_PMPF, CLASSUBTRIB, CODCTACTB, CODESPECST, CODEXNCM, CODIPI, CSTIPIENT, CSTIPISAI,
        GRUPOCOFINS, GRUPOCSSL, GRUPOICMS, GRUPOICMS2, GRUPOPIS, IDENTIMOB, NCM, TEMICMS, TEMIPICOMPRA, TEMIPIVENDA, TIPSUBST, UTILIMOB, DTALTER, CODFCI)
        (SELECT V_CODPROD, :NEW.USOPROD,
        :NEW.AD_CODEND, :NEW.AD_DESCRICAOCOMEX, :NEW.AD_IMPRIMEETIQUETA, :NEW.AD_KITFANTASMA, :NEW.AD_OBSNF, :NEW.AD_QTDMINVENDA, :NEW.AD_SEPARAPROD, :NEW.CARACTERISTICAS, :NEW.CODGRUPOPROD,
        :NEW.CODLOCALPADRAO, :NEW.CODVOL, :NEW.DESCRPROD, :NEW.FABRICANTE, :NEW.ORIGPROD, GER.AD_PALLET, GER.AD_PESAGEM, GER.AD_SEPARACAO, GER.AD_VOLUMETRIA, GER.ALTURA, GER.DECQTD,
        GER.DECVLR, GER.ESPESSURA, GER.ESTMIN, GER.LARGURA, GER.LEADTIME, GER.M3, NVL(GER.PERMCOMPPROD,'N'), GER.PESOBRUTO, GER.PESOLIQ, GER.PRAZOVAL, GER.QTDEMB, NVL(GER.RASTRESTOQUE,'N'), FIS.AD_GRAMAMLPMPF,
        FIS.AD_PMPF, FIS.CLASSUBTRIB, FIS.CODCTACTB, FIS.CODESPECST, NVL(FIS.CODEXNCM,0), FIS.CODIPI, FIS.CSTIPIENT, FIS.CSTIPISAI, NVL(FIS.GRUPOCOFINS,'TODOS'), NVL(FIS.GRUPOCSSL,'TODOS'), FIS.GRUPOICMS, FIS.GRUPOICMS2, NVL(FIS.GRUPOPIS,'TODOS'),
        FIS.IDENTIMOB, FIS.NCM, NVL(FIS.TEMICMS,'N'), NVL(FIS.TEMIPICOMPRA,'N'), NVL(FIS.TEMIPIVENDA,'N'), FIS.TIPSUBST, FIS.UTILIMOB, SYSDATE, NULL
        FROM AD_TGFPROGER GER 
        LEFT JOIN AD_TGFPROFIS FIS ON FIS.NUNICO = GER.NUNICO
        WHERE GER.NUNICO = :NEW.NUNICO);

        /*Inserindo dados na aba Impostos por Empesa TGFPEM*/
        INSERT INTO TGFPEM (CODPROD, CODEMP, CSTIPISAI, CSTIPIENT, ORIGPROD, TEMIPIVENDA, TEMIPICOMPRA, TIPOITEMSPED, TEMICMS, CALCDIFAL, GRUPOICMS, GRUPOICMS2, USOPROD, TIPSUBST, PERCCMTNAC, PERCCMTFED, PERCCMTEST, PERCCMTIMP, CODESPECST, CODENQIPIENT, CODENQIPISAI) 
        (SELECT V_CODPROD, CODEMP, CSTIPISAI, CSTIPIENT, ORIGPROD, TEMIPIVENDA, TEMIPICOMPRA, TIPOITEMSPED, TEMICMS, CALCDIFAL, GRUPOICMS, GRUPOICMS2, USOPROD, TIPSUBST, NVL(PERCCMTNAC,0), NVL(PERCCMTFED,0), NVL(PERCCMTEST,0), NVL(PERCCMTIMP,0), CODESPECST, CODENQIPIENT, CODENQIPISAI FROM AD_TGFPROIMP WHERE NUNICO = :NEW.NUNICO); 

        /*Tabela adicional PASSO A PASSO*/
        INSERT INTO AD_PASSOAP (CODPROD, SEQ, DESCR, RPM)
        (SELECT V_CODPROD, SEQ, DESCR, RPM FROM AD_TGFPROPAS WHERE NUNICO = :NEW.NUNICO);

        /*Unidades alternativas*/
        INSERT INTO TGFVOA (CODPROD, UNIDTRIB, DIVIDEMULTIPLICA, TIPCODBARRA, CODBARRA, QUANTIDADE, TIPGTINNFE, ATIVO, CODVOL)
        (SELECT V_CODPROD, UNIDTRIB, DIVIDEMULTIPLICA, TIPCODBARRA, CODBARRA, QUANTIDADE, TIPGTINNFE, 'S', CODVOL FROM AD_TGFPROUNI WHERE NUNICO = :NEW.NUNICO);

        /*Adicionando log da inclusão*/
        SELECT
            USERNAME,
            OSUSER,
            MACHINE,
            sys_context('USERENV','IP_ADDRESS'),
            PROGRAM
        INTO
            V_USUARIO_BANCO,
            V_USUARIO_REDE,
            V_NOMEMAQUINA,
            V_IPMAQUINA,
            V_PROGRAMA
        FROM
            V$SESSION
        WHERE  AUDSID = (SELECT USERENV('SESSIONID') FROM DUAL)
            AND ROWNUM = 1;

        INSERT INTO TSILGT
        (NOMETAB, DHACAO, ACAO, USUBANCO, USUREDE, NOMMAQUINA, IPMAQUINA, PROGRAMA, USUARIOSIS, CHAVE, CAMPO, NOVO, VELHO)
        VALUES('TGFPRO', SYSDATE, 'INSERT', V_USUARIO_BANCO, V_USUARIO_REDE, V_NOMEMAQUINA, V_IPMAQUINA, V_PROGRAMA, STP_GET_CODUSULOGADO, 'PK[NUNICO='||V_CODPROD||']', 'CODPROD', V_CODPROD, 'Inclusão automática via aprovação');

        :NEW.CODPROD := V_CODPROD;
        :NEW.DHAPROVACAO := SYSDATE;
        :NEW.CODUSU := STP_GET_CODUSULOGADO;
    END IF;

    IF DELETING AND :OLD.CODPROD IS NOT NULL THEN 
        raise_application_error(-20101,
            fc_formatahtml(p_mensagem => 'Erro ao deletar cadastro',
            p_motivo   => 'O cadastro não pode ser excluído.',
            p_solucao  => 'Procurar pelo responsável pelo cadastro de PRODUTOS ou administrador do sistema'));
    END IF;

    /*Valida necessidade de atualizar o cadastro de parceiro.*/
    IF NOT UPDATING('REPROCESSAR') AND :NEW.CODPROD IS NOT NULL AND :OLD.CODPROD IS NOT NULL AND :NEW.APROVAFIS = 1 THEN
        SELECT COUNT(1)
        INTO V_ALTERA
        FROM AD_LIBCADUSU USU 
        LEFT JOIN AD_LIBCADUSUPRO PRO 
            ON PRO.NUNICO = USU.NUNICO
        WHERE CODUSU = STP_GET_CODUSULOGADO
        AND NVL(PRO.UPDATEPRO,'N') = 'S'
        AND USU.ATIVO = 'S';

        IF V_ALTERA >= 1 THEN    
            :NEW.REPROCESSAR := 'S';
            :NEW.DHALTERACAO := SYSDATE;
            :NEW.CODUSUALTER := STP_GET_CODUSULOGADO;
            --UPDATE TGFPAR SET ATIVO = 'N' WHERE CODPARC = :NEW.CODPARC;
        ELSE 
            raise_application_error(-20101,
                fc_formatahtml(p_mensagem => 'Erro ao alterar o cadastro',
                p_motivo   => 'O cadastro já foi integrado e seu usuário não tem permissão para edição.',
                p_solucao  => 'Procurar pelo responsável pelo cadastro de produtos ou administrador do sistema'));
        END IF;
    END IF;

    IF UPDATING('TIPCONTEST') AND :NEW.CODPROD IS NOT NULL AND :OLD.CODPROD IS NOT NULL THEN
        raise_application_error(-20101,
            fc_formatahtml(p_mensagem => 'Erro ao alterar o cadastro',
            p_motivo   => 'Não é possível alterar o campo controle de estoque após integração',
            p_solucao  => 'Se for necessário atualizar o campo, realizar direto pela tela PRODUTOS'));
    END IF;
END;

/