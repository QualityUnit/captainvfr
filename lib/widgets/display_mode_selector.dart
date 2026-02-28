import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/display_mode_service.dart';

/// Widget to select display mode (normal, cockpit, night)
class DisplayModeSelector extends StatelessWidget {
  const DisplayModeSelector({super.key});
  
  @override
  Widget build(BuildContext context) {
    final displayModeService = Provider.of<DisplayModeService>(context);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            'Display Mode',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Optimize display for different flight conditions',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey,
                ),
          ),
        ),
        const SizedBox(height: 12),
        _buildModeOption(
          context,
          displayModeService,
          DisplayMode.normal,
          'Normal',
          'Standard dark theme for general use',
          Icons.brightness_4,
        ),
        _buildModeOption(
          context,
          displayModeService,
          DisplayMode.cockpit,
          'Cockpit Mode',
          'High contrast for bright daylight visibility',
          Icons.wb_sunny,
        ),
        _buildModeOption(
          context,
          displayModeService,
          DisplayMode.night,
          'Night Mode',
          'Red lighting to preserve night vision',
          Icons.nightlight_round,
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Tip: Cockpit mode meets WCAG AAA standards for maximum readability in sunlight. Night mode uses red wavelengths to preserve your night vision.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey,
                  fontStyle: FontStyle.italic,
                ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildModeOption(
    BuildContext context,
    DisplayModeService displayModeService,
    DisplayMode mode,
    String title,
    String description,
    IconData icon,
  ) {
    final isSelected = displayModeService.mode == mode;
    
    return InkWell(
      onTap: () => displayModeService.setMode(mode),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).primaryColor.withValues(alpha: 0.1)
              : Colors.transparent,
          border: Border.all(
            color: isSelected
                ? Theme.of(context).primaryColor
                : Colors.grey.withValues(alpha: 0.3),
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected
                    ? Theme.of(context).primaryColor.withValues(alpha: 0.2)
                    : Colors.grey.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: isSelected
                    ? Theme.of(context).primaryColor
                    : Colors.grey,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey,
                        ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle,
                color: Theme.of(context).primaryColor,
                size: 24,
              ),
          ],
        ),
      ),
    );
  }
}
