import 'package:flutter_test/flutter_test.dart';
import 'package:idoc/idoc_document.dart';

void main() {
  test('blank iDoc starts with one page and metadata defaults', () {
    final document = createBlankDocument();

    expect(document.pages, isNotEmpty);
    expect(document.meta['title'], 'Untitled iDoc');
    expect(document.meta['theme'], 'light');
  });
}
