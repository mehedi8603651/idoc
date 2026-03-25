# iDoc Studio

`iDoc Studio` is the Flutter Windows editor for iDoc documents.

The app is now the primary authoring tool. It edits the iDoc JSON model and exports standalone `.idoc.html` runtime files.

## Run

```powershell
cd D:\idoc\idoc
flutter pub get
flutter run -d windows
```

## Current Scope

- Windows desktop authoring
- visual page/block editor
- action editor
- raw JSON fallback editor
- open `.json` and exported `.idoc.html`
- save `.json`
- export standalone `.idoc.html`

## Assets

- [demo_document.json](/d:/idoc/idoc/assets/demo_document.json): bundled demo content
- [idoc_runtime_template.html](/d:/idoc/idoc/assets/idoc_runtime_template.html): exported browser runtime template

## Validation

```powershell
flutter analyze
flutter test
```
