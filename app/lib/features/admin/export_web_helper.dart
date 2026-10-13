// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

void saveOrDownload(String content, String fileName) {
  try {
    final blob = html.Blob([content], 'text/csv;charset=utf-8');
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', fileName)
      ..click();
    html.Url.revokeObjectUrl(url);
  } catch (_) {}
}
