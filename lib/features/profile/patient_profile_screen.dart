import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/theme.dart';
import '../../core/models/models.dart';
import '../../core/photos/photo_picker.dart';
import '../../core/providers/app_state.dart';
import '../auth/auth_service.dart';
import 'patient_profile_fields.dart';
import 'profile_avatar.dart';

/// The patient's profile: photo, basic, medical and care details.
/// Opened by the patient from Settings and by caregivers from their Profile.
class PatientProfileScreen extends ConsumerStatefulWidget {
  const PatientProfileScreen({super.key, this.caregiverView = false});

  final bool caregiverView;

  @override
  ConsumerState<PatientProfileScreen> createState() =>
      _PatientProfileScreenState();
}

class _PatientProfileScreenState extends ConsumerState<PatientProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _controllers = <String, TextEditingController>{};
  final _choices = <String, String?>{};
  DateTime? _dateOfBirth;
  bool _editing = false;
  bool _saving = false;
  bool _uploadingPhoto = false;

  @override
  void dispose() {
    _nameController.dispose();
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _startEditing(PatientDetails details) {
    _nameController.text = details.fullName;
    _dateOfBirth = details.dateOfBirth;
    for (final section in patientProfileSections) {
      for (final field in section.fields) {
        if (field.kind == ProfileFieldKind.choice) {
          final value = details.value(field.key);
          _choices[field.key] = field.choices.containsKey(value) ? value : null;
        } else {
          (_controllers[field.key] ??= TextEditingController()).text = details
              .value(field.key);
        }
      }
    }
    setState(() => _editing = true);
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    final patient = ref.read(patientProvider);
    setState(() => _saving = true);
    try {
      await ref
          .read(patientDetailsProvider.notifier)
          .save(
            patientId: patient.id,
            fullName: _nameController.text,
            dateOfBirth: _dateOfBirth,
            fields: {
              for (final entry in _controllers.entries)
                entry.key: entry.value.text,
              for (final entry in _choices.entries)
                entry.key: entry.value ?? '',
            },
          );
      ref
          .read(patientProvider.notifier)
          .replace(
            patient.copyWith(
              name: _nameController.text.trim(),
              dateOfBirth: _dateOfBirth,
            ),
          );
      if (!mounted) return;
      setState(() => _editing = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profile saved')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(readableAuthError(error))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _changePhoto(PatientDetails details) async {
    final fromCamera = await askPhotoSource(context);
    if (fromCamera == null || !mounted) return;
    setState(() => _uploadingPhoto = true);
    try {
      final bytes = await pickSquarePhoto(fromCamera: fromCamera);
      if (bytes == null) return;
      if (ref.read(careRepositoryProvider) == null) {
        throw const FormatException(
          'Photos can be saved when the app is connected to Supabase.',
        );
      }
      final url = await ref
          .read(patientDetailsProvider.notifier)
          .uploadPhoto(details.profileId, bytes);
      final patient = ref.read(patientProvider);
      ref
          .read(patientProvider.notifier)
          .replace(patient.copyWith(photoUrl: url));
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Photo updated')));
    } catch (error) {
      if (!mounted) return;
      final message = error is FormatException
          ? error.message
          : readableAuthError(error);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateOfBirth ?? DateTime(now.year - 70, 1, 1),
      firstDate: DateTime(1900),
      lastDate: now,
      helpText: 'Date of birth',
      initialEntryMode: DatePickerEntryMode.calendarOnly,
    );
    if (picked != null) setState(() => _dateOfBirth = picked);
  }

  @override
  Widget build(BuildContext context) {
    final details = ref.watch(patientDetailsProvider);
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: Text(
          widget.caregiverView ? "Patient's profile" : 'My profile',
        ),
        actions: [
          if (details != null && !_editing)
            TextButton.icon(
              onPressed: () => _startEditing(details),
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Edit'),
            ),
        ],
      ),
      body: details == null
          ? _NotLoaded(
              onRetry: () => ref.invalidate(careBootstrapProvider),
            )
          : _editing
          ? _buildForm()
          : _buildView(details),
    );
  }

  Widget _buildView(PatientDetails details) {
    final age = details.age;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        Center(
          child: Stack(
            children: [
              ProfileAvatar(
                name: details.fullName,
                photoUrl: details.photoUrl,
                radius: 60,
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: IconButton.filled(
                  tooltip: 'Change photo',
                  onPressed: _uploadingPhoto
                      ? null
                      : () => _changePhoto(details),
                  icon: _uploadingPhoto
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.photo_camera_rounded),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Text(
          details.fullName,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
        ),
        if (details.value('preferred_name').isNotEmpty)
          Text(
            'Likes to be called ${details.value('preferred_name')}',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 17, color: AppTheme.textSecondary),
          ),
        const SizedBox(height: 4),
        Text(
          age == null
              ? 'Date of birth not added'
              : '$age years • Born '
                    '${DateFormat('d MMM yyyy').format(details.dateOfBirth!)}',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 17, color: AppTheme.textSecondary),
        ),
        const SizedBox(height: 20),
        for (final section in patientProfileSections) ...[
          _SectionTitle(section.title, section.icon),
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              children: [
                for (final field in section.fields)
                  ListTile(
                    title: Text(
                      field.label,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    subtitle: Text(
                      details.value(field.key).isEmpty
                          ? 'Not added'
                          : field.display(details.value(field.key)),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: details.value(field.key).isEmpty
                            ? AppTheme.textSecondary
                            : AppTheme.textPrimary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 18),
        ],
      ],
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          TextFormField(
            controller: _nameController,
            enabled: !_saving,
            textCapitalization: TextCapitalization.words,
            maxLength: 120,
            decoration: const InputDecoration(labelText: 'Full name *'),
            validator: (value) =>
                (value?.trim().isEmpty ?? true) ? 'Enter the full name' : null,
          ),
          const SizedBox(height: 8),
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: _saving ? null : _pickBirthDate,
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: 'Date of birth',
                suffixIcon: _dateOfBirth == null
                    ? const Icon(Icons.calendar_today_rounded)
                    : IconButton(
                        tooltip: 'Clear date of birth',
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: _saving
                            ? null
                            : () => setState(() => _dateOfBirth = null),
                      ),
              ),
              child: Text(
                _dateOfBirth == null
                    ? 'Tap to choose'
                    : DateFormat('d MMMM yyyy').format(_dateOfBirth!),
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ),
          const SizedBox(height: 20),
          for (final section in patientProfileSections) ...[
            _SectionTitle(section.title, section.icon),
            for (final field in section.fields) ...[
              _buildField(field),
              const SizedBox(height: 12),
            ],
            const SizedBox(height: 8),
          ],
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _saving
                      ? null
                      : () => setState(() => _editing = false),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Save profile'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildField(ProfileField field) {
    if (field.kind == ProfileFieldKind.choice) {
      return DropdownButtonFormField<String>(
        initialValue: _choices[field.key],
        decoration: InputDecoration(labelText: field.label),
        items: [
          const DropdownMenuItem(value: null, child: Text('Not set')),
          for (final entry in field.choices.entries)
            DropdownMenuItem(value: entry.key, child: Text(entry.value)),
        ],
        onChanged: _saving
            ? null
            : (value) => setState(() => _choices[field.key] = value),
      );
    }
    final multiline = field.kind == ProfileFieldKind.multiline;
    return TextFormField(
      controller: _controllers[field.key],
      enabled: !_saving,
      keyboardType: field.kind == ProfileFieldKind.phone
          ? TextInputType.phone
          : multiline
          ? TextInputType.multiline
          : TextInputType.text,
      textCapitalization: TextCapitalization.sentences,
      minLines: multiline ? 2 : 1,
      maxLines: multiline ? 5 : 1,
      maxLength: field.maxLength,
      decoration: InputDecoration(
        labelText: field.label,
        hintText: field.hint,
        counterText: '',
      ),
      validator: (value) => validateProfileField(field, value ?? ''),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title, this.icon);

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.primaryColor),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _NotLoaded extends StatelessWidget {
  const _NotLoaded({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'The profile could not be loaded.',
              style: TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}
