use std::process::Command;

fn run_simulation() -> String {
    let output = Command::new(env!("CARGO_BIN_EXE_simulate"))
        .args(["--games", "100", "--seed", "42", "--max-turns", "500"])
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
