-- =========================================================
-- 法人営業向け Snowflake Intelligence ハンズオン
-- 〜半導体業界特化シナリオ〜
-- 
-- 04_ai_functions_demo.sql - Cortex AI Functions デモ
-- =========================================================
-- 作成日: 2026/01
-- =========================================================
-- 
-- 📁 ファイル構成:
--    1. 01_db_setup.sql         ← 環境構築・データ投入（先に実行）
--    2. 02_ai_functions_demo.sql ← 本ファイル（Cortex AI Functions デモ）
--    3. 03_sv_setup.sql         ← Semantic View設定
--    4. 04_rag_setup.sql        ← Cortex Search設定
--    5. 05_sproc_setup.sql      ← Stored Procedure
--    6. 06_agent_design.md      ← Agent設計書
--
-- ⚠️ 前提条件:
--    01_db_setup.sql を先に実行してテーブル・データを作成しておくこと
--
-- 【Cortex AI Functions 一覧】
--    - AI_CLASSIFY: テキスト分類
--    - AI_FILTER: 条件によるフィルタリング
--    - AI_COMPLETE: テキスト生成
--
-- =========================================================

USE ROLE ACCOUNTADMIN;
USE DATABASE CORPORATE_BANKING_DB;
USE WAREHOUSE CORPORATE_BANKING_WH;
USE SCHEMA STRUCTURED_DATA;

-- =============================================================================
-- 1. データの確認
-- =============================================================================

-- 法人顧客マスタ
SELECT * FROM CUSTOMER LIMIT 10;

-- 融資情報
SELECT * FROM LOAN WHERE RECORD_DATE = '2025-01-31' LIMIT 10;

-- 営業活動履歴
SELECT * FROM SALES_ACTIVITY LIMIT 10;

-- 商談メモ（UNSTRUCTURED_DATAスキーマ）
SELECT * FROM CORPORATE_BANKING_DB.UNSTRUCTURED_DATA.MEETING_NOTES LIMIT 10;


-- =============================================================================
-- 2. AI_COMPLETE: シンプルな例（モデル比較）
-- =============================================================================
-- 異なるLLMモデルで同じ質問を実行して比較

SELECT AI_COMPLETE('claude-4-sonnet', 'Snowflakeの特徴を50字以内で教えてください。') AS RESPONSE;

SELECT AI_COMPLETE('openai-gpt-4.1', 'Snowflakeの特徴を50字以内で教えてください。') AS RESPONSE;


-- =============================================================================
-- 3. AI_CLASSIFY: 営業活動の分類
-- =============================================================================
-- 営業活動の種別を自動分類

SELECT 
    ACTIVITY_ID,
    c.CUSTOMER_NAME,
    sa.ACTIVITY_DATE,
    LEFT(sa.ACTIVITY_SUMMARY, 80) AS activity_preview,
    AI_CLASSIFY(
        sa.ACTIVITY_SUMMARY,
        ['新規開拓', '深耕営業', '案件フォロー', '情報収集', 'クロスセル提案', '問題対応']
    ) AS activity_category,
    sa.DEAL_STAGE,
    sa.DEAL_AMOUNT
FROM SALES_ACTIVITY sa
JOIN CUSTOMER c ON sa.CUSTOMER_ID = c.CUSTOMER_ID
WHERE sa.ACTIVITY_SUMMARY IS NOT NULL
ORDER BY sa.ACTIVITY_DATE DESC;


-- =============================================================================
-- 4. AI_CLASSIFY: 商談ステージの自動判定
-- =============================================================================
-- 商談メモから商談ステージを自動判定

SELECT 
    NOTE_ID,
    CUSTOMER_NAME,
    MEETING_DATE,
    LEFT(MEETING_CONTENT, 100) AS meeting_preview,
    AI_CLASSIFY(
        MEETING_CONTENT,
        ['情報収集段階', 'ニーズ把握', '提案準備', '条件交渉', '契約直前', '競合対応中']
    ) AS deal_stage_prediction
FROM CORPORATE_BANKING_DB.UNSTRUCTURED_DATA.MEETING_NOTES
ORDER BY MEETING_DATE DESC;


-- =============================================================================
-- 5. AI_FILTER: 政府補助金・支援策に関連する案件の抽出
-- =============================================================================
-- 先端半導体基金、サプライチェーン強靭化支援、経産省補助金、グリーンイノベーション基金等

SELECT 
    NOTE_ID,
    CUSTOMER_NAME,
    MEETING_DATE,
    MEETING_CONTENT
FROM CORPORATE_BANKING_DB.UNSTRUCTURED_DATA.MEETING_NOTES
WHERE AI_FILTER(
    PROMPT('この文章に政府の補助金や支援策（例：先端半導体基金、サプライチェーン強靭化、経産省補助金、グリーンイノベーション基金など）への言及がありますか？: {0}', MEETING_CONTENT)
);


-- =============================================================================
-- 6. AI_FILTER: 車載・ADAS関連案件の抽出
-- =============================================================================
-- イメージセンサーやADAS（先進運転支援システム）に関する案件を抽出

SELECT 
    NOTE_ID,
    CUSTOMER_NAME,
    MEETING_DATE,
    MEETING_CONTENT,
    KEYWORDS
FROM CORPORATE_BANKING_DB.UNSTRUCTURED_DATA.MEETING_NOTES
WHERE AI_FILTER(
    PROMPT('この文章にイメージセンサーまたはADAS（先進運転支援システム）に関する内容がありますか？: {0}', MEETING_CONTENT)
)
ORDER BY MEETING_DATE DESC;


-- =============================================================================
-- 7. AI_COMPLETE: 週次営業レポートの自動生成
-- =============================================================================
-- 営業KPIから週次レポートを自動生成

WITH weekly_metrics AS (
    SELECT 
        -- 営業活動メトリクス
        (SELECT COUNT(*) FROM SALES_ACTIVITY 
         WHERE ACTIVITY_DATE >= DATEADD(day, -7, CURRENT_DATE())) AS weekly_activities,
        
        -- パイプライン金額
        (SELECT SUM(DEAL_AMOUNT) FROM SALES_ACTIVITY 
         WHERE DEAL_STAGE IN ('提案中', '交渉中')) AS pipeline_amount,
        
        -- 新規商談数
        (SELECT COUNT(*) FROM CORPORATE_BANKING_DB.UNSTRUCTURED_DATA.MEETING_NOTES 
         WHERE MEETING_DATE >= DATEADD(day, -7, CURRENT_DATE())) AS weekly_meetings,
        
        -- 融資残高合計
        (SELECT SUM(OUTSTANDING_BALANCE) FROM LOAN 
         WHERE RECORD_DATE = '2025-01-31') AS total_loan_balance
)
SELECT 
    REPLACE(
        AI_COMPLETE(
            'llama4-maverick',
            CONCAT(
                '以下の週次データに基づいて、法人営業部長向けの週次サマリーレポートを作成してください：\n\n',
                '【今週のKPI】\n',
                '- 営業活動件数: ', weekly_activities, '件\n',
                '- 商談件数: ', weekly_meetings, '件\n',
                '- パイプライン金額: ', TO_CHAR(pipeline_amount, '999,999'), '百万円\n',
                '- 融資残高合計: ', TO_CHAR(total_loan_balance, '999,999,999'), '百万円\n\n',
                '以下の構成でレポートを作成してください：\n',
                '1. 今週のハイライト（成果・課題）\n',
                '2. 注目案件の進捗\n',
                '3. 来週の営業重点施策（3つ）\n',
                '実行可能で具体的な内容にまとめてください。'
            )
        ),
        '\\n', CHR(10)
    ) AS weekly_report
FROM weekly_metrics;


-- =========================================================
-- 04_ai_functions_demo.sql 完了
-- =========================================================
-- 
-- 実行したCortex AI Functions:
--   - AI_CLASSIFY: 営業活動・商談ステージの分類
--   - AI_FILTER: 重要案件・緊急案件の抽出
--   - AI_COMPLETE: 週次レポート・営業戦略レポートの生成
-- 
-- 次のステップ:
--   → 05_sproc_setup.sql（Stored Procedure）
-- 
-- =========================================================
