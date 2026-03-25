# iDoc Prototype

`example.idoc.html` is a self-contained interactive document prototype.

## Run It

No build step is required.

### Option 1: Open the file directly

1. Open `example.idoc.html` in a modern browser.
2. If file associations are set up, you can double-click it in Explorer.
3. You can also drag the file into an existing browser window.

This is the intended default for the prototype.

### Option 2: Serve it locally

Use this if your browser applies stricter `file://` rules, or if you want more predictable localStorage behavior.

PowerShell with Python:

```powershell
cd D:\idoc
python -m http.server 8000
```

Then open:

```text
http://localhost:8000/example.idoc.html
```

## Requirements

- Modern browser
- Internet access for KaTeX and Google Fonts CDNs

If the KaTeX CDN is unavailable, the document still works and shows math as plain text fallback.

## What You Can Do

- Read the embedded 3-page demo document
- Navigate pages
- Search and highlight matches
- Toggle theme
- Open popups
- Answer the quiz block
- Enter edit mode and modify the JSON
- Save a draft to localStorage
- Import JSON
- Export JSON

## Notes

- Recommended filename: `example.idoc.html`
- The original task asked for a single HTML deliverable only, so there was no `README.md` initially.
