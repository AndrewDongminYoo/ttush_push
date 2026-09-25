use std::process::{Command, Output};

use engine::bot::{Policy, RandomBot, StrategicBot};
use engine::{
    Direction, GameState, Move, Outcome, PieceId, Player, WinReason, apply_move, outcome,
};

fn run_simulation() -> String {
    simulate(&["--games", "100", "--seed", "42", "--max-turns", "500"])
}

fn simulate(args: &[&str]) -> String {
    let output = run_simulation_command(args);

    assert!(
        output.status.success(),
        "simulation failed: {}",
        String::from_utf8_lossy(&output.stderr),
    );

    String::from_utf8(output.stdout).expect("simulation output is UTF-8")
}

fn run_simulation_command(args: &[&str]) -> Output {
    Command::new(env!("CARGO_BIN_EXE_simulate"))
        .args(args)
        .output()
        .expect("simulation process starts")
}

fn value(output: &str, key: &str) -> u64 {
    output
        .lines()
        .find_map(|line| line.strip_prefix(&format!("{key}=")))
        .unwrap_or_else(|| panic!("missing {key} in:\n{output}"))
        .parse()
        .unwrap_or_else(|_| panic!("{key} is not an unsigned integer in:\n{output}"))
}

fn opening_key(opening: Move) -> String {
    format!(
        "opening.{}.{}",
        opening.piece().0,
        direction_name(opening.direction())
    )
}

fn direction_name(direction: engine::Direction) -> &'static str {
    match direction {
        engine::Direction::Up => "up",
        engine::Direction::Down => "down",
        engine::Direction::Left => "left",
        engine::Direction::Right => "right",
    }
}

fn opening_prefixes(output: &str) -> Vec<&str> {
    output
        .lines()
        .filter_map(|line| line.split_once('=').map(|(key, _)| key))
        .filter_map(|key| key.strip_prefix("opening."))
        .filter_map(|key| key.strip_suffix(".games"))
        .collect()
}

fn opening_total(output: &str, stat: &str) -> u64 {
    opening_prefixes(output)
        .into_iter()
        .map(|prefix| value(output, &format!("opening.{prefix}.{stat}")))
        .sum()
}

fn trace_value<'a>(output: &'a str, key: &str) -> &'a str {
    output
        .lines()
        .find_map(|line| line.strip_prefix(&format!("{key}=")))
        .unwrap_or_else(|| panic!("missing {key} in:\n{output}"))
}

fn trace_direction(value: &str) -> Direction {
    match value {
        "up" => Direction::Up,
        "down" => Direction::Down,
        "left" => Direction::Left,
        "right" => Direction::Right,
        _ => panic!("unknown trace direction: {value}"),
    }
}

fn trace_player(value: &str) -> Player {
    match value {
        "first" => Player::First,
        "second" => Player::Second,
        _ => panic!("unknown trace player: {value}"),
    }
}

fn trace_move(output: &str, number: u64) -> (Player, Move) {
    let player = trace_player(trace_value(output, &format!("trace.move.{number}.player")));
    let piece = trace_value(output, &format!("trace.move.{number}.piece"))
        .parse()
        .expect("trace piece is numeric");
    let direction = trace_direction(trace_value(
        output,
        &format!("trace.move.{number}.direction"),
    ));

    (player, Move::new(PieceId(piece), direction))
}

fn trace_key_count(output: &str, key: &str) -> usize {
    output
        .lines()
        .filter(|line| line.split_once('=').is_some_and(|(found, _)| found == key))
        .count()
}

fn trace_move_line_count(output: &str) -> usize {
    output
        .lines()
        .filter(|line| line.starts_with("trace.move."))
        .count()
}

#[test]
fn fixed_seed_produces_identical_complete_statistics() {
    let first = run_simulation();
    let second = run_simulation();

    assert_eq!(first, second);
    assert!(first.contains("games=100"));
    assert!(first.contains("seed=42"));
    assert!(first.contains("first_mover_wins="));
    assert!(first.contains("second_mover_wins="));
    assert!(first.contains("knockout_wins="));
    assert!(first.contains("immobilization_wins="));
    assert!(first.contains("repetitions="));
}

#[test]
fn a_saved_run_names_the_search_depth_that_produced_it() {
    // Two runs that differ only in depth must not read the same afterwards,
    // or the saved output no longer says what to replay.
    let deep = simulate(&["--games", "4", "--seed", "1", "--first", "minimax:5"]);
    let shallow = simulate(&["--games", "4", "--seed", "1", "--first", "minimax:2"]);

    assert!(deep.contains("first_policy=minimax:5"), "{deep}");
    assert!(shallow.contains("first_policy=minimax:2"), "{shallow}");

    // The default depth prints as the depth it actually is, so every label
    // parses back into the flag that produces the same run.
    let default = simulate(&["--games", "4", "--seed", "1", "--first", "minimax"]);
    assert!(default.contains("first_policy=minimax:2"), "{default}");

    // The policies without a depth keep printing as their own flag value.
    let plain = simulate(&[
        "--games", "4", "--seed", "1", "--first", "random", "--second", "greedy",
    ]);
    assert!(plain.contains("first_policy=random"), "{plain}");
    assert!(plain.contains("second_policy=greedy"), "{plain}");
}

#[test]
fn strategic_first_move_is_reported_from_the_real_strategic_policy() {
    // Changing PolicyKind::Strategic to Random must fail this test: it compares
    // the CLI's observed opening to the move the real StrategicBot selects.
    let seed = 7;
    let expected = StrategicBot::new(seed)
        .choose(&GameState::baseline())
        .expect("the baseline board gives Strategic a legal first move");
    let random = RandomBot::new(seed)
        .choose(&GameState::baseline())
        .expect("the baseline board gives Random a legal first move");
    assert_ne!(expected, random, "the seed must distinguish the policies");
    let output = simulate(&[
        "--games",
        "1",
        "--seed",
        "7",
        "--max-turns",
        "1",
        "--first",
        "strategic",
        "--second",
        "random",
    ]);

    assert!(output.contains("board=baseline"), "{output}");
    assert_eq!(value(&output, "turn_limits"), 1, "{output}");
    assert_eq!(
        value(&output, &format!("{}.games", opening_key(expected))),
        1,
        "{output}"
    );
}

#[test]
fn strategic_second_seat_and_self_play_produce_complete_repeatable_opening_reports() {
    // At seed 19, Strategic knocks out First in 10 turns; Random instead
    // reaches immobilization at turn 40. A policy label alone cannot prove
    // that the second seat actually dispatches to Strategic.
    let second_seat = simulate(&[
        "--games",
        "1",
        "--seed",
        "19",
        "--max-turns",
        "100",
        "--first",
        "random",
        "--second",
        "strategic",
    ]);
    let random_second = simulate(&[
        "--games",
        "1",
        "--seed",
        "19",
        "--max-turns",
        "100",
        "--first",
        "random",
        "--second",
        "random",
    ]);
    assert_eq!(value(&second_seat, "total_turns"), 10, "{second_seat}");
    assert_eq!(value(&second_seat, "knockout_wins"), 1, "{second_seat}");
    assert_eq!(value(&second_seat, "second_mover_wins"), 1, "{second_seat}");
    assert_eq!(value(&second_seat, "turn_limits"), 0, "{second_seat}");
    assert_ne!(
        value(&second_seat, "total_turns"),
        value(&random_second, "total_turns"),
        "the fixture must distinguish Strategic from Random"
    );
    let self_play = simulate(&[
        "--games",
        "1",
        "--seed",
        "19",
        "--max-turns",
        "2",
        "--first",
        "strategic",
        "--second",
        "strategic",
    ]);

    assert!(
        second_seat.contains("second_policy=strategic"),
        "{second_seat}"
    );
    assert!(self_play.contains("first_policy=strategic"), "{self_play}");
    assert!(self_play.contains("second_policy=strategic"), "{self_play}");
    assert_eq!(
        self_play,
        simulate(&[
            "--games",
            "1",
            "--seed",
            "19",
            "--max-turns",
            "2",
            "--first",
            "strategic",
            "--second",
            "strategic",
        ])
    );

    for output in [&second_seat, &self_play] {
        let prefixes = opening_prefixes(output);
        assert!(!prefixes.is_empty(), "{output}");
        assert!(
            prefixes.windows(2).all(|pair| pair[0] < pair[1]),
            "{output}"
        );
        for prefix in prefixes {
            for stat in [
                "games",
                "first_mover_wins",
                "second_mover_wins",
                "knockout_wins",
                "immobilization_wins",
                "repetitions",
                "turn_limits",
                "total_turns",
                "max_observed_turns",
            ] {
                assert!(
                    output.contains(&format!("opening.{prefix}.{stat}=")),
                    "{output}"
                );
            }
        }
        for stat in [
            "games",
            "first_mover_wins",
            "second_mover_wins",
            "knockout_wins",
            "immobilization_wins",
            "repetitions",
            "turn_limits",
            "total_turns",
        ] {
            assert_eq!(
                opening_total(output, stat),
                value(output, stat),
                "{stat}:\n{output}"
            );
        }
        assert!(opening_prefixes(output).into_iter().all(|prefix| {
            value(output, &format!("opening.{prefix}.max_observed_turns"))
                <= value(output, "max_observed_turns")
        }));
    }
}

#[test]
fn completed_runs_assign_wins_and_reasons_to_their_opening_rows() {
    // Dropping a completed outcome after its opening has been selected makes
    // the row lose the win and reason that the aggregate still records.
    let output = simulate(&["--games", "20", "--seed", "42", "--max-turns", "500"]);

    assert!(
        value(&output, "first_mover_wins") + value(&output, "second_mover_wins") > 0,
        "{output}"
    );
    assert!(
        value(&output, "knockout_wins") + value(&output, "immobilization_wins") > 0,
        "{output}"
    );
    let prefixes = opening_prefixes(&output);
    assert!(prefixes.len() > 1, "{output}");
    assert!(
        prefixes.windows(2).all(|pair| pair[0] < pair[1]),
        "{output}"
    );
    for prefix in std::iter::once(String::new())
        .chain(prefixes.iter().map(|prefix| format!("opening.{prefix}.")))
    {
        let count = |stat| value(&output, &format!("{prefix}{stat}"));
        let wins = count("first_mover_wins") + count("second_mover_wins");
        assert_eq!(
            wins + count("repetitions") + count("turn_limits"),
            count("games")
        );
        assert_eq!(count("knockout_wins") + count("immobilization_wins"), wins);
    }
    for stat in [
        "games",
        "first_mover_wins",
        "second_mover_wins",
        "knockout_wins",
        "immobilization_wins",
        "repetitions",
        "turn_limits",
        "total_turns",
    ] {
        assert_eq!(
            opening_total(&output, stat),
            value(&output, stat),
            "{stat}:\n{output}"
        );
    }
    assert_eq!(
        prefixes
            .iter()
            .map(|prefix| value(&output, &format!("opening.{prefix}.max_observed_turns")))
            .max(),
        Some(value(&output, "max_observed_turns")),
        "{output}"
    );
}

#[test]
fn capped_runs_attribute_every_turn_to_the_opening_that_started_it() {
    // Omitting capped results from their opening bucket makes these totals
    // disagree even though the aggregate statistics still look plausible.
    let output = simulate(&[
        "--games",
        "4",
        "--seed",
        "42",
        "--max-turns",
        "1",
        "--first",
        "strategic",
        "--second",
        "strategic",
    ]);

    assert_eq!(value(&output, "games"), 4, "{output}");
    assert_eq!(value(&output, "turn_limits"), 4, "{output}");
    assert_eq!(value(&output, "total_turns"), 4, "{output}");
    assert_eq!(value(&output, "max_observed_turns"), 1, "{output}");
    assert_eq!(opening_total(&output, "games"), 4, "{output}");
    assert_eq!(opening_total(&output, "turn_limits"), 4, "{output}");
    assert_eq!(opening_total(&output, "total_turns"), 4, "{output}");
}

#[test]
fn trace_replays_the_selected_strategic_terminal_round_and_wins_at_its_cap() {
    // Removing selected-round capture or recording the wrong actor makes this
    // replay diverge from the same engine that accepts the moves.
    let output = simulate(&[
        "--games",
        "1",
        "--seed",
        "19",
        "--max-turns",
        "10",
        "--first",
        "random",
        "--second",
        "strategic",
        "--trace-game",
        "0",
    ]);

    assert_eq!(trace_value(&output, "trace.game_index"), "0");
    assert_eq!(trace_value(&output, "trace.first_seed"), "19");
    let expected_second_seed = 19_u64.wrapping_mul(0x9e37_79b9).to_string();
    assert_eq!(
        trace_value(&output, "trace.second_seed"),
        expected_second_seed
    );
    assert_eq!(trace_value(&output, "trace.turns"), "10");
    assert_eq!(trace_value(&output, "trace.termination"), "knockout");
    assert_eq!(trace_value(&output, "trace.winner"), "second");
    for key in [
        "trace.game_index",
        "trace.first_seed",
        "trace.second_seed",
        "trace.turns",
        "trace.termination",
        "trace.winner",
    ] {
        assert_eq!(trace_key_count(&output, key), 1, "{output}");
    }

    let mut state = GameState::baseline();
    for number in 1..=10 {
        let (player, selected_move) = trace_move(&output, number);

        assert_eq!(player, state.current_player(), "move {number}:\n{output}");
        for field in ["player", "piece", "direction"] {
            assert_eq!(
                trace_key_count(&output, &format!("trace.move.{number}.{field}")),
                1,
                "{output}"
            );
        }
        state =
            apply_move(&state, selected_move).expect("the traced move replays through the engine");
    }
    let turns = trace_value(&output, "trace.turns")
        .parse::<usize>()
        .expect("trace turns is numeric");
    assert_eq!(trace_move_line_count(&output), 3 * turns, "{output}");
    assert_eq!(
        trace_key_count(&output, "trace.move.11.player"),
        0,
        "{output}"
    );

    assert_eq!(
        outcome(&state),
        Outcome::Winner(Player::Second, WinReason::Knockout)
    );
}

#[test]
fn trace_uses_the_selected_nonzero_round_with_wrapping_seeds_and_is_repeatable() {
    // Reusing the base seed, retaining a prior round's moves, or constructing
    // the second policy with a non-wrapping seed would fail these comparisons.
    for (base_seed, expected_first_seed) in [(u64::MAX, 0), (u64::MAX - 1, u64::MAX)] {
        let seed = base_seed.to_string();
        let args = [
            "--games",
            "2",
            "--seed",
            &seed,
            "--max-turns",
            "2",
            "--first",
            "random",
            "--second",
            "random",
            "--trace-game",
            "1",
        ];
        let first = simulate(&args);
        let second = simulate(&args);
        let second_seed = expected_first_seed.wrapping_mul(0x9e37_79b9);

        assert_eq!(first, second);
        assert_eq!(trace_value(&first, "trace.game_index"), "1");
        assert_eq!(
            trace_value(&first, "trace.first_seed"),
            expected_first_seed.to_string()
        );
        assert_eq!(
            trace_value(&first, "trace.second_seed"),
            second_seed.to_string()
        );
        assert_eq!(trace_value(&first, "trace.turns"), "2");
        assert_eq!(trace_value(&first, "trace.termination"), "turn_limit");
        assert_eq!(trace_value(&first, "trace.winner"), "none");

        let mut state = GameState::baseline();
        let mut first_policy = RandomBot::new(expected_first_seed);
        let mut second_policy = RandomBot::new(second_seed);
        for number in 1..=2 {
            let expected_player = state.current_player();
            let expected_move = if expected_player == Player::First {
                first_policy.choose(&state)
            } else {
                second_policy.choose(&state)
            }
            .expect("the baseline state has a random move");
            assert_eq!(
                trace_move(&first, number),
                (expected_player, expected_move),
                "move {number}:\n{first}"
            );
            for field in ["player", "piece", "direction"] {
                assert_eq!(
                    trace_key_count(&first, &format!("trace.move.{number}.{field}")),
                    1,
                    "{first}"
                );
            }
            state = apply_move(&state, expected_move).expect("random move replays");
        }
        let turns = trace_value(&first, "trace.turns")
            .parse::<usize>()
            .expect("trace turns is numeric");
        assert_eq!(trace_move_line_count(&first), 3 * turns, "{first}");
        assert_eq!(trace_key_count(&first, "trace.move.3.player"), 0, "{first}");
    }
}

#[test]
fn trace_keeps_statistics_unchanged_and_preserves_a_shorter_cap() {
    // Emitting a trace must append to, rather than alter, the aggregate and
    // opening report, while a shorter cap remains a censored result.
    let base_args = [
        "--games",
        "1",
        "--seed",
        "19",
        "--max-turns",
        "9",
        "--first",
        "random",
        "--second",
        "strategic",
    ];
    let untraced = simulate(&base_args);
    let traced = simulate(&[
        "--games",
        "1",
        "--seed",
        "19",
        "--max-turns",
        "9",
        "--first",
        "random",
        "--second",
        "strategic",
        "--trace-game",
        "0",
    ]);

    assert_eq!(
        traced
            .split_once("trace.game_index=")
            .expect("trace is appended after the existing report")
            .0,
        untraced
    );
    assert_eq!(value(&traced, "total_turns"), 9, "{traced}");
    assert_eq!(value(&traced, "turn_limits"), 1, "{traced}");
    assert_eq!(trace_value(&traced, "trace.termination"), "turn_limit");
    assert_eq!(trace_value(&traced, "trace.winner"), "none");
}

#[test]
fn trace_option_rejects_missing_malformed_negative_and_out_of_range_indices() {
    // Relaxing validation lets a malformed index reach simulation or selects
    // a nonexistent round instead of returning the CLI's error exit code.
    let cases = [
        (
            ["--games", "1", "--seed", "1", "--trace-game"].as_slice(),
            "missing value for --trace-game",
        ),
        (
            ["--games", "1", "--seed", "1", "--trace-game", "nope"].as_slice(),
            "invalid trace game index: nope",
        ),
        (
            ["--games", "1", "--seed", "1", "--trace-game", "-1"].as_slice(),
            "invalid trace game index: -1",
        ),
        (
            ["--trace-game", "2", "--games", "2", "--seed", "1"].as_slice(),
            "--trace-game must be less than games: 2",
        ),
    ];

    for (args, diagnostic) in cases {
        let output = run_simulation_command(args);
        assert_eq!(output.status.code(), Some(2));
        assert!(
            String::from_utf8_lossy(&output.stderr).contains(diagnostic),
            "{}",
            String::from_utf8_lossy(&output.stderr)
        );
    }
}
