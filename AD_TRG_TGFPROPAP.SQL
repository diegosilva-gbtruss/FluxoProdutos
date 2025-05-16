CREATE OR REPLACE TRIGGER AD_TRG_TGFPROPAP
BEFORE INSERT OR UPDATE OR DELETE
ON AD_TGFPROPAP
REFERENCING NEW AS NEW OLD AS OLD
FOR EACH ROW

DECLARE
  V_ALTERA INT;
  V_MSGERR VARCHAR2(4000);
  V_ATUALIZAPRO INT;
  V_PARCEIRO INT;
  V_APROVADO INT;
    PRAGMA AUTONOMOUS_TRANSACTION;

  /*----------------------------------------------------------------------------------------------------
    %proposito:   Validar informações de cadastro de produtos.
    %observacao: trigger faz parte do projeto de substituição do MITRA.
    %historia: Criada para atendimento do briefing:
    https://docs.google.com/document/d/1o-U5oKX5WiKUQrP1IGEyA3LInDaipLJYVz4Vtunuji0/edit?tab=t.0
    * 01.00.0 29/10/2024 Diego.Alves
    - versao inicial
  ----------------------------------------------------------------------------------------------------*/

BEGIN

  /* Valida alterações após a integração. */
  SELECT COUNT(1)
  INTO V_ATUALIZAPRO
  FROM AD_TGFPROCAB
  WHERE CODPROD IS NOT NULL
    AND NUNICO = :NEW.NUNICO
    AND APROVAFIS = '1';

  IF UPDATING /* OR (INSERTING) */ AND NOT UPDATING('REPROCESSAR') AND NOT UPDATING('DHAPROVACAO') AND V_ATUALIZAPRO >= 1 THEN

      :NEW.REPROCESSAR := 'S';
      :NEW.DHALTERACAO := SYSDATE;
      :NEW.CODUSUALTER := STP_GET_CODUSULOGADO;

    END IF;


  IF INSERTING AND V_ATUALIZAPRO >= 1 AND :NEW.DHAPROVACAO IS NULL THEN
    :NEW.REPROCESSAR := 'S';
    :NEW.DHALTERACAO := SYSDATE;
    :NEW.CODUSUALTER := STP_GET_CODUSULOGADO;

  END IF;



  IF INSERTING THEN

    SELECT COUNT(1)
    INTO V_APROVADO
    FROM AD_TGFPROCAB
    WHERE CODPROD IS NOT NULL
    AND NUNICO = :NEW.NUNICO
      AND APROVAFIS = 1;

    IF V_APROVADO >= 1 THEN

      SELECT COUNT(1)
      INTO V_PARCEIRO
      FROM TGFPAP
      WHERE CODPROD = (SELECT CODPROD FROM AD_TGFPROCAB WHERE NUNICO = :NEW.NUNICO)
        AND CODPARC = :NEW.CODPARC;

      IF V_PARCEIRO >= 1 THEN

        SELECT MAX(SEQUENCIA) + 1
        INTO :NEW.SEQUENCIA
        FROM TGFPAP
        WHERE CODPROD = (SELECT CODPROD FROM AD_TGFPROCAB WHERE NUNICO = :NEW.NUNICO)
          AND CODPARC = :NEW.CODPARC;
      END IF;

    ELSE

      SELECT COUNT(1)
      INTO V_PARCEIRO
      FROM AD_TGFPROPAP
      WHERE NUNICO = :NEW.NUNICO
        AND CODPARC = :NEW.CODPARC;

      IF V_PARCEIRO >= 1 THEN 

        SELECT MAX(SEQUENCIA) + 1
        INTO :NEW.SEQUENCIA
        FROM AD_TGFPROPAP
        WHERE NUNICO = :NEW.NUNICO
          AND CODPARC = :NEW.CODPARC;
      ELSE
        :NEW.SEQUENCIA := 0;
      END IF;
    END IF;
  END IF;
END;

/