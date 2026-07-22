# XRD Analyzer — 開き方とデータ保全

アクティブ版: **`xrd_analyzer_v18.html`**

このアプリのDB（測定キャッシュ・プロジェクト・特徴量）は、開いているブラウザの
**IndexedDB** に保存されます。**オリジン（file:// か http://localhost か）ごとに別のDB**
になります。各自が自分のDBを持ち、共有はしません。

---

## 開き方は2通り

### A. localhost で開く（推奨・データが消えにくい）

`file://` はブラウザがストレージを「best-effort」扱いにするため、ディスク逼迫時などに
DBを自動退避（削除）することがあります。`http://localhost` は正規オリジンなので退避されにくい。

- **macOS**: `XRD-localhost.command` をダブルクリック
- **Windows**: `XRD-localhost.bat` をダブルクリック（要 Python3 / インストール時「Add to PATH」）
- **Linux**: `bash XRD-localhost.sh`
- 手動でも同じ: フォルダで `python3 -m http.server 8753` を実行 →
  ブラウザで `http://localhost:8753/xrd_analyzer_v18.html`

> ⚠️ 一度 A を使い始めたら**常に A で開く**。間違えて file:// で開くと別オリジンの空DBに
> 見えます（データは消えていない。localhost側に無いだけ）。

### B. file:// で開く（従来どおり・手軽）

HTML をダブルクリックするだけ。**使えます**が、退避リスクが残るので**バックアップ必須**。
起動時に出る「Back up your database?」で毎回フォルダを選んでください。

---

## データ保全（両モード共通・重要）

- **auto-backup**: DBタブの「Backup」または起動時モーダルでフォルダを選ぶと、変更のたびに
  日付き JSON（`xrd_th_db_YYYYMMDD.json` と `xrd_th_db_latest.json`）が自動保存されます。
  権限はセッションごとに再付与が必要 → 起動時モーダルで毎回通すのを習慣に。
- **手動**: 「DB Export」でいつでも JSON に保存できます。
- **File System Access API は Chrome / Edge のみ**。Safari/Firefox では自動バックアップ不可
  → その場合は手動「DB Export」で保存。

## 復元

- 「DB Import」でバックアップ JSON を選ぶ → **常にマージ（非破壊）**。既存を消さず不足分だけ追加。
  重複は自動除外なので、複数ファイルを順に取り込んでOK。
- **巨大DB（数百MB超）**は、ブラウザの文字列長上限で一括インポートに失敗することがあります。
  その場合はファイルを分割してから順に Import してください（分割チャンク例: `dbBackup/restore_chunks/`）。
