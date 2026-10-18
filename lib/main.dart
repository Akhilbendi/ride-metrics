import 'dart:io';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';

import 'models.dart';
import 'store.dart';

const ink = Color(0xff07111d);
const panel = Color(0xff101d2c);
const cyan = Color(0xff00d9ff);
const lime = Color(0xffb7f34a);
final money = NumberFormat.currency(symbol: '₹', decimalDigits: 0);
final shortDate = DateFormat('d MMM yyyy');

void main() => runApp(const App());

class App extends StatelessWidget {
  const App({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'Ride Metrics',
    theme: ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: ink,
      colorScheme: ColorScheme.fromSeed(
        seedColor: cyan,
        brightness: Brightness.dark,
      ),
      cardTheme: const CardThemeData(color: panel, margin: EdgeInsets.zero),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: panel,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    ),
    home: const Dashboard(),
  );
}

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});
  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  final store = Store();
  List<Vehicle> vehicles = [];
  List<FuelRecord> fuel = [];
  List<ServiceItem> services = [];
  Vehicle? active;
  bool loading = true;
  bool showingVehicleList = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final previousId = active?.id;
    final loadedVehicles = await store.vehicles();
    final loadedFuel = await store.fuel();
    final loadedServices = await store.services();
    if (!mounted) return;
    setState(() {
      vehicles = loadedVehicles;
      fuel = loadedFuel;
      services = loadedServices;
      active =
          loadedVehicles.where((item) => item.id == previousId).firstOrNull ??
          loadedVehicles.firstOrNull;
      loading = false;
    });
  }

  Future<void> _deleteVehicle(Vehicle vehicle) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Remove ${vehicle.name}?'),
        content: const Text(
          'This removes the vehicle and all of its fuel entries, documents, reminders and budget data from this device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove vehicle'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await store.deleteVehicle(vehicle.id);
    await _load();
  }

  Future<void> _addVehicle() async {
    final result = await Navigator.push<Vehicle>(
      context,
      MaterialPageRoute(builder: (_) => const VehicleForm()),
    );
    if (result == null) return;
    final updated = [...vehicles, result];
    await store.saveVehicles(updated);
    if (mounted)
      setState(() {
        vehicles = updated;
        active = result;
        showingVehicleList = true;
      });
  }

  Future<void> _open(Widget page) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => page));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    if (loading)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (active == null)
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'assets/ride_metrics_logo.png',
                  width: 112,
                  height: 112,
                ),
                const SizedBox(height: 18),
                Text(
                  'Your rides, measured.',
                  style: Theme.of(context).textTheme.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Track fuel, maintenance, documents and running costs in one private offline app.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _addVehicle,
                  icon: const Icon(Icons.add),
                  label: const Text('Add your first vehicle'),
                ),
              ],
            ),
          ),
        ),
      );

    if (showingVehicleList) {
      return Scaffold(
        appBar: AppBar(title: const Text('Your vehicles')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            Text(
              'Select a vehicle',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 6),
            const Text(
              'Open a vehicle to see its fuel, documents, reminders and insights.',
            ),
            const SizedBox(height: 18),
            ...vehicles.map(
              (vehicle) => _VehicleChooserTile(
                vehicle: vehicle,
                onTap: () => setState(() {
                  active = vehicle;
                  showingVehicleList = false;
                }),
              ),
            ),
            _AddVehicleTile(onTap: _addVehicle),
          ],
        ),
      );
    }

    final vehicle = active!;
    final vehicleFuel = fuel.where((e) => e.vehicleId == vehicle.id).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    final vehicleServices =
        services.where((e) => e.vehicleId == vehicle.id).toList()
          ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
    final ascendingFuel = [...vehicleFuel]
      ..sort((a, b) => a.date.compareTo(b.date));
    final mileageValues = <double>[];
    for (var i = 1; i < ascendingFuel.length; i++) {
      final distance =
          ascendingFuel[i].odometer - ascendingFuel[i - 1].odometer;
      if (distance > 0 && ascendingFuel[i].litres > 0)
        mileageValues.add(distance / ascendingFuel[i].litres);
    }
    final averageMileage = mileageValues.isEmpty
        ? 0.0
        : mileageValues.reduce((a, b) => a + b) / mileageValues.length;
    final totalSpend = vehicleFuel.fold<double>(
      0,
      (sum, item) => sum + item.cost,
    );
    final avgPrice = vehicleFuel.isEmpty
        ? 0
        : vehicleFuel.fold<double>(0, (sum, item) => sum + item.price) /
              vehicleFuel.length;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ride Metrics'),
        actions: [
          IconButton(
            onPressed: () => setState(() => showingVehicleList = true),
            icon: const Icon(Icons.grid_view_rounded),
            tooltip: 'All vehicles',
          ),
          IconButton(
            onPressed: _addVehicle,
            icon: const Icon(Icons.add_circle_outline),
            tooltip: 'Add vehicle',
          ),
        ],
      ),
      drawer: _VehicleDrawer(
        vehicles: vehicles,
        active: vehicle,
        onSelect: (v) {
          setState(() => active = v);
          Navigator.pop(context);
        },
        onAdd: _addVehicle,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _open(FuelPage(vehicle: vehicle, store: store)),
        icon: const Icon(Icons.local_gas_station),
        label: const Text('Add fuel'),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
          children: [
            _VehicleHeader(
              vehicle: vehicle,
              onEdit: () async {
                final edited = await Navigator.push<Vehicle>(
                  context,
                  MaterialPageRoute(builder: (_) => VehicleForm(old: vehicle)),
                );
                if (edited == null) return;
                final updated = vehicles
                    .map((e) => e.id == edited.id ? edited : e)
                    .toList();
                await store.saveVehicles(updated);
                if (mounted)
                  setState(() {
                    vehicles = updated;
                    active = edited;
                  });
              },
              onDelete: () => _deleteVehicle(vehicle),
            ),
            const SizedBox(height: 18),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              childAspectRatio: 1.55,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              children: [
                _DashboardMetric(
                  label: 'Average mileage',
                  value: averageMileage == 0
                      ? 'Add 2 fills'
                      : '${averageMileage.toStringAsFixed(1)} km/L',
                  icon: Icons.speed_rounded,
                ),
                _DashboardMetric(
                  label: 'Fuel spent',
                  value: money.format(totalSpend),
                  icon: Icons.payments_outlined,
                ),
                _DashboardMetric(
                  label: 'Latest odometer',
                  value: vehicleFuel.isEmpty
                      ? 'No data'
                      : '${vehicleFuel.first.odometer.toStringAsFixed(0)} km',
                  icon: Icons.pin_outlined,
                ),
                _DashboardMetric(
                  label: 'Est. full range',
                  value: averageMileage == 0
                      ? 'Need mileage'
                      : '${(averageMileage * vehicle.tankCapacity).toStringAsFixed(0)} km',
                  icon: Icons.route_outlined,
                ),
              ],
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    label: 'Fuel spend',
                    value: money.format(totalSpend),
                    icon: Icons.payments_outlined,
                    color: lime,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _StatCard(
                    label: 'Avg. price/L',
                    value: avgPrice == 0 ? '—' : money.format(avgPrice),
                    icon: Icons.trending_up,
                    color: cyan,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            Text(
              'Quick actions',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 10),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              childAspectRatio: 1.8,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              children: [
                _QuickAction(
                  label: 'Fuel log',
                  icon: Icons.local_gas_station,
                  onTap: () => _open(FuelPage(vehicle: vehicle, store: store)),
                ),
                _QuickAction(
                  label: 'Documents',
                  icon: Icons.folder_copy_outlined,
                  onTap: () =>
                      _open(DocumentsPage(vehicle: vehicle, store: store)),
                ),
                _QuickAction(
                  label: 'Service',
                  icon: Icons.build_outlined,
                  onTap: () =>
                      _open(ServicesPage(vehicle: vehicle, store: store)),
                ),
                _QuickAction(
                  label: 'Insights',
                  icon: Icons.insights_outlined,
                  onTap: () =>
                      _open(InsightsPage(vehicle: vehicle, store: store)),
                ),
              ],
            ),
            const SizedBox(height: 22),
            _SectionTitle(
              title: 'Recent fuel',
              action: vehicleFuel.isEmpty ? null : 'View all',
              onTap: () => _open(FuelPage(vehicle: vehicle, store: store)),
            ),
            if (vehicleFuel.isEmpty)
              const _EmptyCard(
                icon: Icons.local_gas_station_outlined,
                text: 'No fuel entries yet. Add your first fill-up to start seeing mileage and costs.',
              )
            else
              ...vehicleFuel.take(3).map((record) => _FuelTile(record: record)),
            const SizedBox(height: 22),
            _SectionTitle(
              title: 'Upcoming service',
              action: vehicleServices.isEmpty ? 'Add reminder' : 'View all',
              onTap: () => _open(ServicesPage(vehicle: vehicle, store: store)),
            ),
            if (vehicleServices.isEmpty)
              const _EmptyCard(
                icon: Icons.event_available_outlined,
                text: 'Keep your ride ready with service reminders.',
              )
            else
              ...vehicleServices
                  .take(2)
                  .map((item) => _ServiceTile(item: item)),
          ],
        ),
      ),
    );
  }
}

class _VehicleDrawer extends StatelessWidget {
  const _VehicleDrawer({
    required this.vehicles,
    required this.active,
    required this.onSelect,
    required this.onAdd,
  });
  final List<Vehicle> vehicles;
  final Vehicle active;
  final ValueChanged<Vehicle> onSelect;
  final VoidCallback onAdd;
  @override
  Widget build(BuildContext context) => Drawer(
    child: SafeArea(
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 12),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
            child: Row(
              children: [
                Image.asset(
                  'assets/ride_metrics_logo.png',
                  width: 30,
                  height: 30,
                ),
                const SizedBox(width: 10),
                const Text(
                  'RIDE METRICS',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 14, 20, 6),
            child: Text(
              'YOUR VEHICLES',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 12,
                letterSpacing: 1.2,
              ),
            ),
          ),
          ...vehicles.map(
            (v) => ListTile(
              selected: v.id == active.id,
              onTap: () => onSelect(v),
              leading: Icon(
                v.kind == VehicleKind.bike
                    ? Icons.two_wheeler
                    : Icons.directions_car,
              ),
              title: Text(v.name),
              subtitle: Text('${v.model} • ${v.registration}'),
            ),
          ),
          ListTile(
            onTap: onAdd,
            leading: const Icon(Icons.add),
            title: const Text('Add vehicle'),
          ),
        ],
      ),
    ),
  );
}

class _VehicleChooserTile extends StatelessWidget {
  const _VehicleChooserTile({required this.vehicle, required this.onTap});
  final Vehicle vehicle;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 8),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: cyan.withOpacity(.15),
              child: Icon(
                vehicle.kind == VehicleKind.bike
                    ? Icons.two_wheeler
                    : Icons.directions_car,
                color: cyan,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    vehicle.name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${vehicle.model} • ${vehicle.year} • ${vehicle.registration}',
                    style: const TextStyle(fontSize: 12, color: Colors.white70),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 7),
                  Wrap(
                    spacing: 5,
                    runSpacing: 4,
                    children: [
                      _ChooserMeta(
                        icon: Icons.speed,
                        text: '${vehicle.odometer.toStringAsFixed(0)} km',
                      ),
                      if (vehicle.engineCc != null)
                        _ChooserMeta(
                          icon: Icons.settings_outlined,
                          text: '${vehicle.engineCc} cc',
                        ),
                      _ChooserMeta(
                        icon: Icons.local_gas_station_outlined,
                        text: '${vehicle.tankCapacity.toStringAsFixed(0)} L',
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white54),
          ],
        ),
      ),
    ),
  );
}

class _ChooserMeta extends StatelessWidget {
  const _ChooserMeta({required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(.06),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: cyan),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(fontSize: 10, color: Colors.white70)),
      ],
    ),
  );
}

class _AddVehicleTile extends StatelessWidget {
  const _AddVehicleTile({required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 12),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: const Padding(
        padding: EdgeInsets.all(22),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_circle_outline, color: lime),
            SizedBox(width: 10),
            Text(
              'Add new vehicle',
              style: TextStyle(color: lime, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    ),
  );
}

class _VehicleHeader extends StatelessWidget {
  const _VehicleHeader({
    required this.vehicle,
    required this.onEdit,
    required this.onDelete,
  });
  final Vehicle vehicle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  @override
  Widget build(BuildContext context) => Card(
    child: InkWell(
      onTap: onEdit,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: cyan.withOpacity(.15),
              child: Icon(
                vehicle.kind == VehicleKind.bike
                    ? Icons.two_wheeler
                    : Icons.directions_car,
                color: cyan,
                size: 30,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'READY TO RIDE',
                    style: TextStyle(
                      color: lime,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                  Text(
                    vehicle.name,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  Text(
                    '${vehicle.model} • ${vehicle.year} • ${vehicle.fuelType}${vehicle.engineCc == null ? '' : ' • ${vehicle.engineCc} cc'}',
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'edit') onEdit();
                if (value == 'delete') onDelete();
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('Edit vehicle')),
                PopupMenuItem(value: 'delete', child: Text('Remove vehicle')),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });
  final String label, value;
  final IconData icon;
  final Color color;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 12),
          Text(value, style: Theme.of(context).textTheme.titleLarge),
          Text(
            label,
            style: const TextStyle(color: Colors.white60, fontSize: 12),
          ),
        ],
      ),
    ),
  );
}

class _DashboardMetric extends StatelessWidget {
  const _DashboardMetric({
    required this.label,
    required this.value,
    required this.icon,
  });
  final String label;
  final String value;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: cyan, size: 28),
          const Spacer(),
          Text(value, style: Theme.of(context).textTheme.titleLarge),
          Text(label, style: const TextStyle(color: Colors.white70)),
        ],
      ),
    ),
  );
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.label,
    required this.icon,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Card(
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(icon, color: cyan),
            const SizedBox(width: 10),
            Flexible(child: Text(label)),
          ],
        ),
      ),
    ),
  );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, this.action, this.onTap});
  final String title;
  final String? action;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(title, style: Theme.of(context).textTheme.titleLarge),
      if (action != null) TextButton(onPressed: onTap, child: Text(action!)),
    ],
  );
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Icon(icon, color: Colors.white38),
          const SizedBox(width: 14),
          Expanded(
            child: Text(text, style: const TextStyle(color: Colors.white60)),
          ),
        ],
      ),
    ),
  );
}

class _FuelTile extends StatelessWidget {
  const _FuelTile({required this.record, this.onTap});
  final FuelRecord record;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      onTap: onTap,
      leading: const CircleAvatar(
        backgroundColor: Color(0x2200d9ff),
        child: Icon(Icons.local_gas_station, color: cyan),
      ),
      title: Text(
        '${record.litres.toStringAsFixed(1)} L • ${money.format(record.cost)}',
      ),
      subtitle: Text(
        '${shortDate.format(record.date)} • ${record.place?.isNotEmpty == true ? record.place : 'Station not named'}',
      ),
      trailing: Text('${money.format(record.price)}/L'),
    ),
  );
}

class _ServiceTile extends StatelessWidget {
  const _ServiceTile({required this.item});
  final ServiceItem item;
  @override
  Widget build(BuildContext context) {
    final overdue = item.dueDate.isBefore(DateTime.now());
    final days = item.dueDate.difference(DateTime.now()).inDays;
    final dueSoon = !overdue && days <= 7;
    return Card(
      child: ListTile(
        leading: Icon(
          overdue || dueSoon
              ? Icons.warning_amber_rounded
              : Icons.event_available,
          color: overdue || dueSoon ? Colors.orange : lime,
        ),
        title: Text(item.title),
        subtitle: Text(
          overdue
              ? 'OVERDUE • ${shortDate.format(item.dueDate)}'
              : dueSoon
              ? 'DUE SOON • ${shortDate.format(item.dueDate)}'
              : 'Due ${shortDate.format(item.dueDate)}',
        ),
      ),
    );
  }
}

class VehicleForm extends StatefulWidget {
  const VehicleForm({super.key, this.old});
  final Vehicle? old;
  @override
  State<VehicleForm> createState() => _VehicleFormState();
}

class _VehicleFormState extends State<VehicleForm> {
  final form = GlobalKey<FormState>();
  late final TextEditingController name = TextEditingController(
        text: widget.old?.name,
      ),
      model = TextEditingController(text: widget.old?.model),
      year = TextEditingController(text: widget.old?.year.toString()),
      registration = TextEditingController(text: widget.old?.registration),
      engineCc = TextEditingController(
        text: widget.old?.engineCc?.toString() ?? '',
      ),
      tank = TextEditingController(text: widget.old?.tankCapacity.toString()),
      odo = TextEditingController(text: widget.old?.odometer.toString());
  late VehicleKind kind = widget.old?.kind ?? VehicleKind.bike;
  late String fuelType = widget.old?.fuelType ?? 'Petrol';
  String? requiredValue(String? value) =>
      value == null || value.trim().isEmpty ? 'Required' : null;
  void save() {
    if (!form.currentState!.validate()) return;
    Navigator.pop(
      context,
      Vehicle(
        id: widget.old?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
        kind: kind,
        name: name.text.trim(),
        model: model.text.trim(),
        year: int.parse(year.text),
        registration: registration.text.trim().toUpperCase(),
        fuelType: fuelType,
        engineCc: int.tryParse(engineCc.text.trim()),
        tankCapacity: double.parse(tank.text),
        odometer: double.parse(odo.text),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.old == null ? 'Add vehicle' : 'Edit vehicle'),
    ),
    body: Form(
      key: form,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SegmentedButton<VehicleKind>(
            segments: const [
              ButtonSegment(
                value: VehicleKind.bike,
                icon: Icon(Icons.two_wheeler),
                label: Text('Bike'),
              ),
              ButtonSegment(
                value: VehicleKind.car,
                icon: Icon(Icons.directions_car),
                label: Text('Car'),
              ),
            ],
            selected: {kind},
            onSelectionChanged: (x) => setState(() => kind = x.first),
          ),
          const SizedBox(height: 18),
          _field(name, 'Vehicle name'),
          _field(model, 'Brand / model'),
          Row(
            children: [
              Expanded(child: _field(year, 'Year', numeric: true)),
              const SizedBox(width: 10),
              Expanded(child: _field(registration, 'Registration')),
            ],
          ),
          Row(
            children: [
              Expanded(child: _field(tank, 'Tank litres', numeric: true)),
              const SizedBox(width: 10),
              Expanded(child: _field(odo, 'Odometer km', numeric: true)),
            ],
          ),
          _field(
            engineCc,
            'Engine capacity (cc)',
            numeric: true,
            optional: true,
          ),
          DropdownButtonFormField<String>(
            initialValue: fuelType,
            items: const [
              DropdownMenuItem(value: 'Petrol', child: Text('Petrol')),
              DropdownMenuItem(value: 'Diesel', child: Text('Diesel')),
              DropdownMenuItem(value: 'Electric', child: Text('Electric')),
            ],
            onChanged: (value) => setState(() => fuelType = value!),
            decoration: const InputDecoration(labelText: 'Fuel type'),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: save,
            icon: const Icon(Icons.check),
            label: const Text('Save vehicle'),
          ),
        ],
      ),
    ),
  );
  Widget _field(
    TextEditingController controller,
    String label, {
    bool numeric = false,
    bool optional = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      controller: controller,
      validator: optional ? null : requiredValue,
      keyboardType: numeric
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      decoration: InputDecoration(labelText: label),
    ),
  );
}

class FuelPage extends StatefulWidget {
  const FuelPage({super.key, required this.vehicle, required this.store});
  final Vehicle vehicle;
  final Store store;
  @override
  State<FuelPage> createState() => _FuelPageState();
}

class _FuelPageState extends State<FuelPage> {
  List<FuelRecord> records = [];
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final all = await widget.store.fuel();
    if (mounted)
      setState(
        () => records =
            all.where((e) => e.vehicleId == widget.vehicle.id).toList()
              ..sort((a, b) => b.date.compareTo(a.date)),
      );
  }

  Future<void> _syncVehicleOdometer(FuelRecord record) async {
    final allVehicles = await widget.store.vehicles();
    final updated = allVehicles.map((item) {
      if (item.id == record.vehicleId && record.odometer > item.odometer) {
        return item.copyWith(odometer: record.odometer);
      }
      return item;
    }).toList();
    await widget.store.saveVehicles(updated);
  }

  Future<void> _add() async {
    final result = await showModalBottomSheet<FuelRecord>(
      context: context,
      isScrollControlled: true,
      builder: (_) => FuelFormV2(
        vehicle: widget.vehicle,
        suggestedOdometer: records.isEmpty
            ? widget.vehicle.odometer
            : records.first.odometer,
      ),
    );
    if (result == null) return;
    final all = await widget.store.fuel();
    await widget.store.saveFuel([...all, result]);
    await _syncVehicleOdometer(result);
    _load();
  }

  Future<void> _edit(FuelRecord record) async {
    final result = await showModalBottomSheet<FuelRecord>(
      context: context,
      isScrollControlled: true,
      builder: (_) => FuelFormV2(vehicle: widget.vehicle, existing: record),
    );
    if (result == null) return;
    final all = await widget.store.fuel();
    await widget.store.saveFuel(
      all.map((item) => item.id == result.id ? result : item).toList(),
    );
    await _syncVehicleOdometer(result);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final total = records.fold<double>(0, (sum, e) => sum + e.cost);
    final sorted = [...records]..sort((a, b) => a.date.compareTo(b.date));
    final mileage = <double>[];
    for (var i = 1; i < sorted.length; i++) {
      final distance = sorted[i].odometer - sorted[i - 1].odometer;
      if (distance > 0 && sorted[i].litres > 0)
        mileage.add(distance / sorted[i].litres);
    }
    final averageMileage = mileage.isEmpty
        ? 0.0
        : mileage.reduce((a, b) => a + b) / mileage.length;
    final children = <Widget>[
      Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Column(
                children: [
                  Text(
                    '${records.length}',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const Text(
                    'fill-ups',
                    style: TextStyle(color: Colors.white60),
                  ),
                ],
              ),
              Column(
                children: [
                  Text(
                    averageMileage == 0
                        ? '—'
                        : '${averageMileage.toStringAsFixed(1)} km/L',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const Text(
                    'avg. mileage',
                    style: TextStyle(color: Colors.white60),
                  ),
                ],
              ),
              Column(
                children: [
                  Text(
                    money.format(total),
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const Text(
                    'total spend',
                    style: TextStyle(color: Colors.white60),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 14),
    ];
    if (records.isEmpty) {
      children.add(
        const _EmptyCard(
          icon: Icons.local_gas_station_outlined,
          text: 'Your fill-ups will appear here.',
        ),
      );
    } else {
      children.addAll(
        records.map(
          (record) => Dismissible(
            key: ValueKey(record.id),
            direction: DismissDirection.endToStart,
            background: Container(
              color: Colors.red.shade900,
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 20),
              child: const Icon(Icons.delete),
            ),
            onDismissed: (_) async {
              final all = await widget.store.fuel();
              await widget.store.saveFuel(
                all.where((e) => e.id != record.id).toList(),
              );
            },
            child: _FuelTile(record: record, onTap: () => _edit(record)),
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Fuel log')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _add,
        icon: const Icon(Icons.add),
        label: const Text('Add fill-up'),
      ),
      body: ListView(padding: const EdgeInsets.all(16), children: children),
    );
  }
}

class FuelForm extends StatefulWidget {
  const FuelForm({super.key, required this.vehicle});
  final Vehicle vehicle;
  @override
  State<FuelForm> createState() => _FuelFormState();
}

class _FuelFormState extends State<FuelForm> {
  final form = GlobalKey<FormState>();
  late final TextEditingController odo = TextEditingController(
    text: widget.vehicle.odometer.toString(),
  );
  final litres = TextEditingController(),
      cost = TextEditingController(),
      place = TextEditingController();
  DateTime date = DateTime.now();
  double? lat, lng;
  String? requiredValue(String? value) =>
      value == null || value.trim().isEmpty ? 'Required' : null;
  Future<void> _location() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied)
        permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever)
        return;
      final position = await Geolocator.getCurrentPosition();
      if (mounted)
        setState(() {
          lat = position.latitude;
          lng = position.longitude;
        });
    } catch (_) {}
  }

  void save() {
    if (!form.currentState!.validate()) return;
    Navigator.pop(
      context,
      FuelRecord(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        vehicleId: widget.vehicle.id,
        date: date,
        odometer: double.parse(odo.text),
        litres: double.parse(litres.text),
        cost: double.parse(cost.text),
        place: place.text.trim().isEmpty ? null : place.text.trim(),
        latitude: lat,
        longitude: lng,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(
      left: 16,
      right: 16,
      top: 12,
      bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
    ),
    child: Form(
      key: form,
      child: ListView(
        shrinkWrap: true,
        children: [
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Add fuel fill-up',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),
          _field(odo, 'Odometer km'),
          _field(litres, 'Litres'),
          _field(cost, 'Total cost (₹)'),
          TextFormField(
            controller: place,
            decoration: const InputDecoration(
              labelText: 'Station / place (optional)',
              suffixIcon: Icon(Icons.place_outlined),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final selected = await showDatePicker(
                      context: context,
                      firstDate: DateTime(2000),
                      lastDate: DateTime.now(),
                      initialDate: date,
                    );
                    if (selected != null) setState(() => date = selected);
                  },
                  icon: const Icon(Icons.calendar_today_outlined),
                  label: Text(shortDate.format(date)),
                ),
              ),
              const SizedBox(width: 10),
              IconButton(
                onPressed: _location,
                tooltip: 'Use current location',
                icon: Icon(
                  lat == null ? Icons.my_location : Icons.location_on,
                  color: lat == null ? null : lime,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          FilledButton(onPressed: save, child: const Text('Save fill-up')),
        ],
      ),
    ),
  );
  Widget _field(TextEditingController c, String label) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      controller: c,
      validator: requiredValue,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(labelText: label),
    ),
  );
}

enum FuelEntryMode { amountPaid, litres }

class FuelFormV2 extends StatefulWidget {
  const FuelFormV2({
    super.key,
    required this.vehicle,
    this.existing,
    this.suggestedOdometer,
  });
  final Vehicle vehicle;
  final FuelRecord? existing;
  final double? suggestedOdometer;
  @override
  State<FuelFormV2> createState() => _FuelFormV2State();
}

class _FuelFormV2State extends State<FuelFormV2> {
  final form = GlobalKey<FormState>();
  late final TextEditingController odo = TextEditingController(
    text:
        widget.existing?.odometer.toString() ??
        widget.suggestedOdometer?.toString() ??
        widget.vehicle.odometer.toString(),
  );
  late final TextEditingController quantity = TextEditingController(
    text: widget.existing == null
        ? ''
        : widget.existing!.cost.toStringAsFixed(2),
  );
  late final TextEditingController price = TextEditingController(
    text: widget.existing?.price.toStringAsFixed(2) ?? '',
  );
  late final TextEditingController place = TextEditingController(
    text: widget.existing?.place ?? '',
  );
  FuelEntryMode mode = FuelEntryMode.amountPaid;
  late DateTime date = widget.existing?.date ?? DateTime.now();
  double? lat, lng;

  @override
  void initState() {
    super.initState();
    lat = widget.existing?.latitude;
    lng = widget.existing?.longitude;
  }

  String? positive(String? value) {
    final number = double.tryParse(value?.trim() ?? '');
    return number == null || number <= 0 ? 'Enter a number above 0' : null;
  }

  Future<void> _location() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied)
        permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever)
        return;
      final position = await Geolocator.getCurrentPosition();
      if (mounted)
        setState(() {
          lat = position.latitude;
          lng = position.longitude;
        });
    } catch (_) {}
  }

  void save() {
    if (!form.currentState!.validate()) return;
    final input = double.parse(quantity.text);
    final fuelPrice = double.parse(price.text);
    final litres = mode == FuelEntryMode.amountPaid ? input / fuelPrice : input;
    final cost = mode == FuelEntryMode.amountPaid ? input : input * fuelPrice;
    Navigator.pop(
      context,
      FuelRecord(
        id:
            widget.existing?.id ??
            DateTime.now().microsecondsSinceEpoch.toString(),
        vehicleId: widget.vehicle.id,
        date: date,
        odometer: double.parse(odo.text),
        litres: litres,
        cost: cost,
        place: place.text.trim().isEmpty ? null : place.text.trim(),
        latitude: lat,
        longitude: lng,
      ),
    );
  }

  Widget _preview() {
    final input = double.tryParse(quantity.text);
    final fuelPrice = double.tryParse(price.text);
    if (input == null || input <= 0 || fuelPrice == null || fuelPrice <= 0)
      return const SizedBox.shrink();
    final litres = mode == FuelEntryMode.amountPaid ? input / fuelPrice : input;
    final cost = mode == FuelEntryMode.amountPaid ? input : input * fuelPrice;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        'Saves ${litres.toStringAsFixed(2)} L • ${money.format(cost)} total',
        style: const TextStyle(color: lime, fontWeight: FontWeight.w700),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(
      left: 16,
      right: 16,
      top: 12,
      bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
    ),
    child: Form(
      key: form,
      child: ListView(
        shrinkWrap: true,
        children: [
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            widget.existing == null ? 'Add fuel fill-up' : 'Edit fuel fill-up',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 14),
          SegmentedButton<FuelEntryMode>(
            segments: const [
              ButtonSegment(
                value: FuelEntryMode.amountPaid,
                icon: Icon(Icons.payments_outlined),
                label: Text('Amount paid'),
              ),
              ButtonSegment(
                value: FuelEntryMode.litres,
                icon: Icon(Icons.local_gas_station_outlined),
                label: Text('Litres'),
              ),
            ],
            selected: {mode},
            onSelectionChanged: (value) {
              setState(() {
                mode = value.first;
                if (widget.existing != null) {
                  final item = widget.existing!;
                  quantity.text = mode == FuelEntryMode.amountPaid
                      ? item.cost.toStringAsFixed(2)
                      : item.litres.toStringAsFixed(2);
                }
              });
            },
          ),
          const SizedBox(height: 14),
          _numeric(odo, 'Odometer km'),
          _numeric(
            quantity,
            mode == FuelEntryMode.amountPaid ? 'Amount paid (₹)' : 'Litres',
          ),
          _numeric(price, 'Fuel price (₹/L)'),
          _preview(),
          TextFormField(
            controller: place,
            decoration: const InputDecoration(
              labelText: 'Station / place (optional)',
              suffixIcon: Icon(Icons.place_outlined),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final selected = await showDatePicker(
                      context: context,
                      firstDate: DateTime(2000),
                      lastDate: DateTime.now(),
                      initialDate: date,
                    );
                    if (selected != null) setState(() => date = selected);
                  },
                  icon: const Icon(Icons.calendar_today_outlined),
                  label: Text(shortDate.format(date)),
                ),
              ),
              const SizedBox(width: 10),
              IconButton(
                onPressed: _location,
                tooltip: 'Use current location',
                icon: Icon(
                  lat == null ? Icons.my_location : Icons.location_on,
                  color: lat == null ? null : lime,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          FilledButton(
            onPressed: save,
            child: Text(
              widget.existing == null ? 'Save fill-up' : 'Save changes',
            ),
          ),
        ],
      ),
    ),
  );
  Widget _numeric(TextEditingController controller, String label) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      controller: controller,
      validator: positive,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(labelText: label),
    ),
  );
  @override
  void dispose() {
    odo.dispose();
    quantity.dispose();
    price.dispose();
    place.dispose();
    super.dispose();
  }
}

class DocumentsPage extends StatefulWidget {
  const DocumentsPage({super.key, required this.vehicle, required this.store});
  final Vehicle vehicle;
  final Store store;
  @override
  State<DocumentsPage> createState() => _DocumentsPageState();
}

class _DocumentsPageState extends State<DocumentsPage> {
  List<VehicleDocument> documents = [];
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final all = await widget.store.documents();
    if (mounted)
      setState(
        () => documents = all
            .where((e) => e.vehicleId == widget.vehicle.id)
            .toList(),
      );
  }

  static const defaultNames = [
    'RC book',
    'Insurance',
    'Pollution (PUC)',
    "Driver's licence",
  ];

  VehicleDocument? _find(String name) {
    for (final doc in documents) {
      if (doc.name == name) return doc;
    }
    return null;
  }

  Future<void> _addFor(String name) async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'webp', 'pdf'],
    );
    if (result == null || result.files.single.path == null) return;
    final existing = _find(name);
    final id = existing?.id ?? DateTime.now().microsecondsSinceEpoch.toString();
    final copied = await widget.store.copyDocument(
      result.files.single.path!,
      id,
      existing?.paths.length ?? 0,
    );
    final all = await widget.store.documents();
    final updated = VehicleDocument(
      id: id,
      vehicleId: widget.vehicle.id,
      name: name,
      paths: [...?existing?.paths, copied],
    );
    final without = all.where((doc) => doc.id != id).toList();
    await widget.store.saveDocuments([...without, updated]);
    _load();
  }

  Future<void> _addCustom() async {
    final c = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Custom document'),
        content: TextField(
          controller: c,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Document name',
            hintText: 'Fitness certificate',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, c.text.trim()),
            child: const Text('Next'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    await _addFor(name);
  }

  void _open(VehicleDocument doc) => Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => DocumentViewer(document: doc)),
  );

  Future<void> _delete(VehicleDocument doc) async {
    final all = await widget.store.documents();
    await widget.store.saveDocuments(all.where((e) => e.id != doc.id).toList());
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[
      const Card(
        child: Padding(
          padding: EdgeInsets.all(18),
          child: Row(
            children: [
              Icon(Icons.lock_outline, color: lime),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Vehicle documents stay on this device. Tap a document name to view its photo.',
                ),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 18),
      Text('Required documents', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 8),
    ];
    for (final name in defaultNames) {
      final doc = _find(name);
      children.add(
        Card(
          child: ListTile(
            onTap: doc == null ? null : () => _open(doc),
            leading: Icon(
              doc == null ? Icons.upload_file_outlined : Icons.image_outlined,
              color: doc == null ? Colors.white54 : cyan,
            ),
            title: Text(name),
            subtitle: Text(
              doc == null
                  ? 'Tap + to add a photo'
                  : '${doc.paths.length} photo${doc.paths.length == 1 ? '' : 's'} • tap name to open',
            ),
            trailing: doc == null
                ? IconButton(
                    onPressed: () => _addFor(name),
                    icon: const Icon(Icons.add_photo_alternate_outlined),
                  )
                : PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'add') _addFor(name);
                      if (value == 'delete') _delete(doc);
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: 'add',
                        child: Text('Add another photo'),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Text('Delete document'),
                      ),
                    ],
                  ),
          ),
        ),
      );
    }
    final custom = documents
        .where((doc) => !defaultNames.contains(doc.name))
        .toList();
    children.addAll([
      const SizedBox(height: 22),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Custom documents',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          TextButton.icon(
            onPressed: _addCustom,
            icon: const Icon(Icons.add),
            label: const Text('Add'),
          ),
        ],
      ),
    ]);
    if (custom.isEmpty) {
      children.add(
        const _EmptyCard(
          icon: Icons.add_photo_alternate_outlined,
          text: 'Add any other vehicle document with your own name.',
        ),
      );
    } else {
      for (final doc in custom) {
        children.add(
          Card(
            child: ListTile(
              onTap: () => _open(doc),
              leading: const Icon(Icons.image_outlined, color: cyan),
              title: Text(doc.name),
              subtitle: Text(
                '${doc.paths.length} photo${doc.paths.length == 1 ? '' : 's'} • tap name to open',
              ),
              trailing: IconButton(
                onPressed: () => _delete(doc),
                icon: const Icon(Icons.delete_outline),
              ),
            ),
          ),
        );
      }
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Vehicle documents')),
      body: ListView(padding: const EdgeInsets.all(16), children: children),
    );
  }
}

class DocumentViewer extends StatelessWidget {
  const DocumentViewer({super.key, required this.document});
  final VehicleDocument document;
  bool _isPdf(String path) => path.toLowerCase().endsWith('.pdf');
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(document.name)),
    body: PageView.builder(
      itemCount: document.paths.length,
      itemBuilder: (_, index) {
        final path = document.paths[index];
        if (_isPdf(path)) return PDFView(filePath: path);
        return InteractiveViewer(
          minScale: .8,
          maxScale: 4,
          child: Center(
            child: Image.file(
              File(path),
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'This saved document photo could not be opened on this device.',
                ),
              ),
            ),
          ),
        );
      },
    ),
  );
}

class ServicesPage extends StatefulWidget {
  const ServicesPage({super.key, required this.vehicle, required this.store});
  final Vehicle vehicle;
  final Store store;
  @override
  State<ServicesPage> createState() => _ServicesPageState();
}

class _ServicesPageState extends State<ServicesPage> {
  List<ServiceItem> services = [];
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final all = await widget.store.services();
    if (mounted)
      setState(
        () => services =
            all.where((e) => e.vehicleId == widget.vehicle.id).toList()
              ..sort((a, b) => a.dueDate.compareTo(b.dueDate)),
      );
  }

  Future<void> _add() async {
    final result = await showDialog<ServiceItem>(
      context: context,
      builder: (_) => ServiceForm(vehicle: widget.vehicle),
    );
    if (result == null) return;
    final all = await widget.store.services();
    await widget.store.saveServices([...all, result]);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    if (services.isEmpty) {
      children.add(
        const _EmptyCard(
          icon: Icons.event_available_outlined,
          text: 'Add oil changes, insurance renewals or any maintenance due date.',
        ),
      );
    } else {
      children.addAll(
        services.map(
          (item) => Dismissible(
            key: ValueKey(item.id),
            background: Container(
              color: Colors.red.shade900,
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 20),
              child: const Icon(Icons.delete),
            ),
            direction: DismissDirection.endToStart,
            onDismissed: (_) async {
              final all = await widget.store.services();
              await widget.store.saveServices(
                all.where((e) => e.id != item.id).toList(),
              );
            },
            child: _ServiceTile(item: item),
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Service reminders')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _add,
        icon: const Icon(Icons.add),
        label: const Text('Add reminder'),
      ),
      body: ListView(padding: const EdgeInsets.all(16), children: children),
    );
  }
}

class ServiceForm extends StatefulWidget {
  const ServiceForm({super.key, required this.vehicle});
  final Vehicle vehicle;
  @override
  State<ServiceForm> createState() => _ServiceFormState();
}

class _ServiceFormState extends State<ServiceForm> {
  final form = GlobalKey<FormState>();
  final notes = TextEditingController();
  static const serviceTypes = [
    'Oil change',
    'Tyre pressure',
    'Chain service',
    'Brake service',
    'Insurance expiry',
    'PUC expiry',
  ];
  String serviceType = serviceTypes.first;
  DateTime dueDate = DateTime.now().add(const Duration(days: 30));
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('New service reminder'),
    content: Form(
      key: form,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: serviceType,
              items: serviceTypes
                  .map(
                    (type) => DropdownMenuItem(value: type, child: Text(type)),
                  )
                  .toList(),
              onChanged: (value) => setState(() => serviceType = value!),
              decoration: const InputDecoration(labelText: 'Reminder type'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: notes,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Notes (optional)'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () async {
                final selected = await showDatePicker(
                  context: context,
                  firstDate: DateTime.now().subtract(
                    const Duration(days: 3650),
                  ),
                  lastDate: DateTime.now().add(const Duration(days: 3650)),
                  initialDate: dueDate,
                );
                if (selected != null) setState(() => dueDate = selected);
              },
              icon: const Icon(Icons.calendar_today),
              label: Text('Due ${shortDate.format(dueDate)}'),
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () {
          if (!form.currentState!.validate()) return;
          Navigator.pop(
            context,
            ServiceItem(
              id: DateTime.now().microsecondsSinceEpoch.toString(),
              vehicleId: widget.vehicle.id,
              title: serviceType,
              dueDate: dueDate,
              notes: notes.text.trim().isEmpty ? null : notes.text.trim(),
            ),
          );
        },
        child: const Text('Save'),
      ),
    ],
  );
}

class TrendsPage extends StatefulWidget {
  const TrendsPage({super.key, required this.vehicle, required this.store});
  final Vehicle vehicle;
  final Store store;
  @override
  State<TrendsPage> createState() => _TrendsPageState();
}

class _TrendsPageState extends State<TrendsPage> {
  List<FuelRecord> records = [];
  double budget = 0;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final all = await widget.store.fuel();
    final saved = await widget.store.budget(widget.vehicle.id);
    if (mounted)
      setState(() {
        records = all.where((e) => e.vehicleId == widget.vehicle.id).toList()
          ..sort((a, b) => a.date.compareTo(b.date));
        budget = saved;
      });
  }

  Future<void> _budget() async {
    final c = TextEditingController(
      text: budget == 0 ? '' : budget.toStringAsFixed(0),
    );
    final value = await showDialog<double>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Monthly fuel budget'),
        content: TextField(
          controller: c,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(prefixText: '₹ '),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, double.tryParse(c.text)),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (value != null) {
      await widget.store.saveBudget(widget.vehicle.id, value);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final last30 = DateTime.now().subtract(const Duration(days: 30));
    final monthSpend = records
        .where((e) => e.date.isAfter(last30))
        .fold<double>(0, (sum, e) => sum + e.cost);
    final mileage = <double>[];
    for (var i = 1; i < records.length; i++) {
      final distance = records[i].odometer - records[i - 1].odometer;
      if (distance > 0 && records[i].litres > 0)
        mileage.add(distance / records[i].litres);
    }
    final avg = mileage.isEmpty
        ? 0.0
        : mileage.reduce((a, b) => a + b) / mileage.length;
    final stationWidgets = records.isEmpty
        ? <Widget>[
            const _EmptyCard(
              icon: Icons.place_outlined,
              text: 'Named stations from your fuel log will appear here.',
            ),
          ]
        : _stationHistory(records);
    return Scaffold(
      appBar: AppBar(title: const Text('Insights')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Fuel budget',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      IconButton(
                        onPressed: _budget,
                        icon: const Icon(Icons.edit_outlined),
                      ),
                    ],
                  ),
                  Text(
                    budget == 0
                        ? 'Set a monthly target'
                        : '${money.format(monthSpend)} of ${money.format(budget)} used',
                  ),
                  if (budget > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: LinearProgressIndicator(
                        value: math.min(monthSpend / budget, 1.0).toDouble(),
                        color: monthSpend > budget ? Colors.orange : lime,
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  label: 'Avg. mileage',
                  value: avg == 0 ? '—' : '${avg.toStringAsFixed(1)} km/L',
                  icon: Icons.speed,
                  color: cyan,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatCard(
                  label: 'Fill-ups',
                  value: '${records.length}',
                  icon: Icons.local_gas_station,
                  color: lime,
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Text('Mileage trend', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 20, 18, 16),
              child: SizedBox(
                height: 190,
                child: mileage.isEmpty
                    ? const Center(
                        child: Text(
                          'Add at least two fill-ups to see your trend.',
                          style: TextStyle(color: Colors.white60),
                        ),
                      )
                    : CustomPaint(
                        painter: _TrendPainter(mileage),
                        child: const SizedBox.expand(),
                      ),
              ),
            ),
          ),
          const SizedBox(height: 22),
          Text(
            'Fuel station history',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 10),
          ...stationWidgets,
        ],
      ),
    );
  }

  List<Widget> _stationHistory(List<FuelRecord> input) {
    final map = <String, List<FuelRecord>>{};
    for (final record in input) {
      final key = record.place?.isNotEmpty == true
          ? record.place!
          : 'Unnamed station';
      (map[key] ??= []).add(record);
    }
    return map.entries.map((entry) {
      final spend = entry.value.fold<double>(0, (sum, e) => sum + e.cost);
      return Card(
        child: ListTile(
          leading: const Icon(Icons.place_outlined, color: cyan),
          title: Text(entry.key),
          subtitle: Text(
            '${entry.value.length} visit${entry.value.length == 1 ? '' : 's'}',
          ),
          trailing: Text(money.format(spend)),
        ),
      );
    }).toList();
  }
}

enum _InsightPeriod { week, month }

class InsightsPage extends StatefulWidget {
  const InsightsPage({super.key, required this.vehicle, required this.store});
  final Vehicle vehicle;
  final Store store;
  @override
  State<InsightsPage> createState() => _InsightsPageState();
}

class _InsightsPageState extends State<InsightsPage> {
  List<Vehicle> vehicles = [];
  List<FuelRecord> allRecords = [];
  Vehicle? selected;
  double budget = 0;
  _InsightPeriod period = _InsightPeriod.week;
  final distanceController = TextEditingController();
  double? estimatedLitres;
  double? estimatedCost;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final loadedVehicles = await widget.store.vehicles();
    final loadedRecords = await widget.store.fuel();
    final chosen =
        loadedVehicles
            .where((item) => item.id == (selected?.id ?? widget.vehicle.id))
            .firstOrNull ??
        loadedVehicles.firstOrNull;
    final savedBudget = chosen == null
        ? 0.0
        : await widget.store.budget(chosen.id);
    if (!mounted) return;
    setState(() {
      vehicles = loadedVehicles;
      allRecords = loadedRecords;
      selected = chosen;
      budget = savedBudget;
    });
  }

  List<FuelRecord> get records {
    final id = selected?.id;
    if (id == null) return [];
    return allRecords.where((item) => item.vehicleId == id).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
  }

  List<double> get mileageValues {
    final result = <double>[];
    final sorted = records;
    for (var i = 1; i < sorted.length; i++) {
      final distance = sorted[i].odometer - sorted[i - 1].odometer;
      if (distance > 0 && sorted[i].litres > 0)
        result.add(distance / sorted[i].litres);
    }
    return result;
  }

  double get averageMileage => mileageValues.isEmpty
      ? 0
      : mileageValues.reduce((a, b) => a + b) / mileageValues.length;
  double get averagePrice => records.isEmpty
      ? 0
      : records.fold<double>(0, (sum, item) => sum + item.price) /
            records.length;
  DateTime get rangeStart => DateTime.now().subtract(
    Duration(days: period == _InsightPeriod.week ? 6 : 29),
  );
  int get bucketCount => period == _InsightPeriod.week ? 7 : 5;
  int _bucket(DateTime date) {
    final offset = date
        .difference(rangeStart)
        .inDays
        .clamp(0, period == _InsightPeriod.week ? 6 : 29);
    return period == _InsightPeriod.week ? offset : (offset ~/ 7).clamp(0, 4);
  }

  List<double> get spendBuckets {
    final values = List<double>.filled(bucketCount, 0);
    for (final item in records.where((e) => e.date.isAfter(rangeStart)))
      values[_bucket(item.date)] += item.cost;
    return values;
  }

  List<double> get mileageBuckets {
    final values = List<double>.filled(bucketCount, 0);
    final counts = List<int>.filled(bucketCount, 0);
    final sorted = records;
    for (var i = 1; i < sorted.length; i++) {
      final distance = sorted[i].odometer - sorted[i - 1].odometer;
      if (sorted[i].date.isAfter(rangeStart) &&
          distance > 0 &&
          sorted[i].litres > 0) {
        final index = _bucket(sorted[i].date);
        values[index] += distance / sorted[i].litres;
        counts[index]++;
      }
    }
    for (var i = 0; i < values.length; i++) {
      if (counts[i] > 0) values[i] /= counts[i];
    }
    return values;
  }

  Map<String, double> get mileageByRecord {
    final result = <String, double>{};
    final sorted = records;
    for (var i = 1; i < sorted.length; i++) {
      final distance = sorted[i].odometer - sorted[i - 1].odometer;
      if (distance > 0 && sorted[i].litres > 0)
        result[sorted[i].id] = distance / sorted[i].litres;
    }
    return result;
  }

  Future<void> _changeVehicle(Vehicle value) async {
    final saved = await widget.store.budget(value.id);
    if (mounted)
      setState(() {
        selected = value;
        budget = saved;
        estimatedCost = null;
        estimatedLitres = null;
      });
  }

  Future<void> _saveBudget() async {
    final c = TextEditingController(
      text: budget == 0 ? '' : budget.toStringAsFixed(0),
    );
    final value = await showDialog<double>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Monthly fuel budget'),
        content: TextField(
          controller: c,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(prefixText: '₹ '),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, double.tryParse(c.text)),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (value == null || selected == null) return;
    await widget.store.saveBudget(selected!.id, value);
    if (mounted) setState(() => budget = value);
  }

  void _estimateTrip() {
    final distance = double.tryParse(distanceController.text);
    if (distance == null || distance <= 0 || averageMileage == 0) {
      setState(() {
        estimatedLitres = null;
        estimatedCost = null;
      });
      return;
    }
    setState(() {
      estimatedLitres = distance / averageMileage;
      estimatedCost = estimatedLitres! * averagePrice;
    });
  }

  @override
  Widget build(BuildContext context) {
    final vehicle = selected;
    final monthSpend = records
        .where(
          (item) => item.date.isAfter(
            DateTime.now().subtract(const Duration(days: 30)),
          ),
        )
        .fold<double>(0, (sum, item) => sum + item.cost);
    final history = _stationHistoryWithComparisons(records);
    final stationWidgets = history.isEmpty
        ? <Widget>[
            const _EmptyCard(
              icon: Icons.place_outlined,
              text: 'Name a station when adding fuel to compare prices and mileage.',
            ),
          ]
        : history;
    return Scaffold(
      appBar: AppBar(title: const Text('Insights & trip planner')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (vehicles.length > 1)
            Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
                child: DropdownButtonFormField<Vehicle>(
                  initialValue: vehicle,
                  decoration: const InputDecoration(labelText: 'Vehicle'),
                  items: vehicles
                      .map(
                        (item) => DropdownMenuItem(
                          value: item,
                          child: Text('${item.name} • ${item.registration}'),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) _changeVehicle(value);
                  },
                ),
              ),
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  label: 'Avg. mileage',
                  value: averageMileage == 0
                      ? 'Add 2 fills'
                      : '${averageMileage.toStringAsFixed(1)} km/L',
                  icon: Icons.speed,
                  color: cyan,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatCard(
                  label: 'Avg. price/L',
                  value: averagePrice == 0 ? '—' : money.format(averagePrice),
                  icon: Icons.local_offer_outlined,
                  color: lime,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Fuel budget',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      IconButton(
                        onPressed: _saveBudget,
                        icon: const Icon(Icons.edit_outlined),
                      ),
                    ],
                  ),
                  Text(
                    budget == 0
                        ? 'Set a monthly target'
                        : '${money.format(monthSpend)} of ${money.format(budget)} used this month',
                  ),
                  if (budget > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: LinearProgressIndicator(
                        value: math.min(monthSpend / budget, 1.0).toDouble(),
                        color: monthSpend > budget ? Colors.orange : lime,
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Trip fuel estimator',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Uses this vehicle’s recorded mileage and fuel prices.',
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: distanceController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Trip distance',
                            suffixText: 'km',
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      FilledButton(
                        onPressed: _estimateTrip,
                        child: const Text('Estimate'),
                      ),
                    ],
                  ),
                  if (estimatedLitres != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 14),
                      child: Text(
                        '${estimatedLitres!.toStringAsFixed(1)} L needed • ${money.format(estimatedCost)} estimated cost',
                        style: const TextStyle(
                          color: lime,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  if (averageMileage == 0)
                    const Padding(
                      padding: EdgeInsets.only(top: 10),
                      child: Text(
                        'Add two fuel entries with odometer readings to enable estimates.',
                        style: TextStyle(color: Colors.orange),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 22),
          Text(
            'Mileage and spending trends',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 10),
          SegmentedButton<_InsightPeriod>(
            segments: const [
              ButtonSegment(value: _InsightPeriod.week, label: Text('Weekly')),
              ButtonSegment(
                value: _InsightPeriod.month,
                label: Text('Monthly'),
              ),
            ],
            selected: {period},
            onSelectionChanged: (value) => setState(() => period = value.first),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Mileage'),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 150,
                    child: mileageValues.isEmpty
                        ? const Center(
                            child: Text(
                              'Add at least two fill-ups to see mileage.',
                              style: TextStyle(color: Colors.white60),
                            ),
                          )
                        : CustomPaint(
                            painter: _BarChartPainter(mileageBuckets, cyan),
                            child: const SizedBox.expand(),
                          ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Spending'),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 150,
                    child: records.isEmpty
                        ? const Center(
                            child: Text(
                              'Fuel spending will appear here.',
                              style: TextStyle(color: Colors.white60),
                            ),
                          )
                        : CustomPaint(
                            painter: _BarChartPainter(spendBuckets, lime),
                            child: const SizedBox.expand(),
                          ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 22),
          Text(
            'Fuel-station history',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 10),
          ...stationWidgets,
        ],
      ),
    );
  }

  List<Widget> _stationHistoryWithComparisons(List<FuelRecord> input) {
    final mileage = mileageByRecord;
    final grouped = <String, List<FuelRecord>>{};
    for (final item in input) {
      final key = item.place?.isNotEmpty == true
          ? item.place!
          : 'Unnamed station';
      (grouped[key] ??= []).add(item);
    }
    return grouped.entries.map((entry) {
      final avgPrice =
          entry.value.fold<double>(0, (sum, item) => sum + item.price) /
          entry.value.length;
      final knownMileage = entry.value
          .where((item) => mileage.containsKey(item.id))
          .map((item) => mileage[item.id]!)
          .toList();
      final avgMileage = knownMileage.isEmpty
          ? null
          : knownMileage.reduce((a, b) => a + b) / knownMileage.length;
      return Card(
        child: ListTile(
          leading: const Icon(Icons.place_outlined, color: cyan),
          title: Text(entry.key),
          subtitle: Text(
            '${entry.value.length} visit${entry.value.length == 1 ? '' : 's'} • ${avgMileage == null ? 'mileage pending' : '${avgMileage.toStringAsFixed(1)} km/L'}',
          ),
          trailing: Text('${money.format(avgPrice)}/L'),
        ),
      );
    }).toList();
  }
}

class _BarChartPainter extends CustomPainter {
  _BarChartPainter(this.values, this.color);
  final List<double> values;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final maxValue = values.fold<double>(0, math.max);
    final barWidth = size.width / (values.length * 1.7);
    final paint = Paint()..color = color.withOpacity(.8);
    for (var i = 0; i < values.length; i++) {
      final height = maxValue == 0
          ? 3.0
          : (values[i] / maxValue) * (size.height - 18);
      final x = (i + .35) * size.width / values.length;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, size.height - height, barWidth, height),
          const Radius.circular(6),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BarChartPainter oldDelegate) =>
      oldDelegate.values != values || oldDelegate.color != color;
}

class _TrendPainter extends CustomPainter {
  _TrendPainter(this.values);
  final List<double> values;
  @override
  void paint(Canvas canvas, Size size) {
    final maxValue = values.reduce(math.max);
    final minValue = values.reduce(math.min);
    final range = math.max(maxValue - minValue, 1.0).toDouble();
    final line = Paint()
      ..color = cyan
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final dots = Paint()..color = lime;
    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final x = values.length == 1
          ? size.width / 2
          : i * size.width / (values.length - 1);
      final y =
          size.height -
          ((values[i] - minValue) / range * (size.height - 22)) -
          10;
      if (i == 0)
        path.moveTo(x, y);
      else
        path.lineTo(x, y);
      canvas.drawCircle(Offset(x, y), 5, dots);
    }
    canvas.drawPath(path, line);
  }

  @override
  bool shouldRepaint(covariant _TrendPainter oldDelegate) =>
      oldDelegate.values != values;
}

extension FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
