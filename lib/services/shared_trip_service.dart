import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/shared_trip.dart';

class SharedTripService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> get _trips =>
      _firestore.collection('shared_trips');

  String get _uid {
    final user = _auth.currentUser;

    if (user == null) {
      throw StateError('Sign in before managing trips.');
    }

    return user.uid;
  }

  // Generate once per start attempt; reuse the ID when retrying.
  String newTripId() => _trips.doc().id;

  Stream<List<SharedTrip>> watchActiveTrips() {
    return _trips.where('status', isEqualTo: 'active').snapshots().map((
      snapshot,
    ) {
      final trips = snapshot.docs.map(SharedTrip.fromDocument).toList();

      trips.sort((a, b) => a.route.compareTo(b.route));
      return trips;
    });
  }

  Stream<List<SharedTrip>> watchCompletedTrips() {
    return _trips
        .where('status', isEqualTo: 'completed')
        .orderBy('endedAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(SharedTrip.fromDocument).toList());
  }

  Future<void> startTrip({
    required String tripId,
    required String bus,
    required String route,
    required int capacity,
  }) async {
    final uid = _uid;
    final busName = bus.trim();
    final routeName = route.trim();

    if (tripId.isEmpty || tripId.contains('/')) {
      throw ArgumentError('A valid trip ID is required.');
    }

    if (busName.isEmpty || busName.length > 30) {
      throw ArgumentError('Enter a bus name of 1 to 30 characters.');
    }

    if (routeName.isEmpty || routeName.length > 80) {
      throw ArgumentError('Enter a route name of 1 to 80 characters.');
    }
    if (capacity < 1 || capacity > 100) {
      throw ArgumentError('Enter a boarding limit from 1 to 100.');
    }

    final tripRef = _trips.doc(tripId);
    final profileRef = _firestore.collection('users').doc(uid);
    final slotRef = _firestore.collection('driver_trip_slots').doc(uid);

    await _firestore.runTransaction<void>((transaction) async {
      // Read everything before writing.
      final profileSnapshot = await transaction.get(profileRef);
      final existingTrip = await transaction.get(tripRef);
      final slotSnapshot = await transaction.get(slotRef);

      final profile = profileSnapshot.data();
      final activeTripId = slotSnapshot.data()?['tripId'];

      if (profile == null ||
          profile['role'] != 'driver' ||
          profile['isActive'] != true) {
        throw StateError('An active driver account is required.');
      }

      final name = profile['fullName'];

      if (name is! String || name.trim().isEmpty) {
        throw StateError('The driver profile needs a valid name.');
      }

      if (existingTrip.exists) {
        final existing = existingTrip.data()!;

        if (existing['driverUid'] != uid ||
            existing['bus'] != busName ||
            existing['route'] != routeName ||
            existing['capacity'] != capacity) {
          throw StateError('This trip ID is already in use.');
        }

        if (existing['status'] != 'active') {
          throw StateError(
            'This trip has already ended. Reopen the trip page '
            'to start a new trip.',
          );
        }

        if (activeTripId != tripId) {
          throw StateError(
            'This trip has no matching driver slot. '
            'End the old trip before starting another.',
          );
        }

        // The previous attempt succeeded; no duplicate write.
        return;
      }

      if (activeTripId != null) {
        throw StateError(
          'You already have an active trip. Finish it before starting another.',
        );
      }

      transaction.set(tripRef, {
        'driverUid': uid,
        'driverName': name,
        'bus': busName,
        'capacity': capacity,
        'route': routeName,
        'status': 'active',
        'startedAt': FieldValue.serverTimestamp(),
        'endedAt': null,
      });

      transaction.set(slotRef, {'tripId': tripId});
    });
  }

  Future<void> endTrip(String tripId) async {
    final uid = _uid;
    final tripRef = _trips.doc(tripId);
    final slotRef = _firestore.collection('driver_trip_slots').doc(uid);

    await _firestore.runTransaction<void>((transaction) async {
      final snapshot = await transaction.get(tripRef);
      final slotSnapshot = await transaction.get(slotRef);
      final data = snapshot.data();

      if (data == null) {
        throw StateError('This trip does not exist.');
      }

      if (data['driverUid'] != uid) {
        throw StateError('Only the trip driver can end this trip.');
      }

      if (data['status'] == 'completed') {
        return;
      }

      transaction.update(tripRef, {
        'status': 'completed',
        'endedAt': FieldValue.serverTimestamp(),
      });

      // Release only this trip's slot.
      // Old trips without slots can still be completed.
      if (slotSnapshot.data()?['tripId'] == tripId) {
        transaction.update(slotRef, {'tripId': null});
      }
    });
  }
}
