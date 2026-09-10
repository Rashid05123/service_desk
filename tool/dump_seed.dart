/// Выгрузка начального набора в api/seed.json.
///
/// Учебный сервер обязан отдавать те же записи, с которыми приложение
/// работало в ПР3. Переписывать 868 строк начального набора на JavaScript
/// вручную — гарантированное расхождение данных, которое потом ищется
/// по несовпадающим идентификаторам. Поэтому набор выгружается тем же
/// методом toJson, которым он писался в localStorage.
///
///   dart run tool/dump_seed.dart
library;

import 'dart:convert';
import 'dart:io';

import 'package:service_desk/data/seed_data.dart';

void main() {
  final data = {
    'departments': seedDepartments.map((e) => e.toJson()).toList(),
    'categories': seedCategories.map((e) => e.toJson()).toList(),
    'employees': seedEmployees.map((e) => e.toJson()).toList(),
    'requesters': seedRequesters.map((e) => e.toJson()).toList(),
    'tickets': seedTickets.map((e) => e.toJson()).toList(),
  };

  final file = File('api/seed.json');
  file.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(data));

  for (final entry in data.entries) {
    stdout.writeln('${entry.key}: ${entry.value.length}');
  }
  stdout.writeln('записано в ${file.path}');
}
