use std::fs;
use std::process::{Command, Output};
use std::sync::atomic::{AtomicUsize, Ordering};

use engine::{Direction, GameState, Move, PieceId, apply_move, legal_moves};

const DUEL: &str =
    "ttush-board-v1 duel\ncell 0 0\ncell 1 0\npiece 0 first 0 0\npiece 1 second 1 0\n";
const BASELINE: &str =
    include_str!("../../docs/notes/2026-09-26-board-comparison-control/boards/baseline.board");

fn run(board: &str, moves: &str, depth: &str, nodes: &str, extra: &[&str]) -> Output {
    static NEXT: AtomicUsize = AtomicUsize::new(0);
    let directory = std::env::temp_dir().join(format!(
        "ttush-analysis-{}-{}",
        std::process::id(),
        NEXT.fetch_add(1, Ordering::Relaxed)
    ));
    fs::create_dir(&directory).unwrap();
    let board_file = directory.join("input.board");
    let moves_file = directory.join("input.moves");
    fs::write(&board_file, board).unwrap();
    fs::write(&moves_file, moves).unwrap();
    let result = Command::new(env!("CARGO_BIN_EXE_analyze"))
        .args([
            "--board-file",
            board_file.to_str().unwrap(),
            "--moves-file",
            moves_file.to_str().unwrap(),
            "--depth",
            depth,
            "--nodes",
            nodes,
        ])
        .args(extra)
        .output()
        .unwrap();
    fs::remove_dir_all(directory).unwrap();
    result
}

fn report(output: &Output) -> String {
    assert!(
        output.status.success(),
        "{}",
        String::from_utf8_lossy(&output.stderr)
    );
    assert!(output.stderr.is_empty());
    String::from_utf8(output.stdout.clone()).unwrap()
}

fn value<'a>(report: &'a str, key: &str) -> &'a str {
    report
        .lines()
        .find_map(|line| line.strip_prefix(&format!("{key}=")))
        .unwrap()
}

#[test]
fn reports_a_forced_knockout_and_every_root_alternative() {
    let output = report(&run(DUEL, "ttush-moves-v1\n", "1", "1", &[]));
    assert_eq!(value(&output, "board"), "duel");
    assert_eq!(value(&output, "result"), "first");
    assert_eq!(value(&output, "alternatives"), "1");
    assert_eq!(value(&output, "reply.0.move"), "0,right");
    assert_eq!(value(&output, "reply.0.result"), "first");
    assert_eq!(value(&output, "reply.0.nodes"), "1");
}

#[test]
fn replays_the_path_before_enumerating_replies_and_repeats_exactly() {
    let moves = "ttush-moves-v1\nmove first 0 down\n";
    let output = report(&run(BASELINE, moves, "1", "100", &[]));
    assert_eq!(value(&output, "path_length"), "1");
    assert_eq!(value(&output, "player"), "second");
    assert_eq!(value(&output, "result"), "unknown");
    let state = apply_move(
        &GameState::baseline(),
        Move::new(PieceId(0), Direction::Down),
    )
    .unwrap();
    let actual = legal_moves(&state);
    assert_eq!(
        value(&output, "alternatives").parse::<usize>().unwrap(),
        actual.len()
    );
    for (index, candidate) in actual.iter().enumerate() {
        let direction = match candidate.direction() {
            Direction::Up => "up",
            Direction::Down => "down",
            Direction::Left => "left",
            Direction::Right => "right",
        };
        assert_eq!(
            value(&output, &format!("reply.{index}.move")),
            format!("{},{direction}", candidate.piece().0)
        );
        assert_eq!(value(&output, &format!("reply.{index}.result")), "unknown");
        assert_eq!(value(&output, &format!("reply.{index}.depth_cutoffs")), "1");
    }
    assert_eq!(output, report(&run(BASELINE, moves, "1", "100", &[])));
}

#[test]
fn exhausted_node_budget_cannot_be_reported_as_a_loss() {
    let output = report(&run(BASELINE, "ttush-moves-v1\n", "8", "1", &[]));
    assert_eq!(value(&output, "result"), "unknown");
    let count: usize = value(&output, "alternatives").parse().unwrap();
    assert!(count > 1);
    for index in 0..count {
        assert_eq!(value(&output, &format!("reply.{index}.result")), "unknown");
        assert_eq!(value(&output, &format!("reply.{index}.nodes")), "1");
        assert!(
            value(&output, &format!("reply.{index}.node_cutoffs"))
                .parse::<usize>()
                .unwrap()
                > 0
        );
    }
}

#[test]
fn terminal_path_reports_winner_without_fabricating_replies() {
    let output = report(&run(
        DUEL,
        "ttush-moves-v1\nmove first 0 right\n",
        "8",
        "100",
        &[],
    ));
    assert_eq!(value(&output, "result"), "first");
    assert_eq!(value(&output, "alternatives"), "0");
    assert_eq!(value(&output, "terminal"), "first,knockout");
}

#[test]
fn rejects_malformed_illegal_and_post_terminal_paths_before_reporting() {
    for (moves, message) in [
        ("ttush-moves-v2\n", "version"),
        ("ttush-moves-v1\nmove second 0 right\n", "actor"),
        ("ttush-moves-v1\nmove first 0 left\n", "illegal"),
        (
            "ttush-moves-v1\nmove first 0 right\nmove second 1 left\n",
            "terminal",
        ),
        ("ttush-moves-v1\nmove first 256 right\n", "piece"),
        ("ttush-moves-v1\nmove first 0 diagonal\n", "direction"),
        ("ttush-moves-v1\nmove first 0 right extra\n", "row"),
        ("ttush-moves-v1\n\n", "row"),
    ] {
        let output = run(DUEL, moves, "8", "100", &[]);
        assert_eq!(output.status.code(), Some(2), "{moves}");
        assert!(output.stdout.is_empty());
        assert!(
            String::from_utf8_lossy(&output.stderr).contains(message),
            "{}",
            String::from_utf8_lossy(&output.stderr)
        );
    }
}

#[test]
fn rejects_invalid_limits_duplicate_flags_and_invalid_boards() {
    for (depth, nodes, extra, board) in [
        ("0", "100", vec![], DUEL),
        ("33", "100", vec![], DUEL),
        ("8", "0", vec![], DUEL),
        ("8", "1000001", vec![], DUEL),
        ("8", "100", vec!["--depth", "2"], DUEL),
        ("8", "100", vec!["--unknown", "2"], DUEL),
        ("8", "100", vec![], "ttush-board-v9 duel\n"),
    ] {
        let output = run(board, "ttush-moves-v1\n", depth, nodes, &extra);
        assert_eq!(output.status.code(), Some(2));
        assert!(output.stdout.is_empty());
        assert!(!output.stderr.is_empty());
    }
    let output = Command::new(env!("CARGO_BIN_EXE_analyze"))
        .output()
        .unwrap();
    assert_eq!(output.status.code(), Some(2));
    assert!(output.stdout.is_empty());
}
