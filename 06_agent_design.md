# Snowflake Intelligence向けAgent 設計書

## 🤖 基本情報

| 項目 | 値 |
|------|-----|
| **作成先DB** | `CORPORATE_BANKING_DB` |
| **作成先スキーマ** | `AGENT` |
| **エージェントオブジェクト名** | `CORPORATE_SALES_AGENT` |

---

## 📝 エージェント説明

### 概要

```
半導体関連企業向け法人営業を支援するAIエージェントです。
顧客の財務情報（融資残高・預金残高・預貸率）、営業活動履歴、
政府の半導体支援策（補助金・助成金）、商談履歴、
および米国半導体企業の決算発言（Earning Call）を横断的に分析し、
営業担当者の意思決定をサポートします。
```

### エージェント使用方法

```
このエージェントは以下の4つの情報源を活用して質問に回答します：

1. 【構造化データ】顧客マスタ、融資情報、預金残高、営業活動履歴
   → 企業の財務状況、融資残高ランキング、預貸率分析など

2. 【商談履歴】過去の商談メモ、議事録、ネクストアクション
   → 特定企業との商談経緯、過去の提案内容など

3. 【政府資料】経産省の半導体政策、補助金・助成金情報
   → 活用可能な支援策、ラピダス/TSMC関連情報など

4. 【決算発言】米国上場企業の決算説明会スクリプト（Earning Call）
   → NVIDIA、Intel、AMD、ASML等の半導体競合企業の市場見通し、設備投資計画など

質問は自然な日本語で入力してください。
```

---

## 💬 サンプル質問（6つ）

| # | 質問 | 使用ツール |
|---|------|-----------|
| 1 | 東京エレクトロンの融資残高と預金残高を教えてください | Cortex Analyst |
| 2 | 信越化学との過去の商談でウェハ工場増設について話した内容は？ | Cortex Search（商談履歴） |
| 3 | 半導体の設備投資に使える政府の補助金制度は何がありますか？ | Cortex Search（政府資料） |
| 4 | NVIDIAの最新決算でAI半導体の需要についてどのように言及していますか？ | Cortex Search（Earning Call） |
| 5 | ルネサスの財務状況と、活用できそうな政府支援策を教えてください | Analyst + Search（複合） |
| 6 | NVIDIAの決算発言を踏まえて、東京エレクトロンへの提案ポイントは？ | Analyst + Earning Call（複合） |

---

## 🔄 オーケストレーション手順

```
1. ユーザーからの質問を受け取り、質問の意図を分析する

2. 質問の内容に応じて、適切なツールを選択する：
   - 財務データ（融資・預金・顧客情報）に関する質問
     → CORPORATE_SALES_ANALYSIS_SV（Cortex Analyst）を使用
   - 商談履歴・過去のやり取りに関する質問
     → MEETING_NOTES_SEARCH（Cortex Search）を使用
   - 政府の補助金・支援策に関する質問
     → GOVERNMENT_DOCS_SEARCH（Cortex Search）を使用
   - 半導体競合企業の決算・市場動向に関する質問
     → COMPANY_EVENT_TRANSCRIPT_CORTEX_SEARCH_SERVICE（Cortex Search - Marketplace）を使用

3. 複合的な質問の場合は、複数のツールを順次実行し、結果を統合する
   - 例：「NVIDIAの決算を踏まえた東京エレクトロンへの提案」
     → Earning Call検索 + 顧客情報取得 を組み合わせ

4. 取得した情報を整理し、ユーザーにわかりやすい形式で回答を生成する
```

---

## 📋 応答手順

```
1. 質問に対する回答は必ず日本語で行うこと

2. 回答の構成：
   - まず結論を簡潔に述べる
   - 必要に応じて詳細データ（表形式）を提示する
   - 情報の出典（テーブル名/ドキュメント名）を明記する

3. 数値データを含む場合：
   - 単位（百万円など）を明記する
   - 基準日（RECORD_DATE）を明記する

4. 政府資料からの回答の場合：
   - 該当するPDFファイル名とページ番号を引用情報として提示する

5. 情報が見つからない場合：
   - 「該当する情報が見つかりませんでした」と回答する
   - 関連する別の情報があれば提案する
```

---

## 🛠️ ツール一覧

| ツール名 | 種別 | 説明 | オブジェクトパス |
|---------|------|------|-----------------|
| **CORPORATE_SALES_ANALYSIS_SV** | Semantic View | 顧客・融資・預金・営業活動の構造化データ分析 | `CORPORATE_BANKING_DB.ANALYTICS.CORPORATE_SALES_ANALYSIS_SV` |
| **MEETING_NOTES_SEARCH** | Cortex Search | 商談履歴・議事録の検索 | `CORPORATE_BANKING_DB.UNSTRUCTURED_DATA.MEETING_NOTES_SEARCH` |
| **GOVERNMENT_DOCS_SEARCH** | Cortex Search | 政府の半導体支援策PDF検索 | `CORPORATE_BANKING_DB.UNSTRUCTURED_DATA.GOVERNMENT_DOCS_SEARCH` |
| **COMPANY_EVENT_TRANSCRIPT_CORTEX_SEARCH_SERVICE** | Cortex Search (Marketplace) | 米国上場企業の決算発言検索 | `SNOWFLAKE_PUBLIC_DATA_CORTEX_KNOWLEDGE_EXTENSIONS.AI.COMPANY_EVENT_TRANSCRIPT_CORTEX_SEARCH_SERVICE` ※1 |
| **SEND_EMAIL** | Stored Procedure | メール送信 | `CORPORATE_BANKING_DB.AGENT.SEND_EMAIL` |
| **GET_DOCUMENT_DOWNLOAD_URL** | Stored Procedure | ドキュメントダウンロードURL生成 | `CORPORATE_BANKING_DB.AGENT.GET_DOCUMENT_DOWNLOAD_URL` |

> ※1 Marketplaceからの取得時にデータベース名を変更した場合は、パスを適宜修正してください

---

## 📊 ツール詳細

### 1. CORPORATE_SALES_ANALYSIS_SV（Cortex Analyst）

**対象テーブル：**
- CUSTOMER（法人顧客マスタ）
- LOAN（融資情報）
- DEPOSIT（預金残高）
- SALES_ACTIVITY（営業活動履歴）

**回答可能な質問例：**
- 特定企業の融資残高・預金残高
- 業種別の融資残高合計
- 預貸率の計算
- 営業パイプライン状況
- 担当者別の活動件数

### 2. MEETING_NOTES_SEARCH（Cortex Search）

**検索対象：**
- 商談メモ、議事録
- 面談相手、商談内容
- ネクストアクション

**回答可能な質問例：**
- 「○○社との過去の商談内容は？」
- 「ウェハ工場について話した記録は？」
- 「補助金について相談した企業は？」

### 3. GOVERNMENT_DOCS_SEARCH（Cortex Search）

**検索対象：**
- Semiconductor_Strategy_and_Policy.pdf（経産省 半導体政策について）
- SupplyChain__Semiconductors_Govsupport.pdf（サプライチェーン支援策）

**回答可能な質問例：**
- 「半導体の設備投資に使える補助金は？」
- 「ラピダスはどのような支援を受けていますか？」
- 「TSMCの熊本進出の経済効果は？」

### 4. COMPANY_EVENT_TRANSCRIPT_CORTEX_SEARCH_SERVICE（Cortex Search - Marketplace）

**データソース：**
- Snowflake Marketplace: Cortex Knowledge Extensions
- URL: https://app.snowflake.com/marketplace/listing/GZTSZ290BV65X

**検索対象：**
- 米国上場企業の決算説明会（Earning Call）スクリプト
- 四半期決算発表時のCEO/CFOコメント、アナリストQ&A

**活用可能な半導体関連企業：**
- NVIDIA（AI向けGPU、データセンター）
- Intel（設備投資計画、工場建設）
- AMD（データセンター向け半導体）
- ASML（EUV露光装置、中国規制）
- その他米国上場の半導体関連企業

**回答可能な質問例：**
- 「NVIDIAの最新決算でAI需要についてどのように言及していますか？」
- 「Intelの設備投資計画は？オハイオ工場の進捗は？」
- 「ASMLの中国向け輸出規制の影響は？」
- 「AMDのデータセンター事業の見通しは？」

**営業活用シナリオ：**
| シナリオ | 活用方法 |
|---------|---------|
| 市場トレンド把握 | NVIDIA増産計画 → 装置メーカー（東京エレクトロン）への提案タイミング |
| 競合動向共有 | Intel工場投資 → 材料メーカー（信越化学）への情報提供 |
| リスク分析 | ASML中国規制 → 顧客のサプライチェーンリスク把握 |

### 5. SEND_EMAIL（Stored Procedure）

**用途：**
- Agent経由で「この内容を○○にメールで送って」に対応
- 商談サマリーや提案資料の情報を関係者にメール送信
- Agentが分析した結果や検索結果をメールで共有する際に使用

**ツール説明（Agent向け）：**
```
このツールは、Agentが取得・分析した情報をメールで送信します。
商談サマリー、財務分析結果、政府支援策情報などをチームメンバーや関係者に共有する際に使用してください。
```

**パラメータ：**
| パラメータ名 | 型 | 説明 |
|-------------|-----|------|
| RECIPIENT_EMAIL | VARCHAR | 送信先メールアドレス。**メールアドレスが提供されていない場合は、現在のユーザーのメールアドレスに送信します。** |
| SUBJECT | VARCHAR | メール件名。**件名が指定されていない場合は「Snowflake Intelligence」を使用します。** |
| BODY | VARCHAR | メール本文。**HTML構文を使用してください。取得したコンテンツがマークダウン形式の場合は、HTMLに変換してください。本文が提供されていない場合は、最後の質問を要約し、それをメールの本文として使用してください。** |

**回答可能な質問例：**
- 「この商談サマリーを sales@example.com に送って」
- 「東京エレクトロンの財務状況をチームにメールで共有して」
- 「今の分析結果を自分宛にメールして」

### 6. GET_DOCUMENT_DOWNLOAD_URL（Stored Procedure）

**用途：**
- Agent経由で「この資料をダウンロードしたい」に対応
- ステージ内のPDFファイルに対して署名付きダウンロードURLを生成

**ツール説明（Agent向け）：**
```
このツールは、参照ドキュメント用のCortex Searchツール（GOVERNMENT_DOCS_SEARCH）から取得した
relative_pathを使用し、ユーザーがドキュメントを表示・ダウンロードするための一時URLを返します。

返されたURLは、ドキュメントタイトルをテキストとし、このツールの出力をURLとする
HTMLハイパーリンクとして表示する必要があります。
```

**パラメータ：**
| パラメータ名 | 型 | 説明 |
|-------------|-----|------|
| relative_file_path | STRING | **Cortex Searchツール（GOVERNMENT_DOCS_SEARCH）から取得されるrelative_pathの値です。**（例: 'Semiconductor_Strategy_and_Policy.pdf'） |
| expiration_mins | INTEGER | URLの有効期限（分）。**デフォルトは5分にしてください。** |

**対象ファイル：**
- Semiconductor_Strategy_and_Policy.pdf（経産省 半導体政策について）
- SupplyChain__Semiconductors_Govsupport.pdf（サプライチェーン支援策）

**回答可能な質問例：**
- 「半導体政策のPDFをダウンロードしたい」
- 「サプライチェーン支援策の資料のURLを教えて」
- 「先ほど検索した政府資料のダウンロードリンクを出して」

---

## 📁 関連ファイル

| ファイル | 説明 |
|---------|------|
| `01_db_setup.sql` | 環境構築・データ投入SQL |
| `02_sv_setup.sql` | Semantic View設定（GUI参照用） |
| `03_rag_setup.sql` | Cortex Search設定SQL（Marketplace手順含む） |
| `04_ai_functions_demo.sql` | Cortex AI Functions デモ |
| `05_sproc_setup.sql` | Stored Procedure（メール送信、URL生成） |
| `resources/99_Intelligence_setup.sql` | Snowflake Intelligence公開設定 |

---

## 🔧 Snowflake Intelligenceへのエージェント公開

GUIでエージェントを作成した後、Snowflake Intelligenceインターフェースに公開するには `resources/99_Intelligence_setup.sql` を実行してください。

詳細は [Snowflake公式ドキュメント](https://docs.snowflake.com/en/user-guide/snowflake-cortex/snowflake-intelligence) を参照。
