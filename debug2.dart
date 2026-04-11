import 'dart:io';
import 'dart:convert';
import 'package:path/path.dart' as p;

void main() async {
  final dir = Directory('C:\\Users\\bhage\\OneDrive\\Documents\\Ricochet\\Pipelines\\Quality Check');
  await for (final entity in dir.list()) {
    if (entity is File && p.basename(entity.path).startsWith('pipeline')) {
      print(p.basename(entity.path));
      final jsonStr = await entity.readAsString();
      final data = jsonDecode(jsonStr);
      print('Nodes: \');
    }
  }
}
