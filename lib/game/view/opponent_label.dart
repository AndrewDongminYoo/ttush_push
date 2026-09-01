import 'package:ttush_push/game/match/match_controller.dart';
import 'package:ttush_push/l10n/l10n.dart';

/// Names [opponent] the way a player reads it.
///
/// The policies are called Easy, Normal and Hard here and nowhere else, so a
/// screen never has to know that they stand for random, greedy and minimax.
String opponentLabel(AppLocalizations l10n, Opponent opponent) {
  return switch (opponent) {
    Opponent.human => l10n.opponentHuman,
    Opponent.random => l10n.opponentRandom,
    Opponent.greedy => l10n.opponentGreedy,
    Opponent.minimax => l10n.opponentMinimax,
  };
}
