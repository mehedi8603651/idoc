// ignore_for_file: invalid_use_of_protected_member

part of 'idoc_studio_app.dart';

extension _IdocStudioUi on _IdocStudioHomeState {
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
        _buildTextStyleControl(),
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
        _buildInsertTool(
          icon: Icons.horizontal_rule,
          label: 'Separator',
          type: 'separator',
        ),
        _buildInsertTool(
          icon: Icons.space_bar,
          label: 'Spacer',
          type: 'spacer',
        ),
        _buildInsertTool(
          icon: Icons.insert_page_break_outlined,
          label: 'Page break',
          type: 'pagebreak',
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

  Widget _buildTextStyleControl() {
    final selected = _selectedElement;
    final enabled = selected != null && _isTextStyleElement(selected);
    final currentStyle = enabled ? _selectedTextStyle : 'disabled';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFCF7),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE4DAC7)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(Icons.text_format),
          const SizedBox(width: 10),
          SizedBox(
            width: 190,
            child: DropdownButtonFormField<String>(
              key: ValueKey<String>('text-style-$currentStyle'),
              initialValue: currentStyle,
              decoration: const InputDecoration.collapsed(
                hintText: 'Text style',
              ),
              items: const <DropdownMenuItem<String>>[
                DropdownMenuItem<String>(
                  value: 'disabled',
                  child: Text('Select text to style'),
                ),
                DropdownMenuItem<String>(
                  value: 'paragraph',
                  child: Text('Paragraph'),
                ),
                DropdownMenuItem<String>(
                  value: 'heading-1',
                  child: Text('Heading 1'),
                ),
                DropdownMenuItem<String>(
                  value: 'heading-2',
                  child: Text('Heading 2'),
                ),
                DropdownMenuItem<String>(
                  value: 'heading-3',
                  child: Text('Heading 3'),
                ),
                DropdownMenuItem<String>(value: 'quote', child: Text('Quote')),
                DropdownMenuItem<String>(
                  value: 'list-bulleted',
                  child: Text('Bulleted list'),
                ),
                DropdownMenuItem<String>(
                  value: 'list-numbered',
                  child: Text('Numbered list'),
                ),
              ],
                  onChanged: enabled
                  ? (String? value) {
                      if (value != null && value != 'disabled') {
                        _applyTextStyleToSelection(value);
                      }
                    }
                  : null,
            ),
          ),
        ],
      ),
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

  String _pageDisplayTitle(IdocPage page, int index) {
    final raw = page.title.trim();
    return raw.isEmpty ? 'Page ${index + 1}' : raw;
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
                      _selectedElementId = null;
                      _selectedTextStyle = 'paragraph';
                      _moveTargetPageIndex = index;
                    });
                    _rebuildPageDocumentSession(requestFocus: true);
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
                                _pageDisplayTitle(page, index),
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
    return _buildContinuousPageEditorCanvas(context);
  }

  Widget _buildCanvasElementEditor(
    IdocPage page,
    int index,
    Map<String, dynamic> element,
  ) {
    switch (_elementType(element)) {
      case 'heading':
      case 'paragraph':
      case 'text':
        return const Text(
          'Text blocks are edited directly in the page editor.',
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
        isCollapsed: true,
        isDense: true,
        contentPadding: EdgeInsets.zero,
        constraints: BoxConstraints(minWidth: 0, minHeight: 0),
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
                      _updateDocumentTheme(value);
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
          _buildPanel(
            title: 'Block content',
            child: _buildBlockContentPanel(),
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
    final supportsBlockWidth = !_isTextFlowElement(element);
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
        if (supportsBlockWidth) ...<Widget>[
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
            children: _IdocStudioHomeState._blockWidthOptions
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
            'Half and third widths let blocks sit horizontally on the same row when there is enough space.',
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
        ],
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
            OutlinedButton.icon(
              onPressed: _selectedElementIndex == null
                  ? null
                  : () => _removeElement(_currentPage, _selectedElementIndex!),
              icon: const Icon(Icons.delete_outline),
              label: const Text('Delete'),
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
                  child: Text(
                    'Page ${entry.key + 1}: ${_pageDisplayTitle(entry.value, entry.key)}',
                  ),
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

  Widget _buildBlockContentPanel() {
    final element = _selectedElement;
    final index = _selectedElementIndex;
    if (element == null || index == null) {
      return const Text(
        'Select a block on the page. Text is edited in the web editor, while special blocks are configured here.',
      );
    }
    if (_isTextFlowElement(element)) {
      return const Text(
        'This block is edited directly in the page editor. Use the Home ribbon for text structure and this inspector for block-level settings.',
      );
    }
    return _buildCanvasElementEditor(_currentPage, index, element);
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
          items: _IdocStudioHomeState._simpleBehaviorTypes
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
                    child: Text(
                      'Page ${entry.key + 1}: ${_pageDisplayTitle(entry.value, entry.key)}',
                    ),
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
}
