import 'dart:convert';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'idoc_document.dart';
import 'idoc_exporter.dart';

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
  late IdocDocument _document;
  late IdocDocument _demoDocument;
  String _runtimeTemplate = '';
  bool _loading = true;
  int _selectedPageIndex = 0;
  String? _selectedActionKey;
  String _status = 'Loading assets...';

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
      setState(() {
        _runtimeTemplate = results[0];
        _demoDocument = demoDocument.deepCopy();
        _document = demoDocument.deepCopy();
        _selectedActionKey = _document.actions.isEmpty
            ? null
            : _document.actions.keys.first;
        _status =
            'Ready. Edit visually here, then export a standalone .idoc.html runtime.';
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
                  SizedBox(width: 280, child: _buildPageRail(context)),
                  const VerticalDivider(width: 1),
                  Expanded(child: _buildEditorCanvas(context)),
                  const VerticalDivider(width: 1),
                  SizedBox(width: 360, child: _buildInspector(context)),
                ],
              ),
            ),
            _buildStatusBar(context),
          ],
        ),
      ),
    );
  }

  Widget _buildCommandBar(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      elevation: 2,
      color: Colors.white.withValues(alpha: 0.78),
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
                        'Windows authoring app. Exported HTML files stay viewer-only.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFF5D6668),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: <Widget>[
                    FilledButton.tonalIcon(
                      onPressed: _createNewDocument,
                      icon: const Icon(Icons.note_add_outlined),
                      label: const Text('New'),
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
                    OutlinedButton.icon(
                      onPressed: _resetToDemo,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Reset demo'),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: <Widget>[
                _buildInfoChip('Title', _document.title),
                _buildInfoChip('Filename', suggestHtmlFilename(_document)),
                _buildInfoChip('Pages', _document.pages.length.toString()),
                _buildInfoChip('Actions', _document.actions.length.toString()),
              ],
            ),
          ],
        ),
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

  IdocPage get _currentPage {
    if (_selectedPageIndex >= _document.pages.length) {
      _selectedPageIndex = _document.pages.length - 1;
    }
    return _document.pages[_selectedPageIndex];
  }

  void _mutateDocument(String message, VoidCallback callback) {
    setState(() {
      callback();
      if (_selectedPageIndex >= _document.pages.length) {
        _selectedPageIndex = _document.pages.length - 1;
      }
      _status = message;
    });
  }

  void _setStatus(String message) {
    setState(() {
      _status = message;
    });
  }

  Widget _buildPageRail(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      color: Colors.white.withValues(alpha: 0.64),
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
            'Select a page, then add or edit blocks in the center canvas.',
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
                        const SizedBox(height: 12),
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
      child: Column(
        children: <Widget>[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Color(0xFFE5DDCE))),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Page canvas',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Visual authoring happens here. Exported .idoc.html files keep the viewer only.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF5D6668),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  key: ValueKey<String>('page-title-${page.id}'),
                  initialValue: page.title,
                  decoration: const InputDecoration(
                    labelText: 'Page title',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (String value) {
                    _mutateDocument('Updated page title.', () {
                      page.title = value;
                    });
                  },
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: <Widget>[
                    PopupMenuButton<String>(
                      tooltip: 'Add block',
                      onSelected: _addBlockToCurrentPage,
                      itemBuilder: (BuildContext context) {
                        return kIdocElementTypes
                            .map(
                              (String type) => PopupMenuItem<String>(
                                value: type,
                                child: Text(_labelize(type)),
                              ),
                            )
                            .toList();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Icon(Icons.add, color: Colors.white),
                            SizedBox(width: 8),
                            Text(
                              'Add block',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: _addPageAfterCurrent,
                      icon: const Icon(Icons.note_add_outlined),
                      label: const Text('New page after this'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _editRawJson,
                      icon: const Icon(Icons.code),
                      label: const Text('Advanced JSON'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: page.elements.isEmpty
                ? Center(
                    child: Text(
                      'No blocks on this page yet. Use “Add block” to start.',
                      style: theme.textTheme.titleMedium,
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(22),
                    itemCount: page.elements.length,
                    itemBuilder: (BuildContext context, int index) {
                      final element = page.elements[index];
                      return _buildElementCard(page, index, element);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildElementCard(
    IdocPage page,
    int index,
    Map<String, dynamic> element,
  ) {
    final type = element['type']?.toString() ?? 'unknown';
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: Color(0xFFE4DAC7)),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
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
                  child: Text(_labelize(type)),
                ),
                const SizedBox(width: 10),
                Text('Block ${index + 1}'),
                const Spacer(),
                IconButton(
                  tooltip: 'Move block up',
                  onPressed: index > 0
                      ? () => _moveElement(page, index, -1)
                      : null,
                  icon: const Icon(Icons.arrow_upward),
                ),
                IconButton(
                  tooltip: 'Move block down',
                  onPressed: index < page.elements.length - 1
                      ? () => _moveElement(page, index, 1)
                      : null,
                  icon: const Icon(Icons.arrow_downward),
                ),
                IconButton(
                  tooltip: 'Duplicate block',
                  onPressed: () => _duplicateElement(page, index),
                  icon: const Icon(Icons.copy_outlined),
                ),
                IconButton(
                  tooltip: 'Delete block',
                  onPressed: () => _removeElement(page, index),
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ..._buildFieldEditors(
              data: element,
              hiddenKeys: const <String>{'type'},
              fieldPrefix: 'page-${page.id}-block-$index',
              onChanged: (String key, dynamic value) {
                _mutateDocument('Updated ${_labelize(type)} block.', () {
                  element[key] = value;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInspector(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      color: Colors.white.withValues(alpha: 0.72),
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
            'Document metadata, actions, and advanced JSON stay in this panel.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF5D6668),
            ),
          ),
          const SizedBox(height: 18),
          _buildInspectorSection(
            context,
            title: 'Metadata',
            child: Column(
              children: _buildFieldEditors(
                data: _document.meta,
                fieldPrefix: 'meta',
                preferredOrder: const <String>[
                  'title',
                  'author',
                  'version',
                  'theme',
                  'recommendedFilename',
                ],
                onChanged: (String key, dynamic value) {
                  _mutateDocument('Updated document metadata.', () {
                    _document.meta[key] = value;
                  });
                },
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildInspectorSection(
            context,
            title: 'Actions',
            headerAction: PopupMenuButton<String>(
              onSelected: _addAction,
              itemBuilder: (BuildContext context) {
                return kIdocActionTypes
                    .map(
                      (String type) => PopupMenuItem<String>(
                        value: type,
                        child: Text(_labelize(type)),
                      ),
                    )
                    .toList();
              },
              child: const Icon(Icons.add_circle_outline),
            ),
            child: _document.actions.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: Text(
                      'No actions yet. Add navigation, popup, and export actions here.',
                    ),
                  )
                : Column(
                    children: _document.actions.entries.map((
                      MapEntry<String, dynamic> entry,
                    ) {
                      final actionData = entry.value is Map<String, dynamic>
                          ? entry.value as Map<String, dynamic>
                          : <String, dynamic>{'type': entry.value.toString()};
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 0,
                        color: _selectedActionKey == entry.key
                            ? const Color(0xFFEEF8F6)
                            : const Color(0xFFFFFCF7),
                        shape: RoundedRectangleBorder(
                          side: BorderSide(
                            color: _selectedActionKey == entry.key
                                ? const Color(0xFF0F766E)
                                : const Color(0xFFE4DAC7),
                          ),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: () {
                            setState(() {
                              _selectedActionKey = entry.key;
                            });
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Row(
                                  children: <Widget>[
                                    Expanded(
                                      child: Text(
                                        entry.key,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      onPressed: () => _renameAction(entry.key),
                                      icon: const Icon(Icons.edit_outlined),
                                    ),
                                    IconButton(
                                      onPressed: () => _removeAction(entry.key),
                                      icon: const Icon(Icons.delete_outline),
                                    ),
                                  ],
                                ),
                                ..._buildFieldEditors(
                                  data: actionData,
                                  fieldPrefix: 'action-${entry.key}',
                                  onChanged: (String key, dynamic value) {
                                    _mutateDocument(
                                      'Updated action ${entry.key}.',
                                      () {
                                        actionData[key] = value;
                                        _document.actions[entry.key] =
                                            actionData;
                                      },
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
          ),
          const SizedBox(height: 16),
          _buildInspectorSection(
            context,
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

  Widget _buildInspectorSection(
    BuildContext context, {
    required String title,
    required Widget child,
    Widget? headerAction,
  }) {
    final theme = Theme.of(context);
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
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              // ignore: use_null_aware_elements
              if (headerAction != null) headerAction,
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _buildStatusBar(BuildContext context) {
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

  List<Widget> _buildFieldEditors({
    required Map<String, dynamic> data,
    required String fieldPrefix,
    required void Function(String key, dynamic value) onChanged,
    List<String> preferredOrder = const <String>[],
    Set<String> hiddenKeys = const <String>{},
  }) {
    final visibleKeys = data.keys
        .where((String key) => !hiddenKeys.contains(key))
        .toList(growable: true);
    visibleKeys.sort((String a, String b) {
      final aIndex = preferredOrder.indexOf(a);
      final bIndex = preferredOrder.indexOf(b);
      if (aIndex == -1 && bIndex == -1) {
        return a.compareTo(b);
      }
      if (aIndex == -1) {
        return 1;
      }
      if (bIndex == -1) {
        return -1;
      }
      return aIndex.compareTo(bIndex);
    });

    return visibleKeys
        .map(
          (String key) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildFieldEditor(
              label: key,
              value: data[key],
              fieldId: '$fieldPrefix-$key',
              onChanged: (dynamic value) => onChanged(key, value),
            ),
          ),
        )
        .toList();
  }

  Widget _buildFieldEditor({
    required String label,
    required dynamic value,
    required String fieldId,
    required ValueChanged<dynamic> onChanged,
  }) {
    final normalizedLabel = _labelize(label);
    if (label == 'theme') {
      final selectedValue = value?.toString() == 'dark' ? 'dark' : 'light';
      return DropdownButtonFormField<String>(
        key: ValueKey<String>(fieldId),
        initialValue: selectedValue,
        decoration: InputDecoration(
          labelText: normalizedLabel,
          border: const OutlineInputBorder(),
        ),
        items: const <DropdownMenuItem<String>>[
          DropdownMenuItem<String>(value: 'light', child: Text('Light')),
          DropdownMenuItem<String>(value: 'dark', child: Text('Dark')),
        ],
        onChanged: (String? nextValue) {
          if (nextValue != null) {
            onChanged(nextValue);
          }
        },
      );
    }
    if (value is bool) {
      return SwitchListTile.adaptive(
        value: value,
        contentPadding: const EdgeInsets.symmetric(horizontal: 4),
        title: Text(normalizedLabel),
        onChanged: onChanged,
      );
    }
    if (value is num) {
      return TextFormField(
        key: ValueKey<String>(fieldId),
        initialValue: value.toString(),
        keyboardType: const TextInputType.numberWithOptions(),
        decoration: InputDecoration(
          labelText: normalizedLabel,
          border: const OutlineInputBorder(),
        ),
        onChanged: (String nextValue) {
          final parsed = int.tryParse(nextValue);
          if (parsed != null) {
            onChanged(parsed);
          }
        },
      );
    }
    if (value is List) {
      final stringItems = value.map((dynamic item) => item.toString()).toList();
      return _buildStringListEditor(
        label: normalizedLabel,
        items: stringItems,
        fieldId: fieldId,
        onChanged: (List<String> nextItems) => onChanged(nextItems),
      );
    }
    if (value is Map) {
      return OutlinedButton.icon(
        onPressed: () => _editNestedJsonField(
          title: normalizedLabel,
          initialValue: const JsonEncoder.withIndent('  ').convert(value),
          onApply: (dynamic nextValue) => onChanged(nextValue),
        ),
        icon: const Icon(Icons.data_object_outlined),
        label: Text('Edit $normalizedLabel as JSON'),
      );
    }

    final textValue = value?.toString() ?? '';
    final isMultiline =
        _multilineKeys.contains(label) ||
        textValue.contains('\n') ||
        textValue.length > 88;
    return TextFormField(
      key: ValueKey<String>(fieldId),
      initialValue: textValue,
      minLines: isMultiline ? 3 : 1,
      maxLines: isMultiline ? 8 : 1,
      decoration: InputDecoration(
        labelText: normalizedLabel,
        border: const OutlineInputBorder(),
      ),
      onChanged: onChanged,
    );
  }

  Widget _buildStringListEditor({
    required String label,
    required List<String> items,
    required String fieldId,
    required ValueChanged<List<String>> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD7CCB9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(child: Text(label)),
              IconButton(
                onPressed: () {
                  final nextItems = List<String>.from(items)..add('New item');
                  onChanged(nextItems);
                },
                icon: const Icon(Icons.add_circle_outline),
              ),
            ],
          ),
          ...items.asMap().entries.map((MapEntry<int, String> entry) {
            final index = entry.key;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: TextFormField(
                      key: ValueKey<String>('$fieldId-$index'),
                      initialValue: entry.value,
                      minLines: 1,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: '$label ${index + 1}',
                        border: const OutlineInputBorder(),
                      ),
                      onChanged: (String value) {
                        final nextItems = List<String>.from(items);
                        nextItems[index] = value;
                        onChanged(nextItems);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () {
                      final nextItems = List<String>.from(items)
                        ..removeAt(index);
                      onChanged(nextItems);
                    },
                    icon: const Icon(Icons.remove_circle_outline),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
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
      setState(() {
        _document = IdocDocument.fromJson(json);
        _selectedPageIndex = 0;
        _selectedActionKey = _document.actions.isEmpty
            ? null
            : _document.actions.keys.first;
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
    setState(() {
      _document = createBlankDocument();
      _selectedPageIndex = 0;
      _selectedActionKey = null;
      _status = 'Started a new document.';
    });
  }

  void _resetToDemo() {
    setState(() {
      _document = _demoDocument.deepCopy();
      _selectedPageIndex = 0;
      _selectedActionKey = _document.actions.isEmpty
          ? null
          : _document.actions.keys.first;
      _status = 'Restored the bundled demo document.';
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
            createDefaultElement('heading'),
            createDefaultElement('paragraph'),
          ],
        ),
      );
      _selectedPageIndex += 1;
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
    });
  }

  void _removePage(int index) {
    if (_document.pages.length <= 1) {
      return;
    }
    _mutateDocument('Deleted page ${index + 1}.', () {
      _document.pages.removeAt(index);
      if (_selectedPageIndex >= _document.pages.length) {
        _selectedPageIndex = _document.pages.length - 1;
      }
    });
  }

  void _addBlockToCurrentPage(String type) {
    final page = _currentPage;
    _mutateDocument('Added a ${_labelize(type).toLowerCase()} block.', () {
      page.elements.add(createDefaultElement(type));
    });
  }

  void _moveElement(IdocPage page, int index, int delta) {
    final nextIndex = index + delta;
    if (nextIndex < 0 || nextIndex >= page.elements.length) {
      return;
    }
    _mutateDocument('Reordered blocks.', () {
      final element = page.elements.removeAt(index);
      page.elements.insert(nextIndex, element);
    });
  }

  void _duplicateElement(IdocPage page, int index) {
    _mutateDocument('Duplicated block ${index + 1}.', () {
      final duplicate = Map<String, dynamic>.from(
        jsonDecode(jsonEncode(page.elements[index])) as Map,
      );
      page.elements.insert(index + 1, duplicate);
    });
  }

  void _removeElement(IdocPage page, int index) {
    _mutateDocument('Deleted block ${index + 1}.', () {
      page.elements.removeAt(index);
    });
  }

  void _addAction(String type) {
    final existingKeys = _document.actions.keys;
    final actionKey = createUniqueId(type, existingKeys);
    _mutateDocument('Added action $actionKey.', () {
      _document.actions[actionKey] = createDefaultAction(actionKey, type);
      _selectedActionKey = actionKey;
    });
  }

  void _removeAction(String key) {
    _mutateDocument('Deleted action $key.', () {
      _document.actions.remove(key);
      _selectedActionKey = _document.actions.isEmpty
          ? null
          : _document.actions.keys.first;
    });
  }

  Future<void> _renameAction(String oldKey) async {
    final controller = TextEditingController(text: oldKey);
    final nextKey = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Rename action'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Action key',
              border: OutlineInputBorder(),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(context).pop(controller.text.trim()),
              child: const Text('Apply'),
            ),
          ],
        );
      },
    );

    if (nextKey == null || nextKey.isEmpty || nextKey == oldKey) {
      return;
    }
    if (_document.actions.containsKey(nextKey)) {
      _showError('An action named "$nextKey" already exists.');
      return;
    }

    _mutateDocument('Renamed action $oldKey to $nextKey.', () {
      final value = _document.actions.remove(oldKey);
      if (value != null) {
        _document.actions[nextKey] = value;
        _selectedActionKey = nextKey;
      }
    });
  }

  Future<void> _editNestedJsonField({
    required String title,
    required String initialValue,
    required ValueChanged<dynamic> onApply,
  }) async {
    final controller = TextEditingController(text: initialValue);
    final result = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Edit $title'),
          content: SizedBox(
            width: 620,
            child: TextField(
              controller: controller,
              maxLines: 18,
              minLines: 12,
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(controller.text),
              child: const Text('Apply'),
            ),
          ],
        );
      },
    );

    if (result == null) {
      return;
    }

    try {
      onApply(jsonDecode(result));
    } catch (error) {
      _showError('That JSON field could not be parsed.\n\n$error');
    }
  }

  Future<void> _editRawJson() async {
    final controller = TextEditingController(text: _document.toPrettyJson());
    final result = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Edit raw iDoc JSON'),
          content: SizedBox(
            width: 760,
            child: TextField(
              controller: controller,
              maxLines: 28,
              minLines: 20,
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
              onPressed: () => Navigator.of(context).pop(controller.text),
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
      setState(() {
        _document = IdocDocument.fromJson(parsed);
        _selectedPageIndex = 0;
        _selectedActionKey = _document.actions.isEmpty
            ? null
            : _document.actions.keys.first;
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

const Set<String> _multilineKeys = <String>{
  'text',
  'code',
  'content',
  'prompt',
  'explanation',
  'caption',
  'placeholder',
  'helpText',
  'alt',
  'tex',
  'url',
  'src',
};
