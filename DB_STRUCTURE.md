# IndexedDB Structure (`xrd_analyzer_db_th`)

Current app reference: `xrd_analyzer_db_TH_v5.html`  
Database name: `xrd_analyzer_db_th`  
Version: `3`

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

## Related JSON Export/Import

## Full DB export (`exportFullDb`)
Structure:
- `version: 2`
- `exportedAt: string`
- `files: files[]`
- `projects: projects[]`
- `thermalSeriesPresets: thermalSeries[]`

## Full DB import (`importFullDb`)
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

