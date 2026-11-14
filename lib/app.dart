import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_music/core/branding/loko_mark.dart';
import 'package:pulse_music/core/router/app_router.dart';
import 'package:pulse_music/core/theme/app_theme.dart';
import 'package:pulse_music/core/utils/ui.dart';
import 'package:pulse_music/shared/providers/core_providers.dart';
import 'package:pulse_music/shared/providers/library_providers.dart';

class PulseApp extends ConsumerStatefulWidget {
  const PulseApp({super.key});
  @override
  ConsumerState<PulseApp> createState() => _PulseAppState();
}

class _PulseAppState extends ConsumerState<PulseApp> {
  @override
  void initState() {
    super.initState();
    // Surface playback errors (unavailable track, network loss) as toasts.
    ref.read(audioHandlerProvider).errors.listen(toast);
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(playbackRecorderProvider);
    final settings = ref.watch(settingsProvider);
    return MaterialApp.router(
      title: Brand.name,
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: rootMessengerKey,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: settings.themeMode,
      routerConfig: ref.watch(routerProvider),
    );
  }
}
