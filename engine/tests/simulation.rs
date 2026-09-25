use std::process::Command;

use engine::bot::{Policy, RandomBot, StrategicBot};
use engine::{GameState, Move};

fn run_simulation() -> String {
    simulate(&["--games", "100", "--seed", "42", "--max-turns", "500"])
}

fn simulate(args: &[&str]) -> String {
    let output = Command::new(env!("CARGO_BIN_EXE_simulate"))
        .args(args)
        .output()
        .expect("simulation process starts");

    assert!(
        output.status.success(),
        "simulation failed: {}",
        String::from_utf8_lossy(&output.stderr),
    );

    String::from_utf8(output.stdout).expect("simulation output is UTF-8")
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
