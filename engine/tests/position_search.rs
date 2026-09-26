#[path = "../src/bin/analyze/search.rs"]
mod search;

use std::collections::HashMap;

use engine::{
    BoardConfig, Direction, GameState, Move, Outcome, Piece, PieceId, Player, Position, apply_move,
    legal_moves, outcome,
};
use search::analyze;

fn opponent(player: Player) -> Player {
    match player {
        Player::First => Player::Second,
        Player::Second => Player::First,
    }
}

fn exhaustive_winner(state: &GameState, memo: &mut HashMap<GameState, Player>) -> Player {
    if let Some(winner) = memo.get(state) {
        return *winner;
    }
    if let Outcome::Winner(winner, _) = outcome(state) {
        return winner;
    }

    let mover = state.current_player();
    let winner = if legal_moves(state).into_iter().any(|candidate| {
        exhaustive_winner(
            &apply_move(state, candidate).expect("legal moves must apply"),
            memo,
        ) == mover
    }) {
        mover
    } else {
        opponent(mover)
    };
    memo.insert(state.clone(), winner);
    winner
}

fn small_state() -> GameState {
    let board = BoardConfig::rectangular(
        3,
        3,
        vec![
            Piece::new(PieceId(0), Player::First, Position::new(0, 0)),
            Piece::new(PieceId(1), Player::Second, Position::new(2, 2)),
        ],
    )
    .unwrap();
    GameState::new(board, Player::First).unwrap()
}

fn after(start: &GameState, moves: &[Move]) -> GameState {
    moves.iter().fold(start.clone(), |state, selected_move| {
        apply_move(&state, *selected_move).expect("fixture moves must stay legal")
    })
}

fn knockout_state() -> GameState {
    let board = BoardConfig::rectangular(
        5,
        5,
        vec![
            Piece::new(PieceId(0), Player::First, Position::new(3, 2)),
            Piece::new(PieceId(1), Player::Second, Position::new(4, 2)),
        ],
    )
    .unwrap();
    GameState::new(board, Player::First).unwrap()
}

#[test]
fn reports_every_root_alternative_with_the_exhaustive_winner() {
    let state = after(&small_state(), &[Move::new(PieceId(0), Direction::Right)]);
    let expected_moves = vec![
        Move::new(PieceId(1), Direction::Up),
        Move::new(PieceId(1), Direction::Left),
    ];
    let mut memo = HashMap::new();
    let expected = expected_moves
        .iter()
        .map(|selected_move| {
            exhaustive_winner(
                &apply_move(&state, *selected_move).expect("expected root moves must be legal"),
                &mut memo,
            )
        })
        .collect::<Vec<_>>();

    assert_eq!(expected, vec![Player::First, Player::Second]);

    let analysis = analyze(&state, 32, 100_000);

    assert_eq!(analysis.winner, Some(Player::Second));
    assert_eq!(
        analysis
            .alternatives
            .iter()
            .map(|alternative| alternative.selected_move)
            .collect::<Vec<_>>(),
        expected_moves,
    );
    assert_eq!(
        analysis
            .alternatives
            .iter()
            .map(|alternative| alternative.winner)
            .collect::<Vec<_>>(),
        expected.into_iter().map(Some).collect::<Vec<_>>(),
    );
}

#[test]
fn terminal_root_reports_its_winner_without_alternatives() {
    let terminal = after(
        &knockout_state(),
        &[Move::new(PieceId(0), Direction::Right)],
    );

    let analysis = analyze(&terminal, 1, 1);

    assert_eq!(analysis.winner, Some(Player::First));
    assert!(analysis.alternatives.is_empty());
}

#[test]
fn terminal_child_is_inspected_before_the_depth_cutoff() {
    let analysis = analyze(&knockout_state(), 1, 1);
    let knockout = analysis
        .alternatives
        .iter()
        .find(|alternative| alternative.selected_move == Move::new(PieceId(0), Direction::Right))
        .expect("the knockout must be reported");

    assert_eq!(knockout.winner, Some(Player::First));
    assert_eq!(knockout.nodes, 1);
    assert_eq!(knockout.depth_cutoffs, 0);
    assert_eq!(knockout.node_cutoffs, 0);
}

#[test]
fn exhausted_node_budget_does_not_inspect_a_terminal_child() {
    let analysis = analyze(&knockout_state(), 1, 0);
    let knockout = analysis
        .alternatives
        .iter()
        .find(|alternative| alternative.selected_move == Move::new(PieceId(0), Direction::Right))
        .expect("the knockout must be reported");

    assert_eq!(knockout.winner, None);
    assert_eq!(knockout.nodes, 0);
    assert_eq!(knockout.depth_cutoffs, 0);
    assert_eq!(knockout.node_cutoffs, 1);
    assert_eq!(analysis.winner, None);
}

#[test]
fn depth_exhaustion_is_unknown_instead_of_a_loss() {
    let analysis = analyze(&small_state(), 1, 100);

    assert_eq!(analysis.alternatives.len(), 2);
    for alternative in analysis.alternatives {
        assert_eq!(alternative.winner, None);
        assert_eq!(alternative.nodes, 1);
        assert_eq!(alternative.depth_cutoffs, 1);
        assert_eq!(alternative.node_cutoffs, 0);
    }
    assert_eq!(analysis.winner, None);
}

#[test]
fn unknown_opponent_replies_prevent_a_false_root_win() {
    let analysis = analyze(&small_state(), 2, 100);

    assert_eq!(analysis.alternatives.len(), 2);
    for alternative in analysis.alternatives {
        assert_eq!(alternative.winner, None);
        assert!(alternative.depth_cutoffs > 0);
        assert_eq!(alternative.node_cutoffs, 0);
    }
    assert_eq!(analysis.winner, None);
}

#[test]
fn each_root_alternative_receives_a_fresh_node_budget() {
    let analysis = analyze(&small_state(), 32, 1);

    assert_eq!(analysis.alternatives.len(), 2);
    for alternative in analysis.alternatives {
        assert_eq!(alternative.winner, None);
        assert_eq!(alternative.nodes, 1);
        assert_eq!(alternative.depth_cutoffs, 0);
        assert!(alternative.node_cutoffs > 0);
    }
    assert_eq!(analysis.winner, None);
}

#[test]
fn a_loss_requires_every_legal_alternative_to_lose() {
    let state = small_state();
    let expected = exhaustive_winner(&state, &mut HashMap::new());
    assert_eq!(expected, Player::Second);
    let analysis = analyze(&state, 32, 100_000);
    assert_eq!(analysis.winner, Some(Player::Second));
    assert_eq!(analysis.alternatives.len(), 2);
    assert!(
        analysis
            .alternatives
            .iter()
            .all(|reply| reply.winner == Some(Player::Second))
    );
}
