import 'package:flutter/material.dart';
import 'package:ttush_push/game/rules/rules_engine.dart';
import 'package:ttush_push/game/view/game_page.dart';
import 'package:ttush_push/l10n/l10n.dart';

class App extends StatelessWidget {
  const App({super.key, this._rulesEngine});

  final RulesEngine? _rulesEngine;

  @override
  Widget build(BuildContext context) {
    return AppView(rulesEngine: _rulesEngine);
  }
}

class AppView extends StatelessWidget {
  const AppView({super.key, this._rulesEngine});

  final RulesEngine? _rulesEngine;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: const Color(0xFF2A48DF),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF2A48DF),
          foregroundColor: Color(0xFFFFFFFF),
        ),
        colorScheme: ColorScheme.fromSwatch(
          accentColor: const Color(0xFF2A48DF),
        ),
        scaffoldBackgroundColor: const Color(0xFFFFFFFF),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ButtonStyle(
            backgroundColor: WidgetStateProperty.all(const Color(0xFF2A48DF)),
            foregroundColor: WidgetStateProperty.all(Colors.white),
          ),
        ),
        fontFamily: 'Poppins',
      ),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: GamePage(rulesEngine: _rulesEngine),
    );
  }
}
