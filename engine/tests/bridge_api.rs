use engine::api::{
    GameDirection, GameMatchPhase, GameMove, GamePiece, GamePlayer, GameTileKind, GameWinReason,
    MatchSnapshot, advance_round, initial_match, match_apply_move, match_legal_moves,
};

fn game_move(piece_id: u8, direction: GameDirection) -> GameMove {
    GameMove {
        piece_id,
        direction,
    }
}

fn play(snapshot: MatchSnapshot, moves: &[(u8, GameDirection)]) -> MatchSnapshot {
    moves.iter().fold(snapshot, |state, (piece, direction)| {
        match_apply_move(state, game_move(*piece, *direction)).unwrap()
    })
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

    let after_first_move = match_apply_move(initial, first_move).unwrap();

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
                match_apply_move(state, moves[0].clone()).unwrap()
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
