import 'package:cloud_firestore/cloud_firestore.dart';

class SharedTrip {
  final String id;
  final String driverUid;
  final String driverName;
  final String bus;
  final String route;
  final String status;
  final int? capacity;
  final DateTime? startedAt;
  final DateTime? endedAt;

  const SharedTrip({
    required this.id,
    required this.driverUid,
    required this.driverName,
    required this.bus,
    required this.route,
    required this.status,
    required this.startedAt,
    required this.endedAt,
    this.capacity,
  });

  bool get isActive => status == 'active';

  factory SharedTrip.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();

    if (data == null) {
      throw const FormatException('Trip data is missing.');
    }

    return SharedTrip(
      id: document.id,
      driverUid: data['driverUid'] as String,
      driverName: data['driverName'] as String,
      bus: data['bus'] as String,
      route: data['route'] as String,
      status: data['status'] as String,
      capacity: data['capacity'] as int?,
      startedAt: (data['startedAt'] as Timestamp?)?.toDate(),
      endedAt: (data['endedAt'] as Timestamp?)?.toDate(),
    );
  }
}
