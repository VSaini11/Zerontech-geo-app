import 'dart:io';
import 'package:path_provider/path_provider.dart';

Future<void> saveOrDownload(String content, String fileName) async {
  try {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$fileName');
    await file.writeAsString(content);
  } catch (_) {}
}
