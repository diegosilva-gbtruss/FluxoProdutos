CREATE OR REPLACE TRIGGER AD_TRG_INTEGRATGFVOA
FOR INSERT OR UPDATE ON AD_INTEGRATGFVOA
COMPOUND TRIGGER

  /*----------------------------------------------------------------------------------------------------
  %proposito:   Adicionar os produtos integrados do SAP para o fluxo de produtos SKW
  %observacao: trigger faz parte do projeto de substituição do MITRA.   
  %historia: Criada para atendimento do briefing:
  https://docs.google.com/document/d/1o-U5oKX5WiKUQrP1IGEyA3LInDaipLJYVz4Vtunuji0/edit?tab=t.0
  * 01.00.0 02/01/2025 Diego.Alves
  - versao inicial
  ----------------------------------------------------------------------------------------------------*/

  V_NUNICO INT;
  V_VAL_CODVOL INT;
  V_CODVOL VARCHAR2(10);
  V_TIPCODBARRA VARCHAR2(10);
  V_CODVOLPRINCIPAL VARCHAR2(10);
  V_DIVIDEMULTIPLICA VARCHAR2(10);
  V_MAXSEQ INT;

  AFTER EACH ROW IS
  BEGIN
    SELECT COUNT(1)
    INTO V_VAL_CODVOL
    FROM TGFVOL
    WHERE AD_CODSAP = :NEW.CODVOL;

    IF V_VAL_CODVOL = 1 THEN
      SELECT NVL(CODVOL,'UN')
      INTO V_CODVOL
      FROM TGFVOL
      WHERE AD_CODSAP = :NEW.CODVOL;
    ELSE
      V_CODVOL := 'UN';
    END IF;

    IF INSERTING THEN
      SELECT NUNICO
      INTO V_NUNICO
      FROM AD_TGFPROCAB
      WHERE CODPROD = REGEXP_REPLACE(:NEW.CODPROD, '[^0-9]', '');

      SELECT NVL(MAX(SEQ),0)+1 
      INTO V_MAXSEQ
      FROM AD_TGFPROUNI
      WHERE NUNICO = V_NUNICO;

      /*Determina o TIPCODBARRA com base no tamanho do ean*/
      IF LENGTH(:NEW.EANGTIN) <= 13 THEN 
        V_TIPCODBARRA := 'A';
      ELSE 
        V_TIPCODBARRA := 'B';
      END IF;

      /*Determina o DIVIDEMULTIPLICA com base no codvol*/
      SELECT NVL(CODVOL,'UN')
      INTO V_CODVOLPRINCIPAL
      FROM AD_TGFPROCAB
      WHERE CODPROD = REGEXP_REPLACE(:NEW.CODPROD, '[^0-9]', '');

      SELECT NVL(CODVOL,'UN')
      INTO V_CODVOL
      FROM TGFVOL
      WHERE AD_CODSAP = :NEW.CODVOL;

      V_DIVIDEMULTIPLICA :=
        CASE 
          WHEN V_CODVOLPRINCIPAL = 'UN' AND V_CODVOL = 'CX' THEN 'M'
          WHEN V_CODVOLPRINCIPAL = 'CX' AND V_CODVOL = 'UN' THEN 'D'
          WHEN V_CODVOLPRINCIPAL = 'UN' AND V_CODVOL = 'KG' THEN 'D'
        END;

      INSERT INTO AD_TGFPROUNI (NUNICO, SEQ, UNIDTRIB, DIVIDEMULTIPLICA, TIPCODBARRA, CODBARRA, QUANTIDADE, TIPGTINNFE, CODVOL)
      VALUES (V_NUNICO, V_MAXSEQ, 'N', V_DIVIDEMULTIPLICA, V_TIPCODBARRA, :NEW.EANGTIN, :NEW.QUANTIDADE, 3, V_CODVOL);
    END IF;
  END AFTER EACH ROW;

  BEFORE EACH ROW IS
  BEGIN
    SELECT COUNT(1)
    INTO V_VAL_CODVOL
    FROM TGFVOL
    WHERE AD_CODSAP = :NEW.CODVOL;

    IF V_VAL_CODVOL = 1 THEN
      SELECT NVL(CODVOL,'UN')
      INTO V_CODVOL
      FROM TGFVOL
      WHERE AD_CODSAP = :NEW.CODVOL;
    ELSE
      V_CODVOL := 'UN';
    END IF;

    IF UPDATING THEN 
      :NEW.DHATUALIZACAO := SYSDATE;

      SELECT NUNICO
      INTO V_NUNICO
      FROM AD_TGFPROCAB
      WHERE CODPROD = REGEXP_REPLACE(:NEW.CODPROD, '[^0-9]', '');

      UPDATE AD_TGFPROUNI 
      SET CODBARRA = :NEW.EANGTIN, 
          QUANTIDADE = :NEW.QUANTIDADE, 
          CODVOL = V_CODVOL 
      WHERE NUNICO = V_NUNICO;

      UPDATE TGFVOA 
      SET CODBARRA = :NEW.EANGTIN, 
          QUANTIDADE = :NEW.QUANTIDADE, 
          CODVOL = V_CODVOL 
      WHERE CODPROD = REGEXP_REPLACE(:NEW.CODPROD, '[^0-9]', '');
    END IF;

    IF INSERTING THEN 
      :NEW.DHINCLUSAO := SYSDATE;
    END IF;
  END BEFORE EACH ROW;
END;

/