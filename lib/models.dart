enum VehicleKind { bike, car }

class Vehicle {
  const Vehicle({
    required this.id,
    required this.kind,
    required this.name,
    required this.model,
    required this.year,
    required this.registration,
    required this.fuelType,
    required this.engineCc,
    required this.tankCapacity,
    required this.odometer,
  });
  final String id;
  final VehicleKind kind;
  final String name;
  final String model;
  final int year;
  final String registration;
  final String fuelType;
  final int? engineCc;
  final double tankCapacity;
  final double odometer;
  Vehicle copyWith({double? odometer}) => Vehicle(
    id: id,
    kind: kind,
    name: name,
    model: model,
    year: year,
    registration: registration,
    fuelType: fuelType,
    engineCc: engineCc,
    tankCapacity: tankCapacity,
    odometer: odometer ?? this.odometer,
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind.name,
    'name': name,
    'model': model,
    'year': year,
    'registration': registration,
    'fuelType': fuelType,
    'engineCc': engineCc,
    'tankCapacity': tankCapacity,
    'odometer': odometer,
  };
  factory Vehicle.fromJson(Map<String, dynamic> json) => Vehicle(
    id: '${json['id']}',
    kind: VehicleKind.values.byName('${json['kind']}'),
    name: '${json['name']}',
    model: '${json['model']}',
    year: (json['year'] as num).toInt(),
    registration: '${json['registration']}',
    fuelType: '${json['fuelType']}',
    engineCc: (json['engineCc'] as num?)?.toInt(),
    tankCapacity: (json['tankCapacity'] as num).toDouble(),
    odometer: (json['odometer'] as num).toDouble(),
  );
}

class FuelRecord {
  const FuelRecord({
    required this.id,
    required this.vehicleId,
    required this.date,
    required this.odometer,
    required this.litres,
    required this.cost,
    this.place,
    this.latitude,
    this.longitude,
  });
  final String id;
  final String vehicleId;
  final DateTime date;
  final double odometer;
  final double litres;
  final double cost;
  final String? place;
  final double? latitude;
  final double? longitude;
  double get price => litres == 0 ? 0 : cost / litres;
  Map<String, dynamic> toJson() => {
    'id': id,
    'vehicleId': vehicleId,
    'date': date.toIso8601String(),
    'odometer': odometer,
    'litres': litres,
    'cost': cost,
    'place': place,
    'latitude': latitude,
    'longitude': longitude,
  };
  factory FuelRecord.fromJson(Map<String, dynamic> json) => FuelRecord(
    id: '${json['id']}',
    vehicleId: '${json['vehicleId']}',
    date: DateTime.parse('${json['date']}'),
    odometer: (json['odometer'] as num).toDouble(),
    litres: (json['litres'] as num).toDouble(),
    cost: (json['cost'] as num).toDouble(),
    place: json['place'] as String?,
    latitude: (json['latitude'] as num?)?.toDouble(),
    longitude: (json['longitude'] as num?)?.toDouble(),
  );
}

class VehicleDocument {
  const VehicleDocument({
    required this.id,
    required this.vehicleId,
    required this.name,
    required this.paths,
  });
  final String id;
  final String vehicleId;
  final String name;
  final List<String> paths;
  Map<String, dynamic> toJson() => {
    'id': id,
    'vehicleId': vehicleId,
    'name': name,
    'paths': paths,
  };
  factory VehicleDocument.fromJson(Map<String, dynamic> json) =>
      VehicleDocument(
        id: '${json['id']}',
        vehicleId: '${json['vehicleId']}',
        name: '${json['name']}',
        paths: List<String>.from(json['paths'] as List),
      );
}

class ServiceItem {
  const ServiceItem({
    required this.id,
    required this.vehicleId,
    required this.title,
    required this.dueDate,
    this.notes,
  });
  final String id;
  final String vehicleId;
  final String title;
  final DateTime dueDate;
  final String? notes;
  Map<String, dynamic> toJson() => {
    'id': id,
    'vehicleId': vehicleId,
    'title': title,
    'dueDate': dueDate.toIso8601String(),
    'notes': notes,
  };
  factory ServiceItem.fromJson(Map<String, dynamic> json) => ServiceItem(
    id: '${json['id']}',
    vehicleId: '${json['vehicleId']}',
    title: '${json['title']}',
    dueDate: DateTime.parse('${json['dueDate']}'),
    notes: json['notes'] as String?,
  );
}
