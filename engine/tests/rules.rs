use std::collections::{BTreeMap, BTreeSet};

use engine::{
    apply_move, legal_moves, outcome, BoardConfig, Direction, GameState, IllegalMove, MatchOutcome,
    MatchState, Move, Outcome, Piece, PieceId, Player, Position, Tile, WinReason,
};

fn position(x: u8, y: u8) -> Position {
    Position::new(x, y)
}

fn state_with_pieces(first: &[(PieceId, Position)], second: &[(PieceId, Position)]) -> GameState {
    let pieces = first
        .iter()
        .map(|(id, position)| Piece::new(*id, Player::First, *position))
        .chain(
            second
                .iter()
                .map(|(id, position)| Piece::new(*id, Player::Second, *position)),
        )
        .collect();
    let board = BoardConfig::rectangular(5, 5, pieces).expect("fixture board is valid");

    GameState::new(board, Player::First).expect("fixture state is valid")
}

fn state_with_tiles(
    first: &[(PieceId, Position)],
    second: &[(PieceId, Position)],
    tile_overrides: &[(Position, Tile)],
) -> GameState {
    let pieces = first
        .iter()
        .map(|(id, position)| Piece::new(*id, Player::First, *position))
        .chain(
            second
                .iter()
                .map(|(id, position)| Piece::new(*id, Player::Second, *position)),
        )
        .collect();
    let board = BoardConfig::rectangular(5, 5, pieces).unwrap();
    let mut tiles = (0..5)
        .flat_map(|x| (0..5).map(move |y| (position(x, y), Tile::Normal)))
        .collect::<BTreeMap<_, _>>();
    for (position, tile) in tile_overrides {
        tiles.insert(*position, *tile);
    }

    GameState::from_parts(board, tiles, Player::First).unwrap()
}

#[test]
fn normal_move_changes_position_and_damages_only_departure_tile() {
    let mover = PieceId(1);
    let state = state_with_pieces(&[(mover, position(2, 2))], &[(PieceId(2), position(4, 4))]);

    let next = apply_move(&state, Move::new(mover, Direction::Up)).expect("move is legal");

    assert_eq!(next.piece(mover).unwrap().position, position(2, 1));
    assert_eq!(next.tile_at(position(2, 2)), Some(Tile::Damaged));
    assert_eq!(next.tile_at(position(2, 1)), Some(Tile::Normal));
    assert_eq!(next.current_player(), Player::Second);
}

#[test]
fn normal_move_supports_every_orthogonal_direction() {
    let mover = PieceId(1);
    for (direction, expected_position) in [
        (Direction::Up, position(2, 1)),
        (Direction::Down, position(2, 3)),
        (Direction::Left, position(1, 2)),
        (Direction::Right, position(3, 2)),
    ] {
        let state = state_with_pieces(&[(mover, position(2, 2))], &[(PieceId(2), position(4, 4))]);

        let next = apply_move(&state, Move::new(mover, direction)).unwrap();

        assert_eq!(next.piece(mover).unwrap().position, expected_position);
    }
}

#[test]
fn legal_moves_lists_only_one_step_empty_destinations_for_the_current_player() {
    let mover = PieceId(1);
    let state = state_with_pieces(&[(mover, position(0, 0))], &[(PieceId(2), position(4, 4))]);

    assert_eq!(
        legal_moves(&state),
        vec![
            Move::new(mover, Direction::Down),
            Move::new(mover, Direction::Right),
        ],
    );
}

#[test]
fn push_moves_one_adjacent_opponent_without_damaging_passive_tiles() {
    let attacker = PieceId(1);
    let pushed = PieceId(2);
    let state = state_with_pieces(&[(attacker, position(1, 2))], &[(pushed, position(2, 2))]);

    let next = apply_move(&state, Move::new(attacker, Direction::Right)).expect("push is legal");

    assert_eq!(next.piece(attacker).unwrap().position, position(2, 2));
    assert_eq!(next.piece(pushed).unwrap().position, position(3, 2));
    assert_eq!(next.tile_at(position(1, 2)), Some(Tile::Damaged));
    assert_eq!(next.tile_at(position(2, 2)), Some(Tile::Normal));
    assert_eq!(next.tile_at(position(3, 2)), Some(Tile::Normal));
    assert_eq!(next.current_player(), Player::Second);
}

#[test]
fn pushed_piece_cannot_immediately_push_its_specific_pusher_back() {
    let attacker = PieceId(1);
    let pushed = PieceId(2);
    let state = state_with_pieces(&[(attacker, position(1, 2))], &[(pushed, position(2, 2))]);
    let after_push = apply_move(&state, Move::new(attacker, Direction::Right)).unwrap();

    assert_eq!(
        apply_move(&after_push, Move::new(pushed, Direction::Left)),
        Err(IllegalMove::ImmediateCounterPush),
    );
    assert!(legal_moves(&after_push).contains(&Move::new(pushed, Direction::Up)));
}

#[test]
fn pushing_an_opponent_into_a_hole_wins_the_round_immediately() {
    let attacker = PieceId(1);
    let pushed = PieceId(2);
    let state = state_with_tiles(
        &[(attacker, position(1, 2))],
        &[(pushed, position(2, 2))],
        &[(position(3, 2), Tile::Hole)],
    );

    let next = apply_move(&state, Move::new(attacker, Direction::Right)).unwrap();

    assert_eq!(next.piece(attacker).unwrap().position, position(2, 2));
    assert_eq!(next.piece(pushed), None);
    assert_eq!(next.tile_at(position(1, 2)), Some(Tile::Damaged));
    assert_eq!(
        outcome(&next),
        Outcome::Winner(Player::First, WinReason::Knockout)
    );
    assert!(legal_moves(&next).is_empty());
}

#[test]
fn leaving_the_next_player_without_any_legal_move_wins_by_immobilization() {
    let mover = PieceId(1);
    let state = state_with_tiles(
        &[(mover, position(3, 3))],
        &[(PieceId(2), position(0, 0))],
        &[(position(0, 1), Tile::Hole), (position(1, 0), Tile::Hole)],
    );

    let next = apply_move(&state, Move::new(mover, Direction::Up)).unwrap();

    assert_eq!(
        outcome(&next),
        Outcome::Winner(Player::First, WinReason::Immobilization),
    );
    assert!(legal_moves(&next).is_empty());
}

#[test]
fn initially_immobilized_player_loses_the_round() {
    let pieces = vec![
        Piece::new(PieceId(1), Player::First, position(3, 3)),
        Piece::new(PieceId(2), Player::Second, position(0, 0)),
    ];
    let board = BoardConfig::rectangular(5, 5, pieces).unwrap();
    let mut tiles = (0..5)
        .flat_map(|x| (0..5).map(move |y| (position(x, y), Tile::Normal)))
        .collect::<BTreeMap<_, _>>();
    tiles.insert(position(0, 1), Tile::Hole);
    tiles.insert(position(1, 0), Tile::Hole);

    let state = GameState::from_parts(board, tiles, Player::Second).unwrap();

    assert_eq!(
        outcome(&state),
        Outcome::Winner(Player::First, WinReason::Immobilization),
    );
    assert!(legal_moves(&state).is_empty());
}

#[test]
fn a_prohibited_only_counter_push_causes_immobilization() {
    let attacker = PieceId(1);
    let pushed = PieceId(2);
    let board = BoardConfig::new(
        [position(1, 0), position(2, 0), position(3, 0)]
            .into_iter()
            .collect::<BTreeSet<_>>(),
        vec![
            Piece::new(attacker, Player::First, position(1, 0)),
            Piece::new(pushed, Player::Second, position(2, 0)),
        ],
    )
    .unwrap();
    let state = GameState::new(board, Player::First).unwrap();

    let next = apply_move(&state, Move::new(attacker, Direction::Right)).unwrap();

    assert_eq!(
        outcome(&next),
        Outcome::Winner(Player::First, WinReason::Immobilization),
    );
    assert!(legal_moves(&next).is_empty());
}

#[test]
fn match_settles_an_initially_immobilized_round() {
    let board = BoardConfig::new(
        [position(0, 0), position(3, 2), position(3, 3)]
            .into_iter()
            .collect::<BTreeSet<_>>(),
        vec![
            Piece::new(PieceId(1), Player::First, position(3, 3)),
            Piece::new(PieceId(2), Player::Second, position(0, 0)),
        ],
    )
    .unwrap();

    let state = MatchState::new(board, Player::Second).unwrap();

    assert_eq!(state.round_wins(Player::First), 2);
    assert_eq!(state.round_wins(Player::Second), 0);
    assert_eq!(state.outcome(), MatchOutcome::Winner(Player::First));
}

#[test]
fn match_resets_the_board_with_the_loser_starting_and_ends_after_two_round_wins() {
    let attacker = PieceId(1);
    let target = PieceId(2);
    let responder = PieceId(3);
    let board = BoardConfig::rectangular(
        5,
        5,
        vec![
            Piece::new(attacker, Player::First, position(3, 2)),
            Piece::new(target, Player::Second, position(4, 2)),
            Piece::new(responder, Player::Second, position(0, 0)),
        ],
    )
    .unwrap();
    let state = MatchState::new(board, Player::First).unwrap();

    let after_first_round = state
        .apply_move(Move::new(attacker, Direction::Right))
        .unwrap();

    assert_eq!(after_first_round.round_wins(Player::First), 1);
    assert_eq!(after_first_round.round().current_player(), Player::Second);
    assert_eq!(
        after_first_round.round().tile_at(position(3, 2)),
        Some(Tile::Normal)
    );
    assert_eq!(after_first_round.outcome(), MatchOutcome::Ongoing);

    let before_second_round_finish = after_first_round
        .apply_move(Move::new(responder, Direction::Down))
        .unwrap();
    let completed_match = before_second_round_finish
        .apply_move(Move::new(attacker, Direction::Right))
        .unwrap();

    assert_eq!(completed_match.round_wins(Player::First), 2);
    assert_eq!(
        completed_match.outcome(),
        MatchOutcome::Winner(Player::First),
    );
}

#[test]
fn baseline_is_a_symmetric_five_by_five_experiment_configuration() {
    let state = GameState::baseline();

    assert_eq!(state.current_player(), Player::First);
    assert_eq!(state.piece(PieceId(0)).unwrap().position, position(1, 0));
    assert_eq!(state.piece(PieceId(1)).unwrap().position, position(3, 0));
    assert_eq!(state.piece(PieceId(2)).unwrap().position, position(1, 4));
    assert_eq!(state.piece(PieceId(3)).unwrap().position, position(3, 4));
    assert_eq!(state.tile_at(position(2, 2)), Some(Tile::Normal));
}

#[test]
fn normal_move_rejects_outside_hole_and_friendly_destinations() {
    let mover = PieceId(1);
    let outside = state_with_pieces(&[(mover, position(0, 0))], &[(PieceId(2), position(4, 4))]);
    let hole = state_with_tiles(
        &[(mover, position(2, 2))],
        &[(PieceId(2), position(4, 4))],
        &[(position(2, 1), Tile::Hole)],
    );
    let friendly = state_with_pieces(
        &[(mover, position(2, 2)), (PieceId(3), position(2, 1))],
        &[(PieceId(2), position(4, 4))],
    );

    assert_eq!(
        apply_move(&outside, Move::new(mover, Direction::Up)),
        Err(IllegalMove::OutsideBoard),
    );
    assert_eq!(
        apply_move(&hole, Move::new(mover, Direction::Up)),
        Err(IllegalMove::Hole),
    );
    assert_eq!(
        apply_move(&friendly, Move::new(mover, Direction::Up)),
        Err(IllegalMove::Occupied),
    );
}

#[test]
fn leaving_a_damaged_tile_turns_it_into_a_hole() {
    let mover = PieceId(1);
    let state = state_with_tiles(
        &[(mover, position(2, 2))],
        &[(PieceId(2), position(4, 4))],
        &[(position(2, 2), Tile::Damaged)],
    );

    let next = apply_move(&state, Move::new(mover, Direction::Up)).unwrap();

    assert_eq!(next.tile_at(position(2, 2)), Some(Tile::Hole));
}

#[test]
fn push_is_rejected_when_a_piece_blocks_the_displaced_piece_regardless_of_owner() {
    let attacker = PieceId(1);
    let pushed = PieceId(2);
    for blocker_owner in [Player::First, Player::Second] {
        let mut first = vec![(attacker, position(1, 2))];
        let mut second = vec![(pushed, position(2, 2))];
        match blocker_owner {
            Player::First => first.push((PieceId(3), position(3, 2))),
            Player::Second => second.push((PieceId(3), position(3, 2))),
        }
        let state = state_with_pieces(&first, &second);

        assert_eq!(
            apply_move(&state, Move::new(attacker, Direction::Right)),
            Err(IllegalMove::BlockedPush),
        );
    }
}

#[test]
fn push_outside_the_playable_topology_wins_the_round() {
    let attacker = PieceId(1);
    let pushed = PieceId(2);
    let state = state_with_pieces(&[(attacker, position(3, 2))], &[(pushed, position(4, 2))]);

    let next = apply_move(&state, Move::new(attacker, Direction::Right)).unwrap();

    assert_eq!(next.piece(attacker).unwrap().position, position(4, 2));
    assert_eq!(next.piece(pushed), None);
    assert_eq!(
        outcome(&next),
        Outcome::Winner(Player::First, WinReason::Knockout)
    );
}

#[test]
fn counter_push_restriction_expires_after_any_legal_response() {
    let attacker = PieceId(1);
    let pushed = PieceId(2);
    let first_helper = PieceId(3);
    let second_helper = PieceId(4);
    let state = state_with_pieces(
        &[(attacker, position(1, 2)), (first_helper, position(0, 0))],
        &[(pushed, position(2, 2)), (second_helper, position(0, 4))],
    );
    let after_push = apply_move(&state, Move::new(attacker, Direction::Right)).unwrap();
    let after_response = apply_move(&after_push, Move::new(second_helper, Direction::Up)).unwrap();
    let before_counter_push =
        apply_move(&after_response, Move::new(first_helper, Direction::Right)).unwrap();

    let after_counter_push =
        apply_move(&before_counter_push, Move::new(pushed, Direction::Left)).unwrap();

    assert_eq!(
        after_counter_push.piece(attacker).unwrap().position,
        position(1, 2)
    );
    assert_eq!(
        after_counter_push.piece(pushed).unwrap().position,
        position(2, 2)
    );
}

#[test]
fn a_finished_round_rejects_additional_moves() {
    let attacker = PieceId(1);
    let state = state_with_pieces(
        &[(attacker, position(3, 2))],
        &[(PieceId(2), position(4, 2))],
    );
    let finished = apply_move(&state, Move::new(attacker, Direction::Right)).unwrap();

    assert_eq!(
        apply_move(&finished, Move::new(attacker, Direction::Left)),
        Err(IllegalMove::RoundFinished),
    );
}

#[test]
fn board_config_accepts_a_non_rectangular_topology() {
    let attacker = PieceId(1);
    let pushed = PieceId(2);
    let playable_cells = [position(1, 1), position(2, 1)]
        .into_iter()
        .collect::<BTreeSet<_>>();
    let board = BoardConfig::new(
        playable_cells,
        vec![
            Piece::new(attacker, Player::First, position(1, 1)),
            Piece::new(pushed, Player::Second, position(2, 1)),
        ],
    )
    .unwrap();
    let state = GameState::new(board, Player::First).unwrap();

    let next = apply_move(&state, Move::new(attacker, Direction::Right)).unwrap();

    assert_eq!(next.piece(attacker).unwrap().position, position(2, 1));
    assert_eq!(
        outcome(&next),
        Outcome::Winner(Player::First, WinReason::Knockout)
    );
}
