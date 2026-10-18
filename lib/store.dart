import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'models.dart';

class Store {
  Future<File> get _file async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}${Platform.pathSeparator}ride_metrics.json');
  }

  Future<Map<String, dynamic>> _read() async {
    try {
      final file = await _file;
      if (!await file.exists()) return {};
      final decoded = jsonDecode(await file.readAsString());
      return decoded is Map ? Map<String, dynamic>.from(decoded) : {};
    } catch (_) {
      return {};
    }
  }

  Future<void> _write(Map<String, dynamic> value) async {
    final file = await _file;
    await file.writeAsString(jsonEncode(value), flush: true);
  }

  Future<List<T>> _list<T>(
    String key,
    T Function(Map<String, dynamic>) fromJson,
  ) async {
    final data = await _read();
    return (data[key] as List? ?? [])
        .map((e) => fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<void> _save<T>(
    String key,
    List<T> items,
    Map<String, dynamic> Function(T) toJson,
  ) async {
    final data = await _read();
    data[key] = items.map(toJson).toList();
    await _write(data);
  }

  Future<List<Vehicle>> vehicles() => _list('vehicles', Vehicle.fromJson);
  Future<void> saveVehicles(List<Vehicle> items) =>
      _save('vehicles', items, (e) => e.toJson());
  Future<List<FuelRecord>> fuel() => _list('fuel', FuelRecord.fromJson);
  Future<void> saveFuel(List<FuelRecord> items) =>
      _save('fuel', items, (e) => e.toJson());
  Future<List<VehicleDocument>> documents() =>
      _list('documents', VehicleDocument.fromJson);
  Future<void> saveDocuments(List<VehicleDocument> items) =>
      _save('documents', items, (e) => e.toJson());
  Future<List<ServiceItem>> services() =>
      _list('services', ServiceItem.fromJson);
  Future<void> saveServices(List<ServiceItem> items) =>
      _save('services', items, (e) => e.toJson());
  Future<double> budget(String vehicleId) async {
    final data = await _read();
    return ((data['budgets'] as Map?)?[vehicleId] as num?)?.toDouble() ?? 0;
  }

  Future<void> saveBudget(String vehicleId, double value) async {
    final data = await _read();
    final budgets = Map<String, dynamic>.from((data['budgets'] as Map?) ?? {});
    budgets[vehicleId] = value;
    data['budgets'] = budgets;
    await _write(data);
  }

  Future<void> deleteVehicle(String vehicleId) async {
    final data = await _read();
    for (final key in ['vehicles', 'fuel', 'documents', 'services']) {
      final items = (data[key] as List? ?? [])
          .where(
            (item) =>
                item is Map &&
                item['vehicleId'] != vehicleId &&
                item['id'] != vehicleId,
          )
          .toList();
      if (key == 'vehicles') {
        data[key] = items;
      } else {
        data[key] = items;
      }
    }
    final budgets = Map<String, dynamic>.from((data['budgets'] as Map?) ?? {});
    budgets.remove(vehicleId);
    data['budgets'] = budgets;
    await _write(data);
  }

  Future<String> copyDocument(String source, String id, int index) async {
    final dir = await getApplicationDocumentsDirectory();
    final out = Directory('${dir.path}${Platform.pathSeparator}documents');
    await out.create(recursive: true);
    final dot = source.lastIndexOf('.');
    final ext = dot >= 0 ? source.substring(dot) : '.bin';
    return (await File(source)
            .copy('${out.path}${Platform.pathSeparator}${id}_$index$ext'))
        .path;
  }
}
