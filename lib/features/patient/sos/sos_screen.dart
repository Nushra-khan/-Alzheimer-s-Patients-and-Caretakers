import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme.dart';
import '../../../core/providers/app_state.dart';

class SosScreen extends ConsumerStatefulWidget {
  const SosScreen({super.key});

  @override
  ConsumerState<SosScreen> createState() => _SosScreenState();
}

class _SosScreenState extends ConsumerState<SosScreen> {
  bool _isCountingDown = false;
  int _countdownSeconds = 5;
  Timer? _timer;
  bool _alertSent = false;
  DateTime? _alertSentTime;

  void _startSosCountdown() {
    setState(() {
      _isCountingDown = true;
      _countdownSeconds = 5;
      _alertSent = false;
    });

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdownSeconds > 1) {
        setState(() {
          _countdownSeconds--;
        });
      } else {
        _timer?.cancel();
        _triggerFinalSos();
      }
    });
  }

  void _cancelSosCountdown() {
    _timer?.cancel();
    setState(() {
      _isCountingDown = false;
      _countdownSeconds = 5;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('SOS Alert cancelled.'),
        backgroundColor: Colors.black87,
      ),
    );
  }

  void _triggerFinalSos() {
    final patient = ref.read(patientProvider);
    ref
        .read(alertsProvider.notifier)
        .triggerSOSAlert(patientName: patient.name);

    setState(() {
      _isCountingDown = false;
      _alertSent = true;
      _alertSentTime = DateTime.now();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final emergencyContacts = ref.watch(emergencyContactsProvider);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Emergency Header Notice
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.alertRedContainer,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.alertRed, width: 1.5),
                ),
                child: Row(
                  children: const [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: AppTheme.alertRed,
                      size: 36,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Emergency Help Signal\nPress button below to notify caregivers immediately.',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.onAlertRedContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // SOS Main Interactive Section
              Center(
                child: Column(
                  children: [
                    if (_isCountingDown) ...[
                      // Countdown Overlay UI
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: AppTheme.alertRedContainer,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppTheme.alertRed,
                            width: 4,
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '$_countdownSeconds',
                              style: const TextStyle(
                                fontSize: 64,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.alertRed,
                              ),
                            ),
                            const Text(
                              'Sending SOS...',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppTheme.alertRed,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black87,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(240, 56),
                        ),
                        onPressed: _cancelSosCountdown,
                        icon: const Icon(Icons.cancel_rounded, size: 28),
                        label: const Text(
                          'CANCEL SOS',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ] else if (_alertSent) ...[
                      // Sent Status UI
                      Container(
                        width: 180,
                        height: 180,
                        decoration: BoxDecoration(
                          color: AppTheme.successGreenContainer,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppTheme.successGreen,
                            width: 3,
                          ),
                        ),
                        child: const Icon(
                          Icons.mark_email_read_rounded,
                          size: 90,
                          color: AppTheme.successGreen,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'SOS ALERT DELIVERED',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.successGreen,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Sent at ${_formatTimestamp(_alertSentTime!)}\nCaregivers (Sunita & Anil) have received push notifications.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 20),
                      OutlinedButton(
                        onPressed: _startSosCountdown,
                        child: const Text('Send Another SOS Signal'),
                      ),
                    ] else ...[
                      // Idle Huge Accessible SOS Button
                      GestureDetector(
                        onTap: _startSosCountdown,
                        child: Container(
                          width: 220,
                          height: 220,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFE53935), Color(0xFFC62828)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.alertRed.withValues(alpha: 0.4),
                                blurRadius: 20,
                                spreadRadius: 4,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.touch_app_rounded,
                                color: Colors.white,
                                size: 48,
                              ),
                              SizedBox(height: 8),
                              Text(
                                'PRESS FOR\nSOS HELP',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  letterSpacing: 1.2,
                                  height: 1.1,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Tap button to notify caregivers instantly (5-second grace period to cancel).',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 40),

              // Emergency Call Direct Dial Section
              const Text(
                '📞 Direct Emergency Call Contacts',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 12),

              ...emergencyContacts.map(
                (contact) => Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    leading: const CircleAvatar(
                      backgroundColor: AppTheme.primaryContainer,
                      child: Icon(
                        Icons.phone_rounded,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    title: Text(
                      contact.name,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      '${contact.relationship} • ${contact.phone}',
                    ),
                    trailing: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.successGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        minimumSize: const Size(70, 44),
                      ),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Calling ${contact.name} (${contact.phone})...',
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.call, size: 20),
                      label: const Text('CALL'),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTimestamp(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
