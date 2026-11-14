import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_music/app.dart';
import 'package:pulse_music/core/network/audius_client.dart';
import 'package:pulse_music/core/services/audio_player_service.dart';
import 'package:pulse_music/core/services/local_store.dart';
import 'package:pulse_music/core/theme/app_theme.dart';
import 'package:pulse_music/features/splash/presentation/splash_view.dart';
import 'package:pulse_music/shared/providers/core_providers.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const Bootstrap());
}

class _Deps {
  _Deps(this.store, this.client, this.handler);
  final LocalStore store;
  final AudiusClient client;
  final AudioPlayerService handler;
}

/// Shows the animated splash while dependencies initialise, then starts the app.
class Bootstrap extends StatefulWidget {
  const Bootstrap({super.key});
  @override
  State<Bootstrap> createState() => _BootstrapState();
}

class _BootstrapState extends State<Bootstrap> {
  late final Future<_Deps> _deps = _init();

  Future<_Deps> _init() async {
    final started = DateTime.now();
    final store = await LocalStore.open();
    final client = AudiusClient();
    final handler = await AudioService.init(
      builder: () => AudioPlayerService(
        // Jamendo (and any future provider) tracks carry their own URL;
        // Audius tracks get the stream endpoint, which redirects to the file.
        streamUrl: (t) => t.streamUrl ?? client.streamUrl(t.id),
        store: store,
      ),
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.pulse.music.playback',
        androidNotificationChannelName: 'Music playback',
        androidNotificationOngoing: true,
      ),
    );
    final remaining = const Duration(milliseconds: 1600) - DateTime.now().difference(started);
    if (!remaining.isNegative) await Future<void>.delayed(remaining);
    return _Deps(store, client, handler);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_Deps>(
      future: _deps,
      builder: (context, snap) {
        if (snap.hasData) {
          final d = snap.data!;
          return ProviderScope(
            overrides: [
              localStoreProvider.overrideWithValue(d.store),
              audiusClientProvider.overrideWithValue(d.client),
              audioHandlerProvider.overrideWithValue(d.handler),
            ],
            child: const PulseApp(),
          );
        }
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.dark(),
          home: snap.hasError
              ? Scaffold(body: Center(child: Padding(padding: const EdgeInsets.all(24), child: Text('Could not start the app.\n${snap.error}', textAlign: TextAlign.center))))
              : const SplashView(),
        );
      },
    );
  }
}
