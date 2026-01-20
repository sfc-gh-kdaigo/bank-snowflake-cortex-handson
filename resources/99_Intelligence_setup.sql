-- =========================================================
-- 法人営業向け Snowflake Intelligence ハンズオン
-- 〜半導体業界特化シナリオ〜
-- 
-- 99_Intelligence_setup.sql - Snowflake Intelligence公開設定
-- =========================================================
-- 作成日: 2026/01
-- =========================================================
-- 
-- 📁 ファイル構成:
--    1. 01_db_setup.sql    ← 環境構築・データ投入
--    2. 02_sv_setup.sql    ← Semantic View設定
--    3. 03_rag_setup.sql   ← Cortex Search設定
--    4. 04_ai_functions_demo.sql  ← Cortex AI Functions デモ
--    5. 05_sproc_setup.sql ← Stored Procedure
--    6. 06_agent_design.md ← Agent設計書
--    → 99_Intelligence_setup.sql ← 本ファイル（Intelligence公開）
--
-- ⚠️ 前提条件:
--    01〜05のセットアップが完了していること
--    GUIでCortex Agentを作成済みであること
--
-- =========================================================

USE ROLE ACCOUNTADMIN;
USE DATABASE CORPORATE_BANKING_DB;
USE WAREHOUSE CORPORATE_BANKING_WH;

-- =========================================================
-- Snowflake Intelligence への公開設定
-- =========================================================
-- 
-- 【概要】
--   GUIで作成したCortex AgentをSnowflake Intelligenceインターフェースに
--   公開するための設定です。
-- 
-- 【前提】
--   - Cortex Agent（CORPORATE_SALES_AGENT）がGUIで作成済み
--   - 必要なツール（Analyst、Search、Stored Procedure）が登録済み
-- 
-- ---------------------------------------------------------
-- Snowflake Intelligence オブジェクトの作成（アカウントに1つのみ）
CREATE SNOWFLAKE INTELLIGENCE IF NOT EXISTS SNOWFLAKE_INTELLIGENCE_OBJECT_DEFAULT;

-- エージェントをSnowflake Intelligenceに追加
ALTER SNOWFLAKE INTELLIGENCE SNOWFLAKE_INTELLIGENCE_OBJECT_DEFAULT 
    ADD AGENT CORPORATE_BANKING_DB.AGENT.CORPORATE_SALES_AGENT;

-- 全ユーザーがアクセスできるようにUSAGE権限を付与
GRANT USAGE ON SNOWFLAKE INTELLIGENCE SNOWFLAKE_INTELLIGENCE_OBJECT_DEFAULT TO ROLE PUBLIC;