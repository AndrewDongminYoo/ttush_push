use std::collections::BTreeSet;

use engine::bot::{GreedyBot, MinimaxBot, Policy, RandomBot};
use engine::{
    BoardConfig, Direction, GameState, Move, Outcome, Piece, PieceId, Player, Position, apply_move,
    legal_moves, outcome,
};

fn position(x: u8, y: u8) -> Position {
    Position::new(x, y)
}

/// A board where First can knock Second's piece off the edge by pushing
/// right, and where not doing so hands Second the same win in reply.
fn knockout_board() -> BoardConfig {
    BoardConfig::rectangular(
        5,
        5,
        vec![
            Piece::new(PieceId(0), Player::First, position(3, 2)),
            Piece::new(PieceId(1), Player::Second, position(4, 2)),
        ],
    )
    .unwrap()
}

fn winning_move(state: &GameState, player: Player) -> Option<Move> {
    legal_moves(state).into_iter().find(|candidate| {
        apply_move(state, *candidate).is_ok_and(
            |next| matches!(outcome(&next), Outcome::Winner(winner, _) if winner == player),
        )
    })
}

fn policies(seed: u64) -> Vec<(&'static str, Box<dyn Policy>)> {
    vec![
        ("random", Box::new(RandomBot::new(seed))),
        ("greedy", Box::new(GreedyBot::new(seed))),
        ("minimax", Box::new(MinimaxBot::new(2, seed))),
    ]
}

#[test]
fn every_policy_returns_a_legal_move_or_none() {
    let state = GameState::baseline();
    let legal = legal_moves(&state);

    for (name, mut policy) in policies(7) {
        let chosen = policy.choose(&state).unwrap_or_else(|| {
            panic!("{name} found no move on the baseline board");
        });

        assert!(legal.contains(&chosen), "{name} chose an illegal move");
    }
}

#[test]
fn every_policy_declines_a_round_with_no_moves() {
    // Second is immobilized here, so the round is already over.
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
    let state = GameState::new(board, Player::Second).unwrap();

    for (name, mut policy) in policies(7) {
        assert!(
            policy.choose(&state).is_none(),
            "{name} produced a move for a finished round",
        );
    }
}

#[test]
fn every_policy_repeats_itself_for_the_same_seed() {
    let state = GameState::baseline();

    for seed in [1_u64, 42, 9_999] {
        let first = policies(seed)
            .into_iter()
            .map(|(name, mut policy)| (name, policy.choose(&state)))
            .collect::<Vec<_>>();
        let second = policies(seed)
            .into_iter()
            .map(|(name, mut policy)| (name, policy.choose(&state)))
            .collect::<Vec<_>>();

        assert_eq!(first, second, "policies diverged at seed {seed}");
    }
}

#[test]
fn greedy_takes_the_win_that_is_there() {
    let state = GameState::new(knockout_board(), Player::First).unwrap();
    let expected = winning_move(&state, Player::First).expect("the fixture must offer a win");

    // Seeds cannot matter when a winning move exists.
    for seed in [0_u64, 3, 1_000] {
        assert_eq!(GreedyBot::new(seed).choose(&state), Some(expected));
    }
}

#[test]
fn greedy_declines_a_move_that_hands_over_the_win() {
    let state = GameState::new(knockout_board(), Player::First).unwrap();

    for seed in 0..32_u64 {
        let chosen = GreedyBot::new(seed).choose(&state).unwrap();
        let next = apply_move(&state, chosen).unwrap();
        if matches!(outcome(&next), Outcome::Winner(Player::First, _)) {
            continue;
        }

        assert!(
            winning_move(&next, Player::Second).is_none(),
            "greedy left Second a winning reply at seed {seed}",
        );
    }
}

#[test]
fn minimax_does_not_walk_into_an_immediate_loss() {
    let state = GameState::new(knockout_board(), Player::First).unwrap();

    for seed in 0..32_u64 {
        let chosen = MinimaxBot::new(2, seed).choose(&state).unwrap();
        let next = apply_move(&state, chosen).unwrap();
        if matches!(outcome(&next), Outcome::Winner(Player::First, _)) {
            continue;
        }

        assert!(
            winning_move(&next, Player::Second).is_none(),
            "minimax left Second a winning reply at seed {seed}",
        );
    }
}

#[test]
fn minimax_prefers_the_faster_win() {
    let state = GameState::new(knockout_board(), Player::First).unwrap();
    let expected = winning_move(&state, Player::First).expect("the fixture must offer a win");

    // Depth beyond the win must not talk it out of taking the win now.
    for depth in [1_u8, 2, 3] {
        assert_eq!(
            MinimaxBot::new(depth, 5).choose(&state),
            Some(expected),
            "minimax at depth {depth} passed up an immediate win",
        );
    }
}

#[test]
fn a_faster_finish_outranks_a_slower_one() {
    // The knockout fixture offers only one winning line, so the test above
    // holds whichever way the depth term points. Assert the ordering the
    // search is built on directly: an unspent budget means the round ended
    // sooner, so a win must score higher and a loss must score lower.
    assert!(MinimaxBot::terminal_score(true, 3) > MinimaxBot::terminal_score(true, 1));
    assert!(MinimaxBot::terminal_score(false, 3) < MinimaxBot::terminal_score(false, 1));

    // A win at the slowest possible pace still outranks the fastest loss.
    assert!(MinimaxBot::terminal_score(true, 0) > MinimaxBot::terminal_score(false, u8::MAX));
}

#[test]
fn a_depth_of_zero_still_searches_one_ply() {
    let state = GameState::new(knockout_board(), Player::First).unwrap();
    let expected = winning_move(&state, Player::First).unwrap();

    assert_eq!(MinimaxBot::new(0, 5).choose(&state), Some(expected));
}

#[test]
fn greedy_still_moves_when_every_move_loses() {
    // First must move a piece off its tile, and both destinations let Second
    // push it out; the policy still has to return one of them.
    let board = BoardConfig::new(
        [
            position(1, 1),
            position(1, 2),
            position(2, 1),
            position(2, 2),
        ]
        .into_iter()
        .collect::<BTreeSet<_>>(),
        vec![
            Piece::new(PieceId(0), Player::First, position(1, 1)),
            Piece::new(PieceId(1), Player::Second, position(2, 2)),
        ],
    )
    .unwrap();
    let state = GameState::new(board, Player::First).unwrap();
    let legal = legal_moves(&state);

    let chosen = GreedyBot::new(11).choose(&state).unwrap();

    assert!(legal.contains(&chosen));
}

#[test]
fn a_policy_can_play_a_round_to_its_end() {
    let mut state = GameState::baseline();
    let mut greedy = GreedyBot::new(3);
    let mut random = RandomBot::new(3);
    let mut turns = 0;

    while let Some(chosen) = if state.current_player() == Player::First {
        greedy.choose(&state)
    } else {
        random.choose(&state)
    } {
        assert!(turns < 200, "a round must end");
        state = apply_move(&state, chosen).expect("a policy must return a legal move");
        turns += 1;
    }

    assert!(matches!(outcome(&state), Outcome::Winner(_, _)));
}

#[test]
fn direction_coverage_is_not_assumed() {
    // The fixture's win is a push to the right; assert that rather than
    // trusting the board layout to stay as it is.
    let state = GameState::new(knockout_board(), Player::First).unwrap();
    let expected = winning_move(&state, Player::First).unwrap();

    assert_eq!(expected, Move::new(PieceId(0), Direction::Right));
}

/// Plays one round between two policies and reports the winner.
fn play_round(first: &mut dyn Policy, second: &mut dyn Policy) -> Player {
    let mut state = GameState::baseline();
    for _ in 0..200 {
        let chosen = if state.current_player() == Player::First {
            first.choose(&state)
        } else {
            second.choose(&state)
        };
        let Some(chosen) = chosen else { break };
        state = apply_move(&state, chosen).expect("a policy must return a legal move");
        if let Outcome::Winner(winner, _) = outcome(&state) {
            return winner;
        }
    }

    match outcome(&state) {
        Outcome::Winner(winner, _) => winner,
        Outcome::Ongoing => panic!("a round between policies must end"),
    }
}

#[test]
fn minimax_outplays_greedy_from_both_seats() {
    // The searching half of minimax shows up only in results. A search that
    // minimises where it should maximise still takes a winning move and
    // still avoids an immediate loss, because both are decided by terminal
    // scores; it loses this comparison instead. Measured at 500 games the
    // correct search takes 73% and 79% of the two seats, and the inverted
    // one 37% and 41%, so 60% over 100 games separates them with room.
    let games = 100;
    let mut minimax_first = 0;
    let mut minimax_second = 0;
    for game in 0..games {
        let seed = 42 + game;
        if play_round(&mut MinimaxBot::new(2, seed), &mut GreedyBot::new(seed)) == Player::First {
            minimax_first += 1;
        }
        if play_round(&mut GreedyBot::new(seed), &mut MinimaxBot::new(2, seed)) == Player::Second {
            minimax_second += 1;
        }
    }

    assert!(
        minimax_first * 100 >= games * 60,
        "minimax won only {minimax_first}/{games} as the first player",
    );
    assert!(
        minimax_second * 100 >= games * 60,
        "minimax won only {minimax_second}/{games} as the second player",
    );
}

#[test]
fn greedy_outplays_random_from_both_seats() {
    let games = 100;
    let mut greedy_first = 0;
    let mut greedy_second = 0;
    for game in 0..games {
        let seed = 42 + game;
        if play_round(&mut GreedyBot::new(seed), &mut RandomBot::new(seed)) == Player::First {
            greedy_first += 1;
        }
        if play_round(&mut RandomBot::new(seed), &mut GreedyBot::new(seed)) == Player::Second {
            greedy_second += 1;
        }
    }

    assert!(
        greedy_first * 100 >= games * 70,
        "greedy won only {greedy_first}/{games} as the first player",
    );
    assert!(
        greedy_second * 100 >= games * 70,
        "greedy won only {greedy_second}/{games} as the second player",
    );
}
