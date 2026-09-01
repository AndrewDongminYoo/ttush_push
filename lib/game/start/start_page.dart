import 'package:flutter/material.dart';
import 'package:ttush_push/game/match/match_controller.dart';
import 'package:ttush_push/game/rules/rules_engine.dart';
import 'package:ttush_push/game/view/game_page.dart';
import 'package:ttush_push/game/view/opponent_label.dart';
import 'package:ttush_push/l10n/l10n.dart';

const _surfaceColor = Color(0xFF0B0D12);
const _panelColor = Color(0xFF161A22);
const _panelBorderColor = Color(0xFF303846);
const _mutedTextColor = Color(0xFF8A93A6);

/// The screen a launch opens on, so the seats are chosen before the board.
///
/// It decides nothing about the match itself: the choice is an [Opponent],
/// which [GamePage] hands to the controller, and every rule still belongs to
/// Rust. The difficulty names here are the only place a policy is described in
/// a player's words rather than the engine's.
class StartPage extends StatefulWidget {
  const StartPage({super.key, this.rulesEngine});

  /// Passed through to the match so a test can hold the engine.
  final RulesEngine? rulesEngine;

  @override
  State<StartPage> createState() => _StartPageState();
}

class _StartPageState extends State<StartPage> {
  bool _versusAi = false;

  /// Normal is the opening difficulty: random reads as broken rather than
  /// easy, and minimax is not a first match.
  Opponent _difficulty = Opponent.greedy;

  Opponent get _opponent => _versusAi ? _difficulty : Opponent.human;

  Future<void> _startMatch() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) =>
            GamePage(rulesEngine: widget.rulesEngine, opponent: _opponent),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = localizationsOf(context);

    return Scaffold(
      backgroundColor: _surfaceColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l10n.newMatchTitle,
                    key: const Key('start-title'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 24),
                  _Panel(
                    child: RadioGroup<bool>(
                      groupValue: _versusAi,
                      onChanged: (versusAi) {
                        if (versusAi == null) {
                          return;
                        }
                        setState(() => _versusAi = versusAi);
                      },
                      child: Column(
                        children: [
                          RadioListTile<bool>(
                            key: const Key('start-mode-two-players'),
                            value: false,
                            title: Text(
                              l10n.modeTwoPlayers,
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                          RadioListTile<bool>(
                            key: const Key('start-mode-versus-ai'),
                            value: true,
                            title: Text(
                              l10n.modeVersusAi,
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_versusAi) ...[
                    const SizedBox(height: 16),
                    _Panel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                            child: Text(
                              l10n.difficulty,
                              style: const TextStyle(color: _mutedTextColor),
                            ),
                          ),
                          RadioGroup<Opponent>(
                            groupValue: _difficulty,
                            onChanged: (difficulty) {
                              if (difficulty == null) {
                                return;
                              }
                              setState(() => _difficulty = difficulty);
                            },
                            child: Column(
                              children: [
                                for (final difficulty in _difficulties)
                                  RadioListTile<Opponent>(
                                    key: Key(
                                      'start-difficulty-${difficulty.name}',
                                    ),
                                    value: difficulty,
                                    title: Text(
                                      opponentLabel(l10n, difficulty),
                                      style: const TextStyle(
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  ElevatedButton(
                    key: const Key('start-match'),
                    onPressed: _startMatch,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(l10n.startMatch),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The seats a policy can hold, ordered as a player reads them.
const List<Opponent> _difficulties = [
  Opponent.random,
  Opponent.greedy,
  Opponent.minimax,
];

class _Panel extends StatelessWidget {
  const _Panel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    // Material rather than a DecoratedBox: the tiles inside need one for their
    // ink, and a coloured box between them and the nearest Material throws.
    return Material(
      color: _panelColor,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: _panelBorderColor),
        borderRadius: BorderRadius.circular(12),
      ),
      child: child,
    );
  }
}
