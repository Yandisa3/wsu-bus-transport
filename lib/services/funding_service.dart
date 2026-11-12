import 'package:cloud_firestore/cloud_firestore.dart';

class FundingRecord {
  final String studentNumber;
  final bool isFunded;
  final DateTime? expiry;

  const FundingRecord({
    required this.studentNumber,
    required this.isFunded,
    required this.expiry,
  });

  factory FundingRecord.fromMap(Map<String, dynamic> data) {
    final number = data['studentNumber'];
    final funded = data['isFunded'];
    final expiry = data['fundingExpiry'];

    if (number is! String || number.trim().isEmpty) {
      throw const FormatException('Invalid student number.');
    }
    if (funded is! bool) {
      throw const FormatException('Invalid funding status.');
    }
    if (expiry != null && expiry is! Timestamp) {
      throw const FormatException('Invalid funding expiry.');
    }

    return FundingRecord(
      studentNumber: number.trim(),
      isFunded: funded,
      expiry: expiry is Timestamp ? expiry.toDate() : null,
    );
  }
}

class FundingUpdate {
  final FundingRecord? record;
  final bool fromCache;

  const FundingUpdate({required this.record, required this.fromCache});
}

class FundingService {
  Stream<FundingUpdate> watchFunding(String uid) {
    return FirebaseFirestore.instance
        .collection('students')
        .doc(uid)
        .snapshots(includeMetadataChanges: true)
        .map((snapshot) {
          final data = snapshot.data();

          return FundingUpdate(
            record: data == null ? null : FundingRecord.fromMap(data),
            fromCache: snapshot.metadata.isFromCache,
          );
        });
  }
}
