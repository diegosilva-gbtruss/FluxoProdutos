CREATE OR REPLACE trigger AD_TRG_TGFPAP
AFTER INSERT OR UPDATE OR DELETE
ON TGFPAP
REFERENCING NEW AS NEW OLD AS OLD
FOR EACH ROW
DECLARE
V_VALIDAPROD INT;
V_NUNICO INT;
V_SEQ INT;
V_VALIDASEQ INT;
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

SELECT COUNT(1)
INTO V_VALIDAPROD
FROM AD_TGFPROCAB
WHERE CODPROD = :NEW.CODPROD;

    IF V_VALIDAPROD >=1 AND INSERTING THEN 

    SELECT COUNT(1)
    INTO V_VALIDASEQ
    FROM AD_TGFPROPAP
    WHERE NUNICO = (SELECT NUNICO FROM AD_TGFPROCAB WHERE CODPROD = :NEW.CODPROD)
    AND SEQUENCIA = :NEW.SEQUENCIA
    AND CODPARC = :NEW.CODPARC;

    IF V_VALIDASEQ = 0 THEN


        SELECT NUNICO 
        INTO V_NUNICO 
        FROM AD_TGFPROCAB
        WHERE CODPROD = :NEW.CODPROD;

        SELECT NVL(MAX(SEQ),0)+1
        INTO V_SEQ 
        FROM AD_TGFPROPAP
        WHERE NUNICO = V_NUNICO;


        INSERT INTO AD_TGFPROPAP (UNIDADEPARC,UNIDADE,SEQUENCIA,SEQ,PRAZOENT,NUNICO,DUM14,DHAPROVACAO,DHALTERACAO,DESCRPROPARC,CODUSUALTER,CODUSU,CODPROPARC,CODPARC,CODBARRA,AD_OBSERVACAO,AD_APTOINAPTO)
        VALUES (:NEW.UNIDADEPARC,:NEW.UNIDADE,:NEW.SEQUENCIA,V_SEQ,:NEW.PRAZOENT,V_NUNICO,:NEW.DUM14,SYSDATE,SYSDATE,:NEW.DESCRPROPARC,1209,1209,:NEW.CODPROPARC,:NEW.CODPARC,:NEW.CODBARRA,:NEW.AD_OBSERVACAO,:NEW.AD_APTOINAPTO);

    END IF;
    END IF;
    
        IF V_VALIDAPROD >=1 AND DELETING THEN 
        
                SELECT COUNT(1)
                INTO V_VALIDASEQ
                FROM AD_TGFPROPAP
                WHERE NUNICO = (SELECT NUNICO FROM AD_TGFPROCAB WHERE CODPROD = :OLD.CODPROD)
                AND SEQUENCIA = :OLD.SEQUENCIA
                AND CODPARC = :OLD.CODPARC;
                
                   IF V_VALIDASEQ >= 1 THEN
                   
                   DELETE FROM AD_TGFPROPAP WHERE NUNICO = (SELECT NUNICO FROM AD_TGFPROCAB WHERE CODPROD = :OLD.CODPROD) AND SEQUENCIA = :OLD.SEQUENCIA AND CODPARC = :OLD.CODPARC;
                   
                   END IF;
                   
               IF V_VALIDAPROD >=1 AND UPDATING THEN     
               
             
                SELECT COUNT(1)
                INTO V_VALIDASEQ
                FROM AD_TGFPROPAP
                WHERE NUNICO = (SELECT NUNICO FROM AD_TGFPROCAB WHERE CODPROD = :NEW.CODPROD)
                AND SEQUENCIA = :NEW.SEQUENCIA
                AND CODPARC = :NEW.CODPARC;
                
                IF V_VALIDASEQ >= 1 THEN
               
               UPDATE AD_TGFPROPAP SET 
               CODPROPARC = :NEW.CODPROPARC,
                DESCRPROPARC = :NEW.DESCRPROPARC,
                UNIDADE = :NEW.UNIDADE,
                PRAZOENT = :NEW.PRAZOENT,
                UNIDADEPARC = :NEW.UNIDADEPARC,
                AD_OBSERVACAO = :NEW.AD_OBSERVACAO,
                AD_APTOINAPTO = :NEW.AD_APTOINAPTO,
                CODBARRA = :NEW.CODBARRA,
                DUM14 = :NEW.DUM14
                WHERE NUNICO = (SELECT NUNICO FROM AD_TGFPROCAB WHERE CODPROD = :NEW.CODPROD)
                AND SEQUENCIA = :NEW.SEQUENCIA
                AND CODPARC = :NEW.CODPARC;
               
               END IF;
               END IF;
            
        END IF;
    
commit;


END;
