enum UserRole {
  student,
  driver,
  manager;

  static UserRole fromValue(Object? value) {
    switch (value) {
      case 'student':
        return UserRole.student;
      case 'driver':
        return UserRole.driver;
      case 'manager':
        return UserRole.manager;
      default:
        throw const FormatException('Invalid or missing user role.');
    }
  }
}

class UserProfile {
  final String uid;
  final String fullName;
  final UserRole role;
  final bool isActive;
  final String? studentNumber;

  const UserProfile({
    required this.uid,
    required this.fullName,
    required this.role,
    required this.isActive,
    this.studentNumber,
  });

  factory UserProfile.fromMap(String uid, Map<String, dynamic> data) {
    final fullName = data['fullName'];
    final role = UserRole.fromValue(data['role']);
    final studentNumber = data['studentNumber'];

    if (fullName is! String || fullName.trim().isEmpty) {
      throw const FormatException('Missing full name.');
    }

    if (studentNumber != null && studentNumber is! String) {
      throw const FormatException('Invalid student number.');
    }

    final number = (studentNumber as String?)?.trim();

    if (role == UserRole.student && (number == null || number.isEmpty)) {
      throw const FormatException('Missing student number.');
    }

    return UserProfile(
      uid: uid,
      fullName: fullName.trim(),
      role: role,
      isActive: data['isActive'] == true,
      studentNumber: number,
    );
  }
}

// Labels are presentation only; stored roles remain lowercase.
extension UserRoleLabel on UserRole {
  String get label => switch (this) {
    UserRole.student => 'Student',
    UserRole.driver => 'Driver',
    UserRole.manager => 'Manager',
  };
}
