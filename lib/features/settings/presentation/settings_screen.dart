import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_music/core/config/app_config.dart';
import 'package:pulse_music/core/utils/ui.dart';
import 'package:pulse_music/shared/providers/core_providers.dart';
import 'package:pulse_music/shared/providers/library_providers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  void _info(BuildContext context, String title, String body) => showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(title),
          content: SingleChildScrollView(child: Text(body)),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
        ),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final controller = ref.read(settingsProvider.notifier);
    final label = Theme.of(context).textTheme.titleSmall?.copyWith(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w700);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings', style: TextStyle(fontWeight: FontWeight.w700))),
      body: ListView(children: [
        Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 8), child: Text('Appearance', style: label)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SegmentedButton<ThemeMode>(
            segments: const [
              ButtonSegment(value: ThemeMode.dark, label: Text('Dark'), icon: Icon(Icons.dark_mode_outlined)),
              ButtonSegment(value: ThemeMode.light, label: Text('Light'), icon: Icon(Icons.light_mode_outlined)),
              ButtonSegment(value: ThemeMode.system, label: Text('System'), icon: Icon(Icons.brightness_auto_outlined)),
            ],
            selected: {settings.themeMode},
            onSelectionChanged: (s) => controller.setTheme(s.first),
          ),
        ),
        Padding(padding: const EdgeInsets.fromLTRB(16, 24, 16, 0), child: Text('Streaming', style: label)),
        SwitchListTile(
          title: const Text('Stream on Wi-Fi only'),
          subtitle: const Text('Audius serves a single stream quality, so there is no quality selector. This option saves mobile data instead.'),
          value: settings.wifiOnly,
          onChanged: controller.setWifiOnly,
        ),
        Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 0), child: Text('Storage', style: label)),
        ListTile(
          leading: const Icon(Icons.cleaning_services_outlined),
          title: const Text('Clear cache'),
          subtitle: const Text('Removes cached images and saved API responses'),
          onTap: () async {
            ref.read(audiusClientProvider).clearCache();
            await DefaultCacheManager().emptyCache();
            PaintingBinding.instance.imageCache.clear();
            toast('Cache cleared');
          },
        ),
        ListTile(
          leading: const Icon(Icons.manage_search),
          title: const Text('Clear recent searches'),
          onTap: () {
            ref.read(searchHistoryProvider.notifier).clear();
            toast('Search history cleared');
          },
        ),
        ListTile(
          leading: const Icon(Icons.history),
          title: const Text('Clear recently played'),
          onTap: () {
            ref.read(recentProvider.notifier).clear();
            toast('Listening history cleared');
          },
        ),
        Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 0), child: Text('About', style: label)),
        ListTile(
          leading: const Icon(Icons.info_outline),
          title: const Text('About Loko Music'),
          onTap: () => showAboutDialog(
            context: context,
            applicationName: 'Loko Music',
            applicationVersion: '1.0.0',
            applicationLegalese: 'Music and metadata are provided by the Audius network. Content belongs to its artists.',
            children: [Text(AppConfig.apiKey.isEmpty ? '\nRunning without an API key (default rate limits).' : '\nUsing a configured API key.')],
          ),
        ),
        ListTile(
          leading: const Icon(Icons.privacy_tip_outlined),
          title: const Text('Privacy policy'),
          onTap: () => _info(context, 'Privacy policy',
              'Loko Music does not require an account and does not collect personal data.\n\nFavorites, playlists, queue, search history and settings are stored only on this device.\n\nWhen you browse or play music, requests are sent to the Audius API to fetch catalog data and audio streams. Audius may process those requests under its own privacy policy.'),
        ),
        ListTile(
          leading: const Icon(Icons.description_outlined),
          title: const Text('Terms and conditions'),
          onTap: () => _info(context, 'Terms and conditions',
              'Loko Music streams content from the Audius network for personal, non-commercial listening.\n\nTracks may be unavailable or removed by their owners at any time. Downloading or redistributing content is not supported. You are responsible for following the Audius terms of service and each artist\'s licensing terms.'),
        ),
        const SizedBox(height: 32),
      ]),
    );
  }
}
