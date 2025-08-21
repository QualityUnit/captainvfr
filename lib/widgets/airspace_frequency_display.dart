import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/airspace.dart';
import '../models/airspace_frequency.dart';
import '../l10n/app_localizations.dart';

/// Reusable widget for displaying airspace frequency information
/// with tap-to-copy functionality and dark theme styling
class AirspaceFrequencyDisplay extends StatelessWidget {
  final Airspace airspace;
  final bool showDetails;
  final bool showCallsign;
  
  const AirspaceFrequencyDisplay({
    super.key,
    required this.airspace,
    this.showDetails = true,
    this.showCallsign = true,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    
    if (!airspace.hasFrequencyInfo) {
      return _buildNoFrequencyWidget(context, l10n);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildHeader(context, l10n),
        const SizedBox(height: 4),
        ...airspace.frequencies!.map((freq) => _buildFrequencyItem(
          context, l10n, freq,
        )),
      ],
    );
  }

  Widget _buildHeader(BuildContext context, AppLocalizations l10n) {
    return Row(
      children: [
        Icon(
          Icons.radio,
          size: 16,
          color: Colors.orange,
        ),
        const SizedBox(width: 6),
        Text(
          l10n.communicationFrequencies,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        if (showCallsign && airspace.primaryCallsign != null) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(3),
              border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
            ),
            child: Text(
              airspace.primaryCallsign!,
              style: const TextStyle(
                color: Colors.orange,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildFrequencyItem(
    BuildContext context,
    AppLocalizations l10n,
    AirspaceFrequency frequency,
  ) {
    final isPrimary = frequency == airspace.primaryFrequency;
    
    return Container(
      margin: const EdgeInsets.only(top: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _copyFrequency(context, l10n, frequency),
          borderRadius: BorderRadius.circular(4),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isPrimary 
                  ? Colors.orange.withValues(alpha: 0.1)
                  : Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(4),
              border: isPrimary 
                  ? Border.all(color: Colors.orange.withValues(alpha: 0.3))
                  : Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: Row(
              children: [
                // Frequency type badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isPrimary ? Colors.orange : Colors.lightBlueAccent,
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(
                    frequency.type,
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                
                // Frequency value
                Text(
                  frequency.formattedFrequency,
                  style: TextStyle(
                    color: isPrimary ? Colors.orange : Colors.lightBlueAccent,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    fontFamily: 'monospace',
                  ),
                ),
                
                if (showDetails && frequency.description != null) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      frequency.description!,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
                
                const SizedBox(width: 4),
                Icon(
                  Icons.copy,
                  size: 14,
                  color: Colors.white54,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNoFrequencyWidget(BuildContext context, AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          Icon(
            Icons.radio_button_off,
            size: 16,
            color: Colors.white38,
          ),
          const SizedBox(width: 6),
          Text(
            l10n.noFrequencyAvailable,
            style: const TextStyle(
              color: Colors.white38,
              fontSize: 12,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  void _copyFrequency(
    BuildContext context,
    AppLocalizations l10n,
    AirspaceFrequency frequency,
  ) {
    // Copy frequency to clipboard
    Clipboard.setData(ClipboardData(text: frequency.frequency.toStringAsFixed(3)));
    
    // Show confirmation
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${l10n.copyFrequency}: ${frequency.formattedFrequency}',
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.black87,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        action: SnackBarAction(
          label: 'OK',
          textColor: Colors.orange,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }
}

/// Compact version for use in small spaces (e.g., map popups)
class CompactAirspaceFrequencyDisplay extends StatelessWidget {
  final Airspace airspace;
  final bool showIcon;
  
  const CompactAirspaceFrequencyDisplay({
    super.key,
    required this.airspace,
    this.showIcon = true,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    
    if (!airspace.hasFrequencyInfo) {
      return const SizedBox.shrink();
    }

    final primaryFreq = airspace.primaryFrequency!;
    
    return InkWell(
      onTap: () => _copyFrequency(context, l10n, primaryFreq),
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showIcon) ...[
              Icon(
                Icons.radio,
                size: 12,
                color: Colors.orange,
              ),
              const SizedBox(width: 4),
            ],
            Text(
              primaryFreq.formattedFrequency,
              style: const TextStyle(
                color: Colors.orange,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                fontFamily: 'monospace',
              ),
            ),
            if (primaryFreq.type != 'CTR') ...[
              const SizedBox(width: 4),
              Text(
                primaryFreq.type,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 10,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _copyFrequency(
    BuildContext context,
    AppLocalizations l10n,
    AirspaceFrequency frequency,
  ) {
    Clipboard.setData(ClipboardData(text: frequency.frequency.toStringAsFixed(3)));
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${l10n.copyFrequency}: ${frequency.formattedFrequency}',
        ),
        backgroundColor: Colors.black87,
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}