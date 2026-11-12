class Student {
  final String studentNumber;
  final String name;
  final bool isFunded;
  final DateTime? fundingExpiry;

  const Student({
    required this.studentNumber,
    required this.name,
    required this.isFunded,
    this.fundingExpiry,
  });
}

class BoardingRecord {
  final String studentNumber;
  final String studentName;
  final bool wasFunded;
  final String stopName;
  final DateTime timestamp;
  final bool overridden;

  const BoardingRecord({
    required this.studentNumber,
    required this.studentName,
    required this.wasFunded,
    required this.stopName,
    required this.timestamp,
    this.overridden = false,
  });
}

// Temporary mock data so we can test the logic before connecting a real database
class MockData {
  static final List<Student> students = [
    const Student(
      studentNumber: '221012345',
      name: 'Thando Mtshali',
      isFunded: true,
    ),
    const Student(
      studentNumber: '221054321',
      name: 'Lindiwe Nkosi',
      isFunded: true,
    ),
    const Student(
      studentNumber: '221099999',
      name: 'Sipho Dlamini',
      isFunded: false,
    ),
    const Student(
      studentNumber: '221000001',
      name: 'Amahle Ndlovu',
      isFunded: true,
    ),
  ];

  static List<String> stops = [
    'St Patrix',
    'Anthill',
    'Zanzibar',
    'Twin Towers',
  ];

  static List<BoardingRecord> boardingLog = [];
}
