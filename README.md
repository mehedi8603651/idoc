# iDoc

This repo now has two parts:

- [example.idoc.html](/d:/idoc/example.idoc.html): generated browser runtime sample
- [idoc](/d:/idoc/idoc): Flutter Windows authoring app

## Workflow

1. Run the Flutter app on Windows.
2. Create or edit your document there.
3. Export a standalone `.idoc.html` file.
4. Open that exported file directly in a browser.

The HTML file is the reader/runtime only. The editing system now lives in Flutter.

## Open The Sample

Double-click [example.idoc.html](/d:/idoc/example.idoc.html) in Explorer, or serve the repo root locally:

```powershell
cd D:\idoc
python -m http.server 8000
```

Then open `http://localhost:8000/example.idoc.html`.

## Run The Editor

```powershell
cd D:\idoc\idoc
flutter run -d windows
```

## Bundled Demo

The bundled sample document source is:

- [demo_document.json](/d:/idoc/idoc/assets/demo_document.json)

The regenerated browser sample is:

- [example.idoc.html](/d:/idoc/example.idoc.html)

The current demo covers:

- inline math inside normal text
- popup and link actions
- self-contained image export
- question/reveal/export runtime behavior

## What The Flutter App Does

- visual page and block editing
- metadata and action editing
- raw JSON fallback editor
- open existing `.json` or `.idoc.html`
- save `.json`
- export standalone `.idoc.html`

## Notes

- Current focus is Windows desktop authoring.
- The exported runtime still supports navigation, search, theme switching, popups, questions, and JSON export.
