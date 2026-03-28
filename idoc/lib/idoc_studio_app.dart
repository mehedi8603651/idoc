import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_windows/webview_windows.dart';

import 'idoc_document.dart';
import 'idoc_exporter.dart';
import 'idoc_tiptap_adapter.dart';

part 'idoc_studio_ui.dart';
part 'idoc_studio_logic.dart';
part 'idoc_studio_web_editor.dart';
part 'idoc_studio_widgets.dart';

enum RibbonTab { home, insert }

class IdocStudioApp extends StatelessWidget {
  const IdocStudioApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'iDoc Studio',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0F766E),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF3EFE7),
        fontFamily: 'Segoe UI',
      ),
      home: const IdocStudioHome(),
    );
  }
}

class IdocStudioHome extends StatefulWidget {
  const IdocStudioHome({super.key});

  @override
  State<IdocStudioHome> createState() => _IdocStudioHomeState();
}

class _IdocStudioHomeState extends State<IdocStudioHome> {
  static const List<String> _simpleBehaviorTypes = <String>[
    'popup',
    'gotoPage',
    'openLink',
    'toggleTheme',
    'alert',
    'showAnswer',
    'saveDocument',
    'exportDocument',
  ];
  static const List<BlockWidthOption> _blockWidthOptions = <BlockWidthOption>[
    BlockWidthOption(1, 'Full'),
    BlockWidthOption(0.75, 'Wide'),
    BlockWidthOption(2 / 3, '2/3'),
    BlockWidthOption(0.5, 'Half'),
    BlockWidthOption(1 / 3, '1/3'),
  ];

  late IdocDocument _document;
  late IdocDocument _demoDocument;
  String _runtimeTemplate = '';
  bool _loading = true;
  int _selectedPageIndex = 0;
  String? _selectedElementId;
  String _selectedTextStyle = 'paragraph';
  RibbonTab _activeRibbonTab = RibbonTab.home;
  String _status = 'Loading assets...';
  Map<String, dynamic>? _copiedElement;
  Map<String, dynamic>? _copiedAction;
  int? _moveTargetPageIndex;
  final WebviewController _webviewController = WebviewController();
  StreamSubscription<dynamic>? _webMessageSubscription;
  final List<Map<String, dynamic>> _pendingWebCommands =
      <Map<String, dynamic>>[];
  bool _webEditorReady = false;
  String? _webEditorLoadedPageId;
  String? _webEditorError;

  @override
  void initState() {
    super.initState();
    _loadAssets();
  }

  @override
  void dispose() {
    _webMessageSubscription?.cancel();
    _webviewController.dispose();
    super.dispose();
  }

  Future<void> _loadAssets() async {
    try {
      final results = await Future.wait<String>(<Future<String>>[
        rootBundle.loadString('assets/idoc_runtime_template.html'),
        rootBundle.loadString('assets/demo_document.json'),
        rootBundle.loadString('assets/editor/index.html'),
      ]);
      final demoDocument = IdocDocument.fromJson(
        extractDocumentJsonFromContent(results[1]),
      );
      _normalizeDocumentForEditor(demoDocument);
      final webViewVersion = await WebviewController.getWebViewVersion();
      if (webViewVersion == null) {
        throw const FormatException(
          'Microsoft Edge WebView2 Runtime is not installed on this machine.',
        );
      }
      await _webviewController.initialize();
      _webMessageSubscription = _webviewController.webMessage.listen(
        _handleWebEditorMessage,
        onError: (Object error) {
          if (mounted) {
            setState(() {
              _webEditorError = 'Web editor bridge error: $error';
            });
          }
        },
      );
      await _webviewController.setBackgroundColor(Colors.transparent);
      await _webviewController.loadStringContent(results[2]);
      setState(() {
        _runtimeTemplate = results[0];
        _demoDocument = demoDocument.deepCopy();
        _document = demoDocument.deepCopy();
        _selectedPageIndex = 0;
        _selectedElementId = null;
        _selectedTextStyle = 'paragraph';
        _moveTargetPageIndex = 0;
        _status =
            'Ready. Click inside the page editor and start writing. Use Insert for interactive and media blocks, then export a standalone .idoc.html runtime.';
        _loading = false;
      });
      _rebuildPageDocumentSession();
    } catch (error) {
      setState(() {
        _status = 'Failed to load bundled assets: $error';
        _webEditorError = '$error';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(_status, textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: <Widget>[
            _buildCommandBar(context),
            Expanded(
              child: Row(
                children: <Widget>[
                  SizedBox(width: 270, child: _buildPageRail(context)),
                  const VerticalDivider(width: 1),
                  Expanded(child: _buildEditorCanvas(context)),
                  const VerticalDivider(width: 1),
                  SizedBox(width: 340, child: _buildInspector(context)),
                ],
              ),
            ),
            _buildStatusBar(),
          ],
        ),
      ),
    );
  }
}
