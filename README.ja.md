# XRD-analyzer

Anton Paar / Rigaku などの XRD データと熱履歴をまとめて見るブラウザアプリです。

**English:** [README.md](README.md)

**現行版:** [`xrd_analyzer_db_TH_v4.html`](xrd_analyzer_db_TH_v4.html)  
旧版（v1–v3、`FORLAURA` など）は [`old-version/`](old-version/) にあります。

## 起動方法

### いちばん簡単（HTML をそのまま開く）

1. Finder で `xrd_analyzer_db_TH_v4.html` をダブルクリック  
   - またはファイルを **Chrome / Safari / Edge** のウィンドウにドラッグ＆ドロップ  
2. ブラウザでアプリが開けば、そのまま **Load Files** で使える  

RAS やテキスト形式だけなら、これで十分なことが多いです。

### HDF5 も使うとき（推奨）

`.hdf5` を読む・グラフを安定させるには、ローカルサーバー経由が確実です。

```bash
cd /path/to/XRD-analyzer
python3 -m http.server 8765
```

ブラウザで次を開く: `http://localhost:8765/xrd_analyzer_db_TH_v4.html`

### うまくいかないとき

- 画面が真っ白 → 上の **ローカルサーバー** で開き直す  
- Cursor のプレビューではなく、**通常のブラウザ** で開く  

## 対応ファイル

| 形式 | 例 |
|------|-----|
| HDF5 | `.hdf5`（NeXus / Anton Paar） |
| RAS | `.ras`（Rigaku SmartLab） |
| その他 | `.scn`, `.xrdml` |

## 基本的な使い方

### 1. データを読み込む

- 画面上部の **Load Files**、または左の **+ Load**、ドラッグ＆ドロップ  
- HDF5 から **測定開始・終了時刻** が入る  
- **温度** はファイル名（例 `80.0C`, `-40.0C`）から自動。必要なら各サンプルの **Thermal / segments → T (°C)** で変更  

### 2. 熱履歴用の Series を作る

1. **Thermal History** → **Edit series**  
2. 使うサンプルにチェック（**上から測定順**）→ **Apply**  
   - または **Series from all** で一括登録  
3. **Mode → Series**、ドロップダウンで Series を選択  
4. 横軸は **date** / **sec** / **min** / **hour** で切替  

### 3. XRD パターンを見る

- **XRD Pattern** で全サンプル、または **Data source → Active series** で Series 内だけ表示  
- 軸・凡例・色はパネル上で調整  

### 4. Combine（複数パターン重ね合わせ）

1. **Combine** で **+ From series**（または **+ New** して **Series** を紐づけ）  
2. **Combine** のドロップダウンで表示する Combine を選ぶ  
3. 紐づいた Series のメンバー順に XRD が重なる（凡例・色・オフセットは下のリストで編集）  

複数の Combine を作れます（温度プロファイルごとなど）。

### 5. 保存

| 操作 | 内容 |
|------|------|
| **Save Project** | サンプル・Series・Combine・軸設定など一式を DB に保存 |
| **Export JSON** | プロジェクトを JSON ファイルに出力 |
| **Import JSON** | JSON から復元 |
| 左サイドバー | 個別ファイル・Series の DB キャッシュ |

## よくあること

- **熱履歴が空** → Series を選んだか、各サンプルに時刻と T が入っているか確認  
- **Combine が空** → Combine を作成し、**Series** をリンクしたか確認  
- **グラフが出ない** → ローカルサーバーで開き直す、サンプルの表示（目アイコン）を確認  

## ライセンス・連絡

リポジトリ内の利用・改変はプロジェクトオーナーに従ってください。
