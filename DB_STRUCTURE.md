# IndexedDB Structure (`xrd_analyzer_db_th`)

Current app reference: `xrd_analyzer_db_TH_v15.html`  
Database name: `xrd_analyzer_db_th`  
Version: `4`

## Object Stores

### 1) `files`
- Key: `id` (autoIncrement)
- Used for cached raw file payloads + UI metadata for DB list/tree

Main fields:
- `id: number`
- `name: string`  
  File name used as primary identity in many merge/skip checks.
- `rawText: string`
  - Plain text payload for `.ras`, `.scn`, `.xrdml`
  - `__HDF5_BASE64__...` for cached HDF5 binary
  - `__PROJECT_SAMPLE_JSON__...` for project-derived sample cache
- `rowCount: number`
- `folderPath: string`
- `sampleLabel: string` (optional)
- `tempC: number | null` (optional)
- `capillarySize: number | null` (optional, mm)
- `measurementTimeMin: number | null` (optional, minutes)
- `savedAt: string` (ISO datetime; auto-set on `saveFile`)

Notes:
- `saveFile()` always overwrites `savedAt` with current timestamp.
- Duplicate checks are often name-based (`name`).

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
- `version: 2`
- `app: 'xrd_th'` — app discriminator (DSC dumps use `'dsc'`)
- `exportedAt: string`
- `files: files[]`
- `projects: projects[]`
- `thermalSeriesPresets: thermalSeries[]`

## Full DB import (`importFullDb`)
- Rejects a dump whose `app` is present and not `'xrd_th'` (avoids cross-app corruption); dumps without `app` are still accepted (legacy)
- Supports **replace** or **merge**
- Merge skip rules:
  - `files`: skip if same `name`
  - `projects`: skip if same `name` and `savedAt`
  - `thermalSeries`: skip if same `name` and `savedAt`

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

