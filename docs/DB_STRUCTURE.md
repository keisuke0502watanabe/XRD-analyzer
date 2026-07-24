# IndexedDB Structure (`xrd_analyzer_db_th`)

Current app reference: `xrd_analyzer_v19.html` (v18 = last version before the dataset-name identity)  
Database name: `xrd_analyzer_db_th`  
Version: `5`

## Object Stores

### 1) `files`
- Key: `id` (autoIncrement)
- Used for cached raw file payloads + UI metadata for DB list/tree

Main fields:
- `id: number`
- `name: string`  
  **Original file name — never rewritten.** The parsers, .ras/.dat header regeneration,
  ALBA frame/ExpEnv matching and the external re-integration scripts all key off it.
- `datasetName: string` (v19+)  
  Import-time display identity, `<seq>_<sample>_<temp>_<date>_<filename>`, e.g.
  `0007_PLA-A_120C_20260715_rayonix_iso_002_0000.dat`. Empty parts are dropped rather than
  left as `__` gaps. Shown in the DB list/tree, searchable in the text filter, available as
  a legend part and a tree grouping field. Composed by `buildDatasetName()`.
- `datasetSeq: number` (v19+) — 4-digit running number, allocated from `appState.datasetSeq`.
  Unique on its own, so two files that merely share a filename can never collapse into one
  row. Never re-issued: a record keeps its sequence across metadata edits.
- `datasetNameLocked: boolean` (v19+) — `true` when the user typed the name by hand in the
  file-meta modal. Every regeneration pass (bulk edit, backfill) skips those rows.
- `measurementKey: string` (v19+, pyFAI `.dat` only) — `<scan folder>/<frame base>`, the
  detector frame this pattern came from, independent of how it was integrated. Taken from
  `# source: RAW/…/frame.edf` (re-integration output) or from the `# --> …` path with a
  trailing `LaVue1D`-style output segment dropped (beamline output). `''` for lab formats.
- `processingKey: string` (v19+) — `quickHash` of the calibration header lines
  (`poni:` / `Distance` / `PONI:` / `Rotations:` / `Detector` / `Wavelength:` /
  `Mask applied:` / `Polarization factor:` / `Normalization factor:`). Same frame + same
  `processingKey` = the same .dat twice; same frame + different key = a re-integration.
- `supersededBy: number | null` (v19+) — id of the newer integration that replaced this
  record. Set automatically, never deletes anything; superseded rows are hidden from the DB
  list until **Superseded** is ticked in the filter row.
- `supersededAt: string | null` (v19+, ISO datetime)
- `contentHash: string | null` — cyrb53 hash of `rawText` (`quickHash`). Together with `name`
  it forms `fileIdentityKey()`, the merge/dedup identity. HDF5 payloads fall back to the name
  alone. Legacy rows are hashed on the fly and stamped by `backfillDatasetNames()`.
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
- `saveFile()` always overwrites `savedAt` with the current timestamp;
  `saveFileKeepDate()` keeps the record's own `savedAt` and is what the one-off backfills use,
  so stamping a new field onto every legacy row does not reset the whole cache's dates.
- **Three tiers of identity** — only tier 1 ever drops incoming data:

  | tier | key | meaning | action |
  |---|---|---|---|
  | 1 | `name` + `contentHash` (`fileIdentityKey`) | byte-identical file | skip |
  | 2 | `measurementKey` equal, content different | same frame, re-integrated | import, and mark the older record `supersededBy` |
  | 3 | `name` equal only | same frame index from another scan | keep both; listed under *Name collisions* |

- **Duplicate checks are `name` + `contentHash` (`fileIdentityKey`), never the name alone.**
  Up to v18 the DB Import merge matched on `name` only, so an incoming record whose filename
  already existed here was skipped even when its data differed — that is how records went
  missing. Use **DB audit** to list what a backup dump holds that this DB does not.
- `folderPath` comes from the pyFAI `.dat` header (`# --> …`) when present; otherwise, when a
  whole folder is dropped, from the File's `webkitRelativePath` directory (v19+).
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
- `datasetSeq` — high-water mark of `files.datasetSeq`, so a sequence number is never reused
  after records are deleted.

### 5) `xrdFeatures`
- Key: `id` (autoIncrement)
- Feature DB (v16+): one row per extracted peak or amorphous halo. Cross-measurement search layer,
  the XRD analogue of DSC's `thermal_events`. Not embedded in project payload.
- Indexes: `sampleName`, `sampleUid`, `phase`, `peakType`, `two_theta` (`two_theta_deg`).

Main fields:
- Linkage: `id`, `fileName`, `fileDbId` (v19+), `processingKey` (v19+), `sampleUid`,
  `sampleName`, `tempC` (denormalized). `fileName` alone is ambiguous — delete a file and
  re-upload the same name and its old peaks would re-attach to the new data — so v19+ rows
  pin to a DB record by `fileDbId` and record which integration they were fitted on.
  Pre-v19 rows have neither and fall back to `fileName`.
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
- `version: 4` (3 before the dataset-name fields, 2 before the feature DB). Older dumps import
  fine — the missing `datasetName` / `datasetSeq` / `contentHash` are filled in on merge.
- `app: 'xrd_th'` — app discriminator (DSC dumps use `'dsc'`)
- `exportedAt: string`
- `files: files[]`
- `projects: projects[]`
- `thermalSeriesPresets: thermalSeries[]`
- `xrdFeatures: xrdFeatures[]` (v16+)

## Full DB import (`importFullDb`)
- Rejects a dump whose `app` is present and not `'xrd_th'` (avoids cross-app corruption); dumps without `app` are still accepted (legacy)
- Supports **replace** or **merge**
- Reports `+N added · N identical (skipped) · N kept separately despite a shared filename`
  so a silent drop cannot go unnoticed
- Merge skip rules:
  - `files`: skip only if same `fileIdentityKey` = `name` + `contentHash` (HDF5: `name` alone).
    An incoming record whose `datasetName` is already taken here is re-numbered instead of
    being dropped.
  - `projects`: skip if same `name` and `savedAt`
  - `thermalSeries`: skip if same `name` and `savedAt`
  - `xrdFeatures`: skip if same `featureDedupKey` = `sampleUid|peakType|two_theta_deg|computedAt`

## Backup audit (`runDbAudit`, v19+)

**DB audit** button next to *Find dupes*. Reads one or more `xrd_th_db_*.json` backups and
lists every file record they hold that is not in the current DB, matched by `fileIdentityKey`.
Read-only — nothing is written; re-import the dump with v19+ to bring the records back.
Exists because merges before v19 dropped same-named records silently.

## Bulk delete (`deleteDbBulkSelected`, v19+)

**Delete from DB…** in the bulk edit modal removes every file in the basket (or in the
post-upload target list). Built for re-uploading a batch whose integration was wrong.
Confirms twice: the file list, then — when peaks were extracted from those files — whether
to delete the linked feature rows as well. Also clears the basket, drops the loaded samples
and their traces, and re-reads the DB to verify the rows are gone.

## Duplicate finder (`openDupFinder`)

Two sections:
- **Duplicates** — same `name` AND identical `rawText`. Oldest copy kept, extras deletable.
- **Name collisions** — same `name` but different content. Separate measurements, listed for
  information only and never deleted; each row links to its file-meta editor.

## Project JSON (`serializeProject`)
- Separate from full DB dump
- `ensureProjectSamplesCached()` treats "same filename AND same point count" as already
  cached (a project sample is a reconstruction, so its `__PROJECT_SAMPLE_JSON__` payload never
  matches the original file text)
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
- `dataset` -> `datasetName`
- `sample` -> `sampleLabel`
- `capillary` -> `capillarySize`
- `measTime` -> `measurementTimeMin`
- `date` -> `savedAt` (YYYY-MM-DD key)
- `temp` -> `tempC` (fallback from filename parse)
- `instrument` -> `instrument` (unset → `Unknown instrument`)
- `site` -> `site` (unset → `Unknown site`)

## DB File Filter (`dbFileFilter`)

- `text` — matches `name`, `datasetName`, `sampleLabel`, `instrument`, `site`, `folderPath`
- `showSuperseded` — off by default; rows with `supersededBy != null` are hidden until ticked
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

