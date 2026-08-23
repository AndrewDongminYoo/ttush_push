use std::process::Command;

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
