-- =========================================================
-- 法人営業向け Snowflake Intelligence ハンズオン
-- 〜半導体業界特化シナリオ〜
-- 
-- 05_sproc_setup.sql - Stored Procedure（Agentカスタムツール）
-- =========================================================
-- 作成日: 2026/01
-- =========================================================
-- 
-- 📁 ファイル構成:
--    1. 01_db_setup.sql         ← 環境構築・データ投入（先に実行）
--    2. 02_ai_functions_demo.sql ← Cortex AI Functions デモ
--    3. 03_sv_setup.sql         ← Semantic View設定
--    4. 04_rag_setup.sql        ← Cortex Search設定
--    5. 05_sproc_setup.sql      ← 本ファイル（Stored Procedure）
--    6. 06_agent_design.md      ← Agent設計書
--
-- ⚠️ 事前準備:
--   - 01_db_setup.sql を先に実行してデータベースを作成しておくこと
--   - ACCOUNTADMIN権限が必要
--
-- =========================================================

USE ROLE ACCOUNTADMIN;
USE DATABASE CORPORATE_BANKING_DB;
USE WAREHOUSE CORPORATE_BANKING_WH;
USE SCHEMA AGENT;

-- =========================================================
-- 事前準備: Email Integration の作成
-- =========================================================
-- メール送信機能を使用するために、通知インテグレーションを作成

CREATE OR REPLACE NOTIFICATION INTEGRATION EMAIL_INTEGRATION
    TYPE = EMAIL
    ENABLED = TRUE;

-- Integration の確認
SHOW NOTIFICATION INTEGRATIONS;
-- DESC NOTIFICATION INTEGRATION EMAIL_CONNECTOR;

-- =========================================================
-- Stored Procedure 1: メール送信
-- =========================================================
-- 
-- 【用途】
--   Agent経由で「この内容を○○にメールで送って」に対応
--   商談サマリーや提案資料の情報を関係者にメール送信
-- 
-- 【パラメータ】
--   - RECIPIENT_EMAIL: 送信先メールアドレス
--   - SUBJECT: メール件名
--   - BODY: メール本文（HTML形式可）
-- 
-- 【使用例】
--   CALL SEND_EMAIL('sales@example.com', '東京エレクトロン商談サマリー', '<h1>商談概要</h1><p>...</p>');
-- 
-- ---------------------------------------------------------

CREATE OR REPLACE PROCEDURE CORPORATE_BANKING_DB.AGENT.SEND_EMAIL(
    "RECIPIENT_EMAIL" VARCHAR, 
    "SUBJECT" VARCHAR, 
    "BODY" VARCHAR
)
RETURNS VARCHAR
LANGUAGE PYTHON
RUNTIME_VERSION = '3.12'
PACKAGES = ('snowflake-snowpark-python')
HANDLER = 'send_email'
COMMENT = 'Agentからメールを送信するためのプロシージャ'
EXECUTE AS OWNER
AS '
def send_email(session, recipient_email, subject, body):
    try:
        # Escape single quotes in the body and subject
        escaped_body = body.replace("''", "''''")
        escaped_subject = subject.replace("''", "''''")
        
        # Execute the system procedure call
        session.sql(f"""
            CALL SYSTEM$SEND_EMAIL(
                ''EMAIL_INTEGRATION'',
                ''{recipient_email}'',
                ''{escaped_subject}'',
                ''{escaped_body}'',
                ''text/html''
            )
        """).collect()
        
        return "メールを送信しました: " + recipient_email
    except Exception as e:
        return f"メール送信エラー: {str(e)}"
';

-- ---------------------------------------------------------
-- 動作確認: メール送信テスト
-- ---------------------------------------------------------
-- Step 1: 現在のユーザーのメールアドレスを変数に格納
SET my_email = (
    SELECT EMAIL 
    FROM SNOWFLAKE.ACCOUNT_USAGE.USERS 
    WHERE NAME = CURRENT_USER()
);

-- Step 2: 変数を使ってメール送信
CALL SEND_EMAIL(
    $my_email,
    'Snowflake Intelligence テストメール',
    '<h1>テストメール</h1><p>このメールはSnowflake Intelligence Agentのテストです。</p><p>正常に受信できていれば、メール送信機能は正しく動作しています。</p>'
);


-- =========================================================
-- Stored Procedure 2: ドキュメントダウンロードURL生成
-- =========================================================
-- 
-- 【用途】
--   Agent経由で「この資料をダウンロードしたい」に対応
--   ステージ内のPDFファイルに対して署名付きダウンロードURLを生成
-- 
-- 【パラメータ】
--   - relative_file_path: ファイル名（例: 'Semiconductor_Strategy_and_Policy.pdf'）
--   - expiration_mins: URLの有効期限（分）、デフォルト5分
-- 
-- 【使用例】
--   CALL GET_DOCUMENT_DOWNLOAD_URL('Semiconductor_Strategy_and_Policy.pdf', 5);
-- 
-- 【対象ファイル】
--   - Semiconductor_Strategy_and_Policy.pdf（経産省 半導体政策について）
--   - SupplyChain__Semiconductors_Govsupport.pdf（サプライチェーン支援策）
-- 
-- ---------------------------------------------------------

CREATE OR REPLACE PROCEDURE CORPORATE_BANKING_DB.AGENT.GET_DOCUMENT_DOWNLOAD_URL(
    relative_file_path STRING, 
    expiration_mins INTEGER DEFAULT 5
)
RETURNS STRING
LANGUAGE SQL
COMMENT = '内部ステージのPDFファイル用に署名付きダウンロードURLを生成'
EXECUTE AS CALLER
AS
$$
DECLARE
    presigned_url STRING;
    sql_stmt STRING;
    expiration_seconds INTEGER;
    stage_name STRING DEFAULT '@CORPORATE_BANKING_DB.UNSTRUCTURED_DATA.semiconductor_docs';
BEGIN
    expiration_seconds := expiration_mins * 60;
    
    sql_stmt := 'SELECT GET_PRESIGNED_URL(' || stage_name || ', ' || '''' || relative_file_path || '''' || ', ' || expiration_seconds || ') AS url';

    EXECUTE IMMEDIATE :sql_stmt;

    SELECT "URL"
    INTO :presigned_url
    FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()));

    RETURN :presigned_url;
END;
$$;

-- ---------------------------------------------------------
-- 動作確認: ドキュメントダウンロードURL生成テスト
-- ----------------------------------------------------------
-- 半導体政策PDFのダウンロードURL生成（有効期限5分）
CALL GET_DOCUMENT_DOWNLOAD_URL('Semiconductor_Strategy_and_Policy.pdf', 5);



-- =========================================================
-- Sproc一覧取得
-- =========================================================
-- Stored Procedure の確認
SHOW PROCEDURES IN SCHEMA CORPORATE_BANKING_DB.AGENT;

-- ---------------------------------------------------------

-- =========================================================
-- セットアップ完了
-- =========================================================
-- 
-- 作成されたオブジェクト:
-- 
-- [CORPORATE_BANKING_DB.AGENT]
--   - SEND_EMAIL（メール送信プロシージャ）
--   - GET_DOCUMENT_DOWNLOAD_URL（ダウンロードURL生成プロシージャ）
-- 
-- Agentへのツール登録:
--   1. Snowsight > AI & ML > Snowflake Intelligence
--   2. CORPORATE_SALES_AGENT を編集
--   3. Tools > Add Tool > Stored Procedure
--   4. 上記2つのプロシージャを追加
-- 
-- =========================================================
