import 'package:ttush_push/game/match/match_controller.dart';
import 'package:ttush_push/l10n/l10n.dart';

/// Names [opponent] the way a player reads it.
///
/// The policies are called Easy, Normal, Hard and Expert here and nowhere else,
/// so a screen never has to know their engine names.
String opponentLabel(AppLocalizations l10n, Opponent opponent) {
  return switch (opponent) {
    Opponent.human => l10n.opponentHuman,
    Opponent.random => l10n.opponentRandom,
    Opponent.greedy => l10n.opponentGreedy,
    Opponent.minimax => l10n.opponentMinimax,
    Opponent.strategic => l10n.opponentStrategic,
  };
}
