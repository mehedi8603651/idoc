import 'package:flutter_test/flutter_test.dart';
import 'package:idoc/idoc_document.dart';

void main() {
  test('blank iDoc starts with one page and metadata defaults', () {
    final document = createBlankDocument();

    expect(document.pages, isNotEmpty);
    expect(document.meta['title'], 'Untitled iDoc');
    expect(document.meta['theme'], 'light');
    expect(document.pages.single.elements, hasLength(1));
    expect(document.pages.single.elements.single['type'], 'paragraph');
    expect(document.pages.single.elements.single['text'], isEmpty);
  });

  test('missing pages normalize to a paragraph-first page', () {
    final document = IdocDocument.fromJson(<String, dynamic>{
      'meta': <String, dynamic>{'title': 'Imported'},
      'pages': <dynamic>[],
    });

    expect(document.pages, hasLength(1));
    expect(document.pages.single.elements, hasLength(1));
    expect(document.pages.single.elements.single['type'], 'paragraph');
  });
}
