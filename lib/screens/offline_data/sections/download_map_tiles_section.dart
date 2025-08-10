import 'package:flutter/material.dart';
import '../../../constants/app_colors.dart';
import '../../../utils/form_theme_helper.dart';
import '../controllers/offline_data_state_controller.dart';
import '../../../l10n/app_localizations.dart';

/// Download map tiles section widget
class DownloadMapTilesSection extends StatelessWidget {
  final OfflineDataStateController controller;
  final VoidCallback onDownload;
  final VoidCallback onStopDownload;

  const DownloadMapTilesSection({
    super.key,
    required this.controller,
    required this.onDownload,
    required this.onStopDownload,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return FormThemeHelper.buildSection(
      title: l10n.downloadMapTiles,
      children: [
        Text(
          l10n.downloadMapTilesDescription,
          style: TextStyle(color: AppColors.secondaryTextColor),
        ),
        const SizedBox(height: 16),
        CheckboxListTile(
          title: Text(
            l10n.flightPlanDownloadMapTiles,
            style: const TextStyle(color: AppColors.primaryTextColor),
          ),
          subtitle: Text(
            l10n.automaticallyDownloadFlightPlanTiles,
            style: const TextStyle(color: AppColors.secondaryTextColor, fontSize: 12),
          ),
          value: controller.downloadMapTilesForFlightPlan,
          onChanged: (value) {
            if (value != null) {
              controller.setDownloadMapTilesForFlightPlan(value);
            }
          },
          activeColor: AppColors.primaryAccent,
          contentPadding: EdgeInsets.zero,
        ),
        const SizedBox(height: 8),
        CheckboxListTile(
          title: Text(
            l10n.validateTilesOnStartup,
            style: const TextStyle(color: AppColors.primaryTextColor),
          ),
          subtitle: Text(
            l10n.checkMissingTilesOnStartup,
            style: const TextStyle(color: AppColors.secondaryTextColor, fontSize: 12),
          ),
          value: controller.validateTilesOnStartup,
          onChanged: (value) {
            if (value != null) {
              controller.setValidateTilesOnStartup(value);
            }
          },
          activeColor: AppColors.primaryAccent,
          contentPadding: EdgeInsets.zero,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${l10n.minZoom}: ${controller.minZoom}',
                    style: TextStyle(color: AppColors.primaryTextColor),
                  ),
                  Slider(
                    value: controller.minZoom.toDouble(),
                    min: 1,
                    max: 18,
                    divisions: 17,
                    label: controller.minZoom.toString(),
                    activeColor: AppColors.primaryAccent,
                    onChanged: (value) {
                      controller.setMinZoom(value.toInt());
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${l10n.maxZoom}: ${controller.maxZoom}',
                    style: TextStyle(color: AppColors.primaryTextColor),
                  ),
                  Slider(
                    value: controller.maxZoom.toDouble(),
                    min: 1,
                    max: 18,
                    divisions: 17,
                    label: controller.maxZoom.toString(),
                    activeColor: AppColors.primaryAccent,
                    onChanged: (value) {
                      controller.setMaxZoom(value.toInt());
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (controller.isDownloading) ...[
          LinearProgressIndicator(
            value: controller.downloadProgress,
            backgroundColor: AppColors.primaryAccent.withValues(alpha: 0.3),
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryAccent),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l10n.progressTiles(controller.currentTiles, controller.totalTiles),
                style: TextStyle(color: AppColors.secondaryTextColor),
              ),
              Text(
                '${(controller.downloadProgress * 100).toStringAsFixed(1)}%',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryAccent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l10n.downloadedTiles(controller.downloadedTiles),
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.secondaryTextColor,
                ),
              ),
              Text(
                l10n.skippedTiles(controller.skippedTiles),
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.secondaryTextColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: onStopDownload,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.stop),
            label: Text(l10n.stopDownload),
          ),
        ] else
          ElevatedButton.icon(
            onPressed: onDownload,
            style: FormThemeHelper.getPrimaryButtonStyle(),
            icon: const Icon(Icons.download),
            label: Text(l10n.downloadCurrentArea),
          ),
      ],
    );
  }
}