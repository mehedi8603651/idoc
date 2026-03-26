import 'dart:convert';

const List<String> kIdocElementTypes = <String>[
  'heading',
  'paragraph',
  'text',
  'math',
  'image',
  'button',
  'link',
  'separator',
  'callout',
  'code',
  'spacer',
  'quote',
  'list',
  'question',
  'input',
  'pagebreak',
];

const List<String> kIdocActionTypes = <String>[
  'popup',
  'gotoPage',
  'openLink',
  'toggleTheme',
  'alert',
  'closePopup',
  'setState',
  'evaluateQuestion',
  'showAnswer',
  'saveDocument',
  'exportDocument',
];

class IdocDocument {
  IdocDocument({
    required this.meta,
    required this.state,
    required this.pages,
    required this.actions,
  });

  factory IdocDocument.fromJson(Map<String, dynamic> json) {
    final meta = _asStringKeyedMap(json['meta']);
    final state = _asStringKeyedMap(json['state']);
    final rawPages = json['pages'] is List
        ? json['pages'] as List<dynamic>
        : <dynamic>[];
    final pages = rawPages
        .map((dynamic raw) => IdocPage.fromJson(_asStringKeyedMap(raw)))
        .toList();
    final actions = _asStringKeyedMap(json['actions']);

    if (pages.isEmpty) {
      pages.add(
        IdocPage(
          id: 'page-1',
          title: 'Page 1',
          elements: <Map<String, dynamic>>[
            createDefaultElement('heading'),
            createDefaultElement('paragraph'),
          ],
        ),
      );
    }

    meta.putIfAbsent('title', () => 'Untitled iDoc');
    meta.putIfAbsent('author', () => 'iDoc Studio');
    meta.putIfAbsent('version', () => '1.0');
    meta.putIfAbsent('theme', () => 'light');
    meta.putIfAbsent('recommendedFilename', () => 'document.idoc.html');
    state.putIfAbsent('currentPage', () => 0);

    return IdocDocument(
      meta: meta,
      state: state,
      pages: pages,
      actions: actions.map(
        (String key, dynamic value) =>
            MapEntry<String, dynamic>(key, _normalizeJsonValue(value)),
      ),
    );
  }

  Map<String, dynamic> meta;
  Map<String, dynamic> state;
  List<IdocPage> pages;
  Map<String, dynamic> actions;

  String get title => meta['title']?.toString() ?? 'Untitled iDoc';

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'meta': _normalizeJsonValue(meta),
      'state': _normalizeJsonValue(state),
      'pages': pages.map((IdocPage page) => page.toJson()).toList(),
      'actions': _normalizeJsonValue(actions),
    };
  }

  String toPrettyJson() {
    return const JsonEncoder.withIndent('  ').convert(toJson());
  }

  IdocDocument deepCopy() {
    return IdocDocument.fromJson(
      Map<String, dynamic>.from(jsonDecode(jsonEncode(toJson())) as Map),
    );
  }
}

class IdocPage {
  IdocPage({required this.id, required this.title, required this.elements});

  factory IdocPage.fromJson(Map<String, dynamic> json) {
    final rawElements = json['elements'] is List
        ? json['elements'] as List<dynamic>
        : <dynamic>[];
    return IdocPage(
      id: json['id']?.toString().trim().isNotEmpty == true
          ? json['id'].toString()
          : 'page-1',
      title: json['title']?.toString() ?? 'Untitled Page',
      elements: rawElements
          .map((dynamic raw) => _asStringKeyedMap(raw))
          .toList(growable: true),
    );
  }

  String id;
  String title;
  List<Map<String, dynamic>> elements;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'title': title,
      'elements': elements.map(_normalizeJsonValue).toList(),
    };
  }
}

IdocDocument createBlankDocument() {
  return IdocDocument(
    meta: <String, dynamic>{
      'title': 'Untitled iDoc',
      'author': 'iDoc Studio',
      'version': '1.0',
      'theme': 'light',
      'recommendedFilename': 'document.idoc.html',
    },
    state: <String, dynamic>{'currentPage': 0},
    pages: <IdocPage>[
      IdocPage(
        id: 'page-1',
        title: 'Page 1',
        elements: <Map<String, dynamic>>[
          createDefaultElement('heading'),
          createDefaultElement('paragraph'),
        ],
      ),
    ],
    actions: <String, dynamic>{},
  );
}

Map<String, dynamic> createDefaultElement(String type) {
  switch (type) {
    case 'heading':
      return <String, dynamic>{
        'type': 'heading',
        'level': 1,
        'text': 'New heading',
      };
    case 'paragraph':
      return <String, dynamic>{
        'type': 'paragraph',
        'text': 'Write paragraph text here.',
      };
    case 'text':
      return <String, dynamic>{
        'type': 'text',
        'text': 'Short supporting text.',
      };
    case 'math':
      return <String, dynamic>{
        'type': 'math',
        'tex': r'\frac{a}{b} = c',
        'displayMode': true,
      };
    case 'image':
      return <String, dynamic>{
        'type': 'image',
        'src': '',
        'alt': 'Describe the image',
        'caption': '',
      };
    case 'button':
      return <String, dynamic>{'type': 'button', 'label': 'Run action'};
    case 'link':
      return <String, dynamic>{'type': 'link', 'label': 'Open link'};
    case 'separator':
      return <String, dynamic>{'type': 'separator'};
    case 'callout':
      return <String, dynamic>{
        'type': 'callout',
        'tone': 'info',
        'title': 'Callout title',
        'text': 'Helpful side note or warning.',
      };
    case 'code':
      return <String, dynamic>{
        'type': 'code',
        'language': 'js',
        'code': 'console.log("Hello from iDoc");',
      };
    case 'spacer':
      return <String, dynamic>{'type': 'spacer', 'size': 16};
    case 'quote':
      return <String, dynamic>{
        'type': 'quote',
        'text': 'Quoted text goes here.',
        'cite': 'Source',
      };
    case 'list':
      return <String, dynamic>{
        'type': 'list',
        'ordered': false,
        'items': <String>['First item', 'Second item'],
      };
    case 'question':
      return <String, dynamic>{
        'type': 'question',
        'id': 'question-1',
        'questionType': 'mcq',
        'prompt': 'Choose the correct answer',
        'options': <String>['Option A', 'Option B'],
        'answer': 0,
        'explanation': 'Add a short explanation.',
      };
    case 'input':
      return <String, dynamic>{
        'type': 'input',
        'id': 'input-1',
        'label': 'Input label',
        'placeholder': 'Type here',
        'helpText': 'Helper text',
      };
    case 'pagebreak':
      return <String, dynamic>{'type': 'pagebreak'};
    default:
      return <String, dynamic>{'type': type, 'text': 'Unsupported block type'};
  }
}

Map<String, dynamic> createDefaultAction(String key, String type) {
  switch (type) {
    case 'popup':
      return <String, dynamic>{
        'type': 'popup',
        'title': 'Popup title',
        'content': 'Popup content',
      };
    case 'gotoPage':
      return <String, dynamic>{'type': 'gotoPage', 'page': 0};
    case 'openLink':
      return <String, dynamic>{
        'type': 'openLink',
        'url': 'https://example.com/',
      };
    case 'toggleTheme':
      return <String, dynamic>{'type': 'toggleTheme'};
    case 'alert':
      return <String, dynamic>{
        'type': 'alert',
        'title': 'Alert',
        'content': 'Alert content',
      };
    case 'closePopup':
      return <String, dynamic>{'type': 'closePopup'};
    case 'setState':
      return <String, dynamic>{
        'type': 'setState',
        'key': key,
        'value': 'value',
      };
    case 'evaluateQuestion':
      return <String, dynamic>{
        'type': 'evaluateQuestion',
        'target': 'question-1',
      };
    case 'showAnswer':
      return <String, dynamic>{'type': 'showAnswer', 'target': 'question-1'};
    case 'saveDocument':
      return <String, dynamic>{'type': 'saveDocument'};
    case 'exportDocument':
      return <String, dynamic>{'type': 'exportDocument'};
    default:
      return <String, dynamic>{'type': type};
  }
}

String createUniqueId(String prefix, Iterable<String> existing) {
  var index = 1;
  while (true) {
    final candidate = '$prefix-$index';
    if (!existing.contains(candidate)) {
      return candidate;
    }
    index += 1;
  }
}

Map<String, dynamic> _asStringKeyedMap(dynamic value) {
  if (value is Map) {
    return value.map(
      (dynamic key, dynamic val) =>
          MapEntry<String, dynamic>(key.toString(), _normalizeJsonValue(val)),
    );
  }
  return <String, dynamic>{};
}

dynamic _normalizeJsonValue(dynamic value) {
  if (value is Map) {
    return value.map(
      (dynamic key, dynamic val) =>
          MapEntry<String, dynamic>(key.toString(), _normalizeJsonValue(val)),
    );
  }
  if (value is List) {
    return value.map<dynamic>(_normalizeJsonValue).toList();
  }
  return value;
}
