import 'dart:async';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/models.dart';
import 'care_repository.dart';

class SupabaseCareRepository implements CareRepository {
  SupabaseCareRepository(this._client);

  final SupabaseClient _client;

  static const photoBucket = 'profile-photos';

  /// A private photo link valid for one hour, or '' when there is none.
  Future<String> _photoUrl(String? path) async {
    if (path == null || path.isEmpty) return '';
    try {
      return await _client.storage
          .from(photoBucket)
          .createSignedUrl(path, 3600);
    } catch (_) {
      return '';
    }
  }

  @override
  Future<String> resolveAccessiblePatientId() async {
    // RLS limits this to the user's own patient record or patients they care
    // for. Order by creation so a caregiver linked to several patients always
    // gets the same one instead of whichever row Postgres returns first.
    final row = await _client
        .from('patients')
        .select('id')
        .order('created_at')
        .order('id')
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
        .select('display_name, photo_path')
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
      profileId: patient['profile_id'] as String,
      name: profile['display_name'] as String? ?? 'Patient',
      dateOfBirth:
          DateTime.tryParse(patient['date_of_birth'] as String? ?? '') ?? now,
      photoUrl: await _photoUrl(profile['photo_path'] as String?),
      batteryLevel: null,
      isDeviceOnline:
          lastSeen != null && now.difference(lastSeen).inMinutes < 15,
      locationSharingEnabled:
          patient['location_sharing_enabled'] as bool? ?? false,
      lastSyncTime: lastSeen,
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
    await _ensureDoseInstances(patientId, start);
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
        .inFilter('id', scheduleIds)
        .eq('active', true);
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
              .inFilter('id', medicationIds)
              .eq('active', true);
    final medicationById = <String, Map<String, dynamic>>{
      for (final row in medicationRows) row['id'] as String: row,
    };

    return doseRows
        .where((row) {
          final medicationId =
              medicationIdBySchedule[row['schedule_id'] as String];
          return medicationId != null &&
              medicationById.containsKey(medicationId);
        })
        .map((row) {
          final scheduleId = row['schedule_id'] as String;
          final medicationId = medicationIdBySchedule[scheduleId]!;
          final medication = medicationById[medicationId]!;
          final scheduledFor = DateTime.parse(row['scheduled_for'] as String);
          return DoseInstance(
            id: row['id'] as String,
            medicationId: medicationId,
            medicineName: medication['name'] as String? ?? 'Medication',
            dosage: medication['dosage'] as String? ?? '',
            instructions: medication['instructions'] as String? ?? '',
            scheduledFor: scheduledFor.toLocal(),
            status: _doseStatus(row['status'] as String? ?? 'scheduled'),
          );
        })
        .toList();
  }

  /// Creates the day's doses for daily schedules and marks missed doses as
  /// overdue. Tolerates a backend where migration 0014 is not applied yet.
  Future<void> _ensureDoseInstances(String patientId, DateTime day) async {
    try {
      await _client.rpc<void>(
        'ensure_dose_instances',
        params: {
          'target_patient_id': patientId,
          'target_local_date': _dateOnly(day),
        },
      );
    } on PostgrestException catch (error) {
      if (!error.message.contains('ensure_dose_instances')) rethrow;
    }
  }

  Future<String> _patientName(String patientId) async {
    final patient = await _client
        .from('patients')
        .select('profile_id')
        .eq('id', patientId)
        .single();
    final profile = await _client
        .from('profiles')
        .select('display_name')
        .eq('id', patient['profile_id'] as String)
        .maybeSingle();
    return profile?['display_name'] as String? ?? 'Patient';
  }

  @override
  Future<PatientDetails> loadPatientDetails(String patientId) async {
    final patient = await _client
        .from('patients')
        .select(
          'profile_id, date_of_birth, ${PatientDetails.fieldKeys.join(', ')}',
        )
        .eq('id', patientId)
        .single();
    final profileId = patient['profile_id'] as String;
    final profile = await _client
        .from('profiles')
        .select('display_name, photo_path')
        .eq('id', profileId)
        .single();
    return PatientDetails(
      profileId: profileId,
      fullName: profile['display_name'] as String? ?? '',
      dateOfBirth: DateTime.tryParse(
        patient['date_of_birth'] as String? ?? '',
      ),
      photoUrl: await _photoUrl(profile['photo_path'] as String?),
      fields: {
        for (final key in PatientDetails.fieldKeys)
          if ((patient[key] as String?)?.isNotEmpty ?? false)
            key: patient[key] as String,
      },
    );
  }

  @override
  Future<void> updatePatientDetails({
    required String patientId,
    required String fullName,
    required DateTime? dateOfBirth,
    required Map<String, String> fields,
  }) => _client.rpc<void>(
    'update_patient_profile',
    params: {
      'target_patient_id': patientId,
      'details': {
        ...fields,
        'full_name': fullName.trim(),
        'date_of_birth': dateOfBirth == null ? '' : _dateOnly(dateOfBirth),
      },
    },
  );

  @override
  Future<String> uploadProfilePhoto({
    required String profileId,
    required Uint8List jpegBytes,
  }) async {
    final bucket = _client.storage.from(photoBucket);
    final path = '$profileId/${DateTime.now().millisecondsSinceEpoch}.jpg';
    await bucket.uploadBinary(
      path,
      jpegBytes,
      fileOptions: const FileOptions(contentType: 'image/jpeg'),
    );
    await _client.rpc<void>(
      'set_profile_photo',
      params: {'target_profile_id': profileId, 'new_photo_path': path},
    );
    // Remove older photos in the folder; failures here are harmless.
    try {
      final files = await bucket.list(path: profileId);
      final old = [
        for (final file in files)
          if ('$profileId/${file.name}' != path) '$profileId/${file.name}',
      ];
      if (old.isNotEmpty) await bucket.remove(old);
    } catch (_) {}
    return _photoUrl(path);
  }

  @override
  Future<void> updateCaregiverProfile({
    required String name,
    required String phone,
    required String relationship,
  }) => _client.rpc<void>(
    'update_caregiver_profile',
    params: {
      'full_name': name.trim(),
      'phone_number': phone.trim(),
      'relationship_to_patient': relationship.trim(),
    },
  );

  @override
  Future<List<MedicationModel>> loadMedications(String patientId) async {
    final medicationRows = await _client
        .from('medications')
        .select('id, name, dosage, instructions')
        .eq('patient_id', patientId)
        .eq('active', true);
    if (medicationRows.isEmpty) return const [];
    final scheduleRows = await _client
        .from('medication_schedules')
        .select('medication_id, local_time, starts_on, created_at')
        .inFilter(
          'medication_id',
          medicationRows.map((row) => row['id'] as String).toList(),
        )
        .eq('active', true)
        .order('created_at', ascending: false);
    final scheduleByMedication = <String, Map<String, dynamic>>{};
    for (final row in scheduleRows) {
      scheduleByMedication.putIfAbsent(
        row['medication_id'] as String,
        () => row,
      );
    }
    final medications = <MedicationModel>[];
    for (final row in medicationRows) {
      final schedule = scheduleByMedication[row['id'] as String];
      if (schedule == null) continue;
      final time = (schedule['local_time'] as String? ?? '09:00').split(':');
      medications.add(
        MedicationModel(
          id: row['id'] as String,
          name: row['name'] as String? ?? 'Medication',
          dosage: row['dosage'] as String? ?? '',
          instructions: row['instructions'] as String? ?? '',
          hour: int.tryParse(time.first) ?? 9,
          minute: time.length > 1 ? int.tryParse(time[1]) ?? 0 : 0,
          startsOn:
              DateTime.tryParse(schedule['starts_on'] as String? ?? '') ??
              DateTime.now(),
        ),
      );
    }
    medications.sort((a, b) => a.minutesOfDay.compareTo(b.minutesOfDay));
    return medications;
  }

  @override
  Future<void> updateMedicationTime({
    required String patientId,
    required String medicationId,
    required int hour,
    required int minute,
    required String timezone,
  }) => _client.rpc<void>(
    'update_medication_time',
    params: {
      'target_patient_id': patientId,
      'target_medication_id': medicationId,
      'target_local_time':
          '${hour.toString().padLeft(2, '0')}:'
          '${minute.toString().padLeft(2, '0')}:00',
      'target_timezone': timezone,
    },
  );

  @override
  Future<List<AlertModel>> loadAlerts(String patientId) async {
    final patientName = await _patientName(patientId);
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
            patientName: patientName,
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
        .select('id, profile_id, relationship')
        .inFilter('id', caregiverIds);
    final profileIds = caregivers
        .map((row) => row['profile_id'] as String)
        .toList();
    final profiles = await _client
        .from('profiles')
        .select('id, display_name, phone, photo_path')
        .inFilter('id', profileIds);
    final profileById = <String, Map<String, dynamic>>{
      for (final row in profiles) row['id'] as String: row,
    };
    return Future.wait(
      caregivers.map((row) async {
        final profile = profileById[row['profile_id'] as String];
        return CaregiverModel(
          id: row['id'] as String,
          profileId: row['profile_id'] as String,
          name: profile?['display_name'] as String? ?? 'Caregiver',
          relationship: row['relationship'] as String? ?? 'Caregiver',
          phone: profile?['phone'] as String? ?? '',
          email: '',
          isPrimary: false,
          photoUrl: await _photoUrl(profile?['photo_path'] as String?),
        );
      }),
    );
  }

  @override
  Future<CaregiverModel> loadCurrentCaregiver() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw const AuthException('Authentication required.');
    }
    final caregiver = await _client
        .from('caregivers')
        .select('id, profile_id, relationship')
        .eq('profile_id', user.id)
        .single();
    final profile = await _client
        .from('profiles')
        .select('display_name, phone, photo_path')
        .eq('id', user.id)
        .single();
    return CaregiverModel(
      id: caregiver['id'] as String,
      profileId: user.id,
      name: profile['display_name'] as String? ?? 'Caregiver',
      relationship: caregiver['relationship'] as String? ?? '',
      phone: profile['phone'] as String? ?? '',
      email: user.email ?? '',
      isPrimary: false,
      photoUrl: await _photoUrl(profile['photo_path'] as String?),
    );
  }

  @override
  Future<List<EmergencyContact>> loadEmergencyContacts(String patientId) async {
    final rows = await _client
        .from('emergency_contacts')
        .select('id, name, relationship, phone, priority')
        .eq('patient_id', patientId)
        .order('priority');
    return rows
        .map(
          (row) => EmergencyContact(
            id: row['id'] as String,
            name: row['name'] as String,
            phone: row['phone'] as String,
            relationship: row['relationship'] as String? ?? '',
            priority: row['priority'] as int? ?? 1,
          ),
        )
        .toList();
  }

  @override
  Future<EmergencyContact> createEmergencyContact({
    required String patientId,
    required String name,
    required String relationship,
    required String phone,
    required int priority,
    required String idempotencyKey,
  }) async {
    final contactId = await _client.rpc<String>(
      'create_emergency_contact',
      params: {
        'target_patient_id': patientId,
        'contact_name': name.trim(),
        'contact_relationship': relationship.trim(),
        'contact_phone': phone.trim(),
        'contact_priority': priority,
        'request_idempotency_key': idempotencyKey,
      },
    );
    return EmergencyContact(
      id: contactId,
      name: name.trim(),
      phone: phone.trim(),
      relationship: relationship.trim(),
      priority: priority,
    );
  }

  @override
  Future<void> updateEmergencyContact({
    required String contactId,
    required String name,
    required String relationship,
    required String phone,
    required int priority,
  }) => _client.rpc<void>(
    'update_emergency_contact',
    params: {
      'target_contact_id': contactId,
      'contact_name': name.trim(),
      'contact_relationship': relationship.trim(),
      'contact_phone': phone.trim(),
      'contact_priority': priority,
    },
  );

  @override
  Future<void> deleteEmergencyContact({required String contactId}) =>
      _client.rpc<void>(
        'delete_emergency_contact',
        params: {'target_contact_id': contactId},
      );

  @override
  Future<SafeZoneModel?> loadSafeZone(String patientId) async =>
      (await loadLocationStatus(patientId)).safeZone;

  @override
  Future<LocationStatus> loadLocationStatus(String patientId) async {
    final result = await _client.rpc<Map<String, dynamic>>(
      'get_location_status',
      params: {'target_patient_id': patientId},
    );
    final state = switch (result['status'] as String?) {
      'inside' => LocationState.inside,
      'outside' => LocationState.outside,
      'offline' => LocationState.offline,
      'sharing_off' => LocationState.sharingOff,
      _ => LocationState.unknown,
    };
    final location = result['location'] as Map<String, dynamic>?;
    final zone = result['safe_zone'] as Map<String, dynamic>?;
    return LocationStatus(
      state: state,
      sharingEnabled: result['sharing_enabled'] as bool? ?? false,
      lastSeenAt: _parseTime(result['last_seen_at']),
      batteryLevel: (result['battery_level'] as num?)?.toInt(),
      location: location == null
          ? null
          : PatientLocation(
              latitude: (location['latitude'] as num).toDouble(),
              longitude: (location['longitude'] as num).toDouble(),
              accuracyMeters:
                  (location['accuracy_meters'] as num?)?.toDouble() ?? 0,
              observedAt: _parseTime(location['observed_at']) ?? DateTime.now(),
            ),
      safeZone: zone == null
          ? null
          : SafeZoneModel(
              id: zone['id'] as String,
              name: zone['name'] as String? ?? 'Safe zone',
              radiusMeters: (zone['radius_meters'] as num).toDouble(),
              centerLatitude: (zone['latitude'] as num).toDouble(),
              centerLongitude: (zone['longitude'] as num).toDouble(),
              isPatientInside: state != LocationState.outside,
              lastChecked: _parseTime(zone['updated_at']) ?? DateTime.now(),
            ),
    );
  }

  @override
  Future<String> saveSafeZone({
    required String patientId,
    required String name,
    required double latitude,
    required double longitude,
    required int radiusMeters,
  }) => _client.rpc<String>(
    'save_safe_zone',
    params: {
      'target_patient_id': patientId,
      'zone_name': name.trim(),
      'target_latitude': latitude,
      'target_longitude': longitude,
      'target_radius_meters': radiusMeters,
    },
  );

  @override
  Future<int> recordLocation({
    required double latitude,
    required double longitude,
    required double accuracyMeters,
    required DateTime observedAt,
    required int? batteryLevel,
    required String idempotencyKey,
  }) async {
    final result = await _client.rpc<Map<String, dynamic>>(
      'record_location',
      params: {
        'target_latitude': latitude,
        'target_longitude': longitude,
        'target_accuracy_meters': accuracyMeters,
        'target_observed_at': observedAt.toUtc().toIso8601String(),
        'target_battery_level': batteryLevel,
        'request_idempotency_key': idempotencyKey,
      },
    );
    return (result['next_update_seconds'] as num?)?.toInt() ?? 300;
  }

  static DateTime? _parseTime(Object? value) =>
      value is String ? DateTime.tryParse(value)?.toLocal() : null;

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
  Future<void> revokeCaregiverAccess({
    required String patientId,
    required String caregiverId,
  }) => _client.rpc<void>(
    'revoke_caregiver_access',
    params: {
      'target_patient_id': patientId,
      'target_caregiver_id': caregiverId,
    },
  );

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
  Future<void> deactivateMedication({
    required String patientId,
    required String medicationId,
  }) => _client.rpc<void>(
    'deactivate_medication',
    params: {
      'target_patient_id': patientId,
      'target_medication_id': medicationId,
    },
  );

  @override
  Future<void> updateMedicationDetails({
    required String patientId,
    required String medicationId,
    required String medicineName,
    required String dosage,
    required String instructions,
  }) => _client.rpc<void>(
    'update_medication_details',
    params: {
      'target_patient_id': patientId,
      'target_medication_id': medicationId,
      'medicine_name': medicineName.trim(),
      'medicine_dosage': dosage.trim(),
      'medicine_instructions': instructions.trim(),
    },
  );

  @override
  Future<RoutineItem> createRoutineSchedule({
    required String patientId,
    required String title,
    required String description,
    required DateTime scheduledFor,
    required String timezone,
    required String idempotencyKey,
  }) async {
    final routineId = await _client.rpc<String>(
      'create_routine_schedule',
      params: {
        'target_patient_id': patientId,
        'routine_title': title.trim(),
        'routine_description': description.trim(),
        'target_local_time': _databaseTime(scheduledFor),
        'target_timezone': timezone,
        'request_idempotency_key': idempotencyKey,
      },
    );
    return RoutineItem(
      id: routineId,
      title: title.trim(),
      subtitle: description.trim(),
      time: _displayTime(_databaseTime(scheduledFor)),
      isCompleted: false,
    );
  }

  @override
  Future<void> updateRoutineSchedule({
    required String routineId,
    required String title,
    required String description,
    required DateTime scheduledFor,
    required String timezone,
  }) => _client.rpc<void>(
    'update_routine_schedule',
    params: {
      'target_routine_id': routineId,
      'routine_title': title.trim(),
      'routine_description': description.trim(),
      'target_local_time': _databaseTime(scheduledFor),
      'target_timezone': timezone,
    },
  );

  @override
  Future<void> deactivateRoutineSchedule({required String routineId}) =>
      _client.rpc<void>(
        'deactivate_routine_schedule',
        params: {'target_routine_id': routineId},
      );

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
          'location_observations',
          'safe_zone_transitions',
          'medications',
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
  Future<void> updateDoseStatus({
    required String doseInstanceId,
    required DoseStatus status,
    required String idempotencyKey,
    required DateTime occurredAt,
  }) => _client.rpc<void>(
    'update_dose_status',
    params: {
      'target_dose_instance_id': doseInstanceId,
      'target_status': _databaseDoseStatus(status),
      'request_idempotency_key': idempotencyKey,
      'target_occurred_at': occurredAt.toUtc().toIso8601String(),
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

  static String _databaseDoseStatus(DoseStatus status) => switch (status) {
    DoseStatus.reportedTaken => 'reported_taken',
    DoseStatus.skipped => 'skipped',
    DoseStatus.overdue => 'overdue',
    DoseStatus.scheduled => 'scheduled',
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

  static String _databaseTime(DateTime value) =>
      '${value.hour.toString().padLeft(2, '0')}:'
      '${value.minute.toString().padLeft(2, '0')}:00';
}
