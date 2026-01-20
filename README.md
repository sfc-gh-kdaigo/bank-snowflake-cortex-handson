# 🚀 法人営業向け Snowflake Intelligence ハンズオン - README

このアセットは、**Snowflake Cortex AI**の主要機能を活用し、法人営業担当者向けのAIアシスタントを構築するためのハンズオンです。

## ✨ 主な目的

自然言語でデータ分析・情報検索が可能なAIアシスタントを構築し、その仕組みを理解します。

**具体シナリオ**
*   半導体業界の法人顧客（30社）に対する融資・預金情報、営業活動履歴を自然言語で分析
*   商談メモや政府の半導体政策資料（PDF）をRAG検索で活用
*   **米国半導体企業の決算発言（Earning Call）**を検索し、市場トレンドを把握
*   Snowflake Agent/Snowflake Intelligenceによる統合的な情報提供

## 📚 このハンズオンで学ぶこと

本アセットを通じて、以下のスキルや知識を習得できます。
*   ✅ Snowflake Cortex AI の全体像と主要な機能（Cortex Agent、Analyst、Search、Intelligence）
*   🤖 Cortex Agentによる複数ツール（Analyst/Search/Sproc）のオーケストレーション
*   📊 Semantic View、Cortex Search Service、Stored Procedure の具体的な実装手順
*   🧠 **Cortex AI Functions**（AI_CLASSIFY, AI_FILTER, AI_COMPLETE）によるテキスト分類・抽出・生成
*   🛒 **Snowflake Marketplaceの活用**（Cortex Knowledge Extensions: 決算発言データ）
*   🔗 構造化データ（顧客・融資・預金・営業活動）と非構造化データ（商談メモ・PDF・Earning Call）の統合活用

## 🏗️ アセット構成：実装する主要コンポーネント

このハンズオンで実際に利用・実装する Snowflake Cortex AI のコンポーネントは以下の通りです。

### アーキテクチャ概要

```
┌─────────────────────────────────────────────────────────────┐
│                  Snowflake Intelligence                     │
│                    （チャットUI）                            │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                      Cortex Agent                           │
│          （オーケストレーション・ツール選択）                  │
│  ┌────────────┬────────────┬────────────┬────────────────┐ │
│  │   Tool 1   │   Tool 2   │   Tool 3   │     Tool 4     │ │
│  │  Analyst   │   Search   │   Search   │ Stored Proc    │ │
│  │            │  (自社)    │(Marketplace│                │ │
│  └────────────┴────────────┴────────────┴────────────────┘ │
└─────────────────────────────────────────────────────────────┘
       │              │              │              │
       ▼              ▼              ▼              ▼
  Semantic View   商談履歴      Earning Call    SEND_EMAIL
  （構造化データ） 政府資料PDF   （決算発言）    GET_DOCUMENT_URL
```

### コンポーネント詳細

| コンポーネント | 役割 |
| :--- | :--- |
| **Snowflake Intelligence** | Cortex Agentを利用するためのチャットボットUI。法人営業担当者が自然言語で質問を入力。 |
| **Cortex Agent** | ユーザーの質問を解析し、適切なツール（Analyst/Search/Sproc）を自動選択・実行するオーケストレーション層。 |
| **Cortex Analyst（ツール）** | Semantic Viewを通じて構造化データ（顧客・融資・預金・営業活動）に対して自然言語からSQLを生成・実行。 |
| **Cortex Search - 自社データ（ツール）** | 商談履歴テキストや政府資料PDFに対するRAG検索を提供。 |
| **Cortex Search - Marketplace（ツール）** | Cortex Knowledge Extensionsの決算発言（Earning Call）検索。NVIDIA、Intel等の半導体競合企業の決算発言を検索し、市場トレンドを把握。 |
| **Stored Procedure（ツール）** | メール送信（`SEND_EMAIL`）やPDFダウンロードURL生成（`GET_DOCUMENT_DOWNLOAD_URL`）などのアクション実行。 |

## 📁 ファイル構成

### SQLファイル（実行順序順）

| ファイル名 | 内容 |
| :--- | :--- |
| `00_git_setup.sql` | GitHubリポジトリとの連携設定（任意） |
| `01_db_setup.sql` | 環境構築・テーブル作成・サンプルデータ投入 |
| `02_ai_functions_demo.sql` | Cortex AI Functions デモ（AI_CLASSIFY, AI_FILTER, AI_COMPLETE） |
| `03_sv_setup.sql` | Semantic View設定（Cortex Analyst用） |
| `04_rag_setup.sql` | Cortex Search設定（RAG用） |
| `05_sproc_setup.sql` | Stored Procedure（カスタムツール） |

### ドキュメント・リソース

| ファイル名 | 内容 |
| :--- | :--- |
| `06_agent_design.md` | Intelligence Agent設計ガイド |
| `resources/99_Intelligence_setup.sql` | Snowflake Intelligence公開設定 |
| `resources/er_diagram.html` | ER図（ブラウザで表示） |

### データファイル

| フォルダ/ファイル | 内容 |
| :--- | :--- |
| `unstructured_data/Semiconductor_Strategy_and_Policy.pdf` | 経産省 半導体政策資料 |
| `unstructured_data/SupplyChain__Semiconductors_Govsupport.pdf` | サプライチェーン支援策資料 |

## 💡 環境構築と利用方法

### Step 1: 環境構築・データ投入
1. `01_db_setup.sql` を実行してデータベース・テーブル・サンプルデータを作成
2. PDFファイル（`unstructured_data/`内）をSnowflakeステージにアップロード

### Step 2: Cortex AI Functions体験（任意）
3. `02_ai_functions_demo.sql` を実行してCortex AI Functions（AI_CLASSIFY, AI_FILTER, AI_COMPLETE）を体験

### Step 3: Semantic View作成
4. `03_sv_setup.sql` を参考にSnowsight GUIでSemantic Viewを作成

### Step 4: Cortex Search設定
5. `04_rag_setup.sql` を実行してCortex Search Serviceを作成（商談履歴・政府資料PDF）

### Step 5: Stored Procedure作成
6. `05_sproc_setup.sql` を実行してStored Procedureを作成（メール送信・URL生成）

### Step 6: Marketplaceからデータ取得
7. Snowflake Marketplaceから「**Cortex Knowledge Extensions**」を取得
   - URL: https://app.snowflake.com/marketplace/listing/GZTSZ290BV65X
   - 米国上場企業の決算発言（Earning Call）をCortex Search Serviceとして利用可能

### Step 7: Cortex Agentの作成
8. `06_agent_design.md` を参考にCortex Agentを作成し、以下のツールを登録：
   - **Cortex Analyst**: 作成したSemantic Viewを指定
   - **Cortex Search（自社）**: 商談履歴・政府資料の2つのSearch Serviceを指定
   - **Cortex Search（Marketplace）**: Earning Call Search Serviceを指定
   - **Stored Procedure**: `SEND_EMAIL`、`GET_DOCUMENT_DOWNLOAD_URL`を指定

### Step 8: Snowflake Intelligenceへ公開
9. `resources/99_Intelligence_setup.sql` を実行してAgentをSnowflake Intelligenceに公開
10. Snowflake Intelligenceから作成したCortex Agentを選択してチャット開始

## 🧑‍💻 対象者

*   Snowflake 上での AI アプリケーション開発に興味のある方
*   Cortex AI の各機能の具体的な実装方法を学びたい方
*   法人営業・金融業界向けAIソリューションのPoCを検討されている方 
