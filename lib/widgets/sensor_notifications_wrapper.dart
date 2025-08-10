import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
import '../services/sensor_availability_service.dart';
import 'sensor_notification_widget.dart';

/// Wrapper widget that displays sensor availability notifications
class SensorNotificationsWrapper extends StatefulWidget {
  final Widget child;

  const SensorNotificationsWrapper({
    super.key,
    required this.child,
  });

  @override
  State<SensorNotificationsWrapper> createState() => _SensorNotificationsWrapperState();
}

class _SensorNotificationsWrapperState extends State<SensorNotificationsWrapper> {
  @override
  void initState() {
    super.initState();
    // Schedule sensor check after widget is built and localization is available
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final l10n = AppLocalizations.of(context);
      if (l10n != null) {
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            context.read<SensorAvailabilityService>().checkSensorAvailability(l10n);
          }
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Consumer<SensorAvailabilityService>(
            builder: (context, sensorService, _) {
              if (sensorService.notifications.isEmpty) {
                return const SizedBox.shrink();
              }

              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: SensorNotificationContainer(
                    notifications: sensorService.notifications,
                    onDismiss: (id) => sensorService.dismissNotification(id),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}