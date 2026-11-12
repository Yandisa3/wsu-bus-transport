import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/student.dart';

class SharedBoardingService {
  final _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _records(String tripId) =>
      _firestore
          .collection('shared_trips')
          .doc(tripId)
          .collection('demo_boardings');

  Stream<QuerySnapshot<Map<String, dynamic>>> watch(String tripId) =>
      _records(tripId).orderBy('boardedAt', descending: true).snapshots();

  Future<String> board({
    required String tripId,
    required String studentNumber,
  }) async {
    Student? student;

    for (final candidate in MockData.students) {
      if (candidate.studentNumber == studentNumber) {
        student = candidate;
        break;
      }
    }

    if (student == null) {
      return 'Student not found in the configured sample records.';
    }

    if (!student.isFunded) {
      return 'Not accepted: this student is not funded in the sample records.';
    }

    final expiry = student.fundingExpiry;

    if (expiry != null && !DateTime.now().isBefore(expiry)) {
      return 'Not accepted: the recorded funding has expired.';
    }

    final passenger = student;
    final tripRef = _firestore.collection('shared_trips').doc(tripId);
    final boardingRef = _records(tripId).doc(studentNumber);
    final counterRef = tripRef.collection('boarding_state').doc('current');

    return _firestore.runTransaction<String>((transaction) async {
      final tripSnapshot = await transaction.get(tripRef);
      final existing = await transaction.get(boardingRef);
      final counterSnapshot = await transaction.get(counterRef);

      final trip = tripSnapshot.data();

      if (trip == null || trip['status'] != 'active') {
        throw StateError('This trip has ended or no longer exists.');
      }

      if (existing.exists) {
        return 'Already boarded: ${passenger.name}.';
      }

      final capacity = trip['capacity'];

      if (capacity is! int || capacity < 1 || capacity > 100) {
        throw StateError(
          'This older trip has no boarding limit. '
          'End it and start a new trip.',
        );
      }

      final counter = counterSnapshot.data();
      final count = counter == null ? 0 : counter['count'];

      if (count is! int || count < 0 || count > capacity) {
        throw StateError('The boarding counter needs administrator review.');
      }

      if (count >= capacity) {
        return 'Not accepted: the boarding limit has been reached.';
      }

      transaction.set(boardingRef, {
        'studentNumber': passenger.studentNumber,
        'studentName': passenger.name,
        'boardedAt': FieldValue.serverTimestamp(),
        'demo': true,
      });

      transaction.set(counterRef, {
        'count': count + 1,
        'lastStudentNumber': passenger.studentNumber,
      });

      return 'Accepted: ${passenger.name}. '
          '${capacity - count - 1} boarding places remaining.';
    });
  }
}
