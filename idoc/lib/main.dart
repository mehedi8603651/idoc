import 'dart:convert';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'idoc_document.dart';
import 'idoc_exporter.dart';

enum RibbonTab { home, insert }

void main() {
  runApp(const IdocStudioApp());
}

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
  RibbonTab _activeRibbonTab = RibbonTab.home;
  String _status = 'Loading assets...';
  bool _slashMenuOpen = false;
  Map<String, dynamic>? _copiedElement;
  Map<String, dynamic>? _copiedAction;
  int? _moveTargetPageIndex;
  String? _draggingBlockId;
  String? _resizingBlockId;

  @override
  void initState() {
    super.initState();
    _loadAssets();
  }

  Future<void> _loadAssets() async {
    try {
      final results = await Future.wait<String>(<Future<String>>[
        rootBundle.loadString('assets/idoc_runtime_template.html'),
        rootBundle.loadString('assets/demo_document.json'),
      ]);
      final demoDocument = IdocDocument.fromJson(
        extractDocumentJsonFromContent(results[1]),
      );
      _normalizeDocumentForEditor(demoDocument);
      setState(() {
        _runtimeTemplate = results[0];
        _demoDocument = demoDocument.deepCopy();
        _document = demoDocument.deepCopy();
        _selectedPageIndex = 0;
        _selectedElementId = _currentPage.elements.isNotEmpty
            ? _blockId(_currentPage.elements.first)
            : null;
        _moveTargetPageIndex = 0;
        _status =
            'Ready. Write directly on the page canvas, use / to switch text blocks, and export a standalone .idoc.html runtime.';
        _loading = false;
      });
    } catch (error) {
      setState(() {
        _status = 'Failed to load bundled assets: $error';
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

  Widget _buildCommandBar(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      elevation: 2,
      color: Colors.white.withValues(alpha: 0.82),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: const LinearGradient(
                      colors: <Color>[Color(0xFF0F766E), Color(0xFFD97706)],
                    ),
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    'ID',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'iDoc Studio',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Word-like authoring on the canvas, structured export under the hood.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFF5D6668),
                        ),
                      ),
                    ],
                  ),
                ),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: <Widget>[
                    _buildInfoChip('Document', _document.title),
                    _buildInfoChip('Pages', _document.pages.length.toString()),
                    _buildInfoChip('Export', suggestHtmlFilename(_document)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: <Widget>[
                _buildRibbonTabChip('Home', RibbonTab.home),
                const SizedBox(width: 10),
                _buildRibbonTabChip('Insert', RibbonTab.insert),
              ],
            ),
            const SizedBox(height: 14),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: _activeRibbonTab == RibbonTab.home
                  ? _buildHomeRibbon(context)
                  : _buildInsertRibbon(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRibbonTabChip(String label, RibbonTab tab) {
    return ChoiceChip(
      label: Text(label),
      selected: _activeRibbonTab == tab,
      onSelected: (_) {
        setState(() {
          _activeRibbonTab = tab;
        });
      },
      selectedColor: const Color(0xFFDCF4EE),
      labelStyle: TextStyle(
        fontWeight: FontWeight.w700,
        color: _activeRibbonTab == tab
            ? const Color(0xFF0F766E)
            : const Color(0xFF374547),
      ),
    );
  }

  Widget _buildHomeRibbon(BuildContext context) {
    return Wrap(
      key: const ValueKey<String>('home-ribbon'),
      spacing: 10,
      runSpacing: 10,
      children: <Widget>[
        FilledButton.tonalIcon(
          onPressed: _createNewDocument,
          icon: const Icon(Icons.note_add_outlined),
          label: const Text('New document'),
        ),
        FilledButton.tonalIcon(
          onPressed: _openDocumentFile,
          icon: const Icon(Icons.folder_open_outlined),
          label: const Text('Open'),
        ),
        FilledButton.tonalIcon(
          onPressed: _saveJsonFile,
          icon: const Icon(Icons.data_object_outlined),
          label: const Text('Save JSON'),
        ),
        FilledButton.icon(
          onPressed: _exportHtmlFile,
          icon: const Icon(Icons.picture_as_pdf_outlined),
          label: const Text('Export .idoc.html'),
        ),
        FilledButton.tonalIcon(
          onPressed: _selectedElement == null ? null : _copySelectedBlock,
          icon: const Icon(Icons.content_copy_outlined),
          label: const Text('Copy block'),
        ),
        FilledButton.tonalIcon(
          onPressed: _copiedElement == null ? null : _pasteBlockAfterSelection,
          icon: const Icon(Icons.content_paste_go_outlined),
          label: const Text('Paste block'),
        ),
        OutlinedButton.icon(
          onPressed: _editRawJson,
          icon: const Icon(Icons.code),
          label: const Text('Raw JSON'),
        ),
        OutlinedButton.icon(
          onPressed: _resetToDemo,
          icon: const Icon(Icons.refresh),
          label: const Text('Reset demo'),
        ),
      ],
    );
  }

  Widget _buildInsertRibbon(BuildContext context) {
    return Wrap(
      key: const ValueKey<String>('insert-ribbon'),
      spacing: 10,
      runSpacing: 10,
      children: <Widget>[
        _buildInsertTool(icon: Icons.title, label: 'Heading', type: 'heading'),
        _buildInsertTool(
          icon: Icons.notes,
          label: 'Paragraph',
          type: 'paragraph',
        ),
        _buildInsertTool(icon: Icons.text_fields, label: 'Text', type: 'text'),
        _buildInsertTool(
          icon: Icons.info_outline,
          label: 'Callout',
          type: 'callout',
        ),
        _buildInsertTool(
          icon: Icons.smart_button_outlined,
          label: 'Button',
          type: 'button',
        ),
        _buildInsertTool(icon: Icons.link, label: 'Link', type: 'link'),
        _buildInsertTool(icon: Icons.code, label: 'Code', type: 'code'),
        _buildInsertTool(icon: Icons.functions, label: 'Math', type: 'math'),
        _buildInsertTool(
          icon: Icons.format_list_bulleted,
          label: 'List',
          type: 'list',
        ),
        _buildInsertTool(
          icon: Icons.quiz_outlined,
          label: 'Question',
          type: 'question',
        ),
        _buildInsertTool(
          icon: Icons.image_outlined,
          label: 'Image',
          type: 'image',
        ),
        _buildInsertTool(
          icon: Icons.keyboard_outlined,
          label: 'Input',
          type: 'input',
        ),
        OutlinedButton.icon(
          onPressed: _addPageAfterCurrent,
          icon: const Icon(Icons.note_add_outlined),
          label: const Text('New page'),
        ),
      ],
    );
  }

  Widget _buildInsertTool({
    required IconData icon,
    required String label,
    required String type,
  }) {
    return OutlinedButton.icon(
      onPressed: () => _insertBlockAfterSelection(type),
      icon: Icon(icon),
      label: Text(label),
    );
  }

  Widget _buildInfoChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F0E4),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFDDD0B7)),
      ),
      child: Text('$label: $value'),
    );
  }

  Widget _buildPageRail(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      color: Colors.white.withValues(alpha: 0.66),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'Pages',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Add page',
                onPressed: _addPageAfterCurrent,
                icon: const Icon(Icons.add_circle_outline),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Select a page. The center canvas behaves like the writing surface.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF5D6668),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.separated(
              itemCount: _document.pages.length,
              separatorBuilder: (_, index) => const SizedBox(height: 10),
              itemBuilder: (BuildContext context, int index) {
                final page = _document.pages[index];
                final selected = index == _selectedPageIndex;
                return InkWell(
                  onTap: () {
                    setState(() {
                      _selectedPageIndex = index;
                      _selectedElementId = page.elements.isNotEmpty
                          ? _blockId(page.elements.first)
                          : null;
                      _moveTargetPageIndex = index;
                    });
                  },
                  borderRadius: BorderRadius.circular(18),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: selected
                          ? const Color(0xFFEEF8F6)
                          : const Color(0xFFFFFCF7),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: selected
                            ? const Color(0xFF0F766E)
                            : const Color(0xFFE1D7C5),
                        width: selected ? 1.5 : 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Container(
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF6F0E4),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              alignment: Alignment.center,
                              child: Text('${index + 1}'),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                page.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          '${page.elements.length} blocks',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: const Color(0xFF5D6668),
                          ),
                        ),
                        Row(
                          children: <Widget>[
                            IconButton(
                              tooltip: 'Move page up',
                              onPressed: index > 0
                                  ? () => _movePage(index, -1)
                                  : null,
                              icon: const Icon(Icons.arrow_upward),
                            ),
                            IconButton(
                              tooltip: 'Move page down',
                              onPressed: index < _document.pages.length - 1
                                  ? () => _movePage(index, 1)
                                  : null,
                              icon: const Icon(Icons.arrow_downward),
                            ),
                            const Spacer(),
                            IconButton(
                              tooltip: 'Delete page',
                              onPressed: _document.pages.length > 1
                                  ? () => _removePage(index)
                                  : null,
                              icon: const Icon(Icons.delete_outline),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditorCanvas(BuildContext context) {
    final theme = Theme.of(context);
    final page = _currentPage;
    return Container(
      color: const Color(0xFFF7F2E8),
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: <Widget>[
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 920),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFE2D8C6)),
                    ),
                    child: Row(
                      children: <Widget>[
                        const Icon(Icons.tips_and_updates_outlined),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Write directly in the page. Type / in an empty heading, paragraph, or text block to switch block type.',
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.all(28),
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Page ${_selectedPageIndex + 1}',
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: const Color(0xFF5D6668),
                            letterSpacing: 0.3,
                          ),
                        ),
                        _buildInlineTextField(
                          fieldKey: 'page-title-${page.id}',
                          initialValue: page.title,
                          onChanged: (String value) {
                            _mutateDocument('Updated page title.', () {
                              page.title = value;
                            });
                          },
                          style: theme.textTheme.headlineLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -1.3,
                            height: 1.05,
                          ),
                          minLines: 1,
                          maxLines: 3,
                        ),
                        const SizedBox(height: 10),
                        if (page.elements.isEmpty)
                          OutlinedButton.icon(
                            onPressed: () =>
                                _insertBlockAfterSelection('paragraph'),
                            icon: const Icon(Icons.add),
                            label: const Text('Add first block'),
                          )
                        else
                          Column(
                            children: <Widget>[
                              const SizedBox(height: 8),
                              LayoutBuilder(
                                builder:
                                    (
                                      BuildContext context,
                                      BoxConstraints constraints,
                                    ) {
                                      final availableWidth =
                                          constraints.maxWidth;
                                      return Wrap(
                                        spacing: 16,
                                        runSpacing: 18,
                                        children: <Widget>[
                                          for (
                                            var index = 0;
                                            index < page.elements.length;
                                            index += 1
                                          )
                                            _buildCanvasBlockTile(
                                              page: page,
                                              index: index,
                                              element: page.elements[index],
                                              availableWidth: availableWidth,
                                            ),
                                          if (_draggingBlockId != null)
                                            _buildCanvasEndDropTarget(
                                              page: page,
                                              availableWidth: availableWidth,
                                            ),
                                        ],
                                      );
                                    },
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCanvasBlockTile({
    required IdocPage page,
    required int index,
    required Map<String, dynamic> element,
    required double availableWidth,
  }) {
    final blockId = _blockId(element);
    final blockWidth = _blockPixelWidth(element, availableWidth);
    return Builder(
      builder: (BuildContext targetContext) {
        return DragTarget<String>(
          onWillAcceptWithDetails: (DragTargetDetails<String> details) =>
              details.data != blockId,
          onAcceptWithDetails: (DragTargetDetails<String> details) {
            final insertionIndex = _dropInsertionIndex(
              targetContext,
              index,
              details.offset,
            );
            _reorderElementById(page, details.data, insertionIndex);
          },
          builder:
              (
                BuildContext context,
                List<String?> candidateData,
                List<dynamic> rejectedData,
              ) {
                final isDropTarget = candidateData.isNotEmpty;
                final card = SizedBox(
                  width: blockWidth,
                  child: _buildBlockCard(
                    page: page,
                    index: index,
                    element: element,
                    availableWidth: availableWidth,
                  ),
                );
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 140),
                  padding: EdgeInsets.all(isDropTarget ? 4 : 0),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(26),
                    border: Border.all(
                      color: isDropTarget
                          ? const Color(0xFF0F766E)
                          : Colors.transparent,
                      width: 1.2,
                    ),
                  ),
                  child: Opacity(
                    opacity: _draggingBlockId == blockId ? 0.38 : 1,
                    child: card,
                  ),
                );
              },
        );
      },
    );
  }

  Widget _buildCanvasEndDropTarget({
    required IdocPage page,
    required double availableWidth,
  }) {
    return DragTarget<String>(
      onWillAcceptWithDetails: (DragTargetDetails<String> details) =>
          details.data.isNotEmpty,
      onAcceptWithDetails: (DragTargetDetails<String> details) {
        _reorderElementById(page, details.data, page.elements.length);
      },
      builder:
          (
            BuildContext context,
            List<String?> candidateData,
            List<dynamic> rejectedData,
          ) {
            final active = candidateData.isNotEmpty;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              width: availableWidth,
              height: active ? 72 : 36,
              decoration: BoxDecoration(
                color: active
                    ? const Color(0xFFDCF4EE)
                    : const Color(0xFFF7F2E8),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: active
                      ? const Color(0xFF0F766E)
                      : const Color(0xFFE4DAC7),
                  style: BorderStyle.solid,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                active
                    ? 'Drop here to move block to the end'
                    : 'Drag a block here',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF5D6668),
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            );
          },
    );
  }

  Widget _buildDragFeedbackCard(Map<String, dynamic> element) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF0F766E),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 24,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(_iconForType(_elementType(element)), color: Colors.white),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              _labelize(_elementType(element)),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBlockCard({
    required IdocPage page,
    required int index,
    required Map<String, dynamic> element,
    required double availableWidth,
  }) {
    final type = _elementType(element);
    final selected = _isSelected(element);
    final theme = Theme.of(context);
    final blockId = _blockId(element);
    final currentWidthPercent = (_blockWidthFactor(element) * 100).round();

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => _selectElement(element),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFEEF8F6) : const Color(0xFFFFFCF7),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: selected ? const Color(0xFF0F766E) : const Color(0xFFE4DAC7),
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF6F0E4),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    _labelize(type),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Block ${index + 1}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF5D6668),
                  ),
                ),
                if (selected)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCF4EE),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'Selected',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: const Color(0xFF0F766E),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: Wrap(
                spacing: 2,
                runSpacing: 2,
                crossAxisAlignment: WrapCrossAlignment.center,
                alignment: WrapAlignment.end,
                children: <Widget>[
                  IconButton(
                    tooltip: 'Copy block',
                    onPressed: () => _copyElement(element),
                    icon: const Icon(Icons.content_copy_outlined),
                  ),
                  IconButton(
                    tooltip: 'Duplicate block',
                    onPressed: () => _duplicateElement(page, index),
                    icon: const Icon(Icons.copy_all_outlined),
                  ),
                  IconButton(
                    tooltip: 'Delete block',
                    onPressed: () => _removeElement(page, index),
                    icon: const Icon(Icons.delete_outline),
                  ),
                  MouseRegion(
                    cursor: SystemMouseCursors.grab,
                    child: Draggable<String>(
                      data: blockId,
                      dragAnchorStrategy: pointerDragAnchorStrategy,
                      onDragStarted: () {
                        setState(() {
                          _draggingBlockId = blockId;
                          _selectedElementId = blockId;
                        });
                      },
                      onDragEnd: (_) {
                        if (mounted) {
                          setState(() {
                            _draggingBlockId = null;
                          });
                        }
                      },
                      feedback: Material(
                        color: Colors.transparent,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: _blockPixelWidth(
                              element,
                              availableWidth,
                            ).clamp(220, 420),
                          ),
                          child: _buildDragFeedbackCard(element),
                        ),
                      ),
                      childWhenDragging: const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 8,
                        ),
                        child: Icon(
                          Icons.drag_indicator,
                          color: Color(0xFF9CA7A9),
                        ),
                      ),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 8,
                        ),
                        child: Icon(Icons.drag_indicator),
                      ),
                    ),
                  ),
                  MouseRegion(
                    cursor: SystemMouseCursors.resizeLeftRight,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onHorizontalDragStart: (_) {
                        setState(() {
                          _resizingBlockId = blockId;
                          _selectedElementId = blockId;
                        });
                      },
                      onHorizontalDragUpdate: (DragUpdateDetails details) {
                        _resizeBlockWidth(
                          element,
                          availableWidth,
                          details.delta.dx,
                        );
                      },
                      onHorizontalDragEnd: (_) {
                        if (mounted) {
                          setState(() {
                            _resizingBlockId = null;
                          });
                        }
                      },
                      onHorizontalDragCancel: () {
                        if (mounted) {
                          setState(() {
                            _resizingBlockId = null;
                          });
                        }
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 8,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Icon(
                              Icons.drag_handle,
                              color: _resizingBlockId == blockId
                                  ? const Color(0xFF0F766E)
                                  : const Color(0xFF5D6668),
                            ),
                            Text(
                              '$currentWidthPercent%',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: const Color(0xFF5D6668),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _buildCanvasElementEditor(page, index, element),
            if (_isBehaviorElement(element)) ...<Widget>[
              const SizedBox(height: 12),
              Text(
                'Configure what this ${type == 'button' ? 'button' : 'link'} does in the Behavior panel on the right.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF5D6668),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCanvasElementEditor(
    IdocPage page,
    int index,
    Map<String, dynamic> element,
  ) {
    switch (_elementType(element)) {
      case 'heading':
        return _buildInlineTextField(
          fieldKey: '${_blockId(element)}-heading',
          initialValue: _textValue(element['text']),
          onChanged: (String value) {
            _updateElementField(element, 'text', value, 'Updated heading.');
            _maybeOpenSlashMenu(
              page: page,
              index: index,
              element: element,
              value: value,
            );
          },
          style: _styleForElement(
            element,
            Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.6,
            ),
          ),
          minLines: 1,
          maxLines: 4,
        );
      case 'paragraph':
      case 'text':
        return _buildInlineTextField(
          fieldKey: '${_blockId(element)}-text',
          initialValue: _textValue(element['text']),
          onChanged: (String value) {
            _updateElementField(
              element,
              'text',
              value,
              'Updated ${_labelize(_elementType(element)).toLowerCase()}.',
            );
            _maybeOpenSlashMenu(
              page: page,
              index: index,
              element: element,
              value: value,
            );
          },
          style: _styleForElement(
            element,
            Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.7),
          ),
          minLines: 2,
          maxLines: 8,
        );
      case 'callout':
        return _buildCalloutEditor(element);
      case 'code':
        return _buildCodeEditor(element);
      case 'quote':
        return _buildQuoteEditor(element);
      case 'list':
        return _buildListEditor(element);
      case 'question':
        return _buildQuestionEditor(element);
      case 'input':
        return _buildInputEditor(element);
      case 'math':
        return _buildMathEditor(element);
      case 'image':
        return _buildImageEditor(element);
      case 'button':
      case 'link':
        return _buildButtonLikeEditor(element);
      case 'separator':
        return const Divider(height: 24);
      case 'spacer':
        return _buildSpacerEditor(element);
      case 'pagebreak':
        return const Text(
          'Page break marker. The exported runtime will show this as a marker block.',
        );
      default:
        return Text(
          'Unsupported block type. You can still fix it in Raw JSON.',
          style: Theme.of(context).textTheme.bodyMedium,
        );
    }
  }

  Widget _buildInlineTextField({
    required String fieldKey,
    required String initialValue,
    required ValueChanged<String> onChanged,
    TextStyle? style,
    int minLines = 1,
    int maxLines = 1,
  }) {
    return _IdocTextEditor(
      key: ValueKey<String>(fieldKey),
      initialValue: initialValue,
      minLines: minLines,
      maxLines: maxLines,
      style: style,
      decoration: const InputDecoration(
        border: InputBorder.none,
        isDense: true,
        contentPadding: EdgeInsets.zero,
      ),
      onChanged: onChanged,
    );
  }

  Widget _buildCalloutEditor(Map<String, dynamic> element) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: _toneBackground(_textValue(element['tone'], fallback: 'info')),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: _buildInlineTextField(
                  fieldKey: '${_blockId(element)}-callout-title',
                  initialValue: _textValue(element['title']),
                  onChanged: (String value) => _updateElementField(
                    element,
                    'title',
                    value,
                    'Updated callout title.',
                  ),
                  style: _styleForElement(
                    element,
                    Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 140,
                child: DropdownButtonFormField<String>(
                  initialValue: _textValue(element['tone'], fallback: 'info'),
                  decoration: const InputDecoration(
                    labelText: 'Tone',
                    border: OutlineInputBorder(),
                  ),
                  items: const <DropdownMenuItem<String>>[
                    DropdownMenuItem<String>(
                      value: 'info',
                      child: Text('Info'),
                    ),
                    DropdownMenuItem<String>(
                      value: 'success',
                      child: Text('Success'),
                    ),
                    DropdownMenuItem<String>(
                      value: 'warning',
                      child: Text('Warning'),
                    ),
                  ],
                  onChanged: (String? value) {
                    if (value != null) {
                      _updateElementField(
                        element,
                        'tone',
                        value,
                        'Updated callout tone.',
                      );
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildInlineTextField(
            fieldKey: '${_blockId(element)}-callout-text',
            initialValue: _textValue(element['text']),
            onChanged: (String value) => _updateElementField(
              element,
              'text',
              value,
              'Updated callout text.',
            ),
            style: _styleForElement(
              element,
              Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.7),
            ),
            minLines: 2,
            maxLines: 6,
          ),
        ],
      ),
    );
  }

  Widget _buildCodeEditor(Map<String, dynamic> element) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF161D1F),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 140,
            child: TextFormField(
              key: ValueKey<String>('${_blockId(element)}-language'),
              initialValue: _textValue(element['language'], fallback: 'js'),
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Language',
                labelStyle: TextStyle(color: Colors.white70),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.white24),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.white54),
                ),
              ),
              onChanged: (String value) => _updateElementField(
                element,
                'language',
                value,
                'Updated code language.',
              ),
            ),
          ),
          const SizedBox(height: 12),
          _IdocTextEditor(
            key: ValueKey<String>('${_blockId(element)}-code'),
            initialValue: _textValue(element['code']),
            minLines: 6,
            maxLines: 12,
            style: const TextStyle(
              color: Color(0xFFF1F7F6),
              fontFamily: 'Consolas',
              height: 1.5,
            ).copyWith(fontSize: _fontSizeFor(element, fallback: 14)),
            decoration: const InputDecoration(
              border: InputBorder.none,
              hintText: 'Write code here',
              hintStyle: TextStyle(color: Colors.white38),
            ),
            onChanged: (String value) => _updateElementField(
              element,
              'code',
              value,
              'Updated code block.',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuoteEditor(Map<String, dynamic> element) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: const BoxDecoration(
            border: Border(
              left: BorderSide(color: Color(0xFF0F766E), width: 3),
            ),
          ),
          child: _buildInlineTextField(
            fieldKey: '${_blockId(element)}-quote-text',
            initialValue: _textValue(element['text']),
            onChanged: (String value) =>
                _updateElementField(element, 'text', value, 'Updated quote.'),
            style: _styleForElement(
              element,
              Theme.of(context).textTheme.titleMedium?.copyWith(
                fontStyle: FontStyle.italic,
                height: 1.6,
              ),
            ),
            minLines: 2,
            maxLines: 5,
          ),
        ),
        const SizedBox(height: 8),
        _buildInlineTextField(
          fieldKey: '${_blockId(element)}-quote-cite',
          initialValue: _textValue(element['cite']),
          onChanged: (String value) => _updateElementField(
            element,
            'cite',
            value,
            'Updated quote source.',
          ),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: const Color(0xFF5D6668),
            fontSize: (_fontSizeFor(element, fallback: 18) - 2).clamp(12, 44),
          ),
        ),
      ],
    );
  }

  Widget _buildListEditor(Map<String, dynamic> element) {
    final items = _stringList(element['items']);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SwitchListTile.adaptive(
          value: element['ordered'] == true,
          contentPadding: EdgeInsets.zero,
          title: const Text('Ordered list'),
          onChanged: (bool value) => _updateElementField(
            element,
            'ordered',
            value,
            'Updated list style.',
          ),
        ),
        ...items.asMap().entries.map((MapEntry<int, String> entry) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: <Widget>[
                Icon(
                  element['ordered'] == true
                      ? Icons.format_list_numbered
                      : Icons.fiber_manual_record,
                  size: 16,
                  color: const Color(0xFF5D6668),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildInlineTextField(
                    fieldKey: '${_blockId(element)}-item-${entry.key}',
                    initialValue: entry.value,
                    onChanged: (String value) {
                      final nextItems = List<String>.from(items);
                      nextItems[entry.key] = value;
                      _updateElementField(
                        element,
                        'items',
                        nextItems,
                        'Updated list item.',
                      );
                    },
                    style: _styleForElement(
                      element,
                      Theme.of(
                        context,
                      ).textTheme.bodyLarge?.copyWith(height: 1.7),
                    ),
                    minLines: 1,
                    maxLines: 4,
                  ),
                ),
                IconButton(
                  onPressed: () {
                    final nextItems = List<String>.from(items)
                      ..removeAt(entry.key);
                    _updateElementField(
                      element,
                      'items',
                      nextItems,
                      'Removed list item.',
                    );
                  },
                  icon: const Icon(Icons.remove_circle_outline),
                ),
              ],
            ),
          );
        }),
        OutlinedButton.icon(
          onPressed: () {
            final nextItems = List<String>.from(items)..add('New item');
            _updateElementField(
              element,
              'items',
              nextItems,
              'Added list item.',
            );
          },
          icon: const Icon(Icons.add),
          label: const Text('Add item'),
        ),
      ],
    );
  }

  Widget _buildQuestionEditor(Map<String, dynamic> element) {
    final options = _stringList(element['options']);
    final answer = _numberValue(element['answer']);
    final selectedAnswer = options.isEmpty
        ? null
        : answer.clamp(0, options.length - 1);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _buildInlineTextField(
          fieldKey: '${_blockId(element)}-prompt',
          initialValue: _textValue(element['prompt']),
          onChanged: (String value) => _updateElementField(
            element,
            'prompt',
            value,
            'Updated question prompt.',
          ),
          style: _styleForElement(
            element,
            Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          minLines: 2,
          maxLines: 5,
        ),
        const SizedBox(height: 12),
        ...options.asMap().entries.map((MapEntry<int, String> entry) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: _IdocTextEditor(
                    key: ValueKey<String>(
                      '${_blockId(element)}-option-${entry.key}',
                    ),
                    initialValue: entry.value,
                    minLines: 1,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: 'Option ${entry.key + 1}',
                      border: const OutlineInputBorder(),
                    ),
                    style: TextStyle(
                      fontSize: _fontSizeFor(element, fallback: 18),
                    ),
                    onChanged: (String value) {
                      final nextOptions = List<String>.from(options);
                      nextOptions[entry.key] = value;
                      _updateElementField(
                        element,
                        'options',
                        nextOptions,
                        'Updated question option.',
                      );
                    },
                  ),
                ),
                IconButton(
                  onPressed: () {
                    final nextOptions = List<String>.from(options)
                      ..removeAt(entry.key);
                    var nextAnswer = selectedAnswer ?? 0;
                    if (nextAnswer >= nextOptions.length) {
                      nextAnswer = nextOptions.isEmpty
                          ? 0
                          : nextOptions.length - 1;
                    }
                    _mutateDocument('Removed question option.', () {
                      element['options'] = nextOptions;
                      element['answer'] = nextAnswer;
                    });
                  },
                  icon: const Icon(Icons.remove_circle_outline),
                ),
              ],
            ),
          );
        }),
        OutlinedButton.icon(
          onPressed: () {
            final nextOptions = List<String>.from(options)..add('New option');
            _updateElementField(
              element,
              'options',
              nextOptions,
              'Added question option.',
            );
          },
          icon: const Icon(Icons.add),
          label: const Text('Add option'),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<int>(
          initialValue: selectedAnswer,
          decoration: const InputDecoration(
            labelText: 'Correct answer',
            border: OutlineInputBorder(),
          ),
          items: options
              .asMap()
              .entries
              .map(
                (MapEntry<int, String> entry) => DropdownMenuItem<int>(
                  value: entry.key,
                  child: Text('Option ${entry.key + 1}'),
                ),
              )
              .toList(),
          onChanged: options.isEmpty
              ? null
              : (int? value) {
                  if (value != null) {
                    _updateElementField(
                      element,
                      'answer',
                      value,
                      'Updated correct answer.',
                    );
                  }
                },
        ),
        const SizedBox(height: 12),
        _IdocTextEditor(
          key: ValueKey<String>('${_blockId(element)}-explanation'),
          initialValue: _textValue(element['explanation']),
          minLines: 2,
          maxLines: 5,
          style: TextStyle(fontSize: _fontSizeFor(element, fallback: 18)),
          decoration: const InputDecoration(
            labelText: 'Explanation',
            border: OutlineInputBorder(),
          ),
          onChanged: (String value) => _updateElementField(
            element,
            'explanation',
            value,
            'Updated answer explanation.',
          ),
        ),
      ],
    );
  }

  Widget _buildInputEditor(Map<String, dynamic> element) {
    return Column(
      children: <Widget>[
        TextFormField(
          key: ValueKey<String>('${_blockId(element)}-input-label'),
          initialValue: _textValue(element['label']),
          style: TextStyle(fontSize: _fontSizeFor(element, fallback: 18)),
          decoration: const InputDecoration(
            labelText: 'Label',
            border: OutlineInputBorder(),
          ),
          onChanged: (String value) => _updateElementField(
            element,
            'label',
            value,
            'Updated input label.',
          ),
        ),
        const SizedBox(height: 10),
        TextFormField(
          key: ValueKey<String>('${_blockId(element)}-input-placeholder'),
          initialValue: _textValue(element['placeholder']),
          style: TextStyle(fontSize: _fontSizeFor(element, fallback: 18)),
          decoration: const InputDecoration(
            labelText: 'Placeholder',
            border: OutlineInputBorder(),
          ),
          onChanged: (String value) => _updateElementField(
            element,
            'placeholder',
            value,
            'Updated input placeholder.',
          ),
        ),
        const SizedBox(height: 10),
        _IdocTextEditor(
          key: ValueKey<String>('${_blockId(element)}-input-help'),
          initialValue: _textValue(element['helpText']),
          minLines: 1,
          maxLines: 3,
          style: TextStyle(fontSize: _fontSizeFor(element, fallback: 18)),
          decoration: const InputDecoration(
            labelText: 'Help text',
            border: OutlineInputBorder(),
          ),
          onChanged: (String value) => _updateElementField(
            element,
            'helpText',
            value,
            'Updated input helper text.',
          ),
        ),
      ],
    );
  }

  Widget _buildMathEditor(Map<String, dynamic> element) {
    return Column(
      children: <Widget>[
        _IdocTextEditor(
          key: ValueKey<String>('${_blockId(element)}-math-tex'),
          initialValue: _textValue(element['tex']),
          minLines: 2,
          maxLines: 6,
          style: const TextStyle(fontFamily: 'Consolas'),
          decoration: const InputDecoration(
            labelText: 'TeX',
            border: OutlineInputBorder(),
          ),
          onChanged: (String value) =>
              _updateElementField(element, 'tex', value, 'Updated math block.'),
        ),
        const SizedBox(height: 8),
        SwitchListTile.adaptive(
          value: element['displayMode'] == true,
          contentPadding: EdgeInsets.zero,
          title: const Text('Display mode'),
          onChanged: (bool value) => _updateElementField(
            element,
            'displayMode',
            value,
            'Updated math display mode.',
          ),
        ),
      ],
    );
  }

  Widget _buildImageEditor(Map<String, dynamic> element) {
    return Column(
      children: <Widget>[
        Container(
          width: double.infinity,
          height: 140,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: const Color(0xFFF6F0E4),
          ),
          alignment: Alignment.center,
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(Icons.image_outlined, size: 36),
              SizedBox(height: 8),
              Text('Image preview placeholder'),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _IdocTextEditor(
          key: ValueKey<String>('${_blockId(element)}-image-src'),
          initialValue: _textValue(element['src']),
          minLines: 1,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Source URL or data URI',
            border: OutlineInputBorder(),
          ),
          onChanged: (String value) => _updateElementField(
            element,
            'src',
            value,
            'Updated image source.',
          ),
        ),
        const SizedBox(height: 10),
        TextFormField(
          key: ValueKey<String>('${_blockId(element)}-image-alt'),
          initialValue: _textValue(element['alt']),
          decoration: const InputDecoration(
            labelText: 'Alt text',
            border: OutlineInputBorder(),
          ),
          onChanged: (String value) => _updateElementField(
            element,
            'alt',
            value,
            'Updated image alt text.',
          ),
        ),
        const SizedBox(height: 10),
        _IdocTextEditor(
          key: ValueKey<String>('${_blockId(element)}-image-caption'),
          initialValue: _textValue(element['caption']),
          minLines: 1,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Caption',
            border: OutlineInputBorder(),
          ),
          onChanged: (String value) => _updateElementField(
            element,
            'caption',
            value,
            'Updated image caption.',
          ),
        ),
      ],
    );
  }

  Widget _buildButtonLikeEditor(Map<String, dynamic> element) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: const Color(0xFFF6F0E4),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            _elementType(element) == 'button'
                ? Icons.smart_button_outlined
                : Icons.link,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildInlineTextField(
              fieldKey: '${_blockId(element)}-label',
              initialValue: _textValue(element['label']),
              onChanged: (String value) => _updateElementField(
                element,
                'label',
                value,
                'Updated block label.',
              ),
              style: _styleForElement(
                element,
                Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpacerEditor(Map<String, dynamic> element) {
    final currentSize = _numberValue(element['size'], fallback: 24).toDouble();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Slider(
          value: currentSize.clamp(4, 96),
          min: 4,
          max: 96,
          divisions: 23,
          label: currentSize.round().toString(),
          onChanged: (double value) => _updateElementField(
            element,
            'size',
            value.round(),
            'Updated spacer size.',
          ),
        ),
        Text('Current height: ${currentSize.round()} px'),
      ],
    );
  }

  Widget _buildInspector(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      color: Colors.white.withValues(alpha: 0.76),
      padding: const EdgeInsets.all(18),
      child: ListView(
        children: <Widget>[
          Text(
            'Inspector',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'The page canvas is the main editor. This panel keeps document settings, button/link behavior, and raw JSON.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF5D6668),
            ),
          ),
          const SizedBox(height: 16),
          _buildPanel(
            title: 'Document',
            child: Column(
              children: <Widget>[
                TextFormField(
                  key: const ValueKey<String>('meta-title'),
                  initialValue: _textValue(_document.meta['title']),
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (String value) => _mutateDocument(
                    'Updated document title.',
                    () => _document.meta['title'] = value,
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  key: const ValueKey<String>('meta-author'),
                  initialValue: _textValue(_document.meta['author']),
                  decoration: const InputDecoration(
                    labelText: 'Author',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (String value) => _mutateDocument(
                    'Updated author.',
                    () => _document.meta['author'] = value,
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  key: const ValueKey<String>('meta-version'),
                  initialValue: _textValue(_document.meta['version']),
                  decoration: const InputDecoration(
                    labelText: 'Version',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (String value) => _mutateDocument(
                    'Updated version.',
                    () => _document.meta['version'] = value,
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: _textValue(
                    _document.meta['theme'],
                    fallback: 'light',
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Default theme',
                    border: OutlineInputBorder(),
                  ),
                  items: const <DropdownMenuItem<String>>[
                    DropdownMenuItem<String>(
                      value: 'light',
                      child: Text('Light'),
                    ),
                    DropdownMenuItem<String>(
                      value: 'dark',
                      child: Text('Dark'),
                    ),
                  ],
                  onChanged: (String? value) {
                    if (value != null) {
                      _mutateDocument(
                        'Updated default theme.',
                        () => _document.meta['theme'] = value,
                      );
                    }
                  },
                ),
                const SizedBox(height: 10),
                TextFormField(
                  key: const ValueKey<String>('meta-filename'),
                  initialValue: _textValue(
                    _document.meta['recommendedFilename'],
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Recommended filename',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (String value) => _mutateDocument(
                    'Updated recommended filename.',
                    () => _document.meta['recommendedFilename'] = value,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildPanel(
            title: 'Selected block',
            child: _buildSelectedBlockPanel(),
          ),
          const SizedBox(height: 16),
          _buildPanel(title: 'Behavior', child: _buildBehaviorPanel()),
          const SizedBox(height: 16),
          _buildPanel(
            title: 'Raw JSON',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF161D1F),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: SelectableText(
                    _document.toPrettyJson(),
                    style: const TextStyle(
                      fontFamily: 'Consolas',
                      fontSize: 12,
                      color: Color(0xFFF4F8F7),
                      height: 1.55,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: <Widget>[
                    FilledButton.tonalIcon(
                      onPressed: _editRawJson,
                      icon: const Icon(Icons.code),
                      label: const Text('Edit raw JSON'),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: () {
                        Clipboard.setData(
                          ClipboardData(text: _document.toPrettyJson()),
                        );
                        _setStatus('Copied JSON to the clipboard.');
                      },
                      icon: const Icon(Icons.copy_all_outlined),
                      label: const Text('Copy JSON'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPanel({required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFCF7),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE4DAC7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _buildSelectedBlockPanel() {
    final element = _selectedElement;
    if (element == null) {
      return const Text(
        'Select a block on the page to reorder it, copy it, move it to another page, or adjust its text size.',
      );
    }

    final type = _elementType(element);
    final moveTargetPage = _resolvedMoveTargetPageIndex();
    final supportsFontSize = _supportsFontSize(element);
    final currentFontSize = _fontSizeFor(
      element,
      fallback: _defaultFontSizeFor(type),
    );
    final currentBlockWidth = _blockWidthFactor(element);
    final currentBlockWidthPercent = (currentBlockWidth * 100).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Icon(_iconForType(type)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _labelize(type),
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF6F0E4),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text('Page ${_selectedPageIndex + 1}'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text('Block width', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 4),
        Text(
          '$currentBlockWidthPercent% width',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: const Color(0xFF5D6668)),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _blockWidthOptions
              .map(
                (BlockWidthOption option) => ChoiceChip(
                  label: Text(option.label),
                  selected: (currentBlockWidth - option.factor).abs() < 0.01,
                  onSelected: (_) => _setBlockWidth(element, option.factor),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 8),
        Text(
          'Use the card edge handle for mouse resize. Half and third widths let blocks sit horizontally on the same row when there is enough space.',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: const Color(0xFF5D6668)),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => _clearBlockWidth(element),
            icon: const Icon(Icons.restart_alt),
            label: const Text('Reset block width'),
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: <Widget>[
            FilledButton.tonalIcon(
              onPressed: _copySelectedBlock,
              icon: const Icon(Icons.content_copy_outlined),
              label: const Text('Copy'),
            ),
            FilledButton.tonalIcon(
              onPressed: _copiedElement == null
                  ? null
                  : _pasteBlockAfterSelection,
              icon: const Icon(Icons.content_paste_go_outlined),
              label: const Text('Paste after'),
            ),
            OutlinedButton.icon(
              onPressed: _selectedElementIndex == null
                  ? null
                  : () =>
                        _duplicateElement(_currentPage, _selectedElementIndex!),
              icon: const Icon(Icons.copy_all_outlined),
              label: const Text('Duplicate'),
            ),
          ],
        ),
        if (supportsFontSize) ...<Widget>[
          const SizedBox(height: 16),
          Row(
            children: <Widget>[
              Text('Text size', style: Theme.of(context).textTheme.titleSmall),
              const Spacer(),
              Text('${currentFontSize.round()} px'),
            ],
          ),
          Slider(
            value: currentFontSize.clamp(12, 42),
            min: 12,
            max: 42,
            divisions: 15,
            label: currentFontSize.round().toString(),
            onChanged: (double value) => _updateElementField(
              element,
              'fontSize',
              value.round(),
              'Updated text size.',
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => _clearBlockFontSize(element),
              icon: const Icon(Icons.restart_alt),
              label: const Text('Reset text size'),
            ),
          ),
        ],
        const SizedBox(height: 8),
        DropdownButtonFormField<int>(
          key: ValueKey<String>('move-target-${_selectedElementId ?? 'none'}'),
          initialValue: moveTargetPage,
          decoration: const InputDecoration(
            labelText: 'Move block to page',
            border: OutlineInputBorder(),
          ),
          items: _document.pages
              .asMap()
              .entries
              .map(
                (MapEntry<int, IdocPage> entry) => DropdownMenuItem<int>(
                  value: entry.key,
                  child: Text('Page ${entry.key + 1}: ${entry.value.title}'),
                ),
              )
              .toList(),
          onChanged: _document.pages.length < 2
              ? null
              : (int? value) {
                  if (value != null) {
                    setState(() {
                      _moveTargetPageIndex = value;
                    });
                  }
                },
        ),
        const SizedBox(height: 10),
        FilledButton.tonalIcon(
          onPressed:
              _document.pages.length < 2 ||
                  _selectedElementIndex == null ||
                  moveTargetPage == _selectedPageIndex
              ? null
              : () => _moveSelectedBlockToPage(moveTargetPage),
          icon: const Icon(Icons.drive_file_move_outline),
          label: const Text('Move block'),
        ),
      ],
    );
  }

  Widget _buildBehaviorPanel() {
    final element = _selectedElement;
    if (element == null) {
      return const Text(
        'Select a block on the page. Buttons and links show behavior controls here.',
      );
    }
    if (!_isBehaviorElement(element)) {
      return Text(
        '${_labelize(_elementType(element))} blocks are edited directly on the page canvas. Raw JSON is still available below for advanced changes.',
      );
    }

    final action = _ensureBehaviorAction(element);
    final actionType = _textValue(
      action['type'],
      fallback: _defaultBehaviorTypeForElement(element),
    );
    final questionTargets = _questionTargets();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          '${_labelize(_elementType(element))} behavior',
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Text(
          'Action IDs stay hidden. Pick the behavior you want and the editor manages the internal action map.',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: const Color(0xFF5D6668)),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: actionType,
          decoration: const InputDecoration(
            labelText: 'Behavior',
            border: OutlineInputBorder(),
          ),
          items: _simpleBehaviorTypes
              .map(
                (String type) => DropdownMenuItem<String>(
                  value: type,
                  child: Text(_labelize(type)),
                ),
              )
              .toList(),
          onChanged: (String? value) {
            if (value != null) {
              _setBehaviorType(element, value);
            }
          },
        ),
        if (actionType == 'popup' || actionType == 'alert') ...<Widget>[
          const SizedBox(height: 10),
          TextFormField(
            key: ValueKey<String>('${_blockId(element)}-behavior-title'),
            initialValue: _textValue(action['title']),
            decoration: const InputDecoration(
              labelText: 'Title',
              border: OutlineInputBorder(),
            ),
            onChanged: (String value) => _updateBehaviorField(
              element,
              'title',
              value,
              'Updated behavior title.',
            ),
          ),
          const SizedBox(height: 10),
          _IdocTextEditor(
            key: ValueKey<String>('${_blockId(element)}-behavior-content'),
            initialValue: _textValue(action['content']),
            minLines: 2,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: 'Content',
              border: OutlineInputBorder(),
            ),
            onChanged: (String value) => _updateBehaviorField(
              element,
              'content',
              value,
              'Updated behavior content.',
            ),
          ),
        ],
        if (actionType == 'gotoPage') ...<Widget>[
          const SizedBox(height: 10),
          DropdownButtonFormField<int>(
            initialValue: _numberValue(
              action['page'],
              fallback: 0,
            ).clamp(0, _document.pages.length - 1),
            decoration: const InputDecoration(
              labelText: 'Target page',
              border: OutlineInputBorder(),
            ),
            items: _document.pages
                .asMap()
                .entries
                .map(
                  (MapEntry<int, IdocPage> entry) => DropdownMenuItem<int>(
                    value: entry.key,
                    child: Text('Page ${entry.key + 1}: ${entry.value.title}'),
                  ),
                )
                .toList(),
            onChanged: (int? value) {
              if (value != null) {
                _updateBehaviorField(
                  element,
                  'page',
                  value,
                  'Updated target page.',
                );
              }
            },
          ),
        ],
        if (actionType == 'openLink') ...<Widget>[
          const SizedBox(height: 10),
          TextFormField(
            key: ValueKey<String>('${_blockId(element)}-behavior-url'),
            initialValue: _textValue(action['url']),
            decoration: const InputDecoration(
              labelText: 'URL',
              border: OutlineInputBorder(),
            ),
            onChanged: (String value) => _updateBehaviorField(
              element,
              'url',
              value,
              'Updated link URL.',
            ),
          ),
        ],
        if (actionType == 'showAnswer') ...<Widget>[
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: _textValue(action['target']),
            decoration: const InputDecoration(
              labelText: 'Target question',
              border: OutlineInputBorder(),
            ),
            items: questionTargets
                .map(
                  (QuestionTarget target) => DropdownMenuItem<String>(
                    value: target.id,
                    child: Text(target.label),
                  ),
                )
                .toList(),
            onChanged: questionTargets.isEmpty
                ? null
                : (String? value) {
                    if (value != null) {
                      _updateBehaviorField(
                        element,
                        'target',
                        value,
                        'Updated answer target.',
                      );
                    }
                  },
          ),
          if (questionTargets.isEmpty) ...<Widget>[
            const SizedBox(height: 8),
            const Text(
              'Add a question block first, then you can target it here.',
            ),
          ],
        ],
        if (actionType == 'toggleTheme' ||
            actionType == 'saveDocument' ||
            actionType == 'exportDocument') ...<Widget>[
          const SizedBox(height: 10),
          Text(
            'No extra settings are needed for this behavior.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ],
    );
  }

  Widget _buildStatusBar() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE5DDCE))),
      ),
      child: Text(_status),
    );
  }

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

  bool _isSelected(Map<String, dynamic> element) {
    return _selectedElementId != null &&
        _blockId(element) == _selectedElementId;
  }

  void _selectElement(Map<String, dynamic> element) {
    setState(() {
      _selectedElementId = _blockId(element);
      _moveTargetPageIndex = _selectedPageIndex;
    });
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

  void _updateElementField(
    Map<String, dynamic> element,
    String field,
    dynamic value,
    String message,
  ) {
    _mutateDocument(message, () {
      element[field] = value;
    });
  }

  void _maybeOpenSlashMenu({
    required IdocPage page,
    required int index,
    required Map<String, dynamic> element,
    required String value,
  }) {
    if (_slashMenuOpen || value.trim() != '/') {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _slashMenuOpen) {
        return;
      }
      _showSlashInsertMenu(page: page, index: index, element: element);
    });
  }

  Future<void> _showSlashInsertMenu({
    required IdocPage page,
    required int index,
    required Map<String, dynamic> element,
  }) async {
    _slashMenuOpen = true;
    final chosenType = await showModalBottomSheet<String>(
      context: context,
      builder: (BuildContext context) {
        final options = <String>[
          'heading',
          'paragraph',
          'text',
          'callout',
          'button',
          'link',
          'code',
          'math',
          'list',
          'question',
          'image',
          'input',
        ];
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const SizedBox(height: 10),
              const ListTile(
                title: Text('Insert block'),
                subtitle: Text('Choose what this slash block should become.'),
              ),
              ...options.map(
                (String type) => ListTile(
                  leading: Icon(_iconForType(type)),
                  title: Text(_labelize(type)),
                  onTap: () => Navigator.of(context).pop(type),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
    _slashMenuOpen = false;

    if (!mounted) {
      return;
    }

    if (chosenType == null) {
      _mutateDocument('Cleared slash insert.', () {
        element['text'] = '';
      });
      return;
    }

    final previousActionKey = element['action']?.toString();
    final editorId = _blockId(element);
    _mutateDocument(
      'Changed block to ${_labelize(chosenType).toLowerCase()}.',
      () {
        final replacement = _newElement(chosenType);
        replacement['_editorId'] = editorId;
        page.elements[index] = replacement;
        _selectedElementId = editorId;
      },
    );
    if (previousActionKey != null && previousActionKey.isNotEmpty) {
      _removeActionIfUnused(previousActionKey);
    }
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

  void _insertBlockAfterSelection(String type) {
    final page = _currentPage;
    final insertIndex = _selectedElementIndex == null
        ? page.elements.length
        : _selectedElementIndex! + 1;
    _mutateDocument('Inserted ${_labelize(type).toLowerCase()} block.', () {
      final element = _newElement(type);
      page.elements.insert(insertIndex, element);
      _selectedElementId = _blockId(element);
    });
  }

  void _addPageAfterCurrent() {
    final existingIds = _document.pages.map((IdocPage page) => page.id);
    _mutateDocument('Added a new page.', () {
      _document.pages.insert(
        _selectedPageIndex + 1,
        IdocPage(
          id: createUniqueId('page', existingIds),
          title: 'New Page',
          elements: <Map<String, dynamic>>[
            _newElement('heading'),
            _newElement('paragraph'),
          ],
        ),
      );
      _selectedPageIndex += 1;
      _selectedElementId = _currentPage.elements.isNotEmpty
          ? _blockId(_currentPage.elements.first)
          : null;
      _moveTargetPageIndex = _selectedPageIndex;
    });
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
      _selectedElementId = _currentPage.elements.isNotEmpty
          ? _blockId(_currentPage.elements.first)
          : null;
      _moveTargetPageIndex = _selectedPageIndex;
    });
    for (final String key in actionKeys) {
      _removeActionIfUnused(key);
    }
  }

  void _reorderElements(IdocPage page, int oldIndex, int newIndex) {
    if (oldIndex == newIndex ||
        oldIndex < 0 ||
        newIndex < 0 ||
        oldIndex >= page.elements.length ||
        newIndex >= page.elements.length) {
      return;
    }
    _mutateDocument('Reordered blocks.', () {
      final element = page.elements.removeAt(oldIndex);
      page.elements.insert(newIndex, element);
      _selectedElementId = _blockId(element);
    });
  }

  void _reorderElementById(
    IdocPage page,
    String draggedBlockId,
    int targetIndex,
  ) {
    final oldIndex = page.elements.indexWhere(
      (Map<String, dynamic> element) => _blockId(element) == draggedBlockId,
    );
    if (oldIndex == -1) {
      return;
    }
    var nextIndex = targetIndex;
    if (oldIndex < targetIndex) {
      nextIndex -= 1;
    }
    if (nextIndex < 0) {
      nextIndex = 0;
    }
    if (nextIndex >= page.elements.length) {
      nextIndex = page.elements.length - 1;
    }
    _reorderElements(page, oldIndex, nextIndex);
  }

  int _dropInsertionIndex(
    BuildContext targetContext,
    int targetIndex,
    Offset globalOffset,
  ) {
    final renderBox = targetContext.findRenderObject() as RenderBox?;
    if (renderBox == null) {
      return targetIndex;
    }
    final localOffset = renderBox.globalToLocal(globalOffset);
    final dropAfter = localOffset.dy > renderBox.size.height / 2;
    return dropAfter ? targetIndex + 1 : targetIndex;
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
  }

  void _removeElement(IdocPage page, int index) {
    final removed = page.elements[index];
    final actionKey = removed['action']?.toString();
    _mutateDocument('Deleted block ${index + 1}.', () {
      page.elements.removeAt(index);
      _selectedElementId = page.elements.isNotEmpty
          ? _blockId(page.elements[index == 0 ? 0 : index - 1])
          : null;
    });
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
      final targetPage = _document.pages[targetPageIndex];
      targetPage.elements.add(element);
      _selectedPageIndex = targetPageIndex;
      _selectedElementId = _blockId(element);
      _moveTargetPageIndex = targetPageIndex;
    });
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
            label: '${page.title}: ${_textValue(element['prompt'])}',
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
        _selectedElementId = _currentPage.elements.isNotEmpty
            ? _blockId(_currentPage.elements.first)
            : null;
        _moveTargetPageIndex = 0;
        _status = 'Opened ${file.name}.';
      });
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
      _selectedElementId = _currentPage.elements.isNotEmpty
          ? _blockId(_currentPage.elements.first)
          : null;
      _moveTargetPageIndex = 0;
      _status = 'Started a new document.';
    });
  }

  void _resetToDemo() {
    final nextDocument = _demoDocument.deepCopy();
    _normalizeDocumentForEditor(nextDocument);
    setState(() {
      _document = nextDocument;
      _selectedPageIndex = 0;
      _selectedElementId = _currentPage.elements.isNotEmpty
          ? _blockId(_currentPage.elements.first)
          : null;
      _moveTargetPageIndex = 0;
      _status = 'Restored the bundled demo document.';
    });
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
        _selectedElementId = _currentPage.elements.isNotEmpty
            ? _blockId(_currentPage.elements.first)
            : null;
        _moveTargetPageIndex = 0;
        _status = 'Applied raw JSON changes.';
      });
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
      if (page.title.trim().isEmpty) {
        page.title = 'Page ${pageIndex + 1}';
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

  double _blockPixelWidth(Map<String, dynamic> element, double availableWidth) {
    const spacing = 16.0;
    final factor = _blockWidthFactor(element);
    if (factor >= 0.995) {
      return availableWidth;
    }
    return (availableWidth * factor) - (spacing * (1 - factor));
  }

  void _setBlockWidth(Map<String, dynamic> element, double factor) {
    _updateElementField(
      element,
      'width',
      _clampBlockWidthFactor(factor),
      'Updated block width.',
    );
  }

  void _resizeBlockWidth(
    Map<String, dynamic> element,
    double availableWidth,
    double deltaX,
  ) {
    final currentFactor = _blockWidthFactor(element);
    final nextFactor = _clampBlockWidthFactor(
      currentFactor + (deltaX / availableWidth),
    );
    _updateElementField(element, 'width', nextFactor, 'Resized block width.');
  }

  void _clearBlockWidth(Map<String, dynamic> element) {
    _mutateDocument('Reset block width.', () {
      element.remove('width');
    });
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

class QuestionTarget {
  const QuestionTarget({required this.id, required this.label});

  final String id;
  final String label;
}

class BlockWidthOption {
  const BlockWidthOption(this.factor, this.label);

  final double factor;
  final String label;
}

class _IdocTextEditor extends StatefulWidget {
  const _IdocTextEditor({
    super.key,
    required this.initialValue,
    required this.onChanged,
    this.style,
    this.minLines = 1,
    this.maxLines = 1,
    this.decoration = const InputDecoration(),
  });

  final String initialValue;
  final ValueChanged<String> onChanged;
  final TextStyle? style;
  final int minLines;
  final int maxLines;
  final InputDecoration decoration;

  @override
  State<_IdocTextEditor> createState() => _IdocTextEditorState();
}

class _IdocTextEditorState extends State<_IdocTextEditor> {
  late final FocusNode _focusNode;
  late final TextEditingController _controller;

  bool get _isMultiline => widget.minLines > 1 || widget.maxLines > 1;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void didUpdateWidget(covariant _IdocTextEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialValue != _controller.text && !_focusNode.hasFocus) {
      _controller.value = TextEditingValue(
        text: widget.initialValue,
        selection: TextSelection.collapsed(offset: widget.initialValue.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (!_isMultiline ||
        event is! KeyDownEvent ||
        event.logicalKey != LogicalKeyboardKey.tab) {
      return KeyEventResult.ignored;
    }
    const tabInsertion = '    ';
    final selection = _controller.selection;
    final rawStart = selection.isValid
        ? selection.start
        : _controller.text.length;
    final rawEnd = selection.isValid ? selection.end : _controller.text.length;
    final start = rawStart < rawEnd ? rawStart : rawEnd;
    final end = rawStart < rawEnd ? rawEnd : rawStart;
    final nextText = _controller.text.replaceRange(start, end, tabInsertion);
    final caretOffset = start + tabInsertion.length;
    _controller.value = TextEditingValue(
      text: nextText,
      selection: TextSelection.collapsed(offset: caretOffset),
      composing: TextRange.empty,
    );
    widget.onChanged(nextText);
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      onKeyEvent: _handleKeyEvent,
      child: TextFormField(
        controller: _controller,
        focusNode: _focusNode,
        minLines: widget.minLines,
        maxLines: widget.maxLines,
        keyboardType: _isMultiline
            ? TextInputType.multiline
            : TextInputType.text,
        textInputAction: _isMultiline
            ? TextInputAction.newline
            : TextInputAction.done,
        style: widget.style,
        decoration: widget.decoration,
        onChanged: widget.onChanged,
      ),
    );
  }
}
