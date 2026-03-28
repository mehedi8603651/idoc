# iDoc Studio

`iDoc Studio` is the Windows authoring app for iDoc documents.

The current architecture is:

- Flutter = desktop shell
- WebView = embedded editor host
- Tiptap = continuous page writing surface
- `IdocDocument` JSON = canonical document model
- `.idoc.html` = exported standalone reader/runtime

## Current Goal

The app is optimized for this workflow:

1. Open or create an iDoc document in Flutter.
2. Edit page body content in the embedded Tiptap editor.
3. Edit metadata, block settings, behaviors, and raw JSON in Flutter.
4. Save as `.json`.
5. Export as standalone `.idoc.html`.

## Run

```powershell
cd D:\idoc\idoc
flutter pub get
flutter run -d windows
```

## Build The Embedded Editor

The WebView editor is built from the local `editor/` app and bundled into Flutter assets.

Source:

- [editor/index.html](D:\idoc\idoc\editor\index.html)
- [editor/src/main.jsx](D:\idoc\idoc\editor\src\main.jsx)
- [editor/src/App.jsx](D:\idoc\idoc\editor\src\App.jsx)
- [editor/src/editor.css](D:\idoc\idoc\editor\src\editor.css)

Bundled output:

- [assets/editor/index.html](D:\idoc\idoc\assets\editor\index.html)

Rebuild it after changing anything under `editor/`:

```powershell
cd D:\idoc\idoc\editor
npm install
npm run build
```

Then run Flutter again:

```powershell
cd D:\idoc\idoc
flutter run -d windows
```

## Architecture

### 1. Canonical document model

These files are the source of truth for the saved iDoc format:

- [idoc_document.dart](D:\idoc\idoc\lib\idoc_document.dart)
- [idoc_exporter.dart](D:\idoc\idoc\lib\idoc_exporter.dart)

Responsibilities:

- parse and normalize document JSON
- create blank/default documents and blocks
- keep the iDoc schema stable
- export a standalone `.idoc.html`

### 2. Flutter shell

Main Flutter entry and shell:

- [main.dart](D:\idoc\idoc\lib\main.dart)
- [idoc_studio_app.dart](D:\idoc\idoc\lib\idoc_studio_app.dart)
- [idoc_studio_ui.dart](D:\idoc\idoc\lib\idoc_studio_ui.dart)
- [idoc_studio_logic.dart](D:\idoc\idoc\lib\idoc_studio_logic.dart)
- [idoc_studio_widgets.dart](D:\idoc\idoc\lib\idoc_studio_widgets.dart)

Responsibilities:

- page rail and page management
- ribbon and command bar
- inspector panels
- open/save/export/reset
- raw JSON editing
- behavior editing for button/link and other structured blocks

### 3. Web editor bridge

WebView host and bridge:

- [idoc_studio_web_editor.dart](D:\idoc\idoc\lib\idoc_studio_web_editor.dart)

Responsibilities:

- initialize `webview_windows`
- load bundled editor HTML from assets
- send commands from Flutter to the web editor
- receive editor updates back into Flutter
- rebuild the editor when page/body state changes

### 4. Tiptap document adapter

Adapter layer:

- [idoc_tiptap_adapter.dart](D:\idoc\idoc\lib\idoc_tiptap_adapter.dart)

Responsibilities:

- convert `IdocPage.elements` to Tiptap JSON
- convert Tiptap JSON back to iDoc elements
- preserve special blocks as iDoc-owned structured elements
- keep export schema unchanged

### 5. Browser runtime

Reader/runtime assets:

- [assets/idoc_runtime_template.html](D:\idoc\idoc\assets\idoc_runtime_template.html)
- [assets/demo_document.json](D:\idoc\idoc\assets\demo_document.json)

Responsibilities:

- power the exported `.idoc.html`
- render pages, toolbar, search, theme, popup/actions, math, quiz logic

## How It Works

### Edit flow

1. Flutter loads the canonical `IdocDocument`.
2. The current page body is converted into Tiptap JSON by [idoc_tiptap_adapter.dart](D:\idoc\idoc\lib\idoc_tiptap_adapter.dart).
3. Flutter sends that body to the WebView editor.
4. Tiptap edits the page as a continuous writing surface.
5. The web editor sends debounced page-body updates back to Flutter.
6. Flutter converts that Tiptap JSON back into `IdocPage.elements`.
7. Flutter remains the owner of metadata, actions, page structure, export, and raw JSON.

### Ownership rule

This is the most important rule in the project:

- Flutter owns canonical document state.
- Tiptap owns the live writing experience.
- Export always comes from the Flutter `IdocDocument`, not from raw editor HTML.

## Important Structure

Key project files and folders:

- [lib/main.dart](D:\idoc\idoc\lib\main.dart): app entrypoint
- [lib/idoc_studio_app.dart](D:\idoc\idoc\lib\idoc_studio_app.dart): shell state, startup, asset loading
- [lib/idoc_studio_ui.dart](D:\idoc\idoc\lib\idoc_studio_ui.dart): Flutter UI layout
- [lib/idoc_studio_logic.dart](D:\idoc\idoc\lib\idoc_studio_logic.dart): document mutations and commands
- [lib/idoc_studio_web_editor.dart](D:\idoc\idoc\lib\idoc_studio_web_editor.dart): WebView bridge
- [lib/idoc_studio_widgets.dart](D:\idoc\idoc\lib\idoc_studio_widgets.dart): shared Flutter widgets
- [lib/idoc_tiptap_adapter.dart](D:\idoc\idoc\lib\idoc_tiptap_adapter.dart): iDoc <-> Tiptap mapping
- [lib/idoc_document.dart](D:\idoc\idoc\lib\idoc_document.dart): schema and document helpers
- [lib/idoc_exporter.dart](D:\idoc\idoc\lib\idoc_exporter.dart): runtime HTML export
- [editor/](D:\idoc\idoc\editor): source for embedded web editor
- [assets/editor/index.html](D:\idoc\idoc\assets\editor\index.html): built single-file editor asset
- [assets/idoc_runtime_template.html](D:\idoc\idoc\assets\idoc_runtime_template.html): exported reader template
- [test/widget_test.dart](D:\idoc\idoc\test\widget_test.dart): basic document normalization tests

Folders that are generated or not primary editing targets:

- `build/`
- `.dart_tool/`
- `windows/flutter/generated_*`
- `linux/flutter/generated_*`

## Where To Update Next

Use this as the maintenance map.

### If you want to change page writing behavior

Update:

- [editor/src/App.jsx](D:\idoc\idoc\editor\src\App.jsx)
- [editor/src/editor.css](D:\idoc\idoc\editor\src\editor.css)
- [lib/idoc_studio_web_editor.dart](D:\idoc\idoc\lib\idoc_studio_web_editor.dart)
- [lib/idoc_tiptap_adapter.dart](D:\idoc\idoc\lib\idoc_tiptap_adapter.dart)

Examples:

- slash menu behavior
- text editing UX
- selection handling
- embedded block rendering in the editor
- text style commands

### If you want to add a new block type

Update:

- [lib/idoc_document.dart](D:\idoc\idoc\lib\idoc_document.dart)
- [lib/idoc_tiptap_adapter.dart](D:\idoc\idoc\lib\idoc_tiptap_adapter.dart)
- [editor/src/App.jsx](D:\idoc\idoc\editor\src\App.jsx)
- [lib/idoc_studio_ui.dart](D:\idoc\idoc\lib\idoc_studio_ui.dart)
- [assets/idoc_runtime_template.html](D:\idoc\idoc\assets\idoc_runtime_template.html)

Examples:

- new default block shape
- adapter mapping to/from Tiptap
- inspector editor for the block
- runtime rendering/export support

### If you want to change inspector or ribbon behavior

Update:

- [lib/idoc_studio_ui.dart](D:\idoc\idoc\lib\idoc_studio_ui.dart)
- [lib/idoc_studio_logic.dart](D:\idoc\idoc\lib\idoc_studio_logic.dart)

Examples:

- add a new ribbon action
- change block settings UI
- change page actions
- update raw JSON tools

### If you want to change export/runtime behavior

Update:

- [lib/idoc_exporter.dart](D:\idoc\idoc\lib\idoc_exporter.dart)
- [assets/idoc_runtime_template.html](D:\idoc\idoc\assets\idoc_runtime_template.html)

Examples:

- reader toolbar
- runtime search/theme behavior
- page layout in exported HTML
- popup/action handling

### If you want to change parsing/default document behavior

Update:

- [lib/idoc_document.dart](D:\idoc\idoc\lib\idoc_document.dart)
- [test/widget_test.dart](D:\idoc\idoc\test\widget_test.dart)

Examples:

- blank document defaults
- default page structure
- normalization rules
- action defaults

## Bridge Messages

Current Flutter -> Web commands are handled in [idoc_studio_web_editor.dart](D:\idoc\idoc\lib\idoc_studio_web_editor.dart) and [App.jsx](D:\idoc\idoc\editor\src\App.jsx):

- `loadPageBody`
- `replacePageBody`
- `focusEditor`
- `applyTextStyle`
- `insertBlock`
- `setTheme`
- `selectElement`

Current Web -> Flutter messages:

- `editorReady`
- `pageBodyChanged`
- `selectionChanged`
- `requestInsertBlock`

If the editor and Flutter shell get out of sync, this bridge is the first place to inspect.

## Validation

Run Flutter validation:

```powershell
cd D:\idoc\idoc
flutter analyze
flutter test
```

Run editor build validation:

```powershell
cd D:\idoc\idoc\editor
npm run build
```

## Current Limitations

- Windows is the real target for authoring right now.
- The web editor is bundled locally; there is no server dependency.
- Flutter does not own the live text editing experience anymore; it owns document structure and export.
- Special blocks are still primarily configured in Flutter inspector panels, not fully edited inline in Tiptap.

## Recommended Next Work

High-value next areas:

- improve the Tiptap slash menu and block insertion UX
- add richer inline formatting support in the web editor
- improve embedded block placeholders inside the editor
- expand adapter tests for round-trip safety
- add more runtime/export tests around special blocks and actions
- reduce Windows-only assumptions if you later want cross-platform authoring
