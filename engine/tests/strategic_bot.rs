use std::collections::{BTreeSet, HashMap};

#[cfg(not(debug_assertions))]
use std::time::{Duration, Instant};

use engine::api::{
    BotPolicy, GameBoardCell, GameBoardDefinition, GameDirection, GameMove as ApiMove,
    GamePiece as ApiPiece, GamePlayer, MatchSnapshot, choose_bot_move, initial_match,
    match_apply_move,
};
use engine::bot::{MinimaxBot, Policy, StrategicBot};
use engine::{
    BoardConfig, Direction, GameState, Move, Outcome, Piece, PieceId, Player, Position, WinReason,
    apply_move, legal_moves, outcome,
};

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
struct ExactResult {
    winner: Player,
    plies: u16,
}

fn opponent(player: Player) -> Player {
    match player {
        Player::First => Player::Second,
        Player::Second => Player::First,
    }
}

fn exact_result(state: &GameState, memo: &mut HashMap<GameState, ExactResult>) -> ExactResult {
    if let Some(result) = memo.get(state) {
        return *result;
    }
    if let Outcome::Winner(winner, _) = outcome(state) {
        return ExactResult { winner, plies: 0 };
    }

    let mover = state.current_player();
    let children = legal_moves(state)
        .into_iter()
        .map(|candidate| {
            let next = apply_move(state, candidate).unwrap();
            (candidate, exact_result(&next, memo))
        })
        .collect::<Vec<_>>();
    let winning_distance = children
        .iter()
        .filter(|(_, result)| result.winner == mover)
        .map(|(_, result)| result.plies)
        .min();
    let result = if let Some(distance) = winning_distance {
        ExactResult {
            winner: mover,
            plies: distance.saturating_add(1),
        }
    } else {
        ExactResult {
            winner: opponent(mover),
            plies: children
                .iter()
                .map(|(_, result)| result.plies)
                .max()
                .expect("an ongoing state must have a legal move")
                .saturating_add(1),
        }
    };
    memo.insert(state.clone(), result);
    result
}

fn exact_moves(state: &GameState) -> Vec<Move> {
    let mover = state.current_player();
    let mut memo = HashMap::new();
    let choices = legal_moves(state)
        .into_iter()
        .map(|candidate| {
            let next = apply_move(state, candidate).unwrap();
            (candidate, exact_result(&next, &mut memo))
        })
        .collect::<Vec<_>>();
    let wins = choices
        .iter()
        .filter(|(_, result)| result.winner == mover)
        .collect::<Vec<_>>();
    if !wins.is_empty() {
        let shortest = wins.iter().map(|(_, result)| result.plies).min().unwrap();
        return wins
            .into_iter()
            .filter(|(_, result)| result.plies == shortest)
            .map(|(candidate, _)| *candidate)
            .collect();
    }

    let longest = choices
        .iter()
        .map(|(_, result)| result.plies)
        .max()
        .unwrap();
    choices
        .into_iter()
        .filter(|(_, result)| result.plies == longest)
        .map(|(candidate, _)| candidate)
        .collect()
}

fn rectangular_state(width: u8, height: u8, pieces: Vec<Piece>) -> GameState {
    let board = BoardConfig::rectangular(width, height, pieces).unwrap();
    GameState::new(board, Player::First).unwrap()
}

fn small_exact_state() -> GameState {
    rectangular_state(
        3,
        3,
        vec![
            Piece::new(PieceId(0), Player::First, Position::new(0, 0)),
            Piece::new(PieceId(1), Player::Second, Position::new(2, 2)),
        ],
    )
}

fn play_path(start: &GameState, path: &[Move]) -> GameState {
    path.iter().fold(start.clone(), |state, candidate| {
        apply_move(&state, *candidate).expect("the committed fixture path must stay legal")
    })
}

#[test]
fn strategic_finds_a_forced_win_beyond_two_plies() {
    let state = play_path(
        &small_exact_state(),
        &[Move::new(PieceId(0), Direction::Right)],
    );
    let mut memo = HashMap::new();
    let exact = exact_moves(&state);
    let hard_move = MinimaxBot::new(2, 7).choose(&state).unwrap();
    let hard_result = exact_result(&apply_move(&state, hard_move).unwrap(), &mut memo);

    assert_eq!(
        exact_result(&state, &mut memo),
        ExactResult {
            winner: Player::Second,
            plies: 11,
        },
    );
    assert_eq!(exact, vec![Move::new(PieceId(1), Direction::Left)]);
    assert_eq!(
        hard_result,
        ExactResult {
            winner: Player::First,
            plies: 13,
        },
        "Hard's mobility choice must remain a forced loss",
    );
    assert!(
        !exact.contains(&hard_move),
        "the fixture must remain beyond Hard's two-ply horizon",
    );
    assert!(exact.contains(&StrategicBot::new(7).choose(&state).unwrap()));
}

#[test]
fn strategic_matches_the_exact_solver_on_small_late_round_states() {
    let start = small_exact_state();
    let fixtures = [
        (
            vec![],
            ExactResult {
                winner: Player::Second,
                plies: 12,
            },
            vec![
                Move::new(PieceId(0), Direction::Down),
                Move::new(PieceId(0), Direction::Right),
            ],
        ),
        (
            vec![Move::new(PieceId(0), Direction::Right)],
            ExactResult {
                winner: Player::Second,
                plies: 11,
            },
            vec![Move::new(PieceId(1), Direction::Left)],
        ),
        (
            vec![Move::new(PieceId(0), Direction::Down)],
            ExactResult {
                winner: Player::Second,
                plies: 11,
            },
            vec![Move::new(PieceId(1), Direction::Up)],
        ),
        (
            vec![
                Move::new(PieceId(0), Direction::Right),
                Move::new(PieceId(1), Direction::Left),
            ],
            ExactResult {
                winner: Player::Second,
                plies: 10,
            },
            vec![Move::new(PieceId(0), Direction::Down)],
        ),
    ];

    for (path, expected_result, expected_moves) in fixtures {
        let state = play_path(&start, &path);
        let mut memo = HashMap::new();
        let exact = exact_moves(&state);

        assert_eq!(exact_result(&state, &mut memo), expected_result, "{path:?}");
        assert_eq!(exact, expected_moves, "{path:?}");
        assert!(
            exact.contains(&StrategicBot::new(7).choose(&state).unwrap()),
            "Strategic diverged from the exact solver at {path:?}",
        );
    }
}

#[test]
fn strategic_matches_the_exact_solver_on_variant_topologies() {
    let fixtures = [
        ("irregular", translated_horizon_state([Position::new(7, 9)])),
        (
            "larger",
            translated_horizon_state((7..10).map(|x| Position::new(x, 9))),
        ),
    ];
    let expected_result = ExactResult {
        winner: Player::Second,
        plies: 11,
    };
    let expected_moves = vec![Move::new(PieceId(1), Direction::Left)];

    for (name, state) in fixtures {
        let mut memo = HashMap::new();
        let exact = exact_moves(&state);

        assert_eq!(exact_result(&state, &mut memo), expected_result, "{name}");
        assert_eq!(exact, expected_moves, "{name}");
        assert!(
            exact.contains(&StrategicBot::new(7).choose(&state).unwrap()),
            "Strategic diverged from the exact solver on {name}",
        );
    }
}

#[test]
fn strategic_takes_knockout_and_immobilization_wins() {
    let knockout = rectangular_state(
        5,
        5,
        vec![
            Piece::new(PieceId(0), Player::First, Position::new(3, 2)),
            Piece::new(PieceId(1), Player::Second, Position::new(4, 2)),
        ],
    );
    let knockout_move = StrategicBot::new(7).choose(&knockout).unwrap();
    assert_eq!(knockout_move, Move::new(PieceId(0), Direction::Right));
    assert_eq!(
        outcome(&apply_move(&knockout, knockout_move).unwrap()),
        Outcome::Winner(Player::First, WinReason::Knockout),
    );

    let immobilization_board = BoardConfig::new(
        [
            Position::new(1, 0),
            Position::new(2, 0),
            Position::new(3, 0),
        ]
        .into_iter()
        .collect(),
        vec![
            Piece::new(PieceId(0), Player::First, Position::new(1, 0)),
            Piece::new(PieceId(1), Player::Second, Position::new(2, 0)),
        ],
    )
    .unwrap();
    let immobilization = GameState::new(immobilization_board, Player::First).unwrap();
    let immobilizing_move = StrategicBot::new(7).choose(&immobilization).unwrap();
    assert_eq!(immobilizing_move, Move::new(PieceId(0), Direction::Right));
    assert_eq!(
        outcome(&apply_move(&immobilization, immobilizing_move).unwrap()),
        Outcome::Winner(Player::First, WinReason::Immobilization),
    );
}

#[test]
fn strategic_uses_irregular_non_zero_origin_topology() {
    let cells = [
        Position::new(4, 7),
        Position::new(5, 7),
        Position::new(6, 7),
        Position::new(4, 8),
        Position::new(5, 8),
    ]
    .into_iter()
    .collect::<BTreeSet<_>>();
    let board = BoardConfig::new(
        cells,
        vec![
            Piece::new(PieceId(7), Player::First, Position::new(5, 7)),
            Piece::new(PieceId(9), Player::Second, Position::new(6, 7)),
        ],
    )
    .unwrap();
    let state = GameState::new(board, Player::First).unwrap();

    assert_eq!(
        StrategicBot::new(7).choose(&state),
        Some(Move::new(PieceId(7), Direction::Right)),
    );
}

#[test]
fn strategic_returns_a_legal_move_on_a_larger_board() {
    let state = rectangular_state(
        7,
        6,
        vec![
            Piece::new(PieceId(0), Player::First, Position::new(5, 2)),
            Piece::new(PieceId(1), Player::First, Position::new(0, 0)),
            Piece::new(PieceId(2), Player::Second, Position::new(6, 2)),
            Piece::new(PieceId(3), Player::Second, Position::new(6, 5)),
        ],
    );
    let legal = legal_moves(&state);
    let chosen = StrategicBot::new(7).choose(&state).unwrap();

    assert!(legal.contains(&chosen));
    assert_eq!(chosen, Move::new(PieceId(0), Direction::Right));
}

fn api_move(piece_id: u8, direction: GameDirection) -> ApiMove {
    ApiMove {
        piece_id,
        direction,
    }
}

fn play_match_path(start: MatchSnapshot, path: &[ApiMove]) -> MatchSnapshot {
    path.iter().fold(start, |snapshot, candidate| {
        match_apply_move(snapshot, candidate.clone())
            .expect("the committed production fixture path must stay legal")
            .snapshot
    })
}

fn baseline_definition() -> GameBoardDefinition {
    GameBoardDefinition {
        playable_cells: (0..5)
            .flat_map(|x| (0..5).map(move |y| GameBoardCell { x, y }))
            .collect(),
        starting_pieces: vec![
            ApiPiece {
                id: 0,
                owner: GamePlayer::First,
                x: 1,
                y: 0,
            },
            ApiPiece {
                id: 1,
                owner: GamePlayer::First,
                x: 3,
                y: 0,
            },
            ApiPiece {
                id: 2,
                owner: GamePlayer::Second,
                x: 1,
                y: 4,
            },
            ApiPiece {
                id: 3,
                owner: GamePlayer::Second,
                x: 3,
                y: 4,
            },
        ],
    }
}

fn baseline_league_snapshot() -> MatchSnapshot {
    let start = initial_match(baseline_definition()).unwrap();
    play_match_path(
        start,
        &[
            api_move(0, GameDirection::Down),
            api_move(3, GameDirection::Up),
            api_move(1, GameDirection::Down),
            api_move(2, GameDirection::Up),
            api_move(0, GameDirection::Left),
            api_move(2, GameDirection::Up),
            api_move(1, GameDirection::Down),
            api_move(3, GameDirection::Left),
            api_move(1, GameDirection::Up),
            api_move(3, GameDirection::Right),
            api_move(0, GameDirection::Up),
            api_move(2, GameDirection::Right),
            api_move(0, GameDirection::Right),
            api_move(2, GameDirection::Left),
            api_move(1, GameDirection::Left),
            api_move(2, GameDirection::Down),
            api_move(1, GameDirection::Down),
            api_move(2, GameDirection::Left),
            api_move(0, GameDirection::Right),
            api_move(2, GameDirection::Down),
            api_move(0, GameDirection::Right),
            api_move(2, GameDirection::Right),
            api_move(0, GameDirection::Left),
            api_move(2, GameDirection::Right),
            api_move(0, GameDirection::Down),
            api_move(2, GameDirection::Right),
            api_move(0, GameDirection::Left),
            api_move(2, GameDirection::Left),
            api_move(0, GameDirection::Left),
            api_move(3, GameDirection::Right),
        ],
    )
}

fn translated_horizon_snapshot(
    extra_cells: impl IntoIterator<Item = GameBoardCell>,
) -> MatchSnapshot {
    let mut playable_cells = (4..7)
        .flat_map(|x| (7..10).map(move |y| GameBoardCell { x, y }))
        .collect::<Vec<_>>();
    playable_cells.extend(extra_cells);
    let start = initial_match(GameBoardDefinition {
        playable_cells,
        starting_pieces: vec![
            ApiPiece {
                id: 0,
                owner: GamePlayer::First,
                x: 4,
                y: 7,
            },
            ApiPiece {
                id: 1,
                owner: GamePlayer::Second,
                x: 6,
                y: 9,
            },
        ],
    })
    .unwrap();
    match_apply_move(start, api_move(0, GameDirection::Right))
        .unwrap()
        .snapshot
}

fn play_competition(mut snapshot: MatchSnapshot, strategic_player: GamePlayer) -> GamePlayer {
    for _ in 0..100 {
        let policy = if snapshot.round.current_player == strategic_player {
            BotPolicy::Strategic
        } else {
            BotPolicy::Minimax
        };
        let candidate = choose_bot_move(snapshot.clone(), policy)
            .unwrap()
            .expect("a playing production snapshot must offer a bot move");
        snapshot = match_apply_move(snapshot, candidate).unwrap().snapshot;
        if let Some(winner) = snapshot.round.winner {
            return winner;
        }
    }
    panic!("the competition fixture did not finish");
}

fn translated_horizon_state(extra_cells: impl IntoIterator<Item = Position>) -> GameState {
    let mut cells = (4..7)
        .flat_map(|x| (7..10).map(move |y| Position::new(x, y)))
        .collect::<BTreeSet<_>>();
    cells.extend(extra_cells);
    let board = BoardConfig::new(
        cells,
        vec![
            Piece::new(PieceId(0), Player::First, Position::new(4, 7)),
            Piece::new(PieceId(1), Player::Second, Position::new(6, 9)),
        ],
    )
    .unwrap();
    let state = GameState::new(board, Player::First).unwrap();
    apply_move(&state, Move::new(PieceId(0), Direction::Right)).unwrap()
}

#[cfg(not(debug_assertions))]
fn larger_multi_piece_state() -> GameState {
    rectangular_state(
        7,
        6,
        vec![
            Piece::new(PieceId(0), Player::First, Position::new(1, 0)),
            Piece::new(PieceId(1), Player::First, Position::new(5, 0)),
            Piece::new(PieceId(2), Player::Second, Position::new(1, 5)),
            Piece::new(PieceId(3), Player::Second, Position::new(5, 5)),
        ],
    )
}

#[test]
fn strategic_beats_hard_from_both_seats_in_each_topology_group() {
    let fixtures = [
        ("baseline", baseline_league_snapshot()),
        (
            "irregular",
            translated_horizon_snapshot([GameBoardCell { x: 7, y: 9 }]),
        ),
        (
            "larger",
            translated_horizon_snapshot((7..50).map(|x| GameBoardCell { x, y: 9 })),
        ),
    ];
    let mut strategic_points = 0_u8;
    let mut available_points = 0_u8;

    for (name, snapshot) in fixtures {
        let mut group_points = 0_u8;
        for strategic_player in [GamePlayer::First, GamePlayer::Second] {
            available_points += 1;
            let winner = play_competition(snapshot.clone(), strategic_player);
            if winner == strategic_player {
                strategic_points += 1;
                group_points += 1;
            }
        }
        assert!(
            group_points > 1,
            "Strategic scored {group_points}/2 against Hard on {name}",
        );
    }

    assert!(
        u16::from(strategic_points) * 100 >= u16::from(available_points) * 70,
        "Strategic scored {strategic_points}/{available_points} available match points",
    );
}

#[cfg(not(debug_assertions))]
#[test]
fn strategic_searches_meet_the_host_turn_limit() {
    let fixtures = [
        ("baseline", GameState::baseline()),
        ("irregular", translated_horizon_state([Position::new(7, 9)])),
        ("larger", larger_multi_piece_state()),
    ];
    let mut all_meet_target = true;

    for (name, state) in fixtures {
        let mut bot = StrategicBot::new(7);
        let started = Instant::now();
        let chosen = bot.choose(&state);
        let elapsed = started.elapsed();
        let diagnostics = bot.last_search_diagnostics();

        eprintln!(
            "{name}: elapsed={elapsed:?}, completed_depth={}, expanded_nodes={}",
            diagnostics.completed_depth(),
            diagnostics.expanded_nodes(),
        );
        assert!(chosen.is_some());
        assert!(diagnostics.completed_depth() >= 1);
        assert!(diagnostics.expanded_nodes() > 0);
        assert!(
            elapsed < Duration::from_secs(2),
            "{name} search took {elapsed:?}, exceeding the two-second host limit",
        );
        all_meet_target &= elapsed < Duration::from_secs(1);
    }

    eprintln!("one-second host search target met: {all_meet_target}");
}
