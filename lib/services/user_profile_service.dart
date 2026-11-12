import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/user_profile.dart';

class UserProfileService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  Future<void> createStudentProfile({
    required String uid,
    required String fullName,
    required String studentNumber,
  }) async {
    final name = fullName.trim();
    final number = studentNumber.trim();

    if (uid.trim().isEmpty) {
      throw ArgumentError('A user UID is required.');
    }

    if (name.isEmpty || name.length > 100) {
      throw ArgumentError('Enter a name between 1 and 100 characters.');
    }

    if (number.isEmpty || number.length > 32) {
      throw ArgumentError(
        'Enter a student number between 1 and 32 characters.',
      );
    }

    final profileRef = _firestore.collection('users').doc(uid);

    await _firestore.runTransaction<void>((transaction) async {
      final existingProfile = await transaction.get(profileRef);

      // A retry must not overwrite an existing profile.
      if (existingProfile.exists) {
        return;
      }

      transaction.set(profileRef, {
        'fullName': name,
        'studentNumber': number,
        'role': 'student',
        'isActive': true,
      });
    });
  }

  Stream<UserProfile?> watchProfile(String uid) {
    if (uid.trim().isEmpty) {
      throw ArgumentError('A user UID is required.');
    }

    return _firestore.collection('users').doc(uid).snapshots().map((snapshot) {
      final data = snapshot.data();

      if (data == null) {
        return null;
      }

      return UserProfile.fromMap(snapshot.id, data);
    });
  }
}
