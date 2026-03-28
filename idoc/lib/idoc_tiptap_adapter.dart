import 'dart:convert';

import 'idoc_document.dart';

Map<String, dynamic> buildTiptapPageDocument(IdocPage page) {
  final content = <Map<String, dynamic>>[];
  for (final element in page.elements) {
    final node = _idocElementToTiptapNode(element);
    if (node != null) {
      content.add(node);
    }
  }

  if (content.isEmpty) {
    content.add(_paragraphNode(elementId: _fallbackEditorId()));
  }

  return <String, dynamic>{'type': 'doc', 'content': content};
}

List<Map<String, dynamic>> buildIdocElementsFromTiptapDocument({
  required Map<String, dynamic> doc,
  required IdocPage page,
}) {
  final existingById = <String, Map<String, dynamic>>{
    for (final element in page.elements) _editorIdFor(element): _deepCopy(element),
  };
  final usedIds = <String>{};
  final usedQuestionIds = <String>{
    for (final element in page.elements)
      if (_elementType(element) == 'question' && _textValue(element['id']).isNotEmpty)
        _textValue(element['id']),
  };
  final usedInputIds = <String>{
    for (final element in page.elements)
      if (_elementType(element) == 'input' && _textValue(element['id']).isNotEmpty)
        _textValue(element['id']),
  };
  final content = doc['content'] is List ? doc['content'] as List<dynamic> : const <dynamic>[];
  final result = <Map<String, dynamic>>[];

  for (final rawNode in content) {
    final node = _asMap(rawNode);
    final serialized = _tiptapNodeToIdocElement(
      node: node,
      existingById: existingById,
      usedIds: usedIds,
      usedQuestionIds: usedQuestionIds,
      usedInputIds: usedInputIds,
    );
    if (serialized != null) {
      result.add(serialized);
    }
  }

  if (result.isEmpty) {
    final paragraph = createDefaultElement('paragraph');
    paragraph['_editorId'] = createUniqueId('block', usedIds);
    result.add(paragraph);
  }

  return result;
}

Map<String, dynamic>? _idocElementToTiptapNode(Map<String, dynamic> element) {
  final type = _elementType(element);
  final elementId = _editorIdFor(element);
  final fontSize = element['fontSize'];
  switch (type) {
    case 'heading':
      return <String, dynamic>{
        'type': 'heading',
        'attrs': <String, dynamic>{
          'level': _numberValue(element['level'], fallback: 1).clamp(1, 3),
          'elementId': elementId,
          'fontSize': fontSize,
        },
        'content': _textToInlineContent(_textValue(element['text'])),
      };
    case 'paragraph':
    case 'text':
      return _paragraphNode(
        elementId: elementId,
        elementType: type,
        text: _textValue(element['text']),
        fontSize: fontSize,
      );
    case 'quote':
      return <String, dynamic>{
        'type': 'blockquote',
        'attrs': <String, dynamic>{
          'elementId': elementId,
          'fontSize': fontSize,
        },
        'content': <Map<String, dynamic>>[
          _paragraphNode(
            elementId: elementId,
            text: _textValue(element['text']),
            fontSize: fontSize,
          ),
        ],
      };
    case 'list':
      final items = _stringList(element['items']);
      return <String, dynamic>{
        'type': element['ordered'] == true ? 'orderedList' : 'bulletList',
        'attrs': <String, dynamic>{
          'elementId': elementId,
          'fontSize': fontSize,
        },
        'content': items.isEmpty
            ? <Map<String, dynamic>>[
                _listItemNode(text: '', fontSize: fontSize),
              ]
            : items
                .map(
                  (item) => _listItemNode(text: item, fontSize: fontSize),
                )
                .toList(),
      };
    case 'separator':
      return <String, dynamic>{
        'type': 'horizontalRule',
        'attrs': <String, dynamic>{'elementId': elementId},
      };
    default:
      return <String, dynamic>{
        'type': 'idocBlock',
        'attrs': <String, dynamic>{
          'elementId': elementId,
          'elementType': type,
          'width': _widthValue(element['width'], fallback: 1),
          'preview': _previewForElement(element),
        },
      };
  }
}

Map<String, dynamic> _paragraphNode({
  required String elementId,
  String elementType = 'paragraph',
  String text = '',
  dynamic fontSize,
}) {
  return <String, dynamic>{
    'type': 'paragraph',
    'attrs': <String, dynamic>{
      'elementId': elementId,
      'elementType': elementType,
      'fontSize': fontSize,
    },
    if (_textToInlineContent(text).isNotEmpty) 'content': _textToInlineContent(text),
  };
}

Map<String, dynamic> _listItemNode({required String text, dynamic fontSize}) {
  return <String, dynamic>{
    'type': 'listItem',
    'content': <Map<String, dynamic>>[
      <String, dynamic>{
        'type': 'paragraph',
        'attrs': <String, dynamic>{'fontSize': fontSize},
        if (_textToInlineContent(text).isNotEmpty) 'content': _textToInlineContent(text),
      },
    ],
  };
}

List<Map<String, dynamic>> _textToInlineContent(String text) {
  if (text.isEmpty) {
    return const <Map<String, dynamic>>[];
  }
  final pieces = text.split('\n');
  final content = <Map<String, dynamic>>[];
  for (var index = 0; index < pieces.length; index += 1) {
    if (pieces[index].isNotEmpty) {
      content.add(<String, dynamic>{'type': 'text', 'text': pieces[index]});
    }
    if (index < pieces.length - 1) {
      content.add(const <String, dynamic>{'type': 'hardBreak'});
    }
  }
  return content;
}

Map<String, dynamic>? _tiptapNodeToIdocElement({
  required Map<String, dynamic> node,
  required Map<String, Map<String, dynamic>> existingById,
  required Set<String> usedIds,
  required Set<String> usedQuestionIds,
  required Set<String> usedInputIds,
}) {
  final type = _textValue(node['type']);
  final attrs = _asMap(node['attrs']);
  final existingId = _textValue(attrs['elementId']);
  final elementId = existingId.isEmpty || usedIds.contains(existingId)
      ? createUniqueId('block', usedIds)
      : existingId;
  usedIds.add(elementId);

  switch (type) {
    case 'heading':
      final heading = existingById[elementId] ?? createDefaultElement('heading');
      heading
        ..['type'] = 'heading'
        ..['level'] = _numberValue(attrs['level'], fallback: 1).clamp(1, 3)
        ..['text'] = _extractInlineText(node['content'])
        ..['_editorId'] = elementId;
      _applyFontSizeFromAttrs(heading, attrs);
      return heading;
    case 'paragraph':
      final elementType = _textValue(attrs['elementType'], fallback: 'paragraph');
      final paragraph = existingById[elementId] ??
          createDefaultElement(elementType == 'text' ? 'text' : 'paragraph');
      paragraph
        ..['type'] = elementType == 'text' ? 'text' : 'paragraph'
        ..['text'] = _extractInlineText(node['content'])
        ..['_editorId'] = elementId;
      _applyFontSizeFromAttrs(paragraph, attrs);
      return paragraph;
    case 'blockquote':
      final quote = existingById[elementId] ?? createDefaultElement('quote');
      quote
        ..['type'] = 'quote'
        ..['text'] = _extractBlockquoteText(node['content'])
        ..['_editorId'] = elementId;
      quote.putIfAbsent('cite', () => '');
      _applyFontSizeFromAttrs(quote, attrs);
      return quote;
    case 'bulletList':
    case 'orderedList':
      final list = existingById[elementId] ?? createDefaultElement('list');
      list
        ..['type'] = 'list'
        ..['ordered'] = type == 'orderedList'
        ..['items'] = _extractListItems(node['content'])
        ..['_editorId'] = elementId;
      _applyFontSizeFromAttrs(list, attrs);
      return list;
    case 'horizontalRule':
      final separator = existingById[elementId] ?? createDefaultElement('separator');
      separator
        ..['type'] = 'separator'
        ..['_editorId'] = elementId;
      return separator;
    case 'idocBlock':
      final elementType = _textValue(attrs['elementType'], fallback: 'callout');
      final block = existingById[elementId] ?? createDefaultElement(elementType);
      block
        ..['type'] = elementType
        ..['_editorId'] = elementId;
      if (block['type'] == 'question') {
        final currentId = _textValue(block['id']);
        if (currentId.isEmpty || usedQuestionIds.contains(currentId)) {
          block['id'] = createUniqueId('question', usedQuestionIds);
        }
        usedQuestionIds.add(_textValue(block['id']));
      }
      if (block['type'] == 'input') {
        final currentId = _textValue(block['id']);
        if (currentId.isEmpty || usedInputIds.contains(currentId)) {
          block['id'] = createUniqueId('input', usedInputIds);
        }
        usedInputIds.add(_textValue(block['id']));
      }
      return block;
    default:
      return null;
  }
}

void _applyFontSizeFromAttrs(
  Map<String, dynamic> element,
  Map<String, dynamic> attrs,
) {
  final value = attrs['fontSize'];
  if (value is num) {
    element['fontSize'] = value.round();
  } else {
    element.remove('fontSize');
  }
}

String _extractInlineText(dynamic rawContent) {
  if (rawContent is! List) {
    return '';
  }
  final buffer = StringBuffer();
  for (final rawNode in rawContent) {
    final node = _asMap(rawNode);
    final type = _textValue(node['type']);
    if (type == 'text') {
      buffer.write(_textValue(node['text']));
    } else if (type == 'hardBreak') {
      buffer.write('\n');
    }
  }
  return buffer.toString();
}

String _extractBlockquoteText(dynamic rawContent) {
  if (rawContent is! List) {
    return '';
  }
  final paragraphs = <String>[];
  for (final rawNode in rawContent) {
    final node = _asMap(rawNode);
    if (_textValue(node['type']) == 'paragraph') {
      paragraphs.add(_extractInlineText(node['content']));
    }
  }
  return paragraphs.join('\n\n');
}

List<String> _extractListItems(dynamic rawContent) {
  if (rawContent is! List) {
    return <String>[''];
  }
  final items = <String>[];
  for (final rawNode in rawContent) {
    final node = _asMap(rawNode);
    if (_textValue(node['type']) != 'listItem') {
      continue;
    }
    final paragraphs = node['content'] is List ? node['content'] as List<dynamic> : const <dynamic>[];
    final buffer = <String>[];
    for (final paragraphRaw in paragraphs) {
      final paragraph = _asMap(paragraphRaw);
      if (_textValue(paragraph['type']) == 'paragraph') {
        buffer.add(_extractInlineText(paragraph['content']));
      }
    }
    items.add(buffer.join('\n'));
  }
  return items.isEmpty ? <String>[''] : items;
}

String _previewForElement(Map<String, dynamic> element) {
  final type = _elementType(element);
  switch (type) {
    case 'button':
    case 'link':
    case 'heading':
    case 'paragraph':
    case 'text':
      return _textValue(element['label']).isNotEmpty
          ? _textValue(element['label'])
          : _textValue(element['text']);
    case 'callout':
      return _textValue(element['title']).isNotEmpty
          ? _textValue(element['title'])
          : _textValue(element['text']);
    case 'code':
      return _textValue(element['language']).isNotEmpty
          ? _textValue(element['language'])
          : 'Code block';
    case 'math':
      return _textValue(element['tex'], fallback: 'Math block');
    case 'image':
      return _textValue(element['alt']).isNotEmpty
          ? _textValue(element['alt'])
          : _textValue(element['caption']);
    case 'question':
      return _textValue(element['prompt']);
    case 'input':
      return _textValue(element['label']);
    case 'list':
      final items = _stringList(element['items']);
      return items.isEmpty ? 'List' : items.first;
    case 'quote':
      return _textValue(element['text']);
    case 'spacer':
      return 'Spacer';
    case 'pagebreak':
      return 'Page break';
    default:
      return _labelize(type);
  }
}

String _editorIdFor(Map<String, dynamic> element) {
  final value = _textValue(element['_editorId']);
  return value.isEmpty ? _fallbackEditorId() : value;
}

String _fallbackEditorId() {
  return 'block-${DateTime.now().microsecondsSinceEpoch}';
}

String _elementType(Map<String, dynamic> element) {
  return _textValue(element['type'], fallback: 'paragraph');
}

String _textValue(dynamic value, {String fallback = ''}) {
  final text = value?.toString() ?? fallback;
  return text.trim().isEmpty && fallback.isNotEmpty ? fallback : text;
}

int _numberValue(dynamic value, {int fallback = 0}) {
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

double _widthValue(dynamic value, {double fallback = 1}) {
  if (value is num) {
    return value.toDouble().clamp(0.2, 1.0);
  }
  return fallback;
}

List<String> _stringList(dynamic value) {
  if (value is List) {
    return value.map((item) => item?.toString() ?? '').toList();
  }
  return const <String>[];
}

Map<String, dynamic> _asMap(dynamic value) {
  if (value is Map) {
    return value.map(
      (key, val) => MapEntry<String, dynamic>(key.toString(), val),
    );
  }
  return <String, dynamic>{};
}

Map<String, dynamic> _deepCopy(Map<String, dynamic> value) {
  return Map<String, dynamic>.from(
    jsonDecode(jsonEncode(value)) as Map,
  );
}

String _labelize(String value) {
  if (value.isEmpty) {
    return 'Block';
  }
  final replaced = value.replaceAll(RegExp(r'[_-]+'), ' ');
  return replaced[0].toUpperCase() + replaced.substring(1);
}
