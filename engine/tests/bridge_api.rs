use engine::api::{
    apply_move, initial_state, legal_moves, GameDirection, GameMove, GamePiece, GamePlayer,
    GameTileKind,
};

fn game_move(piece_id: u8, direction: GameDirection) -> GameMove {
    GameMove {
        piece_id,
        direction,
    }
}

#[test]
fn value_api_preserves_a_snapshot_across_move_calls() {
    let initial = initial_state();

    assert_eq!(initial.current_player, GamePlayer::First);
    assert_eq!(initial.snapshot_hash, "008d1d43a9eefe72");
    assert_eq!(
        initial.pieces,
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

    let first_move = game_move(0, GameDirection::Down);
    assert!(legal_moves(initial.clone()).unwrap().contains(&first_move));

    let after_first_move = apply_move(initial, first_move).unwrap();

    assert_eq!(after_first_move.current_player, GamePlayer::Second);
    assert_eq!(after_first_move.snapshot_hash, "540736b5048c5f9f");
    assert!(after_first_move
        .tiles
        .iter()
        .any(|tile| { tile.x == 1 && tile.y == 0 && tile.kind == GameTileKind::Damaged }));
    assert!(after_first_move.pieces.contains(&GamePiece {
        id: 0,
        owner: GamePlayer::First,
        x: 1,
        y: 1,
    }));

    let after_second_move = apply_move(after_first_move, game_move(2, GameDirection::Up)).unwrap();
    let after_third_move =
        apply_move(after_second_move, game_move(0, GameDirection::Down)).unwrap();
    let after_push = apply_move(after_third_move, game_move(2, GameDirection::Up)).unwrap();

    assert!(
        !legal_moves(after_push)
            .unwrap()
            .contains(&game_move(0, GameDirection::Down)),
        "the snapshot must retain the immediate counter-push restriction",
    );
}

#[test]
fn value_api_rejects_a_snapshot_with_a_mismatched_hash() {
    let mut snapshot = initial_state();
    snapshot.pieces[0].x = 0;

    assert_eq!(
        legal_moves(snapshot).unwrap_err(),
        "snapshot hash does not match its value fields",
    );
}
