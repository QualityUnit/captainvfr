import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/voice_announcement_service.dart';

/// Voice announcement settings widget
class VoiceSettingsWidget extends StatelessWidget {
  const VoiceSettingsWidget({super.key});
  
  @override
  Widget build(BuildContext context) {
    final voiceService = Provider.of<VoiceAnnouncementService>(context);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          title: const Text('Voice Announcements'),
          subtitle: const Text('Hands-free audio alerts during flight'),
          value: voiceService.isEnabled,
          onChanged: (value) {
            voiceService.setEnabled(value);
          },
        ),
        if (voiceService.isEnabled) ...[
          const Divider(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Volume',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                Slider(
                  value: voiceService.volume,
                  min: 0.0,
                  max: 1.0,
                  divisions: 10,
                  label: '${(voiceService.volume * 100).round()}%',
                  onChanged: (value) {
                    voiceService.setVolume(value);
                  },
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Speech Rate',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                Slider(
                  value: voiceService.speechRate,
                  min: 0.0,
                  max: 1.0,
                  divisions: 10,
                  label: voiceService.speechRate < 0.4
                      ? 'Slow'
                      : voiceService.speechRate < 0.6
                          ? 'Normal'
                          : 'Fast',
                  onChanged: (value) {
                    voiceService.setSpeechRate(value);
                  },
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pitch',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                Slider(
                  value: voiceService.pitch,
                  min: 0.5,
                  max: 2.0,
                  divisions: 15,
                  label: voiceService.pitch < 0.9
                      ? 'Low'
                      : voiceService.pitch < 1.1
                          ? 'Normal'
                          : 'High',
                  onChanged: (value) {
                    voiceService.setPitch(value);
                  },
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: ElevatedButton.icon(
              onPressed: () {
                voiceService.testVoice();
              },
              icon: const Icon(Icons.volume_up),
              label: const Text('Test Voice'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
