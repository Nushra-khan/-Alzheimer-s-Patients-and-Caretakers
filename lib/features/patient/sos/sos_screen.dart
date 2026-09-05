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
    ref.read(alertsProvider.notifier).triggerSOSAlert(patientName: patient.name);

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
      backgroundColor: AppTheme.backgroundLight,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAlignment.stretch,
            children: [
              // Emergency Header Notice
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppTheme.alertRedContainer,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.alertRed, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.alertRed.withValues(alpha: 0.15),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: const [
                    Icon(Icons.warning_amber_rounded, color: AppTheme.alertRed, size: 38),
                    SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        'Emergency Help Signal\nPress the button below to alert caregivers immediately.',
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
                        padding: const EdgeInsets.all(28),
                        decoration: BoxDecoration(
                          color: AppTheme.alertRedContainer,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppTheme.alertRed, width: 5),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.alertRed.withValues(alpha: 0.3),
                              blurRadius: 20,
                              spreadRadius: 4,
                            ),
                          ],
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
                              style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.alertRed, fontSize: 16),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 28),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black87,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(240, 56),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: _cancelSosCountdown,
                        icon: const Icon(Icons.cancel_rounded, size: 28),
                        label: const Text('CANCEL SOS', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      ),
                    ] else if (_alertSent) ...[
                      // Sent Status UI
                      Container(
                        width: 190,
                        height: 190,
                        decoration: BoxDecoration(
                          color: AppTheme.successGreenContainer,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppTheme.successGreen, width: 3),
                        ),
                        child: const Icon(
                          Icons.mark_email_read_rounded,
                          size: 96,
                          color: AppTheme.successGreen,
                        ),
                      ),
                      const SizedBox(height: 20),
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
                        'Sent at ${_formatTimestamp(_alertSentTime!)}\nCaregivers have received push notifications.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 15, color: AppTheme.textSecondary),
                      ),
                      const SizedBox(height: 24),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(220, 48),
                        ),
                        onPressed: _startSosCountdown,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Send Another SOS Signal'),
                      ),
                    ] else ...[
                      // Idle Huge Accessible SOS Button
                      GestureDetector(
                        onTap: _startSosCountdown,
                        child: Container(
                          width: 230,
                          height: 230,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFEF5350), Color(0xFFC62828)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.alertRed.withValues(alpha: 0.45),
                                blurRadius: 24,
                                spreadRadius: 6,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.touch_app_rounded, color: Colors.white, size: 52),
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
                      const SizedBox(height: 20),
                      const Text(
                        'Tap button to notify caregivers instantly (5-second grace period to cancel).',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 40),

              // Emergency Direct Phone Call Section
              const Text(
                '📞 Direct Call Contacts',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 14),

              ...emergencyContacts.map(
                (contact) => Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade200),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: const CircleAvatar(
                      backgroundColor: AppTheme.primaryContainer,
                      radius: 24,
                      child: Icon(Icons.phone_rounded, color: AppTheme.primaryColor),
                    ),
                    title: Text(
                      contact.name,
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text('${contact.relationship} • ${contact.phone}'),
                    trailing: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.successGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        minimumSize: const Size(76, 44),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Calling ${contact.name} (${contact.phone})...'),
                          ),
                        );
                      },
                      icon: const Icon(Icons.call, size: 18),
                      label: const Text('CALL', style: TextStyle(fontWeight: FontWeight.bold)),
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
