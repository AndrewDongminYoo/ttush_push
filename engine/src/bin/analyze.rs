use std::collections::BTreeMap;
use std::{env, fs, process};

use engine::{
    Direction, GameState, Move, Outcome, PieceId, Player, Tile, WinReason, apply_move, outcome,
};

#[path = "simulate/board.rs"]
mod board;
#[path = "analyze/search.rs"]
mod search;

fn main() {
    if let Err(error) = run() {
        eprintln!("{error}");
        process::exit(2);
    }
}

fn run() -> Result<(), String> {
    let options = options(env::args().skip(1))?;
    let board = board::read(&options["--board-file"])?;
    let depth = limit(&options["--depth"], "depth", 32)? as u8;
    let nodes = limit(&options["--nodes"], "nodes", 1_000_000)?;
    let moves = fs::read_to_string(&options["--moves-file"])
        .map_err(|error| format!("cannot read moves file: {error}"))?;
    let start = GameState::new(board.config.clone(), Player::First)
        .map_err(|error| format!("invalid initial state: {error:?}"))?;
    let (state, path) = replay(start, &moves)?;
    let analysis = search::analyze(&state, depth, nodes);

    println!("analysis=ttush-position-v1");
    println!("board={}", board.id);
    println!(
        "initial_tiles={}",
        board
            .initial_tiles
            .iter()
            .map(|tile| {
                let kind = match tile.kind {
                    Tile::Normal => "normal",
                    Tile::Damaged => "damaged",
                    Tile::Hole => "hole",
                };
                format!("{},{},{kind}", tile.x, tile.y)
            })
            .collect::<Vec<_>>()
            .join(";")
    );
    println!(
        "initial_pieces={}",
        board
            .initial_pieces
            .iter()
            .map(|piece| {
                format!(
                    "{},{},{},{}",
                    piece.id,
                    player_name(piece.owner),
                    piece.x,
                    piece.y
                )
            })
            .collect::<Vec<_>>()
            .join(";")
    );
    println!("path_length={}", path.len());
    for (index, (actor, selected)) in path.iter().enumerate() {
        println!(
            "path.{}={},{},{}",
            index + 1,
            player_name(*actor),
            selected.piece().0,
            direction_name(selected.direction())
        );
    }
    println!("player={}", player_name(state.current_player()));
    match outcome(&state) {
        Outcome::Ongoing => println!("terminal=none"),
        Outcome::Winner(winner, reason) => {
            let reason = match reason {
                WinReason::Knockout => "knockout",
                WinReason::Immobilization => "immobilization",
            };
            println!("terminal={},{reason}", player_name(winner));
        }
    }
    println!("depth={depth}");
    println!("nodes_per_alternative={nodes}");
    println!("result={}", result_name(analysis.winner));
    println!("alternatives={}", analysis.alternatives.len());
    for (index, alternative) in analysis.alternatives.iter().enumerate() {
        println!(
            "reply.{index}.move={},{}",
            alternative.selected_move.piece().0,
            direction_name(alternative.selected_move.direction())
        );
        println!("reply.{index}.result={}", result_name(alternative.winner));
        println!("reply.{index}.nodes={}", alternative.nodes);
        println!("reply.{index}.depth_cutoffs={}", alternative.depth_cutoffs);
        println!("reply.{index}.node_cutoffs={}", alternative.node_cutoffs);
    }
    Ok(())
}

fn options(args: impl Iterator<Item = String>) -> Result<BTreeMap<String, String>, String> {
    let mut args = args;
    let mut values = BTreeMap::new();
    let required = ["--board-file", "--moves-file", "--depth", "--nodes"];
    while let Some(key) = args.next() {
        if !required.contains(&key.as_str()) {
            return Err(format!("unknown option: {key}"));
        }
        let value = args
            .next()
            .ok_or_else(|| format!("missing value for {key}"))?;
        if values.insert(key.clone(), value).is_some() {
            return Err(format!("duplicate option: {key}"));
        }
    }
    for key in required {
        if !values.contains_key(key) {
            return Err(format!("required option: {key}"));
        }
    }
    Ok(values)
}

fn limit(value: &str, name: &str, maximum: usize) -> Result<usize, String> {
    value
        .parse::<usize>()
        .ok()
        .filter(|n| (1..=maximum).contains(n))
        .ok_or_else(|| format!("invalid {name}: expected 1..={maximum}"))
}

fn replay(mut state: GameState, input: &str) -> Result<(GameState, Vec<(Player, Move)>), String> {
    let mut lines = input.lines();
    if lines.next() != Some("ttush-moves-v1") {
        return Err("invalid moves file version".to_owned());
    }
    let mut path = Vec::new();
    for (index, line) in lines.enumerate() {
        let row = index + 2;
        let fields = line.split_whitespace().collect::<Vec<_>>();
        if fields.len() != 4 || fields[0] != "move" {
            return Err(format!("invalid move row {row}"));
        }
        if outcome(&state) != Outcome::Ongoing {
            return Err(format!("move after terminal at row {row}"));
        }
        let actor = match fields[1] {
            "first" => Player::First,
            "second" => Player::Second,
            _ => return Err(format!("invalid actor at row {row}")),
        };
        if actor != state.current_player() {
            return Err(format!("wrong actor at row {row}"));
        }
        let piece = fields[2]
            .parse::<u8>()
            .map_err(|_| format!("invalid piece at row {row}"))?;
        let direction = match fields[3] {
            "up" => Direction::Up,
            "down" => Direction::Down,
            "left" => Direction::Left,
            "right" => Direction::Right,
            _ => return Err(format!("invalid direction at row {row}")),
        };
        let selected = Move::new(PieceId(piece), direction);
        state = apply_move(&state, selected)
            .map_err(|error| format!("illegal move at row {row}: {error:?}"))?;
        path.push((actor, selected));
    }
    Ok((state, path))
}

fn result_name(winner: Option<Player>) -> &'static str {
    winner.map(player_name).unwrap_or("unknown")
}

fn player_name(player: Player) -> &'static str {
    match player {
        Player::First => "first",
        Player::Second => "second",
    }
}

fn direction_name(direction: Direction) -> &'static str {
    match direction {
        Direction::Up => "up",
        Direction::Down => "down",
        Direction::Left => "left",
        Direction::Right => "right",
    }
}
