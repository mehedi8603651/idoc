// ignore_for_file: invalid_use_of_protected_member

part of 'idoc_studio_app.dart';

extension _IdocStudioLogic on _IdocStudioHomeState {
  IdocPage get _currentPage {
    if (_selectedPageIndex >= _document.pages.length) {
      _selectedPageIndex = _document.pages.length - 1;
    }
    return _document.pages[_selectedPageIndex];
  }

  Map<String, dynamic>? get _selectedElement {
    if (_selectedElementId == null) {
      return null;
    }
    for (final Map<String, dynamic> element in _currentPage.elements) {
      if (_blockId(element) == _selectedElementId) {
        return element;
      }
    }
    return null;
  }

  int? get _selectedElementIndex {
    if (_selectedElementId == null) {
      return null;
    }
    for (var index = 0; index < _currentPage.elements.length; index += 1) {
      if (_blockId(_currentPage.elements[index]) == _selectedElementId) {
        return index;
      }
    }
    return null;
  }

  void _mutateDocument(String message, VoidCallback callback) {
    setState(() {
      callback();
      if (_selectedPageIndex >= _document.pages.length) {
        _selectedPageIndex = _document.pages.length - 1;
      }
      if (_moveTargetPageIndex == null ||
          _moveTargetPageIndex! >= _document.pages.length) {
        _moveTargetPageIndex = _selectedPageIndex;
      }
      _status = message;
    });
  }

  void _setStatus(String message) {
    setState(() {
      _status = message;
    });
  }

  void _updateDocumentTheme(String value) {
    _mutateDocument('Updated default theme.', () {
      _document.meta['theme'] = value;
    });
    _sendWebEditorCommand(
      'setTheme',
      payload: <String, dynamic>{'theme': value},
    );
  }

  void _updateElementField(
    Map<String, dynamic> element,
    String field,
    dynamic value,
    String message,
  ) {
    final blockId = _blockId(element);
    _mutateDocument(message, () {
      element[field] = value;
    });
    if ((_isTextFlowElement(element) && field == 'fontSize') ||
        !_isTextFlowElement(element)) {
      _rebuildPageDocumentSession(
        preferredElementId: blockId,
        selectElement: !_isTextFlowElement(element),
      );
    }
  }

  Map<String, dynamic> _newParagraphElement({String text = ''}) {
    final element = _newElement('paragraph');
    element['text'] = text;
    element.remove('width');
    return element;
  }

  int _bodyParagraphCount(IdocPage page) {
    return page.elements.where(_isBodyParagraphElement).length;
  }

  void _ensurePageHasBodyParagraph(IdocPage page) {
    if (_bodyParagraphCount(page) > 0) {
      return;
    }
    page.elements.add(_newParagraphElement());
  }

  bool _isBodyParagraphElement(Map<String, dynamic> element) {
    final type = _elementType(element);
    return type == 'paragraph' || type == 'text';
  }

  bool _isTextFlowElement(Map<String, dynamic> element) {
    final type = _elementType(element);
    return type == 'heading' || type == 'paragraph' || type == 'text';
  }

  bool _isTextStyleElement(Map<String, dynamic> element) {
    final type = _elementType(element);
    return _isTextFlowElement(element) || type == 'quote' || type == 'list';
  }

  void _applyTextStyleToSelection(String style) {
    final element = _selectedElement;
    if (element == null || !_isTextStyleElement(element)) {
      return;
    }
    _setStatus('Changed text style to ${_labelize(style).toLowerCase()}.');
    _sendWebEditorCommand(
      'applyTextStyle',
      payload: <String, dynamic>{'style': style},
    );
  }

  Map<String, dynamic> _newElement(String type) {
    final element = createDefaultElement(type);
    element['_editorId'] = createUniqueId('block', _allBlockIds());
    _normalizeElementSemanticIds(element);
    if (_isBehaviorElement(element)) {
      final actionKey = createUniqueId('action', _document.actions.keys);
      element['action'] = actionKey;
      _document.actions[actionKey] = createDefaultAction(
        actionKey,
        _defaultBehaviorTypeForElement(element),
      );
    }
    return element;
  }

  bool _isInsertSpecialBlockType(String type) {
    switch (type) {
      case 'callout':
      case 'button':
      case 'link':
      case 'code':
      case 'math':
      case 'question':
      case 'image':
      case 'input':
      case 'separator':
      case 'spacer':
      case 'pagebreak':
        return true;
      default:
        return false;
    }
  }


  void _insertBlockAfterSelection(String type) {
    if (_isInsertSpecialBlockType(type) &&
        _insertEmbeddedBlockIntoPageDocument(type)) {
      _setStatus('Inserted ${_labelize(type).toLowerCase()} block.');
      return;
    }
    final page = _currentPage;
    final insertIndex =
        _selectedElementIndex == null ? page.elements.length : _selectedElementIndex! + 1;
    _mutateDocument('Inserted ${_labelize(type).toLowerCase()} block.', () {
      final element = _newElement(type);
      page.elements.insert(insertIndex, element);
      final blockId = _blockId(element);
      _selectedElementId = blockId;
    });
    _rebuildPageDocumentSession(
      preferredElementId: _selectedElementId,
      selectElement: true,
      requestFocus: true,
    );
  }

  void _addPageAfterCurrent() {
    final existingIds = _document.pages.map((IdocPage page) => page.id);
    _mutateDocument('Added a new page.', () {
      _document.pages.insert(
        _selectedPageIndex + 1,
        IdocPage(
          id: createUniqueId('page', existingIds),
          title: '',
          elements: <Map<String, dynamic>>[_newParagraphElement()],
        ),
      );
      _selectedPageIndex += 1;
      _selectedElementId = null;
      _selectedTextStyle = 'paragraph';
      _moveTargetPageIndex = _selectedPageIndex;
    });
    _rebuildPageDocumentSession(requestFocus: true);
  }

  void _movePage(int index, int delta) {
    final nextIndex = index + delta;
    if (nextIndex < 0 || nextIndex >= _document.pages.length) {
      return;
    }
    _mutateDocument('Reordered pages.', () {
      final page = _document.pages.removeAt(index);
      _document.pages.insert(nextIndex, page);
      _selectedPageIndex = nextIndex;
      _moveTargetPageIndex = nextIndex;
    });
    _rebuildPageDocumentSession(preferredElementId: _selectedElementId);
  }

  void _removePage(int index) {
    if (_document.pages.length <= 1) {
      return;
    }
    final removedPage = _document.pages[index];
    final actionKeys = removedPage.elements
        .map((Map<String, dynamic> element) => element['action']?.toString())
        .whereType<String>()
        .toList();
    _mutateDocument('Deleted page ${index + 1}.', () {
      _document.pages.removeAt(index);
      if (_selectedPageIndex >= _document.pages.length) {
        _selectedPageIndex = _document.pages.length - 1;
      }
      _selectedElementId = null;
      _selectedTextStyle = 'paragraph';
      _moveTargetPageIndex = _selectedPageIndex;
    });
    _rebuildPageDocumentSession();
    for (final String key in actionKeys) {
      _removeActionIfUnused(key);
    }
  }

  void _copyElement(Map<String, dynamic> element) {
    final sourceActionKey = _textValue(element['action']);
    final sourceAction = sourceActionKey.isEmpty
        ? null
        : _document.actions[sourceActionKey];
    setState(() {
      _copiedElement = Map<String, dynamic>.from(
        jsonDecode(jsonEncode(element)) as Map,
      );
      _copiedAction = sourceAction is Map<String, dynamic>
          ? Map<String, dynamic>.from(
              jsonDecode(jsonEncode(sourceAction)) as Map,
            )
          : null;
      _status =
          'Copied ${_labelize(_elementType(element)).toLowerCase()} block.';
    });
  }

  void _copySelectedBlock() {
    final element = _selectedElement;
    if (element == null) {
      return;
    }
    _copyElement(element);
  }

  Map<String, dynamic> _cloneElementForInsertion(
    Map<String, dynamic> source, {
    Map<String, dynamic>? sourceAction,
  }) {
    final duplicate = Map<String, dynamic>.from(
      jsonDecode(jsonEncode(source)) as Map,
    );
    duplicate['_editorId'] = createUniqueId('block', _allBlockIds());
    _normalizeElementSemanticIds(duplicate, forceNew: true);
    if (_isBehaviorElement(duplicate)) {
      final newActionKey = createUniqueId('action', _document.actions.keys);
      duplicate['action'] = newActionKey;
      if (sourceAction != null) {
        _document.actions[newActionKey] = Map<String, dynamic>.from(
          jsonDecode(jsonEncode(sourceAction)) as Map,
        );
      } else {
        _document.actions[newActionKey] = createDefaultAction(
          newActionKey,
          _defaultBehaviorTypeForElement(duplicate),
        );
      }
    }
    return duplicate;
  }

  Map<String, dynamic> _materializeCopiedBlock() {
    final source = _copiedElement;
    if (source == null) {
      throw StateError('No copied block is available.');
    }
    return _cloneElementForInsertion(source, sourceAction: _copiedAction);
  }

  void _pasteBlockAfterSelection() {
    if (_copiedElement == null) {
      _setStatus('Copy a block first.');
      return;
    }
    final page = _currentPage;
    final insertIndex = _selectedElementIndex == null
        ? page.elements.length
        : _selectedElementIndex! + 1;
    _mutateDocument(
      'Pasted ${_labelize(_elementType(_copiedElement!)).toLowerCase()} block.',
      () {
        final duplicate = _materializeCopiedBlock();
        page.elements.insert(insertIndex, duplicate);
        _selectedElementId = _blockId(duplicate);
      },
    );
    _rebuildPageDocumentSession(
      preferredElementId: _selectedElementId,
      selectElement: true,
    );
  }

  void _duplicateElement(IdocPage page, int index) {
    final source = page.elements[index];
    final sourceActionKey = _textValue(source['action']);
    final sourceAction = sourceActionKey.isEmpty
        ? null
        : _document.actions[sourceActionKey];
    _mutateDocument('Duplicated block ${index + 1}.', () {
      final duplicate = _cloneElementForInsertion(
        source,
        sourceAction: sourceAction is Map<String, dynamic>
            ? sourceAction
            : null,
      );
      page.elements.insert(index + 1, duplicate);
      _selectedElementId = _blockId(duplicate);
    });
    _rebuildPageDocumentSession(
      preferredElementId: _selectedElementId,
      selectElement: true,
    );
  }

  void _removeElement(IdocPage page, int index) {
    final removed = page.elements[index];
    final actionKey = removed['action']?.toString();
    _mutateDocument('Deleted block ${index + 1}.', () {
      page.elements.removeAt(index);
      _ensurePageHasBodyParagraph(page);
      _selectedElementId = page.elements.isNotEmpty
          ? _blockId(page.elements[index == 0 ? 0 : index - 1])
          : null;
    });
    _rebuildPageDocumentSession(preferredElementId: _selectedElementId);
    if (actionKey != null && actionKey.isNotEmpty) {
      _removeActionIfUnused(actionKey);
    }
  }

  void _moveSelectedBlockToPage(int targetPageIndex) {
    final currentIndex = _selectedElementIndex;
    if (currentIndex == null ||
        targetPageIndex < 0 ||
        targetPageIndex >= _document.pages.length ||
        targetPageIndex == _selectedPageIndex) {
      return;
    }
    final sourcePage = _currentPage;
    _mutateDocument('Moved block to page ${targetPageIndex + 1}.', () {
      final element = sourcePage.elements.removeAt(currentIndex);
      _ensurePageHasBodyParagraph(sourcePage);
      final targetPage = _document.pages[targetPageIndex];
      targetPage.elements.add(element);
      _ensurePageHasBodyParagraph(targetPage);
      _selectedPageIndex = targetPageIndex;
      _selectedElementId = _blockId(element);
      _moveTargetPageIndex = targetPageIndex;
    });
    _rebuildPageDocumentSession(
      preferredElementId: _selectedElementId,
      selectElement: true,
    );
  }

  bool _isBehaviorElement(Map<String, dynamic> element) {
    final type = _elementType(element);
    return type == 'button' || type == 'link';
  }

  String _defaultBehaviorTypeForElement(Map<String, dynamic> element) {
    return _elementType(element) == 'link' ? 'openLink' : 'popup';
  }

  Map<String, dynamic> _ensureBehaviorAction(Map<String, dynamic> element) {
    final actionKey = _ensureBehaviorActionKey(element);
    final existing = _document.actions[actionKey];
    if (existing is Map<String, dynamic>) {
      return existing;
    }
    final created = createDefaultAction(
      actionKey,
      _defaultBehaviorTypeForElement(element),
    );
    _document.actions[actionKey] = created;
    return created;
  }

  String _ensureBehaviorActionKey(Map<String, dynamic> element) {
    final existingKey = _textValue(element['action']);
    if (existingKey.isNotEmpty) {
      return existingKey;
    }
    final key = createUniqueId('action', _document.actions.keys);
    element['action'] = key;
    _document.actions[key] = createDefaultAction(
      key,
      _defaultBehaviorTypeForElement(element),
    );
    return key;
  }

  void _setBehaviorType(Map<String, dynamic> element, String type) {
    _mutateDocument('Updated ${_elementType(element)} behavior.', () {
      final key = _ensureBehaviorActionKey(element);
      _document.actions[key] = createDefaultAction(key, type);
    });
  }

  void _updateBehaviorField(
    Map<String, dynamic> element,
    String field,
    dynamic value,
    String message,
  ) {
    _mutateDocument(message, () {
      final key = _ensureBehaviorActionKey(element);
      final action = _ensureBehaviorAction(element);
      action[field] = value;
      _document.actions[key] = action;
    });
  }

  void _removeActionIfUnused(String actionKey) {
    final stillUsed = _document.pages.any(
      (IdocPage page) => page.elements.any(
        (Map<String, dynamic> element) =>
            _textValue(element['action']) == actionKey,
      ),
    );
    if (!stillUsed) {
      _document.actions.remove(actionKey);
    }
  }

  int _resolvedMoveTargetPageIndex() {
    final target = _moveTargetPageIndex ?? _selectedPageIndex;
    if (target < 0) {
      return 0;
    }
    if (target >= _document.pages.length) {
      return _document.pages.length - 1;
    }
    return target;
  }

  void _clearBlockFontSize(Map<String, dynamic> element) {
    _mutateDocument('Reset text size.', () {
      element.remove('fontSize');
    });
    _rebuildPageDocumentSession(preferredElementId: _blockId(element));
  }

  List<QuestionTarget> _questionTargets() {
    final targets = <QuestionTarget>[];
    for (final IdocPage page in _document.pages) {
      for (final Map<String, dynamic> element in page.elements) {
        if (_elementType(element) != 'question') {
          continue;
        }
        final id = _textValue(element['id']);
        if (id.isEmpty) {
          continue;
        }
        targets.add(
          QuestionTarget(
            id: id,
            label:
                '${_pageDisplayTitle(page, _document.pages.indexOf(page))}: ${_textValue(element['prompt'])}',
          ),
        );
      }
    }
    return targets;
  }

  Future<void> _openDocumentFile() async {
    final file = await openFile(
      acceptedTypeGroups: <XTypeGroup>[
        const XTypeGroup(
          label: 'iDoc document',
          extensions: <String>['json', 'html', 'htm', 'idoc'],
        ),
      ],
    );
    if (file == null) {
      return;
    }
    try {
      final content = await file.readAsString();
      final json = extractDocumentJsonFromContent(content);
      final nextDocument = IdocDocument.fromJson(json);
      _normalizeDocumentForEditor(nextDocument);
      setState(() {
        _document = nextDocument;
        _selectedPageIndex = 0;
        _selectedElementId = null;
        _selectedTextStyle = 'paragraph';
        _moveTargetPageIndex = 0;
        _status = 'Opened ${file.name}.';
      });
      _rebuildPageDocumentSession(requestFocus: true);
    } catch (error) {
      _showError('Could not open that file.\n\n$error');
    }
  }

  Future<void> _saveJsonFile() async {
    final location = await getSaveLocation(
      suggestedName: suggestJsonFilename(_document),
      acceptedTypeGroups: const <XTypeGroup>[
        XTypeGroup(label: 'JSON', extensions: <String>['json']),
      ],
    );
    if (location == null) {
      return;
    }
    await File(location.path).writeAsString(_document.toPrettyJson());
    _setStatus('Saved JSON to ${location.path}.');
  }

  Future<void> _exportHtmlFile() async {
    if (_runtimeTemplate.isEmpty) {
      _showError('The runtime template is not loaded yet.');
      return;
    }
    final location = await getSaveLocation(
      suggestedName: suggestHtmlFilename(_document),
      acceptedTypeGroups: const <XTypeGroup>[
        XTypeGroup(label: 'HTML', extensions: <String>['html']),
      ],
    );
    if (location == null) {
      return;
    }
    final html = buildRuntimeHtml(
      template: _runtimeTemplate,
      document: _document,
    );
    await File(location.path).writeAsString(html);
    _setStatus('Exported standalone runtime to ${location.path}.');
  }

  void _createNewDocument() {
    final nextDocument = createBlankDocument();
    _normalizeDocumentForEditor(nextDocument);
    setState(() {
      _document = nextDocument;
      _selectedPageIndex = 0;
      _selectedElementId = null;
      _selectedTextStyle = 'paragraph';
      _moveTargetPageIndex = 0;
      _status = 'Started a new document.';
    });
    _rebuildPageDocumentSession(requestFocus: true);
  }

  void _resetToDemo() {
    final nextDocument = _demoDocument.deepCopy();
    _normalizeDocumentForEditor(nextDocument);
    setState(() {
      _document = nextDocument;
      _selectedPageIndex = 0;
      _selectedElementId = null;
      _selectedTextStyle = 'paragraph';
      _moveTargetPageIndex = 0;
      _status = 'Restored the bundled demo document.';
    });
    _rebuildPageDocumentSession(requestFocus: true);
  }

  Future<void> _editRawJson() async {
    var draftText = _document.toPrettyJson();
    final result = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Edit raw iDoc JSON'),
          content: SizedBox(
            width: 760,
            child: _IdocTextEditor(
              key: const ValueKey<String>('raw-json-editor'),
              initialValue: draftText,
              maxLines: 28,
              minLines: 20,
              onChanged: (String value) => draftText = value,
              style: const TextStyle(fontFamily: 'Consolas'),
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(draftText),
              child: const Text('Apply JSON'),
            ),
          ],
        );
      },
    );
    if (result == null) {
      return;
    }
    try {
      final parsed = extractDocumentJsonFromContent(result);
      final nextDocument = IdocDocument.fromJson(parsed);
      _normalizeDocumentForEditor(nextDocument);
      setState(() {
        _document = nextDocument;
        _selectedPageIndex = 0;
        _selectedElementId = null;
        _selectedTextStyle = 'paragraph';
        _moveTargetPageIndex = 0;
        _status = 'Applied raw JSON changes.';
      });
      _rebuildPageDocumentSession(requestFocus: true);
    } catch (error) {
      _showError('The JSON could not be applied.\n\n$error');
    }
  }

  void _showError(String message) {
    showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('iDoc Studio'),
          content: Text(message),
          actions: <Widget>[
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  void _normalizeDocumentForEditor(IdocDocument document) {
    final pageIds = <String>{};
    final editorIds = <String>{};
    final questionIds = <String>{};
    final inputIds = <String>{};
    for (var pageIndex = 0; pageIndex < document.pages.length; pageIndex += 1) {
      final page = document.pages[pageIndex];
      final currentPageId = page.id.trim();
      page.id = currentPageId.isNotEmpty && !pageIds.contains(currentPageId)
          ? currentPageId
          : createUniqueId('page', pageIds);
      pageIds.add(page.id);
      if (page.elements.isEmpty ||
          !page.elements.any(_isBodyParagraphElement)) {
        page.elements.add(createDefaultElement('paragraph'));
      }
      for (final Map<String, dynamic> element in page.elements) {
        final currentEditorId = _textValue(element['_editorId']);
        if (currentEditorId.isEmpty || editorIds.contains(currentEditorId)) {
          element['_editorId'] = createUniqueId('block', editorIds);
        }
        editorIds.add(_textValue(element['_editorId']));
        final type = _elementType(element);
        if (type == 'question') {
          final existing = _textValue(element['id']);
          if (existing.isEmpty || questionIds.contains(existing)) {
            element['id'] = createUniqueId('question', questionIds);
          }
          questionIds.add(_textValue(element['id']));
        }
        if (type == 'input') {
          final existing = _textValue(element['id']);
          if (existing.isEmpty || inputIds.contains(existing)) {
            element['id'] = createUniqueId('input', inputIds);
          }
          inputIds.add(_textValue(element['id']));
        }
      }
    }
  }

  void _normalizeElementSemanticIds(
    Map<String, dynamic> element, {
    bool forceNew = false,
  }) {
    final type = _elementType(element);
    if (type == 'question' && (forceNew || _textValue(element['id']).isEmpty)) {
      element['id'] = createUniqueId('question', _allQuestionIds());
    }
    if (type == 'input' && (forceNew || _textValue(element['id']).isEmpty)) {
      element['id'] = createUniqueId('input', _allInputIds());
    }
  }

  Set<String> _allBlockIds() {
    final ids = <String>{};
    for (final IdocPage page in _document.pages) {
      for (final Map<String, dynamic> element in page.elements) {
        final id = _textValue(element['_editorId']);
        if (id.isNotEmpty) {
          ids.add(id);
        }
      }
    }
    return ids;
  }

  Set<String> _allQuestionIds() {
    final ids = <String>{};
    for (final IdocPage page in _document.pages) {
      for (final Map<String, dynamic> element in page.elements) {
        if (_elementType(element) == 'question') {
          final id = _textValue(element['id']);
          if (id.isNotEmpty) {
            ids.add(id);
          }
        }
      }
    }
    return ids;
  }

  Set<String> _allInputIds() {
    final ids = <String>{};
    for (final IdocPage page in _document.pages) {
      for (final Map<String, dynamic> element in page.elements) {
        if (_elementType(element) == 'input') {
          final id = _textValue(element['id']);
          if (id.isNotEmpty) {
            ids.add(id);
          }
        }
      }
    }
    return ids;
  }

  String _blockId(Map<String, dynamic> element) {
    final existing = _textValue(element['_editorId']);
    if (existing.isNotEmpty) {
      return existing;
    }
    final created = createUniqueId('block', _allBlockIds());
    element['_editorId'] = created;
    return created;
  }

  String _elementType(Map<String, dynamic> element) {
    return _textValue(element['type'], fallback: 'text');
  }

  String _textValue(dynamic value, {String fallback = ''}) {
    final text = value?.toString() ?? '';
    return text.isEmpty ? fallback : text;
  }

  int _numberValue(dynamic value, {int fallback = 0}) {
    if (value is int) {
      return value;
    }
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  double _fontSizeFor(Map<String, dynamic> element, {double fallback = 18}) {
    final raw = element['fontSize'];
    if (raw is num) {
      return raw.toDouble().clamp(12, 42);
    }
    return fallback.clamp(12, 42);
  }

  double _blockWidthFactor(Map<String, dynamic> element) {
    final raw = element['width'];
    final value = raw is num ? raw.toDouble() : double.tryParse('$raw');
    if (value == null) {
      return 1;
    }
    return _clampBlockWidthFactor(value);
  }

  double _clampBlockWidthFactor(double value) {
    final clamped = value.clamp(0.34, 1.0).toDouble();
    return double.parse(clamped.toStringAsFixed(2));
  }

  void _setBlockWidth(Map<String, dynamic> element, double factor) {
    _updateElementField(
      element,
      'width',
      _clampBlockWidthFactor(factor),
      'Updated block width.',
    );
  }

  void _clearBlockWidth(Map<String, dynamic> element) {
    _mutateDocument('Reset block width.', () {
      element.remove('width');
    });
    _rebuildPageDocumentSession(
      preferredElementId: _blockId(element),
      selectElement: true,
    );
  }

  double _defaultFontSizeFor(String type) {
    switch (type) {
      case 'heading':
        return 32;
      case 'button':
      case 'link':
        return 20;
      case 'quote':
        return 20;
      case 'question':
        return 18;
      case 'code':
        return 14;
      default:
        return 18;
    }
  }

  bool _supportsFontSize(Map<String, dynamic> element) {
    switch (_elementType(element)) {
      case 'heading':
      case 'paragraph':
      case 'text':
      case 'callout':
      case 'code':
      case 'quote':
      case 'list':
      case 'question':
      case 'input':
      case 'button':
      case 'link':
        return true;
      default:
        return false;
    }
  }

  TextStyle _styleForElement(
    Map<String, dynamic> element,
    TextStyle? baseStyle,
  ) {
    return (baseStyle ?? const TextStyle()).copyWith(
      fontSize: _fontSizeFor(
        element,
        fallback: _defaultFontSizeFor(_elementType(element)),
      ),
    );
  }

  List<String> _stringList(dynamic value) {
    if (value is List) {
      return value.map((dynamic item) => item.toString()).toList();
    }
    return <String>[];
  }

  Color _toneBackground(String tone) {
    switch (tone) {
      case 'success':
        return const Color(0xFFE8F7F0);
      case 'warning':
        return const Color(0xFFFFF3E1);
      default:
        return const Color(0xFFEAF7F5);
    }
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'heading':
        return Icons.title;
      case 'paragraph':
        return Icons.notes;
      case 'text':
        return Icons.text_fields;
      case 'callout':
        return Icons.info_outline;
      case 'button':
        return Icons.smart_button_outlined;
      case 'link':
        return Icons.link;
      case 'code':
        return Icons.code;
      case 'math':
        return Icons.functions;
      case 'list':
        return Icons.format_list_bulleted;
      case 'question':
        return Icons.quiz_outlined;
      case 'image':
        return Icons.image_outlined;
      case 'input':
        return Icons.keyboard_outlined;
      default:
        return Icons.add_box_outlined;
    }
  }

  String _labelize(String raw) {
    return raw
        .replaceAllMapped(
          RegExp(r'([A-Z])'),
          (Match match) => ' ${match.group(1)}',
        )
        .replaceAll('-', ' ')
        .replaceAll('_', ' ')
        .trim()
        .split(' ')
        .where((String part) => part.isNotEmpty)
        .map(
          (String part) =>
              '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}',
        )
        .join(' ');
  }
}
