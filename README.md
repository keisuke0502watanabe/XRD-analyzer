# XRD-analyzer

[![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.21812182.svg)](https://doi.org/10.5281/zenodo.21812182)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

Browser app for viewing XRD data and thermal history together (Anton Paar, Rigaku, ALBA, etc.).
Single self-contained HTML file — no build step, no install.

**日本語:** [README.ja.md](README.ja.md)

**Current version:** [`xrd_analyzer_v20.html`](xrd_analyzer_v20.html)
Older builds are in [`old-version/`](old-version/); design notes are in [`docs/`](docs/).

## How to run

### Recommended — the localhost launcher

| OS | File to double-click |
|----|----------------------|
| macOS | `launchers_mac/XRD-localhost.command` |
| Windows | `launchers_win/XRD-localhost.bat` |
| Linux | `launchers_mac/XRD-localhost.sh` (`bash launchers_mac/XRD-localhost.sh`) |

Each one serves the **repo root** with `python3 -m http.server 8753` and opens
`http://localhost:8753/xrd_analyzer_v20.html`.

**Use this, not `file://`.** The app keeps your cached files and projects in IndexedDB; on a
`file://` page the browser may evict that store under disk pressure, and `.hdf5` import needs a
real origin. See [`docs/HOW-TO-OPEN.md`](docs/HOW-TO-OPEN.md) for the full reasoning and for the
data-safety checklist (auto-backup folder, JSON export).

### Manual equivalent

```bash
python3 -m http.server 8753
```

Then open `http://localhost:8753/xrd_analyzer_v20.html`.

### If something goes wrong

- Blank page → reopen through the launcher / local server above
- Use a **normal browser** (Chrome, Edge, Safari), not an embedded IDE preview
- Data missing after an import → **DB & Projects → DB audit**, which lists what a backup JSON
  holds that the current DB does not

## Supported files

| Format | Example |
|--------|---------|
| HDF5 | `.hdf5`, `.h5` (NeXus / Anton Paar) |
| RAS | `.ras` (Rigaku SmartLab) |
| pyFAI / ALBA | `.dat`, `.alba` (+ ExpEnv text for the temperature log) |
| Other | `.scn`, `.xrdml`, `.txt` |

## Tabs

| Tab | What it is for |
|-----|----------------|
| **DB & Projects** | Cached files, tree/filters, file metadata, projects, DB import / audit / backup |
| **Thermal History** | Temperature vs time per sample or per series; I(θ) vs time |
| **Patterns** | The plotting workspace — basket → pattern tree → overlay/stack chart → PNG/PDF |
| **Samples** | One row per loaded file: offsets, gains, times, temperature overrides |
| **Feature DB** | Pseudo-Voigt peak fitting → 2θ / FWHM / integrated intensity / Scherrer size, saved per peak |

## Basic workflow

### 1. Load data

- **Load Files** in the top bar, or drag-and-drop files (a whole folder works too)
- HDF5 supplies **measurement start/end times**; ALBA ExpEnv logs supply the temperature
- **Temperature** otherwise comes from the filename (e.g. `80.0C`, `-40.0C`) and is editable
  per sample in **Samples**
- Every import gets a **dataset name** `<seq>_<sample>_<temp>_<date>_<filename>` so two files
  that merely share a filename stay separate records

### 2. Build a pattern

1. **Patterns → + Root** creates a pattern, then tick traces in the **Basket** (works across series)
2. **+ Child (narrow)** copies the active pattern so you can narrow it further — patterns form a tree
3. Each pattern keeps its own chart settings (mode, offsets, axis ranges, labels)

### 3. Chart controls

- **Mode**: Overlay or Stack; Offset% / Gain% either equal for all traces or per trace
- **X mode**: `2theta (deg)` / `d (nm)` / `nm^-1` / `q (nm^-1)` — q uses each file's own wavelength
- **X scale / Y scale**: Linear or **Log** (log is what you want when q spans SAXD→WAXD, or for
  intensities covering decades; non-positive points are dropped)
- **Export displayed chart**: PNG / PDF

### 4. Thermal history

1. **Thermal History → Edit series**, check samples in measurement order → **Apply**
2. **Mode → Series** and pick the series; X axis in date / sec / min / hour
3. **I(θ)** mode plots the intensity at a chosen 2θ against time

### 5. Peak features

**Feature DB** → pick a sample, click near a peak (or **Auto-suggest**), **Fit** → **Save**.
Pseudo-Voigt gives 2θ, FWHM, integrated intensity, d and Scherrer size (with optional
instrumental FWHM correction). Saved rows are filterable and exportable as CSV.

### 6. Save

| Action | What it does |
|--------|----------------|
| **Save Project** | Save samples, series, patterns and chart settings into the built-in DB |
| **Export JSON** | Export the project to a JSON file |
| **Import JSON** | Restore from JSON |
| **Choose backup folder** | Auto-save a dated JSON dump on every change (Chrome / Edge) |

## Docs

- [`docs/HOW-TO-OPEN.md`](docs/HOW-TO-OPEN.md) — localhost vs `file://`, data safety
- [`docs/DB_STRUCTURE.md`](docs/DB_STRUCTURE.md) — IndexedDB stores and fields
- [`docs/FEATURE_DB_DESIGN.md`](docs/FEATURE_DB_DESIGN.md) — peak-feature DB design notes

## License

MIT License — see [LICENSE](LICENSE).
