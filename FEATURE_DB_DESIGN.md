# XRD 特徴量DB 設計メモ

> **目的**: XRD測定パターンからピーク特徴量（角度・強度・半値幅・結晶サイズ・相タグ）と
> 非晶質ハローを抽出し、専用ストアに格納して測定横断の検索・絞り込み・温度依存プロットにつなげる。
> **背景**: DSC の `ANALYSIS_DESIGN.md`（生波形層 / 特徴量層の二層構造）の XRD 版。
> **現状**: v15 (`xrd_analyzer_v15.html`) は可視化・DB整理のみ。信号処理（平滑化・ベースライン・
> ピークフィット）はゼロ ＝ DSC v3 と同じ出発点。

---

## 確定した設計判断

| 論点 | 決定 |
|---|---|
| ピーク幅/位置の測定 | **擬フォークト（pseudo-Voigt）フィット主体**。2θ・FWHM・積分強度を同時に高精度取得（XRD標準）。窓とベースラインはドラッグ調整。半値幅の直接読み取りはフォールバック。 |
| ミラー指数 hkl | **手動入力のみ**（まず）。全自動の格子決定は単一HTMLで非現実的。参照ピークリスト照合は後続フェーズの任意機能。 |
| 装置広がり補正 | **任意入力**。装置由来FWHM(deg)を入力欄で受け、Gaussは β=√(B_obs²−B_inst²)、Lorentzは β=B_obs−B_inst。標準試料(Si/LaB6等)があれば設定、無ければ0（=生FWHM）。補正前後を両方保存。 |
| 特徴量の保存先 | **専用 `xrd_features` ストア**（横断検索向き。project payload には埋めない）。 |
| 紐づけキー | `sampleUid`（DB往復で安定なUUID）。`sampleName`/`tempC` は非正規化。 |
| ハロー | 同じ抽出器を広い窓で使い `peakType='halo'` として中心2θ・高さを保存。 |

---

## 既存スキーマの前提（v15 で判明した事実）

- DB: `xrd_analyzer_db_th` **v4**。ストア: `files`（生キャッシュ）/ `projects` / `thermalSeries` / `appState`。
- 各 sample: `{ tth[°], intensity[cps], sampleUid, name, peakPos(=argmaxのみ), tempC/tempSetPoint,
  scanRate, meta:{ lambda[Å], … } }`。
- **λ は `meta.lambda`（Å）**。`.ras`/`.hdf5` は実測、`.xrdml` は既定 1.5406Å。Scherrer/d換算に使用。
- d換算は実装済み: `d[nm] = λ[Å] / (20·sinθ)`（θ=2θ/2）、X軸モード 2theta/d/nm⁻¹ 切替あり。
- チャート基盤: Patterns タブの combine チャート（Chart.js）。zoom/offset ハンドル基盤あり。

---

## 保存設計: `xrd_features` ストア（DB v4 → v5）

生波形とは別ストア。1測定パターンあたり 0..N 行、**1行＝1ピーク（またはハロー）**。

```javascript
xrd_features (keyPath: id, autoIncrement)
  index: sampleName        // 横断検索の主キー
  index: phase             // 結晶相タグ
  index: peakType          // 'bragg' | 'halo'
  index: two_theta
```

レコード形状:

```javascript
{
  id, fileName, sampleUid,          // 生データ層への紐づけ
  sampleName, tempC,                // 非正規化（横断検索・温度依存プロット）
  peakType,                         // 'bragg'（結晶ピーク）| 'halo'（非晶質ハロー）

  // 位置・強度
  two_theta_deg, d_nm,              // ピーク角・面間隔（λから導出）
  intensity_cps, area_cps_deg,      // 高さ・積分強度
  rel_intensity,                    // パターン内最強ピーク=100 の相対強度

  // 幅・結晶サイズ
  fwhm_deg,                         // 半値幅（観測、フィット由来）
  fwhm_corrected_deg,               // 装置広がり補正後
  crystallite_nm,                   // シェラー径 D = Kλ / (β·cosθ)
  K, lambda_A, instrumental_fwhm_deg,  // シェラー・パラメータ（再現用）

  // タグ
  hkl, phase,                       // ミラー指数（手動）・結晶相

  // 再現・監査
  fitModel,                         // 'pseudo-voigt'|'gaussian'|'lorentzian'|'half-max'
  fitParams,                        // {amp, center, fwhm, eta, ...} 復元用
  baselinePoints:[{x,y},{x,y}], fit_xMin, fit_xMax,
  method,                           // 'auto'|'manual-adjusted'
  computedAt, appVersion
}
```

DBダンプ（`exportFullDb` version 2 → 3）に `xrdFeatures:[]` を追加。`app:'xrd_th'` 判別は維持。
project は参照のみで軽量維持。

---

## 抽出アルゴリズム

### ピーク（bragg）
1. 対象パターンから (2θ, I) を表示。
2. **ピーク自動サジェスト**: prominence 閾値の卓越極大を検出 → 主ピークをサジェスト。or クリックで指定。
3. **2点直線ベースライン**を自動サジェスト（ピーク裾の平坦部）→ ドラッグ微調整。
4. **擬フォークトフィット**: `I(2θ) = bg(2θ) + A·[η·L + (1−η)·G]`、
   L=ローレンツ, G=ガウス, 中心 μ, 半値幅 Γ 共通, 混合 η∈[0,1]。
   非線形最小二乗（Levenberg–Marquardt 相当の軽量実装 or Nelder–Mead）で窓内フィット。
   出力: 中心 `two_theta_deg`=μ、`fwhm_deg`=Γ、`intensity_cps`=A、`area_cps_deg`=解析積分。
5. **Scherrer**: β[rad] = 補正FWHM×π/180、`crystallite_nm = K·λ[nm] / (β·cos θ)`（θ=μ/2）。
   K 既定 0.9。装置補正: Gauss近似 √(B_obs²−B_inst²)（既定）。補正前後を両方保存。
6. `d_nm` は μ から Bragg で導出。`rel_intensity` はパターン内最強ピーク基準。

### ハロー（amorphous）
広い窓で単一の擬フォークト（or ガウス）フィット → 中心2θ・高さ・（FWHM）を `peakType='halo'` で保存。
Scherrer は非適用（結晶サイズ欄は空）。

### タグ
`hkl`（手動テキスト, 例 "111"）、`phase`（結晶相, 例 "α-quartz"）。相はインデックス化し横断フィルタに使用。

---

## UI（新タブ「特徴量DB」, DSC を踏襲）

### 1) 解析ワークベンチ
パターン選択 → チャート表示 → 種別（ピーク/ハロー）選択 → 区間・ベースライン自動サジェスト →
チャート上クリック/ドラッグ or 数値で微調整 → 2θ/d/FWHM/D/強度 ライブ表示 →
hkl・相を入力 → 保存で `xrd_features` に1行＋マーカー＆フィット曲線を重畳。
既存 combine チャートの zoom/offset ハンドル基盤に載せる。

### 2) 特徴量DB表
全ピークを横断表示。フィルタ（種別 / Sample部分一致 / 相 / 2θ範囲）、並べ替え
（測定日・2θ・D・強度・Sample）、種別で表示分岐、行削除、CSV出力（BOM付き）。

### 3) 温度依存プロット（目玉）
プロット ON で「tempC × 選択量（2θ / D / 強度 / FWHM）」の散布図（Sample/相 別に系列化）。
in-situ 加熱XRD で **結晶成長（D↑）・熱膨張（2θシフト）・結晶化/相転移** を可視化。
DSC の校正ドリフト散布図に相当。tempC は sample の温度メタから結合。

---

## 段階リリース

- **Phase 1 ✅ 完了**（`xrd_analyzer_v16.html`）: スキーマ v4→v5 + `xrd_features` ストア + ピーク抽出
  ワークベンチ（擬フォークトフィット＝Nelder–Mead・自動サジェスト＋チャートクリック＋2θ数値窓・
  2点エッジベースライン・Scherrer任意装置補正）。保存＝1行＋フィット曲線/ベースライン/頂点・FWHM
  マーカーのオーバーレイ。特徴量DB表（Sample/種別/2θ/d/FWHM/強度/D/T/hkl/相・削除）、CSV出力（BOM付き）。
  DBダンプ export/import に `xrdFeatures` 追加（version 2→3、`featureDedupKey` でマージskip）。
  - **ドラッグ微調整**（DSC Phase2相当を前倒し）: ベースライン端点(●)をチャート上で直接ドラッグ可能。
    横=フィット窓の端、縦=ベースライン高さを1操作で調整→離すと自動再フィット（`featOnDragDown/Move/Up`、
    14pxヒットテスト、rAFスロットル）。手動オーバーライド中は端点がシアン表示（`featManualBase`）、
    窓変更/Auto-suggest/Clear/別Sample選択で自動ベースラインへ復帰。
  - 検証: 合成擬フォークト（既知 μ=28.44/Γ=0.22/η=0.6）で **μ完全一致・FWHM 0.14–0.18%誤差・
    Scherrer D/d-spacing/装置√補正が手計算と一致**（Nodeヘッドレス）。実機ブラウザで
    parse相当の合成sample→fit(R²=0.9996)→保存→IndexedDB往復→一覧→削除→DB export(v3) 全通し、
    コンソールエラーなし、オーバーレイ描画確認。ドラッグは合成mouseイベントで端点移動→窓29.4→29.9・
    手動ベースライン有効化・自動再フィットを確認、シアン端点をスクリーンショットで確認。
- **Phase 2**: ハロー抽出、rel_intensity、hkl/相タグ入力、種別フィルタ。
- **Phase 3**: 特徴量DB表（横断検索・フィルタ・並べ替え・削除・CSV）。
- **Phase 4**: 温度依存散布図（D/2θ/強度/FWHM × tempC）。
- **Phase 5**（任意）: 解析結果の版管理（DSC Phase5 相当）、参照ピークリスト照合による hkl/相 自動割当。

---

## 検証方針（各Phase）
- 合成擬フォークト（既知 μ/Γ/A）でフィット往復 → 中心・FWHM・面積が既知値に一致。
- Scherrer: 既知 FWHM・λ・θ で手計算値と一致、装置補正の √差 を確認。
- 実データ: parse → 抽出 → `xrd_features` 保存往復 → 表示 → オーバーレイ、コンソールエラーなし。
</content>
</invoke>
