import 'package:flutter/material.dart';
import 'package:ttush_push/game/ads/ad_gateway.dart';
import 'package:ttush_push/game/board/board_definition.dart';
import 'package:ttush_push/game/match/match_controller.dart';
import 'package:ttush_push/game/rules/rules_engine.dart';
import 'package:ttush_push/game/start/board_preview.dart';
import 'package:ttush_push/game/view/game_page.dart';
import 'package:ttush_push/game/view/opponent_label.dart';
import 'package:ttush_push/l10n/l10n.dart';

const _surfaceColor = Color(0xFF0B0D12);
const _panelColor = Color(0xFF161A22);
const _panelBorderColor = Color(0xFF303846);
const _mutedTextColor = Color(0xFF8A93A6);
const _selectedControlColor = Color(0xFF6C8CFF);

/// Chooses seats and a catalog board before opening the Rust-owned match.
class StartPage extends StatefulWidget {
  const StartPage({super.key, this.rulesEngine, this.adGateway});

  final RulesEngine? rulesEngine;
  final AdGateway? adGateway;

  @override
  State<StartPage> createState() => _StartPageState();
}

class _StartPageState extends State<StartPage> {
  bool _versusAi = false;
  BuiltInBoard _board = BuiltInBoard.baseline;
  Opponent _difficulty = Opponent.greedy;

  Opponent get _opponent => _versusAi ? _difficulty : Opponent.human;

  Future<void> _startMatch() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => GamePage(
          rulesEngine: widget.rulesEngine,
          adGateway: widget.adGateway,
          opponent: _opponent,
          boardDefinition: _board.definition,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = localizationsOf(context);
    final largeText = MediaQuery.textScalerOf(context).scale(16) > 20;

    String boardLabel(BuiltInBoard board) => switch (board) {
      BuiltInBoard.baseline => l10n.boardClassic,
      BuiltInBoard.clippedCorners => l10n.boardClippedCorners,
      BuiltInBoard.large => l10n.boardLarge,
      BuiltInBoard.largeHoles => l10n.boardLargeHoles,
    };
    String boardDescription(BuiltInBoard board) => switch (board) {
      BuiltInBoard.baseline => l10n.boardClassicDescription,
      BuiltInBoard.clippedCorners => l10n.boardClippedCornersDescription,
      BuiltInBoard.large => l10n.boardLargeDescription,
      BuiltInBoard.largeHoles => l10n.boardLargeHolesDescription,
    };

    final opponents = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionLabel(l10n.opponent),
        _ChoiceRows(
          singleColumn: largeText,
          children: [
            _SelectionCard(
              key: const Key('start-mode-two-players'),
              selected: !_versusAi,
              onPressed: () => setState(() => _versusAi = false),
              child: _ModeLabel(Icons.people_outline, l10n.modeTwoPlayers),
            ),
            _SelectionCard(
              key: const Key('start-mode-versus-ai'),
              selected: _versusAi,
              onPressed: () => setState(() => _versusAi = true),
              child: _ModeLabel(Icons.smart_toy_outlined, l10n.modeVersusAi),
            ),
          ],
        ),
        if (_versusAi) ...[
          const SizedBox(height: 24),
          _SectionLabel(l10n.difficulty),
          _ChoiceRows(
            singleColumn: largeText,
            children: [
              for (final difficulty in _difficulties)
                _SelectionCard(
                  key: Key('start-difficulty-${difficulty.name}'),
                  selected: _difficulty == difficulty,
                  onPressed: () => setState(() => _difficulty = difficulty),
                  child: Text(opponentLabel(l10n, difficulty)),
                ),
            ],
          ),
        ],
      ],
    );
    final boards = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionLabel(l10n.board),
        _ChoiceRows(
          singleColumn: largeText,
          children: [
            for (final board in BuiltInBoard.values)
              _SelectionCard(
                key: Key('start-board-${board.id}'),
                selected: _board == board,
                onPressed: () => setState(() => _board = board),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: SizedBox.square(
                        dimension: 104,
                        child: BoardPreview(definition: board.definition.rules),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      boardLabel(board),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      boardDescription(board),
                      style: const TextStyle(
                        color: _mutedTextColor,
                        fontSize: 12,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );

    return Scaffold(
      backgroundColor: _surfaceColor,
      body: Stack(
        children: [
          Positioned.fill(
            child: ExcludeSemantics(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(
                    _board.definition.backgroundAssetPath,
                    fit: BoxFit.cover,
                    alignment: Alignment.centerLeft,
                  ),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xAA0B0D12), Color(0xF00B0D12)],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    key: const Key('start-choices-scroll'),
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 880),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                ExcludeSemantics(
                                  child: SizedBox(
                                    width: 76,
                                    height: 64,
                                    child: Stack(
                                      children: [
                                        Image.asset(
                                          'assets/images/sprites/azure_explorer_down.png',
                                          width: 52,
                                        ),
                                        Positioned(
                                          right: 0,
                                          bottom: 0,
                                          child: Image.asset(
                                            'assets/images/sprites/ember_explorer_down.png',
                                            width: 48,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    l10n.newMatchTitle,
                                    key: const Key('start-title'),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 28,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 28),
                            LayoutBuilder(
                              builder: (context, constraints) {
                                if (constraints.maxWidth >= 720 && !largeText) {
                                  return Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      SizedBox(width: 260, child: opponents),
                                      const SizedBox(width: 32),
                                      Expanded(child: boards),
                                    ],
                                  );
                                }
                                return Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    opponents,
                                    const SizedBox(height: 28),
                                    boards,
                                  ],
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Container(
                  decoration: const BoxDecoration(
                    color: _surfaceColor,
                    border: Border(top: BorderSide(color: _panelBorderColor)),
                  ),
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 880),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          key: const Key('start-match'),
                          onPressed: _startMatch,
                          icon: const Icon(Icons.arrow_forward),
                          label: Text(l10n.startMatch),
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(0, 56),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 14,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

const List<Opponent> _difficulties = [
  Opponent.random,
  Opponent.greedy,
  Opponent.minimax,
  Opponent.strategic,
];

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Text(
      label,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

class _ModeLabel extends StatelessWidget {
  const _ModeLabel(this.icon, this.label);

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [Icon(icon, size: 24), const SizedBox(height: 8), Text(label)],
  );
}

class _SelectionCard extends StatelessWidget {
  const _SelectionCard({
    required this.selected,
    required this.onPressed,
    required this.child,
    super.key,
  });

  final bool selected;
  final VoidCallback onPressed;
  final Widget child;

  @override
  Widget build(BuildContext context) => MergeSemantics(
    child: Semantics(
      selected: selected,
      inMutuallyExclusiveGroup: true,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          backgroundColor: _panelColor,
          alignment: Alignment.topLeft,
          padding: const EdgeInsets.all(12),
          minimumSize: const Size(0, 52),
          textStyle: const TextStyle(fontFamily: 'Poppins', fontSize: 14),
          side: BorderSide(
            color: selected ? _selectedControlColor : _panelBorderColor,
            width: selected ? 2 : 1,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: Icon(
                selected ? Icons.check_circle : Icons.circle_outlined,
                color: selected ? _selectedControlColor : _mutedTextColor,
                size: 18,
              ),
            ),
            child,
          ],
        ),
      ),
    ),
  );
}

/// Equal-height pairs at normal text size, full-width choices at large text.
class _ChoiceRows extends StatelessWidget {
  const _ChoiceRows({required this.singleColumn, required this.children});

  final bool singleColumn;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    if (singleColumn) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12,
        children: children,
      );
    }
    return Column(
      spacing: 12,
      children: [
        for (var index = 0; index < children.length; index += 2)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 12,
              children: [
                Expanded(child: children[index]),
                Expanded(child: children[index + 1]),
              ],
            ),
          ),
      ],
    );
  }
}
