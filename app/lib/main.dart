import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config.dart';
import 'core/local_store.dart';
import 'state/session.dart';
import 'theme.dart';
import 'ui/auth/auth_screen.dart';
import 'ui/shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(statusBarColor: Colors.transparent, statusBarIconBrightness: Brightness.dark));
  await Future.wait([
    LocalStore.init(),
    initializeDateFormatting('ru'),
    Supabase.initialize(
      url: AppConfig.supabaseUrl,
      publishableKey: AppConfig.supabaseAnonKey,
      realtimeClientOptions: const RealtimeClientOptions(eventsPerSecond: 20),
    ),
  ]);
  await AppSession.instance.start();
  runApp(const MigrantHubApp());
}

class MigrantHubApp extends StatelessWidget {
  const MigrantHubApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Migrant Hub',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      locale: const Locale('ru'),
      supportedLocales: const [Locale('ru'), Locale('en')],
      localizationsDelegates: const [GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
      home: ListenableBuilder(
        listenable: AppSession.instance,
        builder: (context, _) {
          final s = AppSession.instance;
          if (!s.ready) return const _Splash();
          if (!s.signedIn) return const AuthScreen();
          return const Shell();
        },
      ),
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) => const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: Text('Migrant Hub', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.navy))),
      );
}
