-- =========================================================
-- 法人営業向け Snowflake Intelligence ハンズオン
-- 〜半導体業界特化シナリオ〜
-- 
-- 02_sv_setup.sql - Semantic View設定（Cortex Analyst用）
-- =========================================================
-- 作成日: 2026/01
-- =========================================================
-- 
-- 📁 ファイル構成:
--    1. 01_db_setup.sql         ← 環境構築・データ投入（先に実行）
--    2. 02_ai_functions_demo.sql ← Cortex AI Functions デモ
--    3. 03_sv_setup.sql         ← 本ファイル（Semantic View設定）
--    4. 04_rag_setup.sql        ← Cortex Search設定
--    5. 05_sproc_setup.sql      ← Stored Procedure
--    6. 06_agent_design.md      ← Agent設計書
--
-- ⚠️ 前提条件:
--    01_db_setup.sql を先に実行してテーブル・データを作成しておくこと
--
-- =========================================================

-- =========================================================
-- Semantic Viewの作成（Cortex Analyst用）
-- =========================================================
-- 
-- ⚠️ Semantic ViewはSnowsight GUIで作成します
--    以下は設定時の参考情報です（GUI画面遷移順に記載）
-- 
-- ---------------------------------------------------------
-- Step 1: Semantic View基本情報
-- ---------------------------------------------------------
-- 
-- 【Semantic View名】
--   CORPORATE_SALES_ANALYSIS_SV
-- 
-- 【SVの説明（Description）】※コピペ用
/*
半導体関連企業向け法人営業のためのSemantic Viewです。
顧客情報（CUSTOMER）、融資情報（LOAN）、預金残高（DEPOSIT）、
営業活動履歴（SALES_ACTIVITY）の4テーブルを統合し、
融資残高、預金残高、預貸率、営業活動状況などのKPIを
自然言語で分析できるようにします。
法人営業担当者が顧客の財務状況把握、案件管理、
ポートフォリオ分析を効率的に行うことを目的としています。
*/
-- 
-- ---------------------------------------------------------
-- Step 2: サンプルSQLクエリ（説明入力後に登録）
-- ---------------------------------------------------------
-- ※ Semantic Viewのドラフト作成および精度向上のため、以下のサンプルクエリを登録してください
-- ※ SQL部分は /* */ でくくっているので、そのままコピー＆ペーストできます
-- ※ 4つのクエリで全テーブル（CUSTOMER, LOAN, DEPOSIT, SALES_ACTIVITY）をカバー
-- 

-- ■ クエリ1: 企業の融資案件一覧 (使用テーブル: CUSTOMER, LOAN)
-- 質問: 融資案件と融資残高を教えてください
/*
SELECT 
  c.CUSTOMER_NAME AS "企業名",
  l.LOAN_TYPE AS "融資種別",
  l.LOAN_PURPOSE AS "資金使途",
  l.LOAN_AMOUNT AS "融資金額_百万円",
  l.OUTSTANDING_BALANCE AS "融資残高_百万円",
  l.INTEREST_RATE AS "金利",
  l.LOAN_START_DATE AS "融資実行日",
  l.LOAN_END_DATE AS "返済期限",
  l.RELATED_SUBSIDY AS "関連補助金"
FROM CORPORATE_BANKING_DB.STRUCTURED_DATA.CUSTOMER c
JOIN CORPORATE_BANKING_DB.STRUCTURED_DATA.LOAN l 
  ON c.CUSTOMER_ID = l.CUSTOMER_ID
WHERE l.RECORD_DATE = '2025-01-31'
ORDER BY l.OUTSTANDING_BALANCE DESC;
*/

-- ■ クエリ2: 預金残高ランキング (使用テーブル: CUSTOMER, DEPOSIT)
-- 質問: 預金残高が多い企業トップ5を教えてください
/*
SELECT 
  c.CUSTOMER_NAME AS "企業名",
  c.INDUSTRY_CATEGORY AS "業種",
  SUM(d.BALANCE) AS "預金残高_百万円"
FROM CORPORATE_BANKING_DB.STRUCTURED_DATA.CUSTOMER c
JOIN CORPORATE_BANKING_DB.STRUCTURED_DATA.DEPOSIT d 
  ON c.CUSTOMER_ID = d.CUSTOMER_ID
WHERE d.RECORD_DATE = '2025-01-31'
GROUP BY c.CUSTOMER_NAME, c.INDUSTRY_CATEGORY
ORDER BY "預金残高_百万円" DESC
LIMIT 5;
*/

-- ■ クエリ3: 営業パイプライン状況 (使用テーブル: CUSTOMER, SALES_ACTIVITY)
-- 質問: 提案中、交渉中の案件を一覧化してください。
/*
SELECT 
  c.CUSTOMER_NAME AS "企業名",
  c.INDUSTRY_CATEGORY AS "業種",
  sa.ACTIVITY_DATE AS "活動日",
  sa.DEAL_STAGE AS "案件ステージ",
  sa.DEAL_AMOUNT AS "想定金額_百万円",
  sa.SALES_REP AS "担当者"
FROM CORPORATE_BANKING_DB.STRUCTURED_DATA.SALES_ACTIVITY sa
JOIN CORPORATE_BANKING_DB.STRUCTURED_DATA.CUSTOMER c 
  ON sa.CUSTOMER_ID = c.CUSTOMER_ID
WHERE sa.DEAL_STAGE IN ('提案中', '交渉中')
ORDER BY sa.DEAL_AMOUNT DESC;
*/

-- ■ クエリ4: フォローアップ対象の抽出 (使用テーブル: CUSTOMER, LOAN, SALES_ACTIVITY)
-- 質問: 融資残高が大きいのに最近訪問していない企業を抽出してください。
/*
SELECT 
  c.CUSTOMER_NAME AS "企業名",
  c.INDUSTRY_CATEGORY AS "業種",
  SUM(l.OUTSTANDING_BALANCE) AS "融資残高_百万円",
  MAX(sa.ACTIVITY_DATE) AS "最終活動日"
FROM CORPORATE_BANKING_DB.STRUCTURED_DATA.CUSTOMER c
JOIN CORPORATE_BANKING_DB.STRUCTURED_DATA.LOAN l 
  ON c.CUSTOMER_ID = l.CUSTOMER_ID AND l.RECORD_DATE = '2025-01-31'
LEFT JOIN CORPORATE_BANKING_DB.STRUCTURED_DATA.SALES_ACTIVITY sa 
  ON c.CUSTOMER_ID = sa.CUSTOMER_ID
GROUP BY c.CUSTOMER_NAME, c.INDUSTRY_CATEGORY
ORDER BY "融資残高_百万円" DESC;
*/

-- ---------------------------------------------------------
-- Step 3: テーブル・リレーションシップ・メトリクス設定
-- ---------------------------------------------------------
-- 
-- ⚠️ サンプルクエリから自動的にテーブル/カラム選択、リレーションシップ定義されていることを確認してください。
-- 【対象テーブル】
--   - CORPORATE_BANKING_DB.STRUCTURED_DATA.CUSTOMER
--   - CORPORATE_BANKING_DB.STRUCTURED_DATA.LOAN
--   - CORPORATE_BANKING_DB.STRUCTURED_DATA.DEPOSIT
--   - CORPORATE_BANKING_DB.STRUCTURED_DATA.SALES_ACTIVITY
-- 
-- 【リレーションシップ】
--   - LOAN.CUSTOMER_ID → CUSTOMER.CUSTOMER_ID (多:1)
--   - DEPOSIT.CUSTOMER_ID → CUSTOMER.CUSTOMER_ID (多:1)
--   - SALES_ACTIVITY.CUSTOMER_ID → CUSTOMER.CUSTOMER_ID (多:1)
--
-- ⚠️ 以下のメトリクス定義とシノニム設定はSnowsight GUIで行ってください。
-- 【定義するメトリクス（KPI）】※デモで使用する4つに厳選しています
--   1. TOTAL_LOAN_BALANCE: SUM(LOAN.OUTSTANDING_BALANCE)
--      - Synonyms: 融資残高合計, 貸出残高, 融資総額
--   2. TOTAL_DEPOSIT_BALANCE: SUM(DEPOSIT.BALANCE)
--      - Synonyms: 預金残高合計, 預金総額
--   3. LOAN_DEPOSIT_RATIO: SUM(LOAN.OUTSTANDING_BALANCE) / NULLIF(SUM(DEPOSIT.BALANCE), 0) * 100
--      - Synonyms: 預貸率, LDR
--   4. CUSTOMER_COUNT: COUNT(DISTINCT CUSTOMER.CUSTOMER_ID)
--      - Synonyms: 顧客数, 取引先数
-- 
-- 【テーブルのSynonyms】
--   - CUSTOMER: 法人顧客, 企業, 取引先, 半導体企業
--   - LOAN: 融資, ローン, 貸出, 借入, 与信
--   - DEPOSIT: 預金, 預金残高, 口座残高
--   - SALES_ACTIVITY: 営業活動, 商談, 訪問, 活動履歴
-- 
-- ---------------------------------------------------------
-- =========================================================
-- 02_sv_setup.sql 完了
-- =========================================================
-- 
-- Semantic ViewはGUIで作成してください。
-- 本ファイルの情報を参考に設定を行ってください。
-- 
-- 次のステップ:
--   → 03_rag_setup.sql（Cortex Search設定）
-- 
-- =========================================================
