CREATE OR REPLACE PROCEDURE "AD_STP_EMAIL_TGFPRO" AS
  
  V_MAILBODY CLOB;
  V_CODFILA INT;
  V_INTEGRACAO CLOB;
  V_MSGBODY CLOB;
  V_TIPO VARCHAR2(50);
  V_ENVIAEMAIL BOOLEAN;

  CURSOR USUARIO IS 
    SELECT CAB.CODUSU, USU.EMAIL, PRO.APROVAFIS, ROWNUM SEQ
    FROM AD_LIBCADUSU CAB
    LEFT JOIN AD_LIBCADUSUPRO PRO ON CAB.NUNICO = PRO.NUNICO
    LEFT JOIN TSIUSU USU ON USU.CODUSU = CAB.CODUSU
    WHERE CAB.ATIVO = 'S'
    AND (PRO.APROVAFIS = 'S');

BEGIN
  FOR USU IN USUARIO LOOP
    SELECT MAX(CODFILA) INTO V_CODFILA FROM TMDFMG;

    IF USU.APROVAFIS = 'S' THEN
      /*Captura os parceiros pendentes de aprovação fiscal*/
      SELECT 
        NVL(listagg('<li><h3>'||CAB.NUNICO ||' - ' ||CAB.DESCRPROD || '</h3><p>Aguardando aprovação.</p></li><br>') 
          within GROUP(ORDER BY CAB.NUNICO), '0') AS TGFPAR_INTEGRACAO
      INTO V_MSGBODY
      FROM AD_TGFPROCAB CAB 
      WHERE CAB.CODPROD IS NULL
      AND CAB.DHAPROVACAO IS NULL
      AND CAB.APROVAFIS = 0;

      IF V_MSGBODY != '0' THEN 
        V_MAILBODY := '<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <title>Notificação de Cadastro de Produtos Sankhya</title>
  <style>
    body {
      font-family: sans-serif;
    }

    .header {
      background-color: #42f569; /* Cor  */
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
      width: 30%; /* Ajuste para 3 seções */
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
    Notificação automática de cadastro de produtos Sankhya
  </div>

  <div class="container">  
    <div class="section">
      <h2>Aprovações Fiscais Pendentes</h2>
      <ul>
        ' || V_MSGBODY || '
        </ul>
    </div>
    </body>
</html>';

        INSERT INTO TMDFMG(
          CODFILA, ASSUNTO, DTENTRADA, STATUS, CODCON, 
          TENTENVIO, MENSAGEM, TIPOENVIO, MAXTENTENVIO, 
          EMAIL, MIMETYPE, CODUSU, CODSMTP
        )
        VALUES (
          V_CODFILA+USU.SEQ, 'Notificação de cadastro de Produtos Sankhya', 
          SYSDATE, 'Pendente', 0, 1, V_MAILBODY, 'E', 3, 
          USU.EMAIL, 'text/html', 0, 1
        );
      END IF;
    END IF;
  END LOOP;

  COMMIT;
END;

/