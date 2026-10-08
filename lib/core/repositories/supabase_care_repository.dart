import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/models.dart';
import 'care_repository.dart';

class SupabaseCareRepository implements CareRepository {
  SupabaseCareRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<String> resolveAccessiblePatientId() async {
    final row = await _client
        .from('patients')
        .select('id')
        .limit(1)
        .maybeSingle();
    final id = row?['id'] as String?;
    if (id == null) {
      throw const NoPatientConnectionException();
    }
    return id;
  }

  @override
  Future<PatientModel> loadPatient(String patientId) async {
    late final Map<String, dynamic> patient;
    try {
      patient = await _client
          .from('patients')
          .select('id, profile_id, date_of_birth, location_sharing_enabled')
          .eq('id', patientId)
          .single();
    } on PostgrestException catch (error) {
      if (!error.message.contains('location_sharing_enabled')) rethrow;
      patient = await _client
          .from('patients')
          .select('id, profile_id, date_of_birth')
          .eq('id', patientId)
          .single();
    }
    final profile = await _client
        .from('profiles')
        .select('display_name')
        .eq('id', patient['profile_id'] as String)
        .single();

    final deviceRows = await _client
        .from('devices')
        .select('last_seen_at')
        .eq('profile_id', patient['profile_id'] as String)
        .eq('active', true)
        .order('last_seen_at', ascending: false)
        .limit(1);
    final lastSeenValue = deviceRows.isEmpty
        ? null
        : deviceRows.first['last_seen_at'] as String?;
    final lastSeen = DateTime.tryParse(lastSeenValue ?? '');
    final now = DateTime.now();

    return PatientModel(
      id: patient['id'] as String,
      name: profile['display_name'] as String? ?? 'Patient',
      dateOfBirth:
          DateTime.tryParse(patient['date_of_birth'] as String? ?? '') ?? now,
      photoUrl: '',
      batteryLevel: 0,
      isDeviceOnline:
          lastSeen != null && now.difference(lastSeen).inMinutes < 15,
      locationSharingEnabled:
          patient['location_sharing_enabled'] as bool? ?? false,
      lastSyncTime: lastSeen ?? now,
      safeZoneStatus: SafeZoneStatus.unknown,
      lastKnownLocationName: 'Location unavailable',
    );
  }

  @override
  Future<List<DoseInstance>> loadTodayDoses(
    String patientId,
    DateTime day,
  ) async {
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));
    final doseRows = await _client
        .from('dose_instances')
        .select('id, schedule_id, scheduled_for, status')
        .eq('patient_id', patientId)
        .gte('scheduled_for', start.toUtc().toIso8601String())
        .lt('scheduled_for', end.toUtc().toIso8601String())
        .order('scheduled_for');
    if (doseRows.isEmpty) return const [];

    final scheduleIds = doseRows
        .map((row) => row['schedule_id'] as String)
        .toSet()
        .toList();
    final scheduleRows = await _client
        .from('medication_schedules')
        .select('id, medication_id')
        .inFilter('id', scheduleIds);
    final medicationIdBySchedule = <String, String>{
      for (final row in scheduleRows)
        row['id'] as String: row['medication_id'] as String,
    };
    final medicationIds = medicationIdBySchedule.values.toSet().toList();
    final medicationRows = medicationIds.isEmpty
        ? <Map<String, dynamic>>[]
        : await _client
              .from('medications')
              .select('id, name, dosage, instructions')
              .inFilter('id', medicationIds);
    final medicationById = <String, Map<String, dynamic>>{
      for (final row in medicationRows) row['id'] as String: row,
    };

    return doseRows.map((row) {
      final scheduleId = row['schedule_id'] as String;
      final medicationId = medicationIdBySchedule[scheduleId] ?? '';
      final medication = medicationById[medicationId];
      final scheduledFor = DateTime.parse(row['scheduled_for'] as String);
      return DoseInstance(
        id: row['id'] as String,
        medicationId: medicationId,
        medicineName: medication?['name'] as String? ?? 'Medication',
        dosage: medication?['dosage'] as String? ?? '',
        instructions: medication?['instructions'] as String? ?? '',
        scheduledFor: scheduledFor.toLocal(),
        status: _doseStatus(row['status'] as String? ?? 'scheduled'),
      );
    }).toList();
  }

  @override
  Future<List<AlertModel>> loadAlerts(String patientId) async {
    final patient = await loadPatient(patientId);
    final rows = await _client
        .from('alerts')
        .select(
          'id, patient_id, type, severity, status, title, message, occurred_at',
        )
        .eq('patient_id', patientId)
        .order('occurred_at', ascending: false)
        .limit(100);
    return rows
        .map(
          (row) => AlertModel(
            id: row['id'] as String,
            patientId: row['patient_id'] as String,
            patientName: patient.name,
            type: _alertType(row['type'] as String? ?? ''),
            severity: _alertSeverity(row['severity'] as String? ?? 'info'),
            title: row['title'] as String? ?? 'Alert',
            description: row['message'] as String? ?? '',
            timestamp: DateTime.parse(row['occurred_at'] as String).toLocal(),
            status: _alertStatus(row['status'] as String? ?? 'created'),
          ),
        )
        .toList();
  }

  @override
  Future<List<RoutineItem>> loadRoutines(String patientId) async {
    final rows = await _client
        .from('routine_schedules')
        .select('id, title, description, local_time')
        .eq('patient_id', patientId)
        .eq('active', true)
        .order('local_time');
    if (rows.isEmpty) return const [];
    final routineIds = rows.map((row) => row['id'] as String).toList();
    final now = DateTime.now();
    final localDate = _dateOnly(now);
    List<Map<String, dynamic>> completionRows;
    try {
      completionRows = await _client
          .from('routine_completions')
          .select('routine_schedule_id')
          .eq('patient_id', patientId)
          .eq('local_date', localDate)
          .inFilter('routine_schedule_id', routineIds);
    } on PostgrestException catch (error) {
      if (!error.message.contains('routine_completions')) rethrow;
      completionRows = const [];
    }
    final completedIds = completionRows
        .map((row) => row['routine_schedule_id'] as String)
        .toSet();
    return rows
        .map(
          (row) => RoutineItem(
            id: row['id'] as String,
            title: row['title'] as String,
            subtitle: row['description'] as String? ?? '',
            time: _displayTime(row['local_time'] as String? ?? ''),
            isCompleted: completedIds.contains(row['id'] as String),
          ),
        )
        .toList();
  }

  @override
  Future<List<CaregiverModel>> loadCaregivers(String patientId) async {
    final relationships = await _client
        .from('care_relationships')
        .select('caregiver_id, permissions')
        .eq('patient_id', patientId)
        .eq('status', 'active');
    if (relationships.isEmpty) return const [];
    final caregiverIds = relationships
        .map((row) => row['caregiver_id'] as String)
        .toList();
    final caregivers = await _client
        .from('caregivers')
        .select('id, profile_id')
        .inFilter('id', caregiverIds);
    final profileIds = caregivers
        .map((row) => row['profile_id'] as String)
        .toList();
    final profiles = await _client
        .from('profiles')
        .select('id, display_name, phone')
        .inFilter('id', profileIds);
    final profileById = <String, Map<String, dynamic>>{
      for (final row in profiles) row['id'] as String: row,
    };
    return caregivers.map((row) {
      final profile = profileById[row['profile_id'] as String];
      return CaregiverModel(
        id: row['id'] as String,
        name: profile?['display_name'] as String? ?? 'Caregiver',
        relationship: 'Caregiver',
        phone: profile?['phone'] as String? ?? '',
        email: '',
        isPrimary: false,
      );
    }).toList();
  }

  @override
  Future<CaregiverModel> loadCurrentCaregiver() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw const AuthException('Authentication required.');
    }
    final caregiver = await _client
        .from('caregivers')
        .select('id, profile_id')
        .eq('profile_id', user.id)
        .single();
    final profile = await _client
        .from('profiles')
        .select('display_name, phone')
        .eq('id', user.id)
        .single();
    return CaregiverModel(
      id: caregiver['id'] as String,
      name: profile['display_name'] as String? ?? 'Caregiver',
      relationship: 'Caregiver',
      phone: profile['phone'] as String? ?? '',
      email: user.email ?? '',
      isPrimary: false,
    );
  }

  @override
  Future<List<EmergencyContact>> loadEmergencyContacts(String patientId) async {
    final rows = await _client
        .from('emergency_contacts')
        .select('name, relationship, phone')
        .eq('patient_id', patientId)
        .order('priority');
    return rows
        .map(
          (row) => EmergencyContact(
            name: row['name'] as String,
            phone: row['phone'] as String,
            relationship: row['relationship'] as String? ?? '',
          ),
        )
        .toList();
  }

  @override
  Future<SafeZoneModel?> loadSafeZone(String patientId) async {
    final row = await _client
        .from('safe_zones')
        .select('id, name, radius_meters, center, updated_at')
        .eq('patient_id', patientId)
        .eq('active', true)
        .limit(1)
        .maybeSingle();
    if (row == null) return null;
    final coordinates = _coordinates(row['center']);
    final transitionRows = await _client
        .from('safe_zone_transitions')
        .select('transition, occurred_at')
        .eq('safe_zone_id', row['id'] as String)
        .order('occurred_at', ascending: false)
        .limit(1);
    final latestTransition = transitionRows.isEmpty
        ? null
        : transitionRows.first['transition'] as String?;
    return SafeZoneModel(
      id: row['id'] as String,
      name: row['name'] as String,
      radiusMeters: (row['radius_meters'] as num).toDouble(),
      centerLatitude: coordinates.$2,
      centerLongitude: coordinates.$1,
      isPatientInside: latestTransition != 'exited',
      lastChecked:
          DateTime.tryParse(row['updated_at'] as String? ?? '')?.toLocal() ??
          DateTime.now(),
    );
  }

  @override
  Future<({String token, DateTime expiresAt})> createCareInvitation() async {
    final rows = await _client.rpc<List<dynamic>>('create_care_invitation');
    if (rows.isEmpty) {
      throw const PostgrestException(message: 'Unable to create invitation.');
    }
    final row = rows.first as Map<String, dynamic>;
    return (
      token: row['invitation_token'] as String,
      expiresAt: DateTime.parse(row['expires_at'] as String).toLocal(),
    );
  }

  @override
  Future<String> acceptCareInvitation(String token) async {
    final patientId = await _client.rpc<String>(
      'accept_care_invitation',
      params: {'invitation_token': token.trim()},
    );
    return patientId;
  }

  @override
  Future<DoseInstance> createMedicationSchedule({
    required String patientId,
    required String medicineName,
    required String dosage,
    required String instructions,
    required DateTime scheduledFor,
    required String timezone,
    required String idempotencyKey,
  }) async {
    final result = await _client.rpc<Map<String, dynamic>>(
      'create_medication_schedule',
      params: {
        'target_patient_id': patientId,
        'medicine_name': medicineName.trim(),
        'medicine_dosage': dosage.trim(),
        'medicine_instructions': instructions.trim(),
        'target_scheduled_for': scheduledFor.toUtc().toIso8601String(),
        'target_timezone': timezone,
        'request_idempotency_key': idempotencyKey,
      },
    );
    return DoseInstance(
      id: result['dose_id'] as String,
      medicationId: result['medication_id'] as String,
      medicineName: medicineName.trim(),
      dosage: dosage.trim(),
      instructions: instructions.trim(),
      scheduledFor: scheduledFor,
      status: DoseStatus.scheduled,
    );
  }

  @override
  Future<void> setRoutineCompleted({
    required String routineId,
    required bool completed,
    required DateTime localDate,
  }) => _client.rpc<void>(
    'set_routine_completed',
    params: {
      'target_routine_id': routineId,
      'completed': completed,
      'target_local_date': _dateOnly(localDate),
    },
  );

  @override
  Future<void> setLocationSharing({
    required String patientId,
    required bool enabled,
  }) => _client.rpc<void>(
    'set_location_sharing',
    params: {'target_patient_id': patientId, 'enabled': enabled},
  );

  @override
  Future<void> updateSafeZoneRadius({
    required String safeZoneId,
    required double radiusMeters,
  }) => _client.rpc<void>(
    'update_safe_zone_radius',
    params: {
      'target_safe_zone_id': safeZoneId,
      'target_radius_meters': radiusMeters.round(),
    },
  );

  @override
  Stream<PatientModel> watchPatient(String patientId) =>
      Stream.fromFuture(loadPatient(patientId));

  @override
  Stream<List<DoseInstance>> watchTodayDoses(String patientId, DateTime day) =>
      Stream.fromFuture(loadTodayDoses(patientId, day));

  @override
  Stream<List<AlertModel>> watchAlerts(String patientId) =>
      Stream.fromFuture(loadAlerts(patientId));

  @override
  Stream<void> watchCareChanges(String patientId) {
    late RealtimeChannel channel;
    Timer? debounce;
    late final StreamController<void> controller;

    void changed(PostgresChangePayload _) {
      debounce?.cancel();
      debounce = Timer(const Duration(milliseconds: 350), () {
        if (!controller.isClosed) controller.add(null);
      });
    }

    RealtimeChannel watchPatientTable(RealtimeChannel target, String table) =>
        target.onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: table,
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'patient_id',
            value: patientId,
          ),
          callback: changed,
        );

    controller = StreamController<void>.broadcast(
      onListen: () {
        channel = _client.channel('care:$patientId');
        for (final table in const [
          'dose_instances',
          'alerts',
          'routine_schedules',
          'routine_completions',
          'safe_zones',
          'care_relationships',
          'emergency_contacts',
        ]) {
          channel = watchPatientTable(channel, table);
        }
        channel
            .onPostgresChanges(
              event: PostgresChangeEvent.all,
              schema: 'public',
              table: 'patients',
              filter: PostgresChangeFilter(
                type: PostgresChangeFilterType.eq,
                column: 'id',
                value: patientId,
              ),
              callback: changed,
            )
            .subscribe();
      },
      onCancel: () async {
        debounce?.cancel();
        await _client.removeChannel(channel);
      },
    );
    return controller.stream;
  }

  @override
  Future<void> reportDoseTaken({
    required String doseInstanceId,
    required String idempotencyKey,
    required DateTime reportedAt,
  }) => _client.rpc<void>(
    'report_dose_taken',
    params: {
      'target_dose_instance_id': doseInstanceId,
      'request_idempotency_key': idempotencyKey,
      'reported_at': reportedAt.toUtc().toIso8601String(),
    },
  );

  @override
  Future<String> createSos({
    required String patientId,
    required String idempotencyKey,
    required DateTime occurredAt,
  }) async {
    final result = await _client.rpc<String>(
      'create_sos',
      params: {
        'target_patient_id': patientId,
        'request_idempotency_key': idempotencyKey,
        'occurred_at': occurredAt.toUtc().toIso8601String(),
      },
    );
    return result;
  }

  @override
  Future<void> acknowledgeAlert({
    required String alertId,
    required String idempotencyKey,
  }) => _client.rpc<void>(
    'acknowledge_alert',
    params: {
      'target_alert_id': alertId,
      'request_idempotency_key': idempotencyKey,
    },
  );

  @override
  Future<void> resolveAlert({
    required String alertId,
    required String resolutionNote,
    required String idempotencyKey,
  }) => _client.rpc<void>(
    'resolve_alert',
    params: {
      'target_alert_id': alertId,
      'resolution_note': resolutionNote,
      'request_idempotency_key': idempotencyKey,
    },
  );

  static DoseStatus _doseStatus(String value) => switch (value) {
    'reported_taken' => DoseStatus.reportedTaken,
    'skipped' => DoseStatus.skipped,
    'overdue' => DoseStatus.overdue,
    _ => DoseStatus.scheduled,
  };

  static AlertType _alertType(String value) => switch (value) {
    'sos' => AlertType.sos,
    'overdue_dose' => AlertType.overdueDose,
    'safe_zone_exit' => AlertType.safeZoneExit,
    _ => AlertType.deviceOffline,
  };

  static AlertSeverity _alertSeverity(String value) => switch (value) {
    'critical' => AlertSeverity.critical,
    'warning' => AlertSeverity.warning,
    _ => AlertSeverity.info,
  };

  static AlertStatus _alertStatus(String value) => switch (value) {
    'acknowledged' || 'action_taken' => AlertStatus.acknowledged,
    'resolved' || 'cancelled' || 'expired' => AlertStatus.resolved,
    _ => AlertStatus.active,
  };

  static String _displayTime(String value) {
    final parts = value.split(':');
    if (parts.length < 2) return value;
    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = parts[1];
    final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    return '$displayHour:$minute ${hour >= 12 ? 'PM' : 'AM'}';
  }

  static String _dateOnly(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';

  static (double, double) _coordinates(Object? value) {
    if (value is Map<String, dynamic>) {
      final coordinates = value['coordinates'];
      if (coordinates is List && coordinates.length >= 2) {
        return (
          (coordinates[0] as num).toDouble(),
          (coordinates[1] as num).toDouble(),
        );
      }
    }
    return (0, 0);
  }
}
