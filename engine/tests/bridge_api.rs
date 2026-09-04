use std::collections::BTreeSet;

use engine::api::{
    BotPolicy, GameBoardCell, GameBoardDefinition, GameDirection, GameMatchPhase, GameMove,
    GamePiece, GamePlayer, GameTileKind, GameWinReason, MatchSnapshot, MoveActionKind,
    PieceDisplacement, PieceTravel, TileTransition, advance_round, choose_bot_move,
    initial_match as initial_match_from_definition, match_apply_move, match_legal_moves,
};

fn game_move(piece_id: u8, direction: GameDirection) -> GameMove {
    GameMove {
        piece_id,
        direction,
    }
}

fn play(snapshot: MatchSnapshot, moves: &[(u8, GameDirection)]) -> MatchSnapshot {
    moves.iter().fold(snapshot, |state, (piece, direction)| {
        match_apply_move(state, game_move(*piece, *direction))
            .unwrap()
            .snapshot
    })
}

fn baseline_definition() -> GameBoardDefinition {
    GameBoardDefinition {
        playable_cells: (0..5)
            .flat_map(|x| (0..5).map(move |y| GameBoardCell { x, y }))
            .collect(),
        starting_pieces: vec![
            GamePiece {
                id: 0,
                owner: GamePlayer::First,
                x: 1,
                y: 0,
            },
            GamePiece {
                id: 1,
                owner: GamePlayer::First,
                x: 3,
                y: 0,
            },
            GamePiece {
                id: 2,
                owner: GamePlayer::Second,
                x: 1,
                y: 4,
            },
            GamePiece {
                id: 3,
                owner: GamePlayer::Second,
                x: 3,
                y: 4,
            },
        ],
    }
}

fn initial_match() -> MatchSnapshot {
    initial_match_from_definition(baseline_definition())
        .expect("the baseline board definition must produce a valid match")
}

#[test]
fn value_api_accepts_an_irregular_board_definition() {
    let definition = GameBoardDefinition {
        playable_cells: vec![
            GameBoardCell { x: 4, y: 7 },
            GameBoardCell { x: 5, y: 7 },
            GameBoardCell { x: 5, y: 8 },
        ],
        starting_pieces: vec![
            GamePiece {
                id: 7,
                owner: GamePlayer::First,
                x: 4,
                y: 7,
            },
            GamePiece {
                id: 9,
                owner: GamePlayer::Second,
                x: 5,
                y: 8,
            },
        ],
    };

    let snapshot = initial_match_from_definition(definition).unwrap();

    assert_eq!(snapshot.round.tiles.len(), 3);
    assert_eq!(
        snapshot
            .round
            .tiles
            .iter()
            .map(|tile| (tile.x, tile.y))
            .collect::<BTreeSet<_>>(),
        BTreeSet::from([(4, 7), (5, 7), (5, 8)]),
    );
    assert_eq!(
        snapshot.starting_pieces,
        vec![
            GamePiece {
                id: 7,
                owner: GamePlayer::First,
                x: 4,
                y: 7,
            },
            GamePiece {
                id: 9,
                owner: GamePlayer::Second,
                x: 5,
                y: 8,
            },
        ],
    );
}

#[test]
fn value_api_rejects_invalid_board_definitions() {
    assert_eq!(
        initial_match_from_definition(GameBoardDefinition {
            playable_cells: vec![GameBoardCell { x: 1, y: 1 }, GameBoardCell { x: 1, y: 1 },],
            starting_pieces: vec![],
        })
        .unwrap_err(),
        "invalid board definition: duplicate playable cell",
    );
    assert_eq!(
        initial_match_from_definition(GameBoardDefinition {
            playable_cells: vec![],
            starting_pieces: vec![],
        })
        .unwrap_err(),
        "invalid board definition: EmptyBoard",
    );
    assert_eq!(
        initial_match_from_definition(GameBoardDefinition {
            playable_cells: vec![GameBoardCell { x: 1, y: 1 }],
            starting_pieces: vec![
                GamePiece {
                    id: 7,
                    owner: GamePlayer::First,
                    x: 1,
                    y: 1,
                },
                GamePiece {
                    id: 8,
                    owner: GamePlayer::Second,
                    x: 1,
                    y: 1,
                },
            ],
        })
        .unwrap_err(),
        "invalid board definition: OverlappingPieces",
    );
    assert_eq!(
        initial_match_from_definition(GameBoardDefinition {
            playable_cells: vec![GameBoardCell { x: 1, y: 1 }, GameBoardCell { x: 2, y: 1 },],
            starting_pieces: vec![
                GamePiece {
                    id: 7,
                    owner: GamePlayer::First,
                    x: 1,
                    y: 1,
                },
                GamePiece {
                    id: 7,
                    owner: GamePlayer::Second,
                    x: 2,
                    y: 1,
                },
            ],
        })
        .unwrap_err(),
        "invalid board definition: DuplicatePieceId(PieceId(7))",
    );
    assert_eq!(
        initial_match_from_definition(GameBoardDefinition {
            playable_cells: vec![GameBoardCell { x: 1, y: 1 }],
            starting_pieces: vec![GamePiece {
                id: 7,
                owner: GamePlayer::First,
                x: 2,
                y: 1,
            }],
        })
        .unwrap_err(),
        "invalid board definition: PieceOutsideBoard(PieceId(7))",
    );
}

#[test]
fn value_api_returns_a_normal_move_resolution() {
    let result = match_apply_move(initial_match(), game_move(0, GameDirection::Down)).unwrap();

    assert_eq!(result.resolution.action_kind, MoveActionKind::Normal);
    assert_eq!(
        result.resolution.mover,
        PieceTravel {
            piece_id: 0,
            from_x: 1,
            from_y: 0,
            to_x: 1,
            to_y: 1,
        },
    );
    assert_eq!(result.resolution.displaced, None);
    assert_eq!(
        result.resolution.tile_transition,
        TileTransition {
            x: 1,
            y: 0,
            from: GameTileKind::Normal,
            to: GameTileKind::Damaged,
        },
    );
    assert_eq!(result.snapshot.round.snapshot_hash, "540736b5048c5f9f");
}

#[test]
fn value_api_returns_a_push_resolution() {
    let after_first = match_apply_move(initial_match(), game_move(0, GameDirection::Down))
        .unwrap()
        .snapshot;
    let after_second = match_apply_move(after_first, game_move(2, GameDirection::Up))
        .unwrap()
        .snapshot;
    let before_push = match_apply_move(after_second, game_move(0, GameDirection::Down))
        .unwrap()
        .snapshot;

    let result = match_apply_move(before_push, game_move(2, GameDirection::Up)).unwrap();

    assert_eq!(result.resolution.action_kind, MoveActionKind::Push);
    assert_eq!(
        result.resolution.mover,
        PieceTravel {
            piece_id: 2,
            from_x: 1,
            from_y: 3,
            to_x: 1,
            to_y: 2,
        },
    );
    assert_eq!(
        result.resolution.displaced,
        Some(PieceDisplacement {
            piece_id: 0,
            from_x: 1,
            from_y: 2,
            to_x: Some(1),
            to_y: Some(1),
            exit_direction: None,
        }),
    );
    assert_eq!(
        result.resolution.tile_transition,
        TileTransition {
            x: 1,
            y: 3,
            from: GameTileKind::Normal,
            to: GameTileKind::Damaged,
        },
    );
}

#[test]
fn value_api_returns_an_exit_direction_for_a_knockout() {
    let before_knockout = play(
        initial_match(),
        &[
            (0, GameDirection::Down),
            (2, GameDirection::Up),
            (0, GameDirection::Down),
            (3, GameDirection::Up),
            (0, GameDirection::Down),
            (3, GameDirection::Up),
        ],
    );

    let result = match_apply_move(before_knockout, game_move(0, GameDirection::Down)).unwrap();

    assert_eq!(result.resolution.action_kind, MoveActionKind::Push);
    assert_eq!(
        result.resolution.displaced,
        Some(PieceDisplacement {
            piece_id: 2,
            from_x: 1,
            from_y: 4,
            to_x: None,
            to_y: None,
            exit_direction: Some(GameDirection::Down),
        }),
    );
    assert_eq!(
        result.resolution.tile_transition,
        TileTransition {
            x: 1,
            y: 3,
            from: GameTileKind::Normal,
            to: GameTileKind::Damaged,
        },
    );
    assert_eq!(result.snapshot.phase, GameMatchPhase::RoundOver);
    assert_eq!(result.snapshot.round_winner, Some(GamePlayer::First));
    assert_eq!(
        result.snapshot.round_win_reason,
        Some(GameWinReason::Knockout)
    );
}

#[test]
fn value_api_preserves_a_snapshot_across_move_calls() {
    let initial = initial_match();

    assert_eq!(initial.round.current_player, GamePlayer::First);
    assert_eq!(initial.round.snapshot_hash, "008d1d43a9eefe72");
    assert_eq!(initial.phase, GameMatchPhase::Playing);
    assert_eq!(initial.first_player_wins, 0);
    assert_eq!(initial.second_player_wins, 0);
    assert_eq!(
        initial.round.pieces,
        vec![
            GamePiece {
                id: 0,
                owner: GamePlayer::First,
                x: 1,
                y: 0,
            },
            GamePiece {
                id: 1,
                owner: GamePlayer::First,
                x: 3,
                y: 0,
            },
            GamePiece {
                id: 2,
                owner: GamePlayer::Second,
                x: 1,
                y: 4,
            },
            GamePiece {
                id: 3,
                owner: GamePlayer::Second,
                x: 3,
                y: 4,
            },
        ],
    );
    // The layout a round resets to travels with the match, because the
    // round's own tiles carry damage rather than the starting board.
    assert_eq!(initial.starting_pieces, initial.round.pieces);

    let first_move = game_move(0, GameDirection::Down);
    assert!(
        match_legal_moves(initial.clone())
            .unwrap()
            .contains(&first_move)
    );

    let after_first_move = match_apply_move(initial, first_move).unwrap().snapshot;

    assert_eq!(after_first_move.round.current_player, GamePlayer::Second);
    assert_eq!(after_first_move.round.snapshot_hash, "540736b5048c5f9f");
    assert!(
        after_first_move
            .round
            .tiles
            .iter()
            .any(|tile| { tile.x == 1 && tile.y == 0 && tile.kind == GameTileKind::Damaged })
    );
    assert!(after_first_move.round.pieces.contains(&GamePiece {
        id: 0,
        owner: GamePlayer::First,
        x: 1,
        y: 1,
    }));

    let after_push = play(
        after_first_move,
        &[
            (2, GameDirection::Up),
            (0, GameDirection::Down),
            (2, GameDirection::Up),
        ],
    );

    assert_eq!(after_push.round.snapshot_hash, "7044880ea390e9a8");
    assert!(
        !match_legal_moves(after_push)
            .unwrap()
            .contains(&game_move(0, GameDirection::Down)),
        "the snapshot must retain the immediate counter-push restriction",
    );
}

#[test]
fn value_api_rejects_a_snapshot_with_a_mismatched_hash() {
    let mut snapshot = initial_match();
    snapshot.round.pieces[0].x = 0;

    // The match hash covers the round's hash string, not its fields, so an
    // edited board is caught one level down by the round's own check. The two
    // layers together leave no field editable.
    assert_eq!(
        match_legal_moves(snapshot).unwrap_err(),
        "snapshot hash does not match its value fields",
    );
}

#[test]
fn value_api_rejects_an_edited_score() {
    let mut snapshot = initial_match();
    snapshot.first_player_wins = 1;

    assert_eq!(
        match_legal_moves(snapshot.clone()).unwrap_err(),
        "match snapshot hash does not match its value fields",
    );

    // Nor can a match be declared won by editing the winner alone.
    let mut declared = initial_match();
    declared.match_winner = Some(GamePlayer::First);
    declared.phase = GameMatchPhase::MatchOver;

    assert_eq!(
        match_legal_moves(declared).unwrap_err(),
        "match snapshot hash does not match its value fields",
    );
}

#[test]
fn value_api_holds_a_finished_round_until_it_is_advanced() {
    // Both of the second player's pieces are pushed off the board, one per
    // round, so the match runs to its end through the value API alone.
    let round_over = play(
        initial_match(),
        &[
            (0, GameDirection::Down),
            (2, GameDirection::Up),
            (0, GameDirection::Down),
            (3, GameDirection::Up),
            (0, GameDirection::Down),
            (3, GameDirection::Up),
            (0, GameDirection::Down),
        ],
    );

    assert_eq!(round_over.phase, GameMatchPhase::RoundOver);
    assert_eq!(round_over.round_winner, Some(GamePlayer::First));
    assert_eq!(round_over.round_win_reason, Some(GameWinReason::Knockout));
    assert_eq!(round_over.match_winner, None);
    assert_eq!(round_over.first_player_wins, 1);
    // The board that ended the round is the one still on show.
    assert!(!round_over.round.pieces.iter().any(|piece| piece.id == 2));
    assert_eq!(
        match_apply_move(round_over.clone(), game_move(1, GameDirection::Down)).unwrap_err(),
        "illegal move: RoundFinished",
    );

    let next_round = advance_round(round_over).unwrap();

    assert_eq!(next_round.phase, GameMatchPhase::Playing);
    assert_eq!(next_round.first_player_wins, 1);
    // The loser starts, on the layout the match carries.
    assert_eq!(next_round.round.current_player, GamePlayer::Second);
    assert_eq!(next_round.round.pieces, next_round.starting_pieces);
    assert_eq!(
        advance_round(next_round).unwrap_err(),
        "illegal move: RoundInProgress",
    );
}

#[test]
fn value_api_carries_a_won_match_back_without_reopening_it() {
    // Always taking the first legal move drives a real match to its end
    // through the value API alone, without pinning a move order that the
    // loser-starts rule would invalidate on the next round.
    let mut state = initial_match();
    let mut steps = 0;
    while state.phase != GameMatchPhase::MatchOver {
        assert!(steps < 500, "a match must reach an end");
        steps += 1;
        state = match state.phase {
            GameMatchPhase::Playing => {
                let moves = match_legal_moves(state.clone()).unwrap();
                assert!(!moves.is_empty(), "a playing round must offer a move");
                match_apply_move(state, moves[0].clone()).unwrap().snapshot
            }
            GameMatchPhase::RoundOver => advance_round(state).unwrap(),
            GameMatchPhase::MatchOver => unreachable!(),
        };
    }

    let winner = state
        .match_winner
        .expect("a decided match names its winner");
    let wins = match winner {
        GamePlayer::First => state.first_player_wins,
        GamePlayer::Second => state.second_player_wins,
    };

    assert_eq!(wins, 2);
    assert_eq!(state.round_winner, Some(winner));
    assert!(state.round_win_reason.is_some());

    // A decided match survives the round trip and stays decided: it neither
    // accepts a move nor reopens into another round.
    assert_eq!(
        match_legal_moves(state.clone()).unwrap(),
        Vec::<GameMove>::new(),
    );
    assert_eq!(
        match_apply_move(state.clone(), game_move(0, GameDirection::Down)).unwrap_err(),
        "illegal move: MatchFinished",
    );
    assert_eq!(
        advance_round(state).unwrap_err(),
        "illegal move: MatchFinished",
    );
}

/// Pins the move each policy plays from the parity fixture.
///
/// The integration test asserts these same four moves on a real Android and
/// a real iOS runtime. Legality and repeatability, which the test below
/// covers, hold separately on either platform without the two agreeing, so
/// the concrete move is what makes the bot's determinism a cross-platform
/// claim rather than a per-runtime one.
#[test]
fn value_api_pins_the_parity_fixture_bot_moves() {
    let fixture = play(
        initial_match(),
        &[
            (0, GameDirection::Down),
            (2, GameDirection::Up),
            (0, GameDirection::Down),
            (2, GameDirection::Up),
        ],
    );
    // The same position the parity hash names, so a fixture that drifts fails
    // here rather than silently repinning the moves below.
    assert_eq!(fixture.round.snapshot_hash, "7044880ea390e9a8");

    for (policy, expected) in [
        (BotPolicy::Random, game_move(1, GameDirection::Down)),
        (BotPolicy::Greedy, game_move(1, GameDirection::Down)),
        (BotPolicy::Minimax, game_move(0, GameDirection::Right)),
        (BotPolicy::Strategic, game_move(0, GameDirection::Right)),
    ] {
        assert_eq!(
            choose_bot_move(fixture.clone(), policy).unwrap(),
            Some(expected),
            "{policy:?} played a different move from the parity fixture",
        );
    }
}

#[test]
fn value_api_chooses_a_bot_move_from_the_position_alone() {
    let initial = initial_match();

    for policy in [
        BotPolicy::Random,
        BotPolicy::Greedy,
        BotPolicy::Minimax,
        BotPolicy::Strategic,
    ] {
        let chosen = choose_bot_move(initial.clone(), policy)
            .unwrap()
            .expect("the opening position offers moves");

        // The seed is derived from the position, so the same snapshot must
        // give the same move however often it is asked.
        assert_eq!(
            choose_bot_move(initial.clone(), policy).unwrap(),
            Some(chosen.clone()),
            "{policy:?} did not repeat itself for the same position",
        );
        assert!(
            match_legal_moves(initial.clone())
                .unwrap()
                .contains(&chosen),
            "{policy:?} chose a move the position does not allow",
        );
        // And it is playable, which is the only claim that matters to a caller.
        match_apply_move(initial.clone(), chosen).unwrap();
    }
}

#[test]
fn value_api_offers_no_bot_move_once_the_round_is_over() {
    let round_over = play(
        initial_match(),
        &[
            (0, GameDirection::Down),
            (2, GameDirection::Up),
            (0, GameDirection::Down),
            (3, GameDirection::Up),
            (0, GameDirection::Down),
            (3, GameDirection::Up),
            (0, GameDirection::Down),
        ],
    );

    assert_eq!(round_over.phase, GameMatchPhase::RoundOver);
    assert_eq!(
        choose_bot_move(round_over, BotPolicy::Greedy).unwrap(),
        None,
    );
}

#[test]
fn value_api_refuses_to_choose_from_an_edited_snapshot() {
    let mut snapshot = initial_match();
    snapshot.first_player_wins = 1;

    assert_eq!(
        choose_bot_move(snapshot, BotPolicy::Random).unwrap_err(),
        "match snapshot hash does not match its value fields",
    );
}
