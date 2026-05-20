# XRD-analyzer

Browser app for viewing XRD data and thermal history together (Anton Paar, Rigaku, etc.).

**日本語:** [README.ja.md](README.ja.md)

**Current version:** [`xrd_analyzer_db_TH_v4.html`](xrd_analyzer_db_TH_v4.html)  
Older builds (v1–v3, `FORLAURA`, …) are in [`old-version/`](old-version/).

## How to run

### Easiest (open the HTML file directly)

1. Double-click `xrd_analyzer_db_TH_v4.html` in Finder  
   - Or drag the file into **Chrome**, **Safari**, or **Edge**  
2. When the app opens, use **Load Files** as usual  

For RAS and plain text formats only, this is often enough.

### When using HDF5 (recommended)

For `.hdf5` import and reliable charts, use a local server:

```bash
cd /path/to/XRD-analyzer
python3 -m http.server 8765
```

Open in your browser: `http://localhost:8765/xrd_analyzer_db_TH_v4.html`

### If something goes wrong

- Blank page → reopen via the **local server** above  
- Use a **normal browser**, not an embedded IDE preview  

## Supported files

| Format | Example |
|--------|---------|
| HDF5 | `.hdf5` (NeXus / Anton Paar) |
| RAS | `.ras` (Rigaku SmartLab) |
| Other | `.scn`, `.xrdml` |

## Basic workflow

### 1. Load data

- **Load Files** (top bar), **+ Load** (sidebar), or drag-and-drop  
- HDF5 provides **measurement start/end times**  
- **Temperature** defaults from the filename (e.g. `80.0C`, `-40.0C`); edit under **Thermal / segments → T (°C)** if needed  

### 2. Create a thermal Series

1. **Thermal History** → **Edit series**  
2. Check samples in **measurement order** (top = first) → **Apply**  
   - Or **Series from all** to add all samples at once  
3. **Mode → Series**, then pick the series in the dropdown  
4. X-axis units: **date** / **sec** / **min** / **hour**  

### 3. XRD patterns

- **XRD Pattern** shows all samples, or **Data source → Active series** for series members only  
- Adjust axes, legend, and colors in the panel  

### 4. Combine (overlay multiple patterns)

1. In **Combine**, click **+ From series** (or **+ New** and link a **Series**)  
2. Choose the active **Combine** from the dropdown  
3. XRD traces appear in series member order (edit legend, color, offsets in the list below)  

You can create **multiple Combines** (e.g. one per temperature profile).

### 5. Save

| Action | What it does |
|--------|----------------|
| **Save Project** | Save samples, series, combines, axis settings, etc. to the built-in DB |
| **Export JSON** | Export the project to a JSON file |
| **Import JSON** | Restore from JSON |
| Left sidebar | Cached files and thermal series in the DB |

## Troubleshooting

- **Empty thermal chart** → Series selected? Start/end times and T set on each sample?  
- **Empty combine** → Combine created and **Series** linked?  
- **No graphs** → Try the local server; check sample visibility (eye icon)  

## License

Use and modify according to the repository owner’s terms.
