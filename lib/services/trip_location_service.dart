import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';

class TripLocationService {
  final _firestore = FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> tripRef(String tripId) =>
      _firestore.collection('shared_trips').doc(tripId);

  DocumentReference<Map<String, dynamic>> locationRef(String tripId) =>
      tripRef(tripId).collection('location').doc('current');

  Future<void> publish(String tripId, Position position) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      throw StateError('Sign in first.');
    }

    // Transactions require a connection; we don't queue old GPS fixes.
    await _firestore.runTransaction<void>((transaction) async {
      final trip = await transaction.get(tripRef(tripId));
      final data = trip.data();

      if (data == null ||
          data['status'] != 'active' ||
          data['driverUid'] != user.uid) {
        throw StateError('You cannot share location for this trip.');
      }

      transaction.set(locationRef(tripId), {
        'latitude': position.latitude,
        'longitude': position.longitude,
        'accuracy': position.accuracy,
        'sampledAt': Timestamp.fromDate(position.timestamp),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }
}
