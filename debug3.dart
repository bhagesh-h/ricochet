import 'dart:convert';
import 'package:Ricochet/models/pipeline_file.dart';
import 'dart:io';

void main() async {
  final content = await File('C:\\Users\\bhage\\OneDrive\\Documents\\code\\ricochet\\lib\\models\\pipeline_file.dart').readAsString();
  print('Loaded model');
}
