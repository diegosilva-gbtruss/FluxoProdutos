CREATE OR REPLACE trigger AD_TRG_TGFPROPAI
BEFORE INSERT OR UPDATE OR DELETE
ON AD_TGFPROPAI
REFERENCING NEW AS NEW OLD AS OLD
FOR EACH ROW

DECLARE
  V_ALTERA INT;
  V_MSGERR VARCHAR2(4000);
  V_ATUALIZAPRO INT;
/*----------------------------------------------------------------------------------------------------
  %proposito:   Validar informações de cadastro de produtos.
  %observacao: trigger faz parte do projeto de substituição do MITRA.
  %historia: Criada para atendimento do briefing:
  https://docs.google.com/document/d/1o-U5oKX5WiKUQrP1IGEyA3LInDaipLJYVz4Vtunuji0/edit?tab=t.0
  * 01.00.0 29/10/2024 Diego.Alves
  - versao inicial
  ----------------------------------------------------------------------------------------------------*/

BEGIN
  /*Bloco de validação de permissões de usuário.*/
  SELECT COUNT(1)
  INTO V_ALTERA
  FROM AD_LIBCADUSU USU
  LEFT JOIN AD_LIBCADUSUPRO PRO
         ON PRO.NUNICO = USU.NUNICO
  WHERE CODUSU = STP_GET_CODUSULOGADO
  AND NVL(PRO.TGFPROPAI,'N') = 'S'
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

  /*VALIDA ALTERAÇÕES APÓS A INTEGRAÇÃO.*/
  SELECT
    COUNT(1)
  INTO V_ATUALIZAPRO
  FROM AD_TGFPROCAB
  WHERE CODPROD IS NOT NULL
  AND NUNICO = :NEW.NUNICO
  AND nvl(APROVAFIS,0) = '1';

  IF UPDATING/* OR (INSERTING)) */ AND NOT UPDATING('REPROCESSAR') AND NOT UPDATING ('DHAPROVACAO') AND V_ATUALIZAPRO >= 1 THEN
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
      -- UPDATE AD_TGFPARCAB SET REPROCESSAR = 'S' WHERE NUNICO = :NEW.NUNICO;
      -- UPDATE TGFPAR SET ATIVO = 'N' WHERE CODPARC = (SELECT CODPARC FROM AD_TGFPARCAB WHERE NUNICO = :NEW.NUNICO);
    ELSE
      raise_application_error(-20101,
        fc_formatahtml(p_mensagem => 'Erro ao alterar cadastro',
        p_motivo   => 'O cadastro já foi integrado e seu usuário não tem permissão para edição.',
        p_solucao  => 'Procurar pelo responsável pelo cadastro de parceiros ou administrador do sistema'));
    END IF;
  END IF;

  IF INSERTING AND V_ATUALIZAPRO >= 1 AND :NEW.DHAPROVACAO IS NULL THEN
    :NEW.REPROCESSAR := 'S';
    :NEW.DHALTERACAO := SYSDATE;
    :NEW.CODUSUALTER := STP_GET_CODUSULOGADO;
    -- UPDATE AD_TGFPARCAB SET REPROCESSAR = 'S' WHERE NUNICO = :NEW.NUNICO;
    -- UPDATE TGFPAR SET ATIVO = 'N' WHERE CODPARC = (SELECT CODPARC FROM AD_TGFPARCAB WHERE NUNICO = :NEW.NUNICO);
  END IF;

  IF DELETING THEN
    SELECT
      COUNT(1)
    INTO V_ATUALIZAPRO
    FROM AD_TGFPROCAB
    WHERE CODPROD IS NOT NULL
    AND NUNICO = :OLD.NUNICO;

    IF V_ATUALIZAPRO >= 1 THEN
      raise_application_error(-20101,
        fc_formatahtml(p_mensagem => 'Erro ao excluir cadastro',
        p_motivo   => 'Não é possível excluir registros em cadastros já integrados, apenas atualizar ou inserir',
        p_solucao  => 'Atualize o registro existente com as novas informações.'));
    END IF;
  END IF;
END;



/