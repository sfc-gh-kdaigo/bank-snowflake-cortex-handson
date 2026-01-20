-- =========================================================
-- 法人営業向け Snowflake Intelligence ハンズオン
-- 〜半導体業界特化シナリオ〜
-- 
-- 03_rag_setup.sql - Cortex Search設定（RAG用）
-- =========================================================
-- 作成日: 2026/01
-- =========================================================
-- 
-- 📁 ファイル構成:
--    1. 01_db_setup.sql    ← 環境構築・データ投入（先に実行）
--    2. 02_sv_setup.sql    ← Semantic View設定
--    3. 03_rag_setup.sql   ← 本ファイル（Cortex Search設定）
--    4. 04_ai_functions_demo.sql  ← Cortex AI Functions デモ
--    5. 05_sproc_setup.sql ← Stored Procedure
--    6. 06_agent_design.md ← Agent設計書
--
-- ⚠️ 前提条件:
--    01_db_setup.sql を先に実行してテーブル・データを作成しておくこと
--
-- =========================================================

USE ROLE ACCOUNTADMIN;
USE DATABASE CORPORATE_BANKING_DB;
USE WAREHOUSE CORPORATE_BANKING_WH;
USE SCHEMA CORPORATE_BANKING_DB.UNSTRUCTURED_DATA;

-- =========================================================
-- PDFファイルの準備
-- =========================================================

-- ---------------------------------------------------------
-- Step 1: PDFファイルのアップロード
-- ---------------------------------------------------------
-- 【事前準備】Snowsight または SnowSQL で以下を実行してPDFをアップロード
-- 
-- ■ Snowsightの場合:
--   1. Data > Databases > CORPORATE_BANKING_DB > UNSTRUCTURED_DATA > Stages
--   2. semiconductor_docs ステージを選択
--   3. 「+ Files」ボタンをクリック
--   4. 以下の2ファイルをアップロード:
--      - Semiconductor_Strategy_and_Policy.pdf
--      - SupplyChain__Semiconductors_Govsupport.pdf
-- 
-- ■ SnowSQLの場合:
--   PUT file:///path/to/Semiconductor_Strategy_and_Policy.pdf @semiconductor_docs;
--   PUT file:///path/to/SupplyChain__Semiconductors_Govsupport.pdf @semiconductor_docs;
-- 
-- ---------------------------------------------------------

-- ステージ内のファイル確認
LIST @semiconductor_docs;


-- =========================================================
-- PDFパースとチャンク化
-- =========================================================

-- ---------------------------------------------------------
-- Step 2: AI_PARSE_DOCUMENTでPDFからテキスト抽出
-- ---------------------------------------------------------
-- AI_PARSE_DOCUMENTを使用してPDFの全文テキストを抽出
-- mode: LAYOUT（レイアウト情報を保持）、page_split: true（ページ単位で分割）

CREATE OR REPLACE TABLE PARSED_DOCUMENTS_RAW AS
SELECT 
    relative_path AS FILE_NAME,
    file_url AS FILE_URL,
    AI_PARSE_DOCUMENT(
        TO_FILE('@CORPORATE_BANKING_DB.UNSTRUCTURED_DATA.semiconductor_docs', relative_path),
        {'mode': 'LAYOUT', 'page_split': true}
    ) AS PARSED_CONTENT
FROM DIRECTORY(@CORPORATE_BANKING_DB.UNSTRUCTURED_DATA.semiconductor_docs)
WHERE relative_path LIKE '%.pdf';

-- パース結果の確認
SELECT FILE_NAME, FILE_URL, PARSED_CONTENT FROM PARSED_DOCUMENTS_RAW;

-- ---------------------------------------------------------
-- Step 3: テキストのチャンク化（Cortex Search用）
-- ---------------------------------------------------------
-- SPLIT_TEXT_RECURSIVE_CHARACTERでチャンク分割
-- chunk_size: 512文字、overlap: 128文字

CREATE OR REPLACE TABLE DOCUMENT_CHUNKS AS
SELECT 
    FILE_NAME,
    FILE_URL,
    f.index AS PAGE_NUMBER,
    ROW_NUMBER() OVER (ORDER BY FILE_NAME, f.index, c.index) AS CHUNK_ID,
    c.value::TEXT AS CHUNK_TEXT
FROM PARSED_DOCUMENTS_RAW r,
    LATERAL FLATTEN(INPUT => r.PARSED_CONTENT:pages) f,
    LATERAL FLATTEN(INPUT => SNOWFLAKE.CORTEX.SPLIT_TEXT_RECURSIVE_CHARACTER(
        f.value:content::TEXT,
        'markdown',
        512,
        128
    )) c;

-- チャンク化結果の確認
SELECT * FROM DOCUMENT_CHUNKS LIMIT 20;


-- =========================================================
-- Cortex Search Serviceの作成
-- =========================================================

-- ---------------------------------------------------------
-- Step 4: 商談履歴用Cortex Search Service
-- ---------------------------------------------------------
CREATE OR REPLACE CORTEX SEARCH SERVICE MEETING_NOTES_SEARCH
  ON MEETING_CONTENT
  ATTRIBUTES CUSTOMER_NAME, MEETING_DATE, KEYWORDS
  WAREHOUSE = CORPORATE_BANKING_WH
  TARGET_LAG = '1 hour'
  AS (
    SELECT 
      NOTE_ID,
      CUSTOMER_ID,
      CUSTOMER_NAME,
      MEETING_DATE,
      MEETING_CONTENT,
      KEYWORDS
    FROM MEETING_NOTES
  );

-- ---------------------------------------------------------
-- Step 5: 政府資料（PDF）用Cortex Search Service
-- ---------------------------------------------------------
CREATE OR REPLACE CORTEX SEARCH SERVICE GOVERNMENT_DOCS_SEARCH
  ON CHUNK_TEXT
  ATTRIBUTES FILE_NAME, FILE_URL, PAGE_NUMBER
  WAREHOUSE = CORPORATE_BANKING_WH
  TARGET_LAG = '1 day'
  EMBEDDING_MODEL = 'snowflake-arctic-embed-l-v2.0'
AS (
    SELECT 
      CHUNK_ID,
      FILE_NAME,
      FILE_URL,
      PAGE_NUMBER,
      CHUNK_TEXT
    FROM DOCUMENT_CHUNKS
);


-- =========================================================
-- Snowflake Marketplace: Cortex Knowledge Extensions
-- =========================================================

-- ---------------------------------------------------------
-- Step 6: Earning Call（決算発言）データの取得
-- ---------------------------------------------------------
-- 
-- 【概要】
--   Snowflake Marketplaceで提供されている「Cortex Knowledge Extensions」には、
--   米国上場企業の決算説明会（Earning Call）スクリプトがCortex Search Serviceとして
--   提供されています。自分でデータを準備・加工する必要がなく、すぐに利用可能です。
-- 
-- 【取得手順】
--   1. Snowsight > Data Products > Marketplace を開く
--   2. 検索ボックスで「Cortex Knowledge Extensions」を検索
--   3. 「Snowflake Public Data (Cortex Knowledge Extensions)」を選択
--      URL: https://app.snowflake.com/marketplace/listing/GZTSZ290BV65X
--   4. 「Get」ボタンをクリックしてアカウントに追加
--   5. データベース名を指定（デフォルト: SNOWFLAKE_PUBLIC_DATA_CORTEX_KNOWLEDGE_EXTENSIONS）
-- 
-- 【提供されるCortex Search Service】
--   - COMPANY_EVENT_TRANSCRIPT_CORTEX_SEARCH_SERVICE: 米国上場企業の決算説明会スクリプト
--   - ※ その他のSearch Serviceも含まれる場合があります
-- 
-- 【活用例：半導体競合企業の決算発言を検索】
--   - NVIDIA: AI向けGPU需要、サプライチェーン状況
--   - Intel: 設備投資計画、工場建設状況
--   - AMD: データセンター向け半導体の動向
--   - ASML: EUV露光装置の出荷状況、中国規制の影響
-- 
-- 【Agent登録時の設定】
--   Cortex Agentのツールとして登録する際は、Marketplaceから取得した
--   データベース内のCortex Search Serviceを指定します。
-- 
-- ---------------------------------------------------------

-- Marketplace取得後の確認クエリ（コメントを外して実行）
/*
-- 取得したデータベースの確認
SHOW DATABASES LIKE 'SNOWFLAKE_PUBLIC_DATA_CORTEX%';

-- 利用可能なCortex Search Serviceの確認
SHOW CORTEX SEARCH SERVICES IN DATABASE SNOWFLAKE_PUBLIC_DATA_CORTEX_KNOWLEDGE_EXTENSIONS;
*/


-- =========================================================
-- 動作確認
-- =========================================================

-- ---------------------------------------------------------
-- Step 7: Cortex Search動作確認
-- ---------------------------------------------------------
-- サンプル質問1: 「半導体の設備投資に使える政府の補助金は？」
-- サンプル質問2: 「ラピダスはどのような支援を受けていますか？」
-- サンプル質問3: 「TSMCの熊本進出の経済効果は？」

-- 政府資料検索テスト（コメントを外して実行）
/*
SELECT SNOWFLAKE.CORTEX.SEARCH_PREVIEW(
    'GOVERNMENT_DOCS_SEARCH',
    '半導体の設備投資に使える政府の補助金は？',
    5
);
*/

-- 商談履歴検索テスト（コメントを外して実行）
/*
SELECT SNOWFLAKE.CORTEX.SEARCH_PREVIEW(
    'MEETING_NOTES_SEARCH',
    '信越化学のウェハ工場増設について',
    5
);
*/

-- Earning Call検索テスト（Marketplace取得後、コメントを外して実行）
-- ※ データベース名・サービス名はMarketplace取得時の設定に合わせて変更してください
/*
SELECT SNOWFLAKE.CORTEX.SEARCH_PREVIEW(
    'SNOWFLAKE_PUBLIC_DATA_CORTEX_KNOWLEDGE_EXTENSIONS.AI.COMPANY_EVENT_TRANSCRIPT_CORTEX_SEARCH_SERVICE',
    'NVIDIA AI GPU demand supply chain',
    5
);
*/


-- =========================================================
-- 03_rag_setup.sql 完了
-- =========================================================
-- 
-- 作成されたオブジェクト:
-- 
-- [CORPORATE_BANKING_DB.UNSTRUCTURED_DATA]
--   - PARSED_DOCUMENTS_RAW - AI_PARSE_DOCUMENTによるPDFパース結果
--   - DOCUMENT_CHUNKS - チャンク化されたドキュメント
--   - MEETING_NOTES_SEARCH（Cortex Search Service）- 商談履歴検索
--   - GOVERNMENT_DOCS_SEARCH（Cortex Search Service）- 政府資料PDF検索
-- 
-- [Snowflake Marketplace - Cortex Knowledge Extensions]
--   - COMPANY_EVENT_TRANSCRIPT_CORTEX_SEARCH_SERVICE（Cortex Search Service）- 決算発言検索
--   - ※ Marketplaceから取得して利用
-- 
-- PDFファイル:
--   - Semiconductor_Strategy_and_Policy.pdf（経産省 半導体政策について）
--   - SupplyChain__Semiconductors_Govsupport.pdf（サプライチェーン支援策）
-- 
-- 次のステップ:
--   → 04_ai_functions_demo.sql（Cortex AI Functions デモ）
--   → 05_sproc_setup.sql（Stored Procedure）
--   → 06_agent_design.md を参考にAgentを作成
-- 
-- =========================================================
