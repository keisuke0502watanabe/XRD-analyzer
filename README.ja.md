# XRD-analyzer

Anton Paar / Rigaku / ALBA などの XRD データと熱履歴をまとめて見るブラウザアプリです。
HTML 1 ファイル完結（ビルド不要・インストール不要）。

**English:** [README.md](README.md)

**現行版:** [`xrd_analyzer_v20.html`](xrd_analyzer_v20.html)
旧版は [`old-version/`](old-version/)、設計メモは [`docs/`](docs/) にあります。

## 起動方法

### 推奨 — localhost ランチャ

| OS | ダブルクリックするファイル |
|----|--------------------------|
| macOS | `launchers_mac/XRD-localhost.command` |
| Windows | `launchers_win/XRD-localhost.bat` |
| Linux | `launchers_mac/XRD-localhost.sh`（`bash launchers_mac/XRD-localhost.sh`） |

いずれも**リポジトリ直下**を `python3 -m http.server 8753` で配信し、
`http://localhost:8753/xrd_analyzer_v20.html` を開きます。

**`file://` で開かないこと。** 読み込んだファイルとプロジェクトは IndexedDB に入りますが、
`file://` のページはディスク逼迫時にブラウザからキャッシュごと破棄されることがあります
（`.hdf5` の読み込みにも正規のオリジンが必要）。理由とデータ保全の手順は
[`docs/HOW-TO-OPEN.md`](docs/HOW-TO-OPEN.md) に詳しく書いてあります。

### 手動で同じことをする場合

```bash
python3 -m http.server 8753
```

ブラウザで `http://localhost:8753/xrd_analyzer_v20.html` を開く。

### うまくいかないとき

- 画面が真っ白 → 上のランチャ／ローカルサーバー経由で開き直す
- Cursor などのプレビューではなく、**通常のブラウザ**（Chrome / Edge / Safari）で開く
- 取り込み後にデータが足りない → **DB & Projects → DB audit**。バックアップ JSON にあって
  現 DB にないレコードを一覧できます

## 対応ファイル

| 形式 | 例 |
|------|-----|
| HDF5 | `.hdf5`, `.h5`（NeXus / Anton Paar） |
| RAS | `.ras`（Rigaku SmartLab） |
| pyFAI / ALBA | `.dat`, `.alba`（温度ログの ExpEnv テキストも可） |
| その他 | `.scn`, `.xrdml`, `.txt` |

## タブ構成

| タブ | 役割 |
|------|------|
| **DB & Projects** | キャッシュ済みファイル、ツリー／フィルタ、メタ情報、プロジェクト、DB の取込・監査・バックアップ |
| **Thermal History** | サンプル別／シリーズ別の温度‑時間、I(θ)‑時間 |
| **Patterns** | 作図の中心。バスケット → パターンツリー → 重ね書き／段積みチャート → PNG/PDF |
| **Samples** | 1 ファイル 1 行。オフセット、ゲイン、時刻、温度の手動上書き |
| **Feature DB** | 擬フォークトでピークフィット → 2θ / FWHM / 積分強度 / 結晶子径（Scherrer）をピーク単位で保存 |

## 基本的な使い方

### 1. データを読み込む

- 上部の **Load Files**、またはドラッグ＆ドロップ（フォルダごとでも可）
- HDF5 からは **測定開始・終了時刻**、ALBA の ExpEnv ログからは温度が入る
- それ以外の **温度** はファイル名（例 `80.0C`, `-40.0C`）から自動。**Samples** タブで修正可
- 取り込み時に **dataset name**（`連番_サンプル_温度_日付_ファイル名`）が付くので、
  ファイル名が同じだけの別測定が 1 レコードに潰れることはありません

### 2. パターンを作る

1. **Patterns → + Root** でパターンを作り、**Basket** で使うトレースにチェック（シリーズ横断可）
2. **+ Child (narrow)** で現在のパターンを複製して絞り込み（パターンはツリー構造）
3. パターンごとにチャート設定（モード・オフセット・軸範囲・ラベル）を個別に保持

### 3. チャートの操作

- **Mode**: Overlay / Stack。Offset% と Gain% は全体一律か、トレース個別か選択
- **X mode**: `2theta (deg)` / `d (nm)` / `nm^-1` / `q (nm^-1)` — q は各ファイルの波長を使用
- **X scale / Y scale**: Linear / **Log** — q が SAXD〜WAXD にまたがるときや、強度が桁で
  変わるときは対数（対数軸では非正の点は除外されます）
- **Export displayed chart**: PNG / PDF

### 4. 熱履歴

1. **Thermal History → Edit series** で測定順にチェック → **Apply**
2. **Mode → Series** でシリーズを選択。横軸は date / sec / min / hour
3. **I(θ)** モードは指定 2θ の強度を時間に対してプロット

### 5. ピーク特徴量

**Feature DB** でサンプルを選び、ピーク近くをクリック（または **Auto-suggest**）→ **Fit** → **Save**。
擬フォークトで 2θ・FWHM・積分強度・d・Scherrer 径（装置広がり補正は任意入力）を算出。
保存済みレコードは絞り込み表示と CSV 出力ができます。

### 6. 保存

| 操作 | 内容 |
|------|------|
| **Save Project** | サンプル・シリーズ・パターン・チャート設定を DB に保存 |
| **Export JSON** | プロジェクトを JSON ファイルに出力 |
| **Import JSON** | JSON から復元 |
| **Choose backup folder** | 変更のたびに日付つき JSON を自動保存（Chrome / Edge） |

## ドキュメント

- [`docs/HOW-TO-OPEN.md`](docs/HOW-TO-OPEN.md) — localhost と `file://` の違い、データ保全
- [`docs/DB_STRUCTURE.md`](docs/DB_STRUCTURE.md) — IndexedDB のストアとフィールド
- [`docs/FEATURE_DB_DESIGN.md`](docs/FEATURE_DB_DESIGN.md) — 特徴量 DB の設計メモ

## ライセンス

MIT License — [LICENSE](LICENSE) を参照してください。
