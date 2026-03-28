// ignore_for_file: invalid_use_of_protected_member, unused_element

part of 'idoc_studio_app.dart';

extension _IdocStudioWebEditor on _IdocStudioHomeState {
  Widget _buildContinuousPageEditorCanvas(BuildContext context) {
    if (_webEditorError != null && !_webviewController.value.isInitialized) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Icon(Icons.error_outline, size: 40, color: Color(0xFFD97706)),
                const SizedBox(height: 12),
                Text(
                  'The embedded editor could not start.',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  _webEditorError!,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (!_webviewController.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    return Container(
      color: const Color(0xFFF7F2E8),
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 980),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: const Color(0xFFE2D8C6)),
              boxShadow: const <BoxShadow>[
                BoxShadow(
                  color: Color(0x12000000),
                  blurRadius: 24,
                  offset: Offset(0, 12),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: <Widget>[
                Positioned.fill(
                  child: Webview(
                    _webviewController,
                  ),
                ),
                if (!_webEditorReady)
                  const Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(color: Color(0xE8FFFDF8)),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _sendWebEditorCommand(
    String type, {
    Map<String, dynamic>? payload,
    bool replaceQueuedBody = false,
  }) async {
    final message = <String, dynamic>{
      'type': type,
      ...?payload == null ? null : <String, dynamic>{'payload': payload},
    };

    if (!_webEditorReady || !_webviewController.value.isInitialized) {
      if (replaceQueuedBody && (type == 'loadPageBody' || type == 'replacePageBody')) {
        _pendingWebCommands.removeWhere(
          (queued) =>
              queued['type'] == 'loadPageBody' ||
              queued['type'] == 'replacePageBody',
        );
      }
      _pendingWebCommands.add(message);
      return;
    }

    await _webviewController.postWebMessage(jsonEncode(message));
  }

  Future<void> _flushPendingWebCommands() async {
    if (!_webEditorReady || !_webviewController.value.isInitialized) {
      return;
    }
    while (_pendingWebCommands.isNotEmpty) {
      final next = _pendingWebCommands.removeAt(0);
      await _webviewController.postWebMessage(jsonEncode(next));
    }
  }

  Map<String, dynamic> _buildCurrentPageBodyDoc() {
    return buildTiptapPageDocument(_currentPage);
  }

  void _handleWebEditorMessage(dynamic rawMessage) {
    Map<String, dynamic>? message;
    if (rawMessage is String) {
      try {
        final decoded = jsonDecode(rawMessage);
        if (decoded is Map) {
          message = decoded.map(
            (dynamic key, dynamic value) =>
                MapEntry<String, dynamic>(key.toString(), value),
          );
        }
      } catch (_) {
        return;
      }
    } else if (rawMessage is Map) {
      message = rawMessage.map(
        (dynamic key, dynamic value) =>
            MapEntry<String, dynamic>(key.toString(), value),
      );
    }

    if (message == null) {
      return;
    }
    final type = _textValue(message['type']);
    final payload = message['payload'] is Map
        ? (message['payload'] as Map).map(
            (dynamic key, dynamic value) =>
                MapEntry<String, dynamic>(key.toString(), value),
          )
        : <String, dynamic>{};

    switch (type) {
      case 'editorReady':
        setState(() {
          _webEditorReady = true;
          _webEditorError = null;
        });
        _flushPendingWebCommands();
        _rebuildPageDocumentSession();
        break;
      case 'pageBodyChanged':
        _applyWebEditorPageBody(payload);
        break;
      case 'selectionChanged':
        final nextSelectedId = _textValue(payload['selectedElementId']);
        final normalizedSelectedId =
            nextSelectedId.isEmpty ? null : nextSelectedId;
        final nextTextStyle = _textValue(
          payload['textStyle'],
          fallback: 'paragraph',
        );
        if (_selectedElementId != normalizedSelectedId ||
            _selectedTextStyle != nextTextStyle) {
          setState(() {
            _selectedElementId = normalizedSelectedId;
            _selectedTextStyle = nextTextStyle;
            _moveTargetPageIndex = _selectedPageIndex;
          });
        }
        break;
      case 'requestInsertBlock':
        final elementType = _textValue(payload['elementType']);
        if (elementType.isNotEmpty) {
          _insertBlockAfterSelection(elementType);
        }
        break;
      default:
        break;
    }
  }

  void _applyWebEditorPageBody(Map<String, dynamic> payload) {
    final pageId = _textValue(payload['pageId']);
    final doc = payload['doc'] is Map
        ? (payload['doc'] as Map).map(
            (dynamic key, dynamic value) =>
                MapEntry<String, dynamic>(key.toString(), value),
          )
        : <String, dynamic>{};
    if (pageId.isEmpty || doc.isEmpty) {
      return;
    }
    final pageIndex = _document.pages.indexWhere((IdocPage page) => page.id == pageId);
    if (pageIndex == -1) {
      return;
    }
    final page = _document.pages[pageIndex];
    final nextElements = buildIdocElementsFromTiptapDocument(
      doc: doc,
      page: page,
    );
    setState(() {
      page.elements = nextElements;
      _ensurePageHasBodyParagraph(page);
      if (_selectedElementId != null &&
          !page.elements.any(
            (Map<String, dynamic> element) =>
                _blockId(element) == _selectedElementId,
          ) &&
          page.id == _currentPage.id) {
        _selectedElementId = null;
      }
    });
  }

  void _rebuildPageDocumentSession({
    String? preferredElementId,
    bool selectElement = false,
    bool requestFocus = false,
  }) {
    if (!mounted || _loading) {
      return;
    }

    final selectedId = preferredElementId ?? _selectedElementId;
    final isPageSwitch = _webEditorLoadedPageId != _currentPage.id;
    _webEditorLoadedPageId = _currentPage.id;

    _sendWebEditorCommand(
      isPageSwitch ? 'loadPageBody' : 'replacePageBody',
      payload: <String, dynamic>{
        'pageId': _currentPage.id,
        'doc': _buildCurrentPageBodyDoc(),
        'preserveSelection': !isPageSwitch,
        if (selectElement && selectedId != null) 'selectedElementId': selectedId,
      },
      replaceQueuedBody: true,
    );

    if (selectElement && selectedId != null) {
      _sendWebEditorCommand(
        'selectElement',
        payload: <String, dynamic>{
          'elementId': selectedId,
          'focus': requestFocus,
        },
      );
    } else if (requestFocus) {
      _sendWebEditorCommand('focusEditor');
    }

    final nextTheme = _textValue(_document.meta['theme'], fallback: 'light');
    _sendWebEditorCommand(
      'setTheme',
      payload: <String, dynamic>{'theme': nextTheme},
    );
  }

  bool _insertEmbeddedBlockIntoPageDocument(String type) {
    if (!_webviewController.value.isInitialized) {
      return false;
    }

    final element = _newElement(type);
    final elementId = _blockId(element);
    _mutateDocument('Inserted ${_labelize(type).toLowerCase()} block.', () {
      _currentPage.elements.add(element);
      _selectedElementId = elementId;
      _moveTargetPageIndex = _selectedPageIndex;
    });

    _sendWebEditorCommand(
      'insertBlock',
      payload: <String, dynamic>{
        'elementId': elementId,
        'elementType': _elementType(element),
        'width': element['width'],
        'preview': _previewForBridge(element),
      },
    );
    _sendWebEditorCommand(
      'selectElement',
      payload: <String, dynamic>{
        'elementId': elementId,
        'focus': true,
      },
    );
    return true;
  }

  String _previewForBridge(Map<String, dynamic> element) {
    final doc = buildTiptapPageDocument(
      IdocPage(
        id: 'preview',
        title: '',
        elements: <Map<String, dynamic>>[element],
      ),
    );
    final content = doc['content'] as List<dynamic>;
    if (content.isEmpty) {
      return '';
    }
    final first = content.first as Map<String, dynamic>;
    final attrs = first['attrs'] is Map
        ? (first['attrs'] as Map).map(
            (dynamic key, dynamic value) =>
                MapEntry<String, dynamic>(key.toString(), value),
          )
        : <String, dynamic>{};
    return _textValue(attrs['preview']);
  }
}
