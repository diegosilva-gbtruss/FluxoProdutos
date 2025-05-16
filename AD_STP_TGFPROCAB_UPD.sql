CREATE OR REPLACE PROCEDURE "AD_STP_TGFPROCAB_UPD" (
    P_CODUSU NUMBER,        -- Código do usuário logado
    P_IDSESSAO VARCHAR2,    -- Identificador da execução. Serve para buscar informações dos parâmetros/campos da execução.
    P_QTDLINHAS NUMBER,     -- Informa a quantidade de registros selecionados no momento da execução.
    P_MENSAGEM OUT VARCHAR2 -- Caso seja passada uma mensagem aqui, ela será exibida como uma informação ao usuário.
) AS
    FIELD_NUNICO NUMBER;
    V_USUARIO_BANCO VARCHAR2(60);
    V_USUARIO_REDE  VARCHAR2(60);
    V_NOMEMAQUINA   VARCHAR2(60);
    V_IPMAQUINA     VARCHAR2(60);
    V_PROGRAMA      VARCHAR2(60);
    V_SEMALTERACAO INT;
    V_ALTERAFIS INT;
    V_ALTERA INT;
    V_VALIDAALTERACAO INT;
    V_CODPROD INT;
    V_CODEMP INT;
    V_PASSOAP INT;
    V_UNIALT INT;
    V_SEQPAI INT;
    V_SEQPAP INT;
BEGIN
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

    FOR I IN 1..P_QTDLINHAS 
    LOOP           
        FIELD_NUNICO := ACT_INT_FIELD(P_IDSESSAO, I, 'NUNICO');

        SELECT SUM(C) INTO V_SEMALTERACAO FROM 
        (
            SELECT count(1) c FROM AD_TGFPROCAB WHERE NUNICO = FIELD_NUNICO AND REPROCESSAR = 'S'
            UNION ALL 
            SELECT count(1) c FROM AD_TGFPROFIS WHERE NUNICO = FIELD_NUNICO AND REPROCESSAR = 'S'
            UNION ALL 
            SELECT count(1) c FROM AD_TGFPROGER WHERE NUNICO = FIELD_NUNICO AND REPROCESSAR = 'S'
            UNION ALL 
            SELECT count(1) c FROM AD_TGFPROIMP WHERE NUNICO = FIELD_NUNICO AND REPROCESSAR = 'S'
            UNION ALL 
            SELECT count(1) c FROM AD_TGFPROPAS WHERE NUNICO = FIELD_NUNICO AND REPROCESSAR = 'S'
            UNION ALL 
            SELECT count(1) c FROM AD_TGFPROUNI WHERE NUNICO = FIELD_NUNICO AND REPROCESSAR = 'S'
            UNION ALL 
            SELECT count(1) c FROM AD_TGFPROPAI WHERE NUNICO = FIELD_NUNICO AND REPROCESSAR = 'S'
            UNION ALL 
            SELECT count(1) c FROM AD_TGFPROPAP WHERE NUNICO = FIELD_NUNICO AND REPROCESSAR = 'S'
        );

        IF V_SEMALTERACAO = 0 THEN 
            raise_application_error(-20101,
            fc_formatahtml(p_mensagem => 'Erro ao executar a ação ',
            p_motivo   => 'Não existem alterações pendentes de reprocessamento',
            p_solucao  => 'Essa ação só pode ser utilizada em cadastros que sofreram alterações.'));
        END IF;

        SELECT CODPROD
        INTO V_CODPROD
        FROM AD_TGFPROCAB 
        WHERE NUNICO = FIELD_NUNICO;

        SELECT COUNT(1)
        INTO V_ALTERA
        FROM AD_LIBCADUSU USU 
        LEFT JOIN AD_LIBCADUSUPRO PRO 
            ON PRO.NUNICO = USU.NUNICO
        WHERE CODUSU = STP_GET_CODUSULOGADO
        AND NVL(PRO.UPDATEPRO,'N') = 'S'
        AND USU.ATIVO = 'S';

        SELECT COUNT(1)
        INTO V_ALTERAFIS
        FROM AD_LIBCADUSU USU 
        LEFT JOIN AD_LIBCADUSUPRO PRO 
            ON PRO.NUNICO = USU.NUNICO
        WHERE CODUSU = STP_GET_CODUSULOGADO
        AND NVL(PRO.UPDATEPRO,'N') = 'S'
        AND USU.ATIVO = 'S'
        AND PRO.APROVAFIS = 'S';

        IF V_ALTERA = 0 THEN
            raise_application_error(-20101,
            fc_formatahtml(p_mensagem => 'Erro ao executar a ação',
            p_motivo   => 'O cadastro já foi integrado e seu usuário não tem permissão para edição.',
            p_solucao  => 'Procurar pelo responsável pelo cadastro de produtos ou administrador do sistema'));
        ELSE 
            SELECT
                COUNT(1)
            INTO V_VALIDAALTERACAO
            FROM AD_TGFPROCAB
            WHERE NUNICO = FIELD_NUNICO
            AND REPROCESSAR = 'S'
            AND APROVAFIS = 1;

            IF V_VALIDAALTERACAO >= 1 AND V_ALTERA >= 1 THEN 
                UPDATE TGFPRO SET 
                    (AD_CODEND, AD_DESCRICAOCOMEX, AD_IMPRIMEETIQUETA, AD_KITFANTASMA, AD_OBSNF, AD_QTDMINVENDA, AD_SEPARAPROD, CARACTERISTICAS, CODGRUPOPROD,
                    CODLOCALPADRAO, CODVOL, DESCRPROD, FABRICANTE, ORIGPROD, PRODUTONFE, REFERENCIA, 
                    SOLCOMPRA, TEMRASTROLOTE, TIPLANCNOTA, USALOCAL, USALOTEDTFAB, USALOTEDTVAL, USOPROD, VENCOMPINDIV,AD_PEDMINIMO) =
                    (SELECT 
                        AD_CODEND, AD_DESCRICAOCOMEX, AD_IMPRIMEETIQUETA, AD_KITFANTASMA, AD_OBSNF, AD_QTDMINVENDA, AD_SEPARAPROD, CARACTERISTICAS, CODGRUPOPROD,
                        CODLOCALPADRAO, CODVOL, DESCRPROD, FABRICANTE, ORIGPROD, NVL(PRODUTONFE,0), REFERENCIA, 
                        SOLCOMPRA, TEMRASTROLOTE, TIPLANCNOTA, USALOCAL, USALOTEDTFAB, USALOTEDTVAL, USOPROD, VENCOMPINDIV,AD_PEDMINIMO
                    FROM AD_TGFPROCAB
                    WHERE NUNICO = FIELD_NUNICO)
                WHERE CODPROD = V_CODPROD;

                INSERT INTO TSILGT
                    (NOMETAB, DHACAO, ACAO, USUBANCO, USUREDE, NOMMAQUINA, IPMAQUINA, PROGRAMA, USUARIOSIS, CHAVE, CAMPO, NOVO, VELHO)
                VALUES
                    ('TGFPRO', SYSDATE, 'UPDATE', V_USUARIO_BANCO, V_USUARIO_REDE, V_NOMEMAQUINA, V_IPMAQUINA, V_PROGRAMA, STP_GET_CODUSULOGADO, 'PK[NUNICO='||V_CODPROD||']', 'CODPROD', V_CODPROD, 'ATUALIZAÇÃO DE DADOS CADASTRAIS DA TABELA: PRINCIPAIS');

                UPDATE AD_TGFPROCAB SET REPROCESSAR = 'N' WHERE NUNICO = FIELD_NUNICO;
            END IF;

            SELECT
                COUNT(1)
            INTO V_VALIDAALTERACAO
            FROM AD_TGFPROFIS
            WHERE NUNICO = FIELD_NUNICO
            AND REPROCESSAR = 'S';

            IF V_VALIDAALTERACAO >= 1 AND V_ALTERAFIS >= 1 AND V_ALTERA >= 1 THEN 
                UPDATE TGFPRO SET 
                    (AD_GRAMAMLPMPF, AD_PMPF, CLASSUBTRIB, CODCTACTB,CODCTACTB2,CODCTACTB3,CODCTACTB4, CODESPECST, CODEXNCM, CODIPI, CSTIPIENT, CSTIPISAI, 
                    GRUPOCOFINS, GRUPOCSSL, GRUPOICMS, GRUPOICMS2, GRUPOPIS, IDENTIMOB, NCM, TEMICMS, TEMIPICOMPRA, TEMIPIVENDA, TIPSUBST, UTILIMOB,TEMINSS,TEMIRF,PERCINSS,PERCIRF,PERCCMTFED,PERCCMTIMP,TEMCIAP) =
                    (SELECT 
                        AD_GRAMAMLPMPF, AD_PMPF, CLASSUBTRIB, CODCTACTB,CODCTACTB2,CODCTACTB3,CODCTACTB4, CODESPECST, NVL(CODEXNCM,0), CODIPI, CSTIPIENT, CSTIPISAI, GRUPOCOFINS, GRUPOCSSL, 
                        GRUPOICMS, GRUPOICMS2, GRUPOPIS, IDENTIMOB, NCM, TEMICMS, TEMIPICOMPRA, TEMIPIVENDA, TIPSUBST, UTILIMOB,TEMINSS,TEMIRF, NVL(PERCINSS,0),NVL(PERCIRF,0),PERCCMTFED,PERCCMTIMP,TEMCIAP
                    FROM AD_TGFPROFIS
                    WHERE NUNICO = FIELD_NUNICO)
                WHERE CODPROD = V_CODPROD;

                INSERT INTO TSILGT
                    (NOMETAB, DHACAO, ACAO, USUBANCO, USUREDE, NOMMAQUINA, IPMAQUINA, PROGRAMA, USUARIOSIS, CHAVE, CAMPO, NOVO, VELHO)
                VALUES
                    ('TGFPRO', SYSDATE, 'UPDATE', V_USUARIO_BANCO, V_USUARIO_REDE, V_NOMEMAQUINA, V_IPMAQUINA, V_PROGRAMA, STP_GET_CODUSULOGADO, 'PK[NUNICO='||V_CODPROD||']', 'CODPROD', V_CODPROD, 'ATUALIZAÇÃO DE DADOS CADASTRAIS DA TABELA: FISCAIS');

                UPDATE AD_TGFPROFIS SET REPROCESSAR = 'N' WHERE NUNICO = FIELD_NUNICO;
            END IF;

            SELECT
                COUNT(1)
            INTO V_VALIDAALTERACAO
            FROM AD_TGFPROGER
            WHERE NUNICO = FIELD_NUNICO
            AND REPROCESSAR = 'S';

            IF V_VALIDAALTERACAO >= 1 AND V_ALTERA >= 1 THEN 
                UPDATE TGFPRO SET 
                    (AD_PALLET, AD_PESAGEM, AD_SEPARACAO, AD_VOLUMETRIA, ALTURA, DECQTD, DECVLR, ESPESSURA, ESTMIN,ESTMAX, LARGURA, 
                    LEADTIME, M3, PERMCOMPPROD, PESOBRUTO, PESOLIQ, PRAZOVAL, QTDEMB, RASTRESTOQUE,REFERENCIA,MARCA,AD_UP,CODVOLCOMPRA,AD_VALIDREGUL,AD_RASTPALETE,AD_VALIDARAST) =
                    (SELECT 
                        AD_PALLET, AD_PESAGEM, AD_SEPARACAO, AD_VOLUMETRIA, ALTURA, DECQTD, DECVLR, ESPESSURA, ESTMIN,ESTMAX,
                        LARGURA, LEADTIME, M3, PERMCOMPPROD, PESOBRUTO, PESOLIQ, PRAZOVAL, QTDEMB, RASTRESTOQUE, REFERENCIA,MARCA,AD_UP,NVL(CODVOLCOMPRA,0),AD_VALIDREGUL,AD_RASTPALETE,AD_VALIDARAST
                    FROM AD_TGFPROGER
                    WHERE NUNICO = FIELD_NUNICO)
                WHERE CODPROD = V_CODPROD;

                INSERT INTO TSILGT
                    (NOMETAB, DHACAO, ACAO, USUBANCO, USUREDE, NOMMAQUINA, IPMAQUINA, PROGRAMA, USUARIOSIS, CHAVE, CAMPO, NOVO, VELHO)
                VALUES
                    ('TGFPRO', SYSDATE, 'UPDATE', V_USUARIO_BANCO, V_USUARIO_REDE, V_NOMEMAQUINA, V_IPMAQUINA, V_PROGRAMA, STP_GET_CODUSULOGADO, 'PK[NUNICO='||V_CODPROD||']', 'CODPROD', V_CODPROD, 'ATUALIZAÇÃO DE DADOS CADASTRAIS DA TABELA: GERAL');

                UPDATE AD_TGFPROGER SET REPROCESSAR = 'N' WHERE NUNICO = FIELD_NUNICO;
            END IF;

            SELECT
            COUNT(1)
            INTO V_VALIDAALTERACAO
            FROM AD_TGFPROIMP
            WHERE NUNICO = FIELD_NUNICO
            AND REPROCESSAR = 'S';

            IF V_VALIDAALTERACAO >= 1 AND V_ALTERAFIS >= 1 AND V_ALTERA >= 1 THEN 
                FOR IMP IN (
                    SELECT 
                        CALCDIFAL, CODEMP, CODENQIPIENT, CODENQIPISAI, CODESPECST, CSTIPIENT, CSTIPISAI, GRUPOICMS, GRUPOICMS2, ORIGPROD, 
                        PERCCMTEST, PERCCMTFED, PERCCMTIMP, PERCCMTNAC, TEMICMS, TEMIPICOMPRA, TEMIPIVENDA, TIPOITEMSPED, TIPSUBST, USOPROD 
                    FROM AD_TGFPROIMP 
                    WHERE NUNICO = FIELD_NUNICO
                ) LOOP
                    SELECT COUNT(1)
                    INTO V_CODEMP
                    FROM TGFPEM
                    WHERE CODPROD = V_CODPROD
                    AND CODEMP = IMP.CODEMP;

                    IF V_CODEMP >= 1 THEN
                        UPDATE TGFPEM SET 
                            CALCDIFAL = IMP.CALCDIFAL,
                            CODEMP = IMP.CODEMP, 
                            CODENQIPIENT = IMP.CODENQIPIENT, 
                            CODENQIPISAI = IMP.CODENQIPISAI, 
                            CODESPECST = IMP.CODESPECST, 
                            CSTIPIENT = IMP.CSTIPIENT, 
                            CSTIPISAI = IMP.CSTIPISAI, 
                            GRUPOICMS = IMP.GRUPOICMS, 
                            GRUPOICMS2 = IMP.GRUPOICMS2, 
                            ORIGPROD = IMP.ORIGPROD, 
                            PERCCMTEST = IMP.PERCCMTEST, 
                            PERCCMTFED = IMP.PERCCMTFED, 
                            PERCCMTIMP = IMP.PERCCMTIMP, 
                            PERCCMTNAC = IMP.PERCCMTNAC, 
                            TEMICMS = IMP.TEMICMS, 
                            TEMIPICOMPRA = IMP.TEMIPICOMPRA, 
                            TEMIPIVENDA = IMP.TEMIPIVENDA, 
                            TIPOITEMSPED = IMP.TIPOITEMSPED, 
                            TIPSUBST = IMP.TIPSUBST, 
                            USOPROD = IMP.USOPROD 
                        WHERE CODPROD = V_CODPROD AND CODEMP = IMP.CODEMP;
                    ELSE 
                        INSERT INTO TGFPEM (
                            CODPROD, CODEMP, CSTIPISAI, CSTIPIENT, ORIGPROD, TEMIPIVENDA, TEMIPICOMPRA, TIPOITEMSPED, TEMICMS, CALCDIFAL, GRUPOICMS, GRUPOICMS2, USOPROD, TIPSUBST, PERCCMTNAC, 
                            PERCCMTFED, PERCCMTEST, PERCCMTIMP, CODESPECST, CODENQIPIENT, CODENQIPISAI
                        ) VALUES (
                            V_CODPROD, IMP.CODEMP, IMP.CSTIPISAI, IMP.CSTIPIENT, IMP.ORIGPROD, IMP.TEMIPIVENDA, IMP.TEMIPICOMPRA, IMP.TIPOITEMSPED, IMP.TEMICMS, IMP.CALCDIFAL, IMP.GRUPOICMS, IMP.GRUPOICMS2, IMP.USOPROD, IMP.TIPSUBST, IMP.PERCCMTNAC, 
                            IMP.PERCCMTFED, IMP.PERCCMTEST, IMP.PERCCMTIMP, IMP.CODESPECST, IMP.CODENQIPIENT, IMP.CODENQIPISAI
                        );
                    END IF;     
                END LOOP;

                INSERT INTO TSILGT
                    (NOMETAB, DHACAO, ACAO, USUBANCO, USUREDE, NOMMAQUINA, IPMAQUINA, PROGRAMA, USUARIOSIS, CHAVE, CAMPO, NOVO, VELHO)
                VALUES
                    ('TGFPRO', SYSDATE, 'UPDATE', V_USUARIO_BANCO, V_USUARIO_REDE, V_NOMEMAQUINA, V_IPMAQUINA, V_PROGRAMA, STP_GET_CODUSULOGADO, 'PK[NUNICO='||V_CODPROD||']', 'CODPROD', V_CODPROD, 'ATUALIZAÇÃO DE DADOS CADASTRAIS DA TABELA: IMPOSTOS POR EMPRESA');

                UPDATE AD_TGFPROIMP SET REPROCESSAR = 'N' WHERE NUNICO = FIELD_NUNICO;
            END IF;

            SELECT
                COUNT(1)
            INTO V_VALIDAALTERACAO
            FROM AD_TGFPROPAS
            WHERE NUNICO = FIELD_NUNICO
            AND REPROCESSAR = 'S';

            IF V_VALIDAALTERACAO >= 1 AND V_ALTERA >= 1 THEN 
                FOR PAS IN (
                    SELECT 
                        SEQ,
                        DESCR,
                        RPM
                    FROM AD_TGFPROPAS
                    WHERE NUNICO = FIELD_NUNICO
                ) LOOP
                    SELECT COUNT(1)
                    INTO V_PASSOAP
                    FROM AD_PASSOAP
                    WHERE CODPROD = V_CODPROD
                    AND SEQ = PAS.SEQ;

                    IF V_PASSOAP >= 1 THEN
                        UPDATE AD_PASSOAP SET 
                            RPM = PAS.RPM, 
                            DESCR = PAS.DESCR 
                        WHERE CODPROD = V_CODPROD AND SEQ = PAS.SEQ;
                    ELSE 
                        INSERT INTO AD_PASSOAP (CODPROD, SEQ, DESCR, RPM) VALUES
                            (V_CODPROD, PAS.SEQ, PAS.DESCR, PAS.RPM);
                    END IF;     
                END LOOP;

                INSERT INTO TSILGT
                    (NOMETAB, DHACAO, ACAO, USUBANCO, USUREDE, NOMMAQUINA, IPMAQUINA, PROGRAMA, USUARIOSIS, CHAVE, CAMPO, NOVO, VELHO)
                VALUES
                    ('TGFPRO', SYSDATE, 'UPDATE', V_USUARIO_BANCO, V_USUARIO_REDE, V_NOMEMAQUINA, V_IPMAQUINA, V_PROGRAMA, STP_GET_CODUSULOGADO, 'PK[NUNICO='||V_CODPROD||']', 'CODPROD', V_CODPROD, 'ATUALIZAÇÃO DE DADOS CADASTRAIS DA TABELA: PASSO A PASSO');

                UPDATE AD_TGFPROPAS SET REPROCESSAR = 'N' WHERE NUNICO = FIELD_NUNICO;
            END IF;

            SELECT
                COUNT(1)
            INTO V_VALIDAALTERACAO
            FROM AD_TGFPROUNI
            WHERE NUNICO = FIELD_NUNICO
            AND REPROCESSAR = 'S';

            IF V_VALIDAALTERACAO >= 1 AND V_ALTERA >= 1 THEN 
                FOR UNI IN (
                    SELECT 
                        CODBARRA,
                        CODVOL,
                        DIVIDEMULTIPLICA,
                        QUANTIDADE,
                        TIPCODBARRA,
                        TIPGTINNFE,
                        UNIDTRIB
                    FROM AD_TGFPROUNI
                    WHERE NUNICO = FIELD_NUNICO
                ) LOOP
                    SELECT COUNT(1)
                    INTO V_UNIALT
                    FROM TGFVOA
                    WHERE CODPROD = V_CODPROD
                    AND CODVOL = UNI.CODVOL;

                    IF V_UNIALT >= 1 THEN
                        UPDATE TGFVOA SET 
                            CODBARRA = UNI.CODBARRA,
                            CODVOL = UNI.CODVOL,
                            DIVIDEMULTIPLICA = UNI.DIVIDEMULTIPLICA,
                            QUANTIDADE = UNI.QUANTIDADE,
                            TIPCODBARRA = UNI.TIPCODBARRA,
                            TIPGTINNFE = UNI.TIPGTINNFE,
                            UNIDTRIB = UNI.UNIDTRIB
                        WHERE CODPROD = V_CODPROD 
                        AND CODVOL = UNI.CODVOL;
                    ELSE 
                        INSERT INTO TGFVOA (CODPROD, UNIDTRIB, DIVIDEMULTIPLICA, TIPCODBARRA, CODBARRA, QUANTIDADE, TIPGTINNFE, ATIVO, CODVOL) VALUES
                            (V_CODPROD, UNI.UNIDTRIB, UNI.DIVIDEMULTIPLICA, UNI.TIPCODBARRA, UNI.CODBARRA, UNI.QUANTIDADE, UNI.TIPGTINNFE, 'S', UNI.CODVOL);
                    END IF;     
                END LOOP;

                INSERT INTO TSILGT
                    (NOMETAB, DHACAO, ACAO, USUBANCO, USUREDE, NOMMAQUINA, IPMAQUINA, PROGRAMA, USUARIOSIS, CHAVE, CAMPO, NOVO, VELHO)
                VALUES
                    ('TGFPRO', SYSDATE, 'UPDATE', V_USUARIO_BANCO, V_USUARIO_REDE, V_NOMEMAQUINA, V_IPMAQUINA, V_PROGRAMA, STP_GET_CODUSULOGADO, 'PK[NUNICO='||V_CODPROD||']', 'CODPROD', V_CODPROD, 'ATUALIZAÇÃO DE DADOS CADASTRAIS DA TABELA: UNIDADES ALTERNATIVAS');

                UPDATE AD_TGFPROUNI SET REPROCESSAR = 'N' WHERE NUNICO = FIELD_NUNICO;
            END IF;

            SELECT
            COUNT(1)
            INTO V_VALIDAALTERACAO
            FROM AD_TGFPROPAI
            WHERE NUNICO = FIELD_NUNICO
            AND REPROCESSAR = 'S';

            IF V_VALIDAALTERACAO >= 1 AND V_ALTERA >= 1 THEN 

            FOR PAI IN (SELECT 
                        SEQ, 
                        CODPAIS,
                        REVISAO, 
                        STATUS, 
                        OBSERVACAO, 
                        FORMULA

                        FROM AD_TGFPROPAI
                        WHERE NUNICO = FIELD_NUNICO

                         )LOOP
                            SELECT COUNT(1)
                            INTO V_SEQPAI
                            FROM AD_PRODPAISES
                            WHERE CODPROD = V_CODPROD
                            AND SEQ = PAI.SEQ;

                             IF V_SEQPAI >= 1 THEN 

                             UPDATE AD_PRODPAISES SET 
                                CODPAIS = PAI.CODPAIS,
                                REVISAO = PAI.REVISAO,
                                STATUS = PAI.STATUS,
                                OBSERVACAO = PAI.OBSERVACAO,
                                FORMULA = PAI.FORMULA
                            WHERE CODPROD = V_CODPROD
                            AND SEQ = PAI.SEQ;


                             ELSE

                             INSERT INTO AD_PRODPAISES (CODPROD, SEQ, CODPAIS, REVISAO, STATUS, OBSERVACAO, FORMULA)
                             VALUES (V_CODPROD, PAI.SEQ, PAI.CODPAIS, PAI.REVISAO, PAI.STATUS, PAI.OBSERVACAO, PAI.FORMULA);

                             END IF;

                        END LOOP;

              INSERT INTO TSILGT
                    (NOMETAB, DHACAO, ACAO, USUBANCO, USUREDE, NOMMAQUINA, IPMAQUINA, PROGRAMA, USUARIOSIS, CHAVE, CAMPO, NOVO, VELHO)
                VALUES
                    ('TGFPRO', SYSDATE, 'UPDATE', V_USUARIO_BANCO, V_USUARIO_REDE, V_NOMEMAQUINA, V_IPMAQUINA, V_PROGRAMA, STP_GET_CODUSULOGADO, 'PK[NUNICO='||V_CODPROD||']', 'CODPROD', V_CODPROD, 'ATUALIZAÇÃO DE DADOS CADASTRAIS DA TABELA: Status Países Regulatório ');
            UPDATE AD_TGFPROPAI SET REPROCESSAR = 'N' WHERE NUNICO = FIELD_NUNICO; 


                        END IF;

                SELECT
                COUNT(1)
                INTO V_VALIDAALTERACAO
                FROM AD_TGFPROPAP
                WHERE NUNICO = FIELD_NUNICO
                AND REPROCESSAR = 'S';

                IF V_VALIDAALTERACAO >= 1 AND V_ALTERA >= 1 THEN

                FOR PAP IN (SELECT 
                            CODPARC, 
                            CODPROPARC, 
                            DESCRPROPARC, 
                            UNIDADE, 
                            PRAZOENT,
                            UNIDADEPARC, 
                            AD_OBSERVACAO,
                            AD_APTOINAPTO, 
                            CODBARRA, 
                            DUM14, 
                            SEQUENCIA

                            FROM AD_TGFPROPAP 
                            WHERE NUNICO = FIELD_NUNICO
                            )LOOP

                            SELECT COUNT(1)
                            INTO V_SEQPAP
                            FROM TGFPAP
                            WHERE CODPROD = V_CODPROD
                            AND SEQUENCIA = PAP.SEQUENCIA
                            AND CODPARC = PAP.CODPARC;

                            IF V_SEQPAP >=1 THEN 

                            UPDATE TGFPAP SET 
                                CODPROPARC = PAP.CODPROPARC,
                                DESCRPROPARC = PAP.DESCRPROPARC, 
                                UNIDADE = PAP.UNIDADE, 
                                PRAZOENT = PAP.PRAZOENT,
                                UNIDADEPARC = PAP.UNIDADEPARC, 
                                AD_OBSERVACAO = PAP.AD_OBSERVACAO,
                                AD_APTOINAPTO = PAP.AD_APTOINAPTO, 
                                CODBARRA = PAP.CODBARRA, 
                                DUM14 = PAP.DUM14
                            WHERE CODPROD = V_CODPROD
                            AND SEQUENCIA = PAP.SEQUENCIA
                            AND CODPARC = PAP.CODPARC;

                            ELSE 

                            INSERT INTO TGFPAP (CODPARC,CODPROPARC,DESCRPROPARC,UNIDADE,PRAZOENT,UNIDADEPARC,AD_OBSERVACAO,AD_APTOINAPTO,CODBARRA,DUM14,SEQUENCIA)
                            VALUES (PAP.CODPARC,PAP.CODPROPARC,PAP.DESCRPROPARC,PAP.UNIDADE,PAP.PRAZOENT,PAP.UNIDADEPARC,PAP.AD_OBSERVACAO,PAP.AD_APTOINAPTO,PAP.CODBARRA,PAP.DUM14,PAP.SEQUENCIA);

                            END IF;

                            END LOOP;   
                INSERT INTO TSILGT
                    (NOMETAB, DHACAO, ACAO, USUBANCO, USUREDE, NOMMAQUINA, IPMAQUINA, PROGRAMA, USUARIOSIS, CHAVE, CAMPO, NOVO, VELHO)
                VALUES
                    ('TGFPRO', SYSDATE, 'UPDATE', V_USUARIO_BANCO, V_USUARIO_REDE, V_NOMEMAQUINA, V_IPMAQUINA, V_PROGRAMA, STP_GET_CODUSULOGADO, 'PK[NUNICO='||V_CODPROD||']', 'CODPROD', V_CODPROD, 'ATUALIZAÇÃO DE DADOS CADASTRAIS DA TABELA: Produtos Equivalentes ');
             UPDATE AD_TGFPROPAP SET REPROCESSAR = 'N' WHERE NUNICO = FIELD_NUNICO; 

                END IF;


            END IF;


    END LOOP;
    COMMIT;

    P_MENSAGEM := 'Produto reprocessado, dados atualizados com sucesso!';
END;


/
