# IndexedDB Structure (`xrd_analyzer_db_th`)

Current app reference: `xrd_analyzer_v16.html` (v15 = last version before the feature DB)  
Database name: `xrd_analyzer_db_th`  
Version: `5`

## Object Stores

### 1) `files`
- Key: `id` (autoIncrement)
- Used for cached raw file payloads + UI metadata for DB list/tree

Main fields:
- `id: number`
- `name: string`  
  File name used as primary identity in many merge/skip checks.
- `rawText: string`
  - Plain text payload for `.ras`, `.scn`, `.xrdml`, `.dat`
  - `__HDF5_BASE64__...` for cached HDF5 binary
  - `__PROJECT_SAMPLE_JSON__...` for project-derived sample cache
- `rowCount: number`
- `folderPath: string`
- `sampleLabel: string` (optional)
- `tags: string[]`
- `instrument: string` (optional, `''` = unset) — 装置, e.g. `Rigaku SmartLab`, `Anton Paar`, `ALBA Rayonix (WAXD)`
- `site: string` (optional, `''` = unset) — 測定地, e.g. `FU`, `UB CCiTUB`, `ALBA`
- `lambdaA: number | null` (optional, Å) — X-ray wavelength. Auto-filled from the file when present
  (ALBA .dat poni header, in metres → Å); editable in the file-meta modal. Drives d / q display and Scherrer.
- `tempC: number | null` (optional)
- `capillarySize: number | null` (optional, mm)
- `measurementTimeMin: number | null` (optional, minutes)
- `savedAt: string` (ISO datetime; auto-set on `saveFile`)

Notes:
- `saveFile()` always overwrites `savedAt` with current timestamp.
- Duplicate checks are often name-based (`name`).
- `instrument` is auto-filled at import from the parsed file (`.ras` → `Rigaku SmartLab`;
  HDF5 → NeXus `instrument/name`, canonicalised to `Anton Paar`). `.scn`/`.xrdml` carry no
  instrument, so they import as `''`. `site` has no in-file source and is always entered by hand
  (file meta modal, trace row, or **Bulk edit basket**).
- Both are free text. `normalizeInstrument()` / `normalizeSite()` snap known spellings onto the
  presets (`INSTRUMENT_PRESETS`, `SITE_PRESETS`) so `rigaku smartlab` and `Rigaku SmartLab` do not
  become two separate filter entries; unknown names pass through unchanged.
- Records cached before these fields existed (`instrument === undefined`) are stamped once by
  `backfillInstrumentField()` on DB load, guessing from the file extension; `site` stays blank.

### 2) `projects`
- Key: `id` (autoIncrement)
- Saved project snapshots

Main fields:
- `id: number`
- `name: string`
- `folderPath: string`
- `tags: string[]`
- `payload: object` (`serializeProject()` output)
- `savedAt: string` (ISO datetime; auto-set on `saveProject`)

`payload` schema (high level):
- Global UI/chart state (`layout`, `xrdMode`, `timeUnit`, ...)
- `thermalSeriesList`, `activeThermalSeriesId`
- `combineList`, `activeCombineId`
- XRD/outer chart settings
- `samples[]` full runtime sample records

### 3) `thermalSeries`
- Key: `id` (autoIncrement)
- Persisted thermal series presets

Main fields:
- `id: number`
- `name: string`
- `folderPath: string`
- `memberUids: string[]`
- `savedAt: string` (ISO datetime; auto-set on `saveThermalSeries`)

### 4) `appState`
- Key: `key` (string)
- Small key/value store for app-level state that must survive in IndexedDB.

Main fields:
- `key: string`
- `value: any`

Current keys:
- `autoBackupDir` — `FileSystemDirectoryHandle` for the auto-backup folder (Chrome/Edge).

### 5) `xrdFeatures`
- Key: `id` (autoIncrement)
- Feature DB (v16+): one row per extracted peak or amorphous halo. Cross-measurement search layer,
  the XRD analogue of DSC's `thermal_events`. Not embedded in project payload.
- Indexes: `sampleName`, `sampleUid`, `phase`, `peakType`, `two_theta` (`two_theta_deg`).

Main fields:
- Linkage: `id`, `fileName`, `sampleUid` (stable key), `sampleName`, `tempC` (denormalized).
- `peakType`: `'bragg'` | `'halo'`.
- Position/intensity: `two_theta_deg`, `d_nm`, `intensity_cps` (net height above baseline),
  `area_cps_deg`, `rel_intensity` (null in Phase 1).
- Width/size: `fwhm_deg`, `fwhm_corrected_deg`, `crystallite_nm` (Scherrer `D = Kλ/(β·cosθ)`),
  `K`, `lambda_A`, `instrumental_fwhm_deg`.
- Tags: `hkl` (manual), `phase`.
- Provenance: `fitModel` (`'pseudo-voigt'`), `fitParams` `{amp,center,fwhm,eta,r2}`,
  `baselinePoints:[{x,y},{x,y}]`, `fit_xMin`, `fit_xMax`, `method`, `computedAt`, `appVersion`.

Extraction: pseudo-Voigt fit (Nelder–Mead, fixed 2-point edge baseline) over a 2θ window set by
click-on-chart or numeric inputs. FWHM = fit Γ; instrumental broadening subtracted as
`β=√(B_obs²−B_inst²)` when an instrumental FWHM is entered.

## Auto-backup to a local folder (`autoBackup`)

Chrome/Edge only (File System Access API). Lets the cache survive a browser-cache wipe.

- "Backup" button (next to DB Export/Import) calls `window.showDirectoryPicker` and stores the
  `FileSystemDirectoryHandle` in `appState.autoBackupDir`.
- On every DB mutation (`refreshDbPanels`) a debounced write pushes the full DB snapshot to the folder:
  - `xrd_th_db_latest.json` — always overwritten with the current snapshot.
  - `xrd_th_db_<YYYYMMDD>.json` — one rolling snapshot per day.
- Snapshot payload is identical to `exportFullDb` (`buildDbExportPayload`), so the files restore via **DB Import**.
- Empty-DB snapshots are skipped so an accidental `Clear` cannot overwrite good backups with an empty file.
- The handle lives in IndexedDB; if the cache is wiped the handle is lost too, but the on-disk backups
  remain — the user re-links the folder once (button shows `Backup: reconnect` when permission lapses).

## Related JSON Export/Import

## Full DB export (`exportFullDb`)
Structure:
- `version: 3` (was 2 before the feature DB)
- `app: 'xrd_th'` — app discriminator (DSC dumps use `'dsc'`)
- `exportedAt: string`
- `files: files[]`
- `projects: projects[]`
- `thermalSeriesPresets: thermalSeries[]`
- `xrdFeatures: xrdFeatures[]` (v16+)

## Full DB import (`importFullDb`)
- Rejects a dump whose `app` is present and not `'xrd_th'` (avoids cross-app corruption); dumps without `app` are still accepted (legacy)
- Supports **replace** or **merge**
- Merge skip rules:
  - `files`: skip if same `name`
  - `projects`: skip if same `name` and `savedAt`
  - `thermalSeries`: skip if same `name` and `savedAt`
  - `xrdFeatures`: skip if same `featureDedupKey` = `sampleUid|peakType|two_theta_deg|computedAt`

## Project JSON (`serializeProject`)
- Separate from full DB dump
- On project load, missing file-cache records can be synthesized into `files` using:
  - `buildProjectCacheRecordFromSample()`
  - Encoded payload marker: `__PROJECT_SAMPLE_JSON__`

## Payload Markers in `files.rawText`

- `__HDF5_BASE64__...`
  - Base64-encoded HDF5 bytes
  - Decoded and parsed via `parseHDF5`
- `__PROJECT_SAMPLE_JSON__...`
  - Base64-encoded JSON sample object
  - Used to backfill DB cache from project payload
- Otherwise:
  - treated as plain text input for `parseAny`

## DB Tree UI Metadata (from `files`)

The DB cache tree can group by:
- `sample` -> `sampleLabel`
- `capillary` -> `capillarySize`
- `measTime` -> `measurementTimeMin`
- `date` -> `savedAt` (YYYY-MM-DD key)
- `temp` -> `tempC` (fallback from filename parse)
- `instrument` -> `instrument` (unset → `Unknown instrument`)
- `site` -> `site` (unset → `Unknown site`)

## DB File Filter (`dbFileFilter`)

- `text` — matches `name`, `sampleLabel`, `instrument`, `site`
- `tags`, `tempMin`, `tempMax`
- `instrument`, `site` — dropdowns built from `INSTRUMENT_PRESETS`/`SITE_PRESETS` plus every value
  present in the cache; the `(unset)` entry (`DB_FILTER_NONE`) selects records with the field empty
- `sort`

`instrument` / `site` are also available as legend parts (`LEGEND_FORMAT_OPTIONS`).

## Supported input formats (`parseAny`)

| Ext | Parser | Notes |
|-----|--------|-------|
| `.ras` | `parseRas` | Rigaku SmartLab, full metadata |
| `.scn` | `parseSCN` | generic 2-col text (x = 2θ) |
| `.xrdml` | `parseXRDML` | PANalytical XML |
| `.hdf5` / `.h5` | `parseHDF5` | NeXus / Anton Paar (h5wasm) |
| `.dat` | `parseDat` | pyFAI 1D → `parseAlbaDat`; else generic 2-col |
| `.alba` | `parseAlbaExpEnv` | ALBA ExpEnv temperature log (not a pattern) |

### ALBA BL11 NCD (pyFAI `.dat`)

- pyFAI 1D integration output, `#`-commented header whose top block is the **poni JSON**
  (`wavelength` in metres, `detector`). Data columns are `q(nm^-1)  I  [sigma]`.
- **x is q, not 2θ.** `parseAlbaDat` converts to 2θ with the header λ via
  `sinθ = q·λ/(4π)` and stores 2θ internally (uniform with lab data). Original q is
  recovered losslessly for display by the `q` axis mode. Detector →
  `instrument` (`ALBA Rayonix (WAXD)` / `ALBA Pilatus (SAXD)`), `site` = `ALBA`,
  `meta.albaQ = true`, `lambdaA` from header.
- Non-pyFAI `.dat` falls back to `parseGeneric2Col` (x treated as 2θ).

### ALBA ExpEnv (`.alba`)

- Tab-separated per-frame log (one file per temperature ramp), header legend line lists
  columns incl. filename columns (`pilatus`/`rayonix`, values are `*.edf`), a Linkam
  temperature column (`linkamt95_t`), and `uxtimer`.
- `parseAlbaExpEnv` → `{ frameBasename: {tempC, timeIso} }`, keyed by `albaBaseName()`
  (dir/ext/` (1)` stripped). `uxtimer` is only used as a timestamp when it looks like a
  Unix epoch (`> 1e9`); small relative values are ignored.
- Loading a `.alba` creates **no sample/record** — it populates `albaExpEnvMap` and
  `applyAlbaExpEnv()` stamps `tempC`/`measurementStartIso` onto matching `.dat` records
  (cached + loaded), by frame basename. Works regardless of load order (the `.dat` save
  path also consults the map; `finishRasBatch` re-stamps once the batch is saved).

## X-axis display modes (`xFromTwoThetaDeg`)

`2theta` (stored) · `d` (nm) · `nm-1` (**1/d**) · `q` (**4π·sinθ/λ**, pyFAI/synchrotron
convention — differs from `nm-1` by 2π). All non-2θ modes need `lambdaA`. In `d`/`nm-1`/`q`
a blank Patterns X window auto-scales instead of clamping to the 2θ default 2–32°.

