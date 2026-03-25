import 'dart:convert';

import 'idoc_document.dart';

Map<String, dynamic> extractDocumentJsonFromContent(String content) {
  final trimmed = content.trim();
  final jsonText = trimmed.startsWith('{')
      ? trimmed
      : _extractEmbeddedJson(trimmed);
  final decoded = jsonDecode(jsonText);
  if (decoded is! Map) {
    throw const FormatException('The document must decode to a JSON object.');
  }
  return Map<String, dynamic>.from(decoded);
}

String buildRuntimeHtml({
  required String template,
  required IdocDocument document,
}) {
  final prettyJson = document.toPrettyJson().replaceAll(
    '</script',
    r'<\/script',
  );
  return template
      .replaceAll('__IDOC_TITLE__', _escapeHtml(document.title))
      .replaceAll('__IDOC_JSON__', prettyJson);
}

String suggestHtmlFilename(IdocDocument document) {
  final recommended =
      document.meta['recommendedFilename']?.toString().trim() ?? '';
  if (recommended.isNotEmpty) {
    return recommended.endsWith('.html') ? recommended : '$recommended.html';
  }

  final slug = _slugify(document.title);
  return slug.isEmpty ? 'document.idoc.html' : '$slug.idoc.html';
}

String suggestJsonFilename(IdocDocument document) {
  final htmlName = suggestHtmlFilename(document);
  if (htmlName.endsWith('.idoc.html')) {
    return htmlName.replaceFirst('.idoc.html', '.idoc.json');
  }
  if (htmlName.endsWith('.html')) {
    return htmlName.replaceFirst('.html', '.json');
  }
  return '$htmlName.json';
}

String _extractEmbeddedJson(String html) {
  final match = RegExp(
    '<script[^>]*id=["\']idoc-data["\'][^>]*>([\\s\\S]*?)</script>',
    caseSensitive: false,
  ).firstMatch(html);
  if (match == null || match.group(1) == null) {
    throw const FormatException(
      'No <script id="idoc-data"> JSON block was found in this file.',
    );
  }
  return match.group(1)!.trim();
}

String _escapeHtml(String value) {
  return value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&#39;');
}

String _slugify(String input) {
  final cleaned = input
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'-+'), '-')
      .replaceAll(RegExp(r'^-|-$'), '');
  return cleaned;
}
