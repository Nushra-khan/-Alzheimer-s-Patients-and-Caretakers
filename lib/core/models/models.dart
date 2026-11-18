enum UserRole { patient, caregiver }

class AppSession {
  final UserRole? role;
  final bool isAuthenticated;

  /// True while a saved sign-in is being checked at app start.
  final bool isRestoring;

  /// The signed-in account, when known.
  final String? userId;

  /// Changes on every new sign-in, so care data from the previous person is
  /// always cleared, even when the role is the same.
  final int generation;

  const AppSession._({
    required this.role,
    required this.isAuthenticated,
    this.isRestoring = false,
    this.userId,
    this.generation = 0,
  });

  const AppSession.signedOut() : this._(role: null, isAuthenticated: false);

  const AppSession.restoring()
    : this._(role: null, isAuthenticated: false, isRestoring: true);

  const AppSession.authenticated(
    UserRole role, {
    String? userId,
    int generation = 0,
  }) : this._(
         role: role,
         isAuthenticated: true,
         userId: userId,
         generation: generation,
       );

  /// Signed in, but the account has not chosen patient or caregiver yet
  /// (for example, a first sign-in with Google).
  const AppSession.needsRole({String? userId, int generation = 0})
    : this._(
        role: null,
        isAuthenticated: true,
        userId: userId,
        generation: generation,
      );

  bool get needsRole => isAuthenticated && role == null;

  @override
  bool operator ==(Object other) =>
      other is AppSession &&
      other.role == role &&
      other.isAuthenticated == isAuthenticated &&
      other.isRestoring == isRestoring &&
      other.userId == userId &&
      other.generation == generation;

  @override
  int get hashCode =>
      Object.hash(role, isAuthenticated, isRestoring, userId, generation);
  bool get canAccessPatient => role == UserRole.patient;
  bool get canAccessCaregiver => role == UserRole.caregiver;
}

enum AlertSeverity { critical, warning, info }

enum AlertStatus { active, acknowledged, resolved }

enum AlertType { sos, overdueDose, safeZoneExit, deviceOffline }

enum SafeZoneStatus { inside, outside, stale, offline, unknown }

class PatientModel {
  final String id;

  /// The patient's profile (auth user) ID; their photos live in this folder.
  final String profileId;
  final String name;
  final DateTime dateOfBirth;
  final String photoUrl;
  final int? batteryLevel;
  final bool isDeviceOnline;
  final bool locationSharingEnabled;
  final DateTime? lastSyncTime;
  final SafeZoneStatus safeZoneStatus;
  final String lastKnownLocationName;

  PatientModel({
    required this.id,
    this.profileId = '',
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
    String? profileId,
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
      profileId: profileId ?? this.profileId,
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
  final String profileId;
  final String name;
  final String relationship;
  final String phone;
  final String email;
  final bool isPrimary;
  final String photoUrl;

  CaregiverModel({
    required this.id,
    this.profileId = '',
    required this.name,
    required this.relationship,
    required this.phone,
    required this.email,
    required this.isPrimary,
    this.photoUrl = '',
  });

  CaregiverModel copyWith({
    String? name,
    String? relationship,
    String? phone,
    String? photoUrl,
  }) {
    return CaregiverModel(
      id: id,
      profileId: profileId,
      name: name ?? this.name,
      relationship: relationship ?? this.relationship,
      phone: phone ?? this.phone,
      email: email,
      isPrimary: isPrimary,
      photoUrl: photoUrl ?? this.photoUrl,
    );
  }
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
  bool get isSkipped => status == DoseStatus.skipped;
  bool get isPending =>
      status == DoseStatus.scheduled || status == DoseStatus.overdue;

  DoseInstance copyWith({
    String? id,
    String? medicationId,
    String? medicineName,
    String? dosage,
    String? instructions,
    DateTime? scheduledFor,
    DoseStatus? status,
    DateTime? reportedAt,
    bool clearReportedAt = false,
  }) {
    return DoseInstance(
      id: id ?? this.id,
      medicationId: medicationId ?? this.medicationId,
      medicineName: medicineName ?? this.medicineName,
      dosage: dosage ?? this.dosage,
      instructions: instructions ?? this.instructions,
      scheduledFor: scheduledFor ?? this.scheduledFor,
      status: status ?? this.status,
      reportedAt: clearReportedAt ? null : reportedAt ?? this.reportedAt,
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
  final String configuredByName;
  final DateTime? configuredAt;

  SafeZoneModel({
    required this.id,
    required this.name,
    required this.radiusMeters,
    required this.centerLatitude,
    required this.centerLongitude,
    required this.isPatientInside,
    required this.lastChecked,
    this.configuredByName = 'Unknown',
    this.configuredAt,
  });

  SafeZoneModel copyWith({
    String? id,
    String? name,
    double? radiusMeters,
    double? centerLatitude,
    double? centerLongitude,
    bool? isPatientInside,
    DateTime? lastChecked,
    String? configuredByName,
    DateTime? configuredAt,
  }) {
    return SafeZoneModel(
      id: id ?? this.id,
      name: name ?? this.name,
      radiusMeters: radiusMeters ?? this.radiusMeters,
      centerLatitude: centerLatitude ?? this.centerLatitude,
      centerLongitude: centerLongitude ?? this.centerLongitude,
      isPatientInside: isPatientInside ?? this.isPatientInside,
      lastChecked: lastChecked ?? this.lastChecked,
      configuredByName: configuredByName ?? this.configuredByName,
      configuredAt: configuredAt ?? this.configuredAt,
    );
  }
}

class EmergencyContact {
  final String id;
  final String name;
  final String phone;
  final String relationship;
  final int priority;

  EmergencyContact({
    required this.id,
    required this.name,
    required this.phone,
    required this.relationship,
    required this.priority,
  });

  EmergencyContact copyWith({
    String? id,
    String? name,
    String? phone,
    String? relationship,
    int? priority,
  }) {
    return EmergencyContact(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      relationship: relationship ?? this.relationship,
      priority: priority ?? this.priority,
    );
  }
}

/// The patient's last reported position.
class PatientLocation {
  final double latitude;
  final double longitude;
  final double accuracyMeters;
  final DateTime observedAt;

  const PatientLocation({
    required this.latitude,
    required this.longitude,
    required this.accuracyMeters,
    required this.observedAt,
  });
}

enum LocationState { inside, outside, offline, unknown, sharingOff }

/// Everything the caregiver's map needs, computed by the backend.
class LocationStatus {
  final LocationState state;
  final bool sharingEnabled;
  final DateTime? lastSeenAt;
  final int? batteryLevel;
  final PatientLocation? location;
  final SafeZoneModel? safeZone;

  const LocationStatus({
    required this.state,
    required this.sharingEnabled,
    required this.lastSeenAt,
    required this.batteryLevel,
    required this.location,
    required this.safeZone,
  });
}

/// An active medication and its daily time, independent of today's dose.
class MedicationModel {
  final String id;
  final String name;
  final String dosage;
  final String instructions;
  final int hour;
  final int minute;

  /// First day a dose is due (later than today when added after its time).
  final DateTime startsOn;

  const MedicationModel({
    required this.id,
    required this.name,
    required this.dosage,
    required this.instructions,
    required this.hour,
    required this.minute,
    required this.startsOn,
  });

  MedicationModel copyWith({
    String? name,
    String? dosage,
    String? instructions,
    int? hour,
    int? minute,
  }) {
    return MedicationModel(
      id: id,
      name: name ?? this.name,
      dosage: dosage ?? this.dosage,
      instructions: instructions ?? this.instructions,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
      startsOn: startsOn,
    );
  }

  /// Minutes after midnight, for sorting by time of day.
  int get minutesOfDay => hour * 60 + minute;
}

/// The patient's full profile: name, birth date, photo and the care details
/// listed in [PatientDetails.fieldKeys], keyed by database column name.
class PatientDetails {
  final String profileId;
  final String fullName;
  final DateTime? dateOfBirth;
  final String photoUrl;
  final Map<String, String> fields;

  const PatientDetails({
    required this.profileId,
    required this.fullName,
    required this.dateOfBirth,
    required this.photoUrl,
    required this.fields,
  });

  static const fieldKeys = [
    'preferred_name',
    'gender',
    'languages',
    'home_address',
    'blood_group',
    'food_allergies',
    'medicine_allergies',
    'other_allergies',
    'medical_conditions',
    'dementia_stage',
    'doctor_name',
    'doctor_phone',
    'preferred_hospital',
    'medical_notes',
    'mobility_aids',
    'sensory_aids',
    'diet_needs',
    'wandering_risk',
    'calming_things',
    'upsetting_things',
    'id_bracelet_number',
  ];

  String value(String key) => fields[key] ?? '';

  /// Age in whole years, or null when the birth date is unknown.
  int? get age {
    final birth = dateOfBirth;
    if (birth == null) return null;
    final now = DateTime.now();
    var years = now.year - birth.year;
    if (now.month < birth.month ||
        (now.month == birth.month && now.day < birth.day)) {
      years--;
    }
    return years;
  }

  /// Every allergy in one line, for the Medical ID card.
  String get allAllergies => [
    value('food_allergies'),
    value('medicine_allergies'),
    value('other_allergies'),
  ].where((text) => text.trim().isNotEmpty).join('; ');

  PatientDetails copyWith({
    String? fullName,
    DateTime? dateOfBirth,
    bool clearDateOfBirth = false,
    String? photoUrl,
    Map<String, String>? fields,
  }) {
    return PatientDetails(
      profileId: profileId,
      fullName: fullName ?? this.fullName,
      dateOfBirth: clearDateOfBirth ? null : dateOfBirth ?? this.dateOfBirth,
      photoUrl: photoUrl ?? this.photoUrl,
      fields: fields ?? this.fields,
    );
  }
}
