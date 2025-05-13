CREATE OR REPLACE trigger AD_TRG_TGFPAP
AFTER INSERT 
ON TGFPAP
REFERENCING NEW AS NEW OLD AS OLD
FOR EACH ROW
DECLARE
V_VALIDAPROD INT;
V_NUNICO INT;
V_SEQ INT;

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

    IF V_VALIDAPROD >=1 THEN 
        
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


END;
