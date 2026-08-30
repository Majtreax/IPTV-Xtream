import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iptv_xtream/app/theme.dart';
import 'package:iptv_xtream/providers/auth_provider.dart';
import 'package:iptv_xtream/screens/main/main_screen.dart';
import 'package:iptv_xtream/screens/login/login_screen.dart';
import 'package:iptv_xtream/screens/player/player_screen.dart';
import 'package:iptv_xtream/providers/settings_provider.dart';

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fontScale = ref.watch(fontSizeScaleProvider);

    return Shortcuts(
      shortcuts: <ShortcutActivator, Intent>{
        const SingleActivator(LogicalKeyboardKey.select):
            const ActivateIntent(),
        const SingleActivator(LogicalKeyboardKey.gameButtonA):
            const ActivateIntent(),
      },
      child: MaterialApp(
        title: 'IPTV Xtream',
        debugShowCheckedModeBanner: false,
        theme: buildTvTheme(),
        home: const AuthGate(),
        routes: {
          '/main': (context) => const MainShell(),
          '/player': (context) => const PlayerScreen(),
        },
        builder: (context, child) {
          final mq = MediaQuery.of(context);

          return ColoredBox(
            color: Colors.black,
            child: SizedBox.expand(
              child: FittedBox(
                fit: BoxFit.contain,
                alignment: Alignment.center,
                child: SizedBox(
                  width: 1920,
                  height: 1080,
                  child: MediaQuery(
                    data: mq.copyWith(
                      size: const Size(1920, 1080),
                      textScaler: TextScaler.linear(fontScale),
                    ),
                    child: child!,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);

    if (authState.isAuthenticated) {
      return const MainShell();
    }

    return const LoginScreen();
  }
}
