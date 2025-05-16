CREATE OR REPLACE PROCEDURE "AD_STP_TGFPROCAB_APROV" (
    P_CODUSU NUMBER,         -- Código do usuário logado
    P_IDSESSAO VARCHAR2,     -- Identificador da execução
    P_QTDLINHAS NUMBER,      -- Quantidade de registros selecionados
    P_MENSAGEM OUT VARCHAR2  -- Mensagem exibida ao usuário
) AS
    FIELD_NUNICO NUMBER;
    V_APROVADO INT;
    V_USUAPROVFIS INT;
    V_FISCAL INT;
    V_GERAL INT;
    V_IMPOSTOEMPRESA INT;
    V_UNIDADES INT;
    V_PASSO INT;
    V_MSGQUA VARCHAR2(50);
    V_MSGFIS VARCHAR2(50);
    V_MSGREG VARCHAR2(50);
    V_USOPROD VARCHAR2(2);
    V_PAP INT;
    V_PAIS INT;
BEGIN
    FOR I IN 1..P_QTDLINHAS LOOP
        FIELD_NUNICO := ACT_INT_FIELD(P_IDSESSAO, I, 'NUNICO');

        -- Valida o uso do produto quando não encontrado no de/para
        SELECT COUNT(1)
        INTO V_USOPROD
        FROM AD_TGFPROCAB
        WHERE NUNICO = FIELD_NUNICO
          AND USOPROD = 'Z';

        IF V_USOPROD >= 1 THEN
            raise_application_error(
                -20101,
                fc_formatahtml(
                    P_MENSAGEM => 'Cadastro do produto não pode ser aprovado',
                    P_MOTIVO   => 'O campo "Uso do Produto" não foi identificado automaticamente pelo de/para da integração e requer sua atenção.',
                    P_SOLUCAO  => 'Por favor, valide o "Uso do Produto" no SAP e corrija-o no Sankhya antes de prosseguir com a aprovação.'
                )
            );
        END IF;

        -- Valida se o cadastro do produto já foi previamente aprovado e integrado
        SELECT COUNT(1)
        INTO V_APROVADO
        FROM AD_TGFPROCAB
        WHERE NUNICO = FIELD_NUNICO
          AND DHAPROVACAO IS NOT NULL
          AND CODPROD IS NOT NULL
          AND APROVAFIS = 1;

        IF V_APROVADO >= 1 THEN
            raise_application_error(
                -20101,
                fc_formatahtml(
                    P_MENSAGEM => 'Não é possível aprovar o Produto.',
                    P_MOTIVO   => 'Este Produto já foi aprovado anteriormente.',
                    P_SOLUCAO  => 'Utilize o botão "Atualizar" para realizar manutenções em cadastros já aprovados.'
                )
            );
        ELSE
            -- Valida se o usuário executando a rotina tem permissão
            SELECT COUNT(1)
            INTO V_USUAPROVFIS
            FROM AD_LIBCADUSU CAB
            LEFT JOIN AD_LIBCADUSUPRO PRO ON PRO.NUNICO = CAB.NUNICO
            WHERE CODUSU = STP_GET_CODUSULOGADO
              AND PRO.APROVAFIS = 'S'
              AND CAB.ATIVO = 'S';

            IF (V_USUAPROVFIS = 0) THEN
                raise_application_error(
                    -20101,
                    fc_formatahtml(
                        P_MENSAGEM => 'Erro ao aprovar cadastro.',
                        P_MOTIVO   => 'Você não possui permissão para aprovar este cadastro.',
                        P_SOLUCAO  => 'Contate o administrador do sistema ou o responsável pela gestão de cadastros.'
                    )
                );
            END IF;

            IF V_USUAPROVFIS >= 1 THEN
                SELECT COUNT(1)
                INTO V_FISCAL
                FROM AD_TGFPROFIS
                WHERE NUNICO = FIELD_NUNICO;

                SELECT COUNT(1)
                INTO V_IMPOSTOEMPRESA
                FROM AD_TGFPROIMP
                WHERE NUNICO = FIELD_NUNICO;

                IF V_FISCAL = 1 THEN
                    UPDATE AD_TGFPROFIS
                    SET CODUSU = STP_GET_CODUSULOGADO,
                        DHAPROVACAO = SYSDATE
                    WHERE NUNICO = FIELD_NUNICO;
                ELSIF V_FISCAL > 1 THEN
                    raise_application_error(
                        -20101,
                        fc_formatahtml(
                            P_MENSAGEM => 'Erro na Aprovação',
                            P_MOTIVO   => 'Este produto possui mais de uma configuração fiscal cadastrada.',
                            P_SOLUCAO  => 'Acesse a aba fiscal do produto e mantenha apenas uma configuração ativa antes de aprovar.'
                        )
                    );
                ELSIF V_FISCAL = 0 THEN
                    raise_application_error(
                        -20101,
                        fc_formatahtml(
                            P_MENSAGEM => 'Erro na Aprovação',
                            P_MOTIVO   => 'A aba fiscal não foi preenchida.',
                            P_SOLUCAO  => 'Preencha os dados da aba fiscal e tente aprovar novamente.'
                        )
                    );
                END IF;

                IF V_IMPOSTOEMPRESA >= 1 THEN
                    UPDATE AD_TGFPROIMP
                    SET CODUSU = STP_GET_CODUSULOGADO,
                        DHAPROVACAO = SYSDATE
                    WHERE NUNICO = FIELD_NUNICO;
                END IF;

                SELECT COUNT(1)
                INTO V_GERAL
                FROM AD_TGFPROGER
                WHERE NUNICO = FIELD_NUNICO;

                IF V_GERAL = 1 THEN
                    UPDATE AD_TGFPROGER
                    SET CODUSU = STP_GET_CODUSULOGADO,
                        DHAPROVACAO = SYSDATE
                    WHERE NUNICO = FIELD_NUNICO;
                END IF;

                SELECT COUNT(1)
                INTO V_PASSO
                FROM AD_TGFPROPAS
                WHERE NUNICO = FIELD_NUNICO;

                IF V_PASSO >= 1 THEN
                    UPDATE AD_TGFPROPAS
                    SET CODUSU = STP_GET_CODUSULOGADO,
                        DHAPROVACAO = SYSDATE
                    WHERE NUNICO = FIELD_NUNICO;
                END IF;

                SELECT COUNT(1)
                INTO V_PAIS
                FROM AD_TGFPROPAI
                WHERE NUNICO = FIELD_NUNICO;

                IF V_PAIS >= 1 THEN
                    UPDATE AD_TGFPROPAI
                    SET CODUSU = STP_GET_CODUSULOGADO,
                        DHAPROVACAO = SYSDATE
                    WHERE NUNICO = FIELD_NUNICO;
                END IF;


               SELECT COUNT(1)
                INTO V_PAP
                FROM AD_TGFPROPAP
                WHERE NUNICO = FIELD_NUNICO;

                IF V_PAP >= 1 THEN


                    UPDATE AD_TGFPROPAP
                    SET CODUSU = STP_GET_CODUSULOGADO,
                        DHAPROVACAO = SYSDATE
                    WHERE NUNICO = FIELD_NUNICO;


                END IF;
            END IF;
        END IF;
    END LOOP;

    IF V_USUAPROVFIS >= 1 THEN
        V_MSGFIS := 'Fiscais';

        UPDATE AD_TGFPROCAB
        SET APROVAFIS = 1
        WHERE NUNICO = FIELD_NUNICO;
    END IF;

    P_MENSAGEM := 'Produto aprovado!';
END;


/
