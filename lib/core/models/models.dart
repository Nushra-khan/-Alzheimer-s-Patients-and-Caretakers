enum UserRole { patient, caregiver }

class AppSession {
  final UserRole? role;
  final bool isAuthenticated;

  const AppSession._({required this.role, required this.isAuthenticated});

  const AppSession.signedOut() : this._(role: null, isAuthenticated: false);

  const AppSession.authenticated(UserRole role)
    : this._(role: role, isAuthenticated: true);

  bool get canAccessPatient => role == UserRole.patient;
  bool get canAccessCaregiver => role == UserRole.caregiver;
}

enum AlertSeverity { critical, warning, info }

enum AlertStatus { active, acknowledged, resolved }

enum AlertType { sos, overdueDose, safeZoneExit, deviceOffline }

enum SafeZoneStatus { inside, outside, stale, offline, unknown }

class PatientModel {
  final String id;
  final String name;
  final DateTime dateOfBirth;
  final String photoUrl;
  final int batteryLevel;
  final bool isDeviceOnline;
  final bool locationSharingEnabled;
  final DateTime lastSyncTime;
  final SafeZoneStatus safeZoneStatus;
  final String lastKnownLocationName;

  PatientModel({
    required this.id,
    required this.name,
    required this.dateOfBirth,
    required this.photoUrl,
    required this.batteryLevel,
    required this.isDeviceOnline,
    required this.locationSharingEnabled,
    required this.lastSyncTime,
    required this.safeZoneStatus,
    required this.lastKnownLocationName,
  });

  PatientModel copyWith({
    String? id,
    String? name,
    DateTime? dateOfBirth,
    String? photoUrl,
    int? batteryLevel,
    bool? isDeviceOnline,
    bool? locationSharingEnabled,
    DateTime? lastSyncTime,
    SafeZoneStatus? safeZoneStatus,
    String? lastKnownLocationName,
  }) {
    return PatientModel(
      id: id ?? this.id,
      name: name ?? this.name,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      photoUrl: photoUrl ?? this.photoUrl,
      batteryLevel: batteryLevel ?? this.batteryLevel,
      isDeviceOnline: isDeviceOnline ?? this.isDeviceOnline,
      locationSharingEnabled:
          locationSharingEnabled ?? this.locationSharingEnabled,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
      safeZoneStatus: safeZoneStatus ?? this.safeZoneStatus,
      lastKnownLocationName:
          lastKnownLocationName ?? this.lastKnownLocationName,
    );
  }

  int ageOn(DateTime date) {
    var years = date.year - dateOfBirth.year;
    final hasHadBirthday =
        date.month > dateOfBirth.month ||
        (date.month == dateOfBirth.month && date.day >= dateOfBirth.day);
    if (!hasHadBirthday) years--;
    return years;
  }

  int get age => ageOn(DateTime.now());
}

class CaregiverModel {
  final String id;
  final String name;
  final String relationship;
  final String phone;
  final String email;
  final bool isPrimary;

  CaregiverModel({
    required this.id,
    required this.name,
    required this.relationship,
    required this.phone,
    required this.email,
    required this.isPrimary,
  });
}

enum DoseStatus { scheduled, reportedTaken, skipped, overdue }

class DoseInstance {
  final String id;
  final String medicationId;
  final String medicineName;
  final String dosage;
  final String instructions;
  final DateTime scheduledFor;
  final DoseStatus status;
  final DateTime? reportedAt;

  const DoseInstance({
    required this.id,
    required this.medicationId,
    required this.medicineName,
    required this.dosage,
    required this.instructions,
    required this.scheduledFor,
    required this.status,
    this.reportedAt,
  });

  bool get isReportedTaken => status == DoseStatus.reportedTaken;

  DoseInstance copyWith({
    String? id,
    String? medicationId,
    String? medicineName,
    String? dosage,
    String? instructions,
    DateTime? scheduledFor,
    DoseStatus? status,
    DateTime? reportedAt,
  }) {
    return DoseInstance(
      id: id ?? this.id,
      medicationId: medicationId ?? this.medicationId,
      medicineName: medicineName ?? this.medicineName,
      dosage: dosage ?? this.dosage,
      instructions: instructions ?? this.instructions,
      scheduledFor: scheduledFor ?? this.scheduledFor,
      status: status ?? this.status,
      reportedAt: reportedAt ?? this.reportedAt,
    );
  }
}

class RoutineItem {
  final String id;
  final String title;
  final String subtitle;
  final String time;
  final bool isCompleted;

  RoutineItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.time,
    required this.isCompleted,
  });

  RoutineItem copyWith({
    String? id,
    String? title,
    String? subtitle,
    String? time,
    bool? isCompleted,
  }) {
    return RoutineItem(
      id: id ?? this.id,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      time: time ?? this.time,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }
}

class AlertModel {
  final String id;
  final String patientId;
  final String patientName;
  final AlertType type;
  final AlertSeverity severity;
  final String title;
  final String description;
  final DateTime timestamp;
  final AlertStatus status;
  final String? acknowledgedBy;
  final DateTime? acknowledgedAt;
  final DateTime? resolvedAt;

  AlertModel({
    required this.id,
    required this.patientId,
    required this.patientName,
    required this.type,
    required this.severity,
    required this.title,
    required this.description,
    required this.timestamp,
    required this.status,
    this.acknowledgedBy,
    this.acknowledgedAt,
    this.resolvedAt,
  });

  AlertModel copyWith({
    String? id,
    String? patientId,
    String? patientName,
    AlertType? type,
    AlertSeverity? severity,
    String? title,
    String? description,
    DateTime? timestamp,
    AlertStatus? status,
    String? acknowledgedBy,
    DateTime? acknowledgedAt,
    DateTime? resolvedAt,
  }) {
    return AlertModel(
      id: id ?? this.id,
      patientId: patientId ?? this.patientId,
      patientName: patientName ?? this.patientName,
      type: type ?? this.type,
      severity: severity ?? this.severity,
      title: title ?? this.title,
      description: description ?? this.description,
      timestamp: timestamp ?? this.timestamp,
      status: status ?? this.status,
      acknowledgedBy: acknowledgedBy ?? this.acknowledgedBy,
      acknowledgedAt: acknowledgedAt ?? this.acknowledgedAt,
      resolvedAt: resolvedAt ?? this.resolvedAt,
    );
  }
}

class SafeZoneModel {
  final String id;
  final String name;
  final double radiusMeters;
  final double centerLatitude;
  final double centerLongitude;
  final bool isPatientInside;
  final DateTime lastChecked;

  SafeZoneModel({
    required this.id,
    required this.name,
    required this.radiusMeters,
    required this.centerLatitude,
    required this.centerLongitude,
    required this.isPatientInside,
    required this.lastChecked,
  });

  SafeZoneModel copyWith({
    String? id,
    String? name,
    double? radiusMeters,
    double? centerLatitude,
    double? centerLongitude,
    bool? isPatientInside,
    DateTime? lastChecked,
  }) {
    return SafeZoneModel(
      id: id ?? this.id,
      name: name ?? this.name,
      radiusMeters: radiusMeters ?? this.radiusMeters,
      centerLatitude: centerLatitude ?? this.centerLatitude,
      centerLongitude: centerLongitude ?? this.centerLongitude,
      isPatientInside: isPatientInside ?? this.isPatientInside,
      lastChecked: lastChecked ?? this.lastChecked,
    );
  }
}

class EmergencyContact {
  final String name;
  final String phone;
  final String relationship;

  EmergencyContact({
    required this.name,
    required this.phone,
    required this.relationship,
  });
}
