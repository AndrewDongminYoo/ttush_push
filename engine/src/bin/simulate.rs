use std::collections::{BTreeMap, HashSet};
use std::env;
use std::fmt;
use std::process;

use engine::bot::{GreedyBot, MinimaxBot, Policy, RandomBot, StrategicBot};
use engine::{
    BoardConfig, Direction, GameState, Move, Outcome, Player, Tile, WinReason, apply_move, outcome,
};

#[path = "simulate/board.rs"]
mod board;

#[derive(Debug)]
struct Options {
    games: u64,
    seed: u64,
    max_turns: u64,
    first: PolicyKind,
    second: PolicyKind,
    trace_game: Option<u64>,
    swap_seeds: bool,
    board: Option<board::SelectedBoard>,
}

/// Which way of playing a side uses. Named rather than boxed in the options
/// so a run's configuration prints back as the flags that produced it.
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
enum PolicyKind {
    Random,
    Greedy,
    Minimax(u8),
    Strategic,
}

impl PolicyKind {
    fn parse(value: &str) -> Result<Self, String> {
        match value {
            "random" => Ok(Self::Random),
            "greedy" => Ok(Self::Greedy),
            "strategic" => Ok(Self::Strategic),
            _ => match value.strip_prefix("minimax") {
                Some("") => Ok(Self::Minimax(2)),
                Some(depth) => depth
                    .strip_prefix(':')
                    .and_then(|depth| depth.parse().ok())
                    .filter(|depth| *depth > 0)
                    .map(Self::Minimax)
                    .ok_or_else(|| format!("invalid minimax depth: {value}")),
                None => Err(format!("unknown policy: {value}\n{}", usage())),
            },
        }
    }

    fn build(self, seed: u64) -> Box<dyn Policy> {
        match self {
            Self::Random => Box::new(RandomBot::new(seed)),
            Self::Greedy => Box::new(GreedyBot::new(seed)),
            Self::Minimax(depth) => Box::new(MinimaxBot::new(depth, seed)),
            Self::Strategic => Box::new(StrategicBot::new(seed)),
        }
    }
}

/// Prints back the flag value that selects this policy.
///
/// The depth is part of the configuration, not decoration: without it a run
/// saved at depth 5 reads the same as one at depth 2, so its output no longer
/// says what produced it. `--first minimax` and `--first minimax:2` are the
/// same run and print the same way, and every form parses back through
/// [`PolicyKind::parse`].
impl fmt::Display for PolicyKind {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::Random => f.write_str("random"),
            Self::Greedy => f.write_str("greedy"),
            Self::Minimax(depth) => write!(f, "minimax:{depth}"),
            Self::Strategic => f.write_str("strategic"),
        }
    }
}

#[derive(Default)]
struct Statistics {
    games: u64,
    first_mover_wins: u64,
    second_mover_wins: u64,
    knockout_wins: u64,
    immobilization_wins: u64,
    repetitions: u64,
    turn_limits: u64,
    total_turns: u64,
    max_observed_turns: u64,
}

impl Statistics {
    fn add(&mut self, other: &Self) {
        self.games += other.games;
        self.first_mover_wins += other.first_mover_wins;
        self.second_mover_wins += other.second_mover_wins;
        self.knockout_wins += other.knockout_wins;
        self.immobilization_wins += other.immobilization_wins;
        self.repetitions += other.repetitions;
        self.turn_limits += other.turn_limits;
        self.total_turns += other.total_turns;
        self.max_observed_turns = self.max_observed_turns.max(other.max_observed_turns);
    }
}

fn opening_key(selected_move: Move) -> (u8, &'static str) {
    (
        selected_move.piece().0,
        direction_name(selected_move.direction()),
    )
}

fn direction_name(direction: Direction) -> &'static str {
    match direction {
        Direction::Up => "up",
        Direction::Down => "down",
        Direction::Left => "left",
        Direction::Right => "right",
    }
}

fn player_name(player: Player) -> &'static str {
    match player {
        Player::First => "first",
        Player::Second => "second",
    }
}

fn main() {
    if let Err(message) = run() {
        eprintln!("{message}");
        process::exit(2);
    }
}

fn run() -> Result<(), String> {
    let options = parse_options(env::args().skip(1))?;
    let simulation = simulate(&options);
    let statistics = &simulation.aggregate;

    println!("games={}", options.games);
    println!("seed={}", options.seed);
    println!("turn_limit={}", options.max_turns);
    println!("first_policy={}", options.first);
    println!("second_policy={}", options.second);
    println!("first_mover_wins={}", statistics.first_mover_wins);
    println!("second_mover_wins={}", statistics.second_mover_wins);
    println!("knockout_wins={}", statistics.knockout_wins);
    println!("immobilization_wins={}", statistics.immobilization_wins);
    println!("repetitions={}", statistics.repetitions);
    println!("turn_limits={}", statistics.turn_limits);
    println!("total_turns={}", statistics.total_turns);
    println!("max_observed_turns={}", statistics.max_observed_turns);
    println!(
        "mean_turns={}",
        mean_turns(statistics.total_turns, options.games)
    );
    print_board_metadata(&options);
    if options.swap_seeds {
        println!("seed_assignment=swapped");
    }
    for (opening, opening_statistics) in simulation.openings {
        print_opening_statistics(opening, &opening_statistics);
    }
    if let Some(trace) = simulation.trace {
        print_trace(&trace);
    }

    Ok(())
}

fn parse_options(arguments: impl IntoIterator<Item = String>) -> Result<Options, String> {
    let mut games = None;
    let mut seed = None;
    let mut max_turns = 10_000;
    let mut first = PolicyKind::Random;
    let mut second = PolicyKind::Random;
    let mut trace_game = None;
    let mut swap_seeds = false;
    let mut board = None;
    let mut arguments = arguments.into_iter();

    while let Some(flag) = arguments.next() {
        if flag == "--swap-seeds" {
            swap_seeds = true;
            continue;
        }
        let value = arguments
            .next()
            .ok_or_else(|| format!("missing value for {flag}\n{}", usage()))?;
        match flag.as_str() {
            "--games" => games = Some(parse_positive(&flag, &value)?),
            "--seed" => {
                seed = Some(
                    value
                        .parse()
                        .map_err(|_| format!("invalid seed: {value}"))?,
                )
            }
            "--max-turns" => max_turns = parse_positive(&flag, &value)?,
            "--first" => first = PolicyKind::parse(&value)?,
            "--second" => second = PolicyKind::parse(&value)?,
            "--trace-game" => {
                trace_game = Some(
                    value
                        .parse()
                        .map_err(|_| format!("invalid trace game index: {value}"))?,
                )
            }
            "--board-file" => board = Some(board::read(&value)?),
            _ => return Err(format!("unknown argument: {flag}\n{}", usage())),
        }
    }

    let games = games.ok_or_else(|| format!("--games is required\n{}", usage()))?;
    if let Some(index) = trace_game
        && index >= games
    {
        return Err(format!("--trace-game must be less than games: {index}"));
    }

    Ok(Options {
        games,
        seed: seed.ok_or_else(|| format!("--seed is required\n{}", usage()))?,
        max_turns,
        first,
        second,
        trace_game,
        swap_seeds,
        board,
    })
}

fn parse_positive(flag: &str, value: &str) -> Result<u64, String> {
    match value.parse() {
        Ok(number) if number > 0 => Ok(number),
        _ => Err(format!("{flag} must be a positive integer: {value}")),
    }
}

fn usage() -> &'static str {
    "usage: simulate --games <positive integer> --seed <u64> \
[--max-turns <positive integer>] [--first <policy>] [--second <policy>] [--trace-game <u64>] [--swap-seeds]\n\
[--board-file <path>]\n\
policies: random | greedy | minimax | minimax:<depth> | strategic"
}

struct SimulationStatistics {
    aggregate: Statistics,
    openings: BTreeMap<(u8, &'static str), Statistics>,
    trace: Option<RoundTrace>,
}

struct RoundTrace {
    game_index: u64,
    first_seed: u64,
    second_seed: u64,
    moves: Vec<(Player, Move)>,
    termination: TraceTermination,
}

enum TraceTermination {
    Winner(Player, WinReason),
    Repetition,
    TurnLimit,
    PolicyNone,
}

fn simulate(options: &Options) -> SimulationStatistics {
    let mut aggregate = Statistics::default();
    let mut openings: BTreeMap<(u8, &'static str), Statistics> = BTreeMap::new();
    let mut selected_trace = None;
    let board = options
        .board
        .as_ref()
        .map(|selected| selected.config.clone())
        .unwrap_or_else(BoardConfig::baseline);

    for game in 0..options.games {
        // Each game gets its own seed, so a policy's choices vary between
        // games while the run as a whole stays reproducible.
        let first_stream_seed = options.seed.wrapping_add(game);
        let second_stream_seed = first_stream_seed.wrapping_mul(0x9e37_79b9);
        let (first_seed, second_seed) = if options.swap_seeds {
            (second_stream_seed, first_stream_seed)
        } else {
            (first_stream_seed, second_stream_seed)
        };
        let mut first = options.first.build(first_seed);
        let mut second = options.second.build(second_seed);
        let mut state = GameState::new(board.clone(), Player::First)
            .expect("the parsed board configuration must create a game state");
        let mut seen_states = HashSet::new();
        let mut turns = 0;
        let mut first_move = None;
        let mut game_statistics = Statistics::default();
        let mut trace = options
            .trace_game
            .filter(|index| *index == game)
            .map(|_| RoundTrace {
                game_index: game,
                first_seed,
                second_seed,
                moves: Vec::new(),
                termination: TraceTermination::PolicyNone,
            });

        loop {
            if let Outcome::Winner(player, reason) = outcome(&state) {
                record_winner(&mut game_statistics, player, reason);
                if let Some(trace) = &mut trace {
                    trace.termination = TraceTermination::Winner(player, reason);
                }
                break;
            }
            if !seen_states.insert(state.clone()) {
                game_statistics.repetitions += 1;
                if let Some(trace) = &mut trace {
                    trace.termination = TraceTermination::Repetition;
                }
                break;
            }
            if turns == options.max_turns {
                game_statistics.turn_limits += 1;
                if let Some(trace) = &mut trace {
                    trace.termination = TraceTermination::TurnLimit;
                }
                break;
            }

            let player = state.current_player();
            let selected_move = if player == Player::First {
                first.choose(&state)
            } else {
                second.choose(&state)
            };
            let Some(selected_move) = selected_move else {
                if let Some(trace) = &mut trace {
                    trace.termination = TraceTermination::PolicyNone;
                }
                break;
            };
            if turns == 0 {
                first_move = Some(opening_key(selected_move));
            }
            if let Some(trace) = &mut trace {
                trace.moves.push((player, selected_move));
            }
            state = apply_move(&state, selected_move).expect("a policy must return a legal move");
            turns += 1;

            if let Outcome::Winner(player, reason) = outcome(&state) {
                record_winner(&mut game_statistics, player, reason);
                if let Some(trace) = &mut trace {
                    trace.termination = TraceTermination::Winner(player, reason);
                }
                break;
            }
        }

        game_statistics.games = 1;
        game_statistics.total_turns = turns;
        game_statistics.max_observed_turns = turns;
        aggregate.add(&game_statistics);
        if let Some(first_move) = first_move {
            openings
                .entry(first_move)
                .or_default()
                .add(&game_statistics);
        }
        if trace.is_some() {
            selected_trace = trace;
        }
    }

    SimulationStatistics {
        aggregate,
        openings,
        trace: selected_trace,
    }
}

fn print_board_metadata(options: &Options) {
    let Some(selected) = &options.board else {
        println!("board=baseline");
        return;
    };

    println!("board={}", selected.id);
    let tiles = selected
        .initial_tiles
        .iter()
        .map(|tile| format!("{},{},{}", tile.x, tile.y, tile_name(tile.kind)))
        .collect::<Vec<_>>()
        .join(";");
    println!("initial_tiles={tiles}");

    let pieces = selected
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
        .join(";");
    println!("initial_pieces={pieces}");
}

fn tile_name(tile: Tile) -> &'static str {
    match tile {
        Tile::Normal => "normal",
        Tile::Damaged => "damaged",
        Tile::Hole => "hole",
    }
}

fn print_opening_statistics(opening: (u8, &'static str), statistics: &Statistics) {
    let prefix = format!("opening.{}.{}", opening.0, opening.1);

    println!("{prefix}.games={}", statistics.games);
    println!("{prefix}.first_mover_wins={}", statistics.first_mover_wins);
    println!(
        "{prefix}.second_mover_wins={}",
        statistics.second_mover_wins
    );
    println!("{prefix}.knockout_wins={}", statistics.knockout_wins);
    println!(
        "{prefix}.immobilization_wins={}",
        statistics.immobilization_wins
    );
    println!("{prefix}.repetitions={}", statistics.repetitions);
    println!("{prefix}.turn_limits={}", statistics.turn_limits);
    println!("{prefix}.total_turns={}", statistics.total_turns);
    println!(
        "{prefix}.max_observed_turns={}",
        statistics.max_observed_turns
    );
}

fn print_trace(trace: &RoundTrace) {
    println!("trace.game_index={}", trace.game_index);
    println!("trace.first_seed={}", trace.first_seed);
    println!("trace.second_seed={}", trace.second_seed);
    for (index, (player, selected_move)) in trace.moves.iter().enumerate() {
        let number = index + 1;
        println!("trace.move.{number}.player={}", player_name(*player));
        println!("trace.move.{number}.piece={}", selected_move.piece().0);
        println!(
            "trace.move.{number}.direction={}",
            direction_name(selected_move.direction())
        );
    }
    println!("trace.turns={}", trace.moves.len());
    match trace.termination {
        TraceTermination::Winner(player, WinReason::Knockout) => {
            println!("trace.termination=knockout");
            println!("trace.winner={}", player_name(player));
        }
        TraceTermination::Winner(player, WinReason::Immobilization) => {
            println!("trace.termination=immobilization");
            println!("trace.winner={}", player_name(player));
        }
        TraceTermination::Repetition => {
            println!("trace.termination=repetition");
            println!("trace.winner=none");
        }
        TraceTermination::TurnLimit => {
            println!("trace.termination=turn_limit");
            println!("trace.winner=none");
        }
        TraceTermination::PolicyNone => {
            println!("trace.termination=policy_none");
            println!("trace.winner=none");
        }
    }
}

fn record_winner(statistics: &mut Statistics, player: Player, reason: WinReason) {
    match player {
        Player::First => statistics.first_mover_wins += 1,
        Player::Second => statistics.second_mover_wins += 1,
    }
    match reason {
        WinReason::Knockout => statistics.knockout_wins += 1,
        WinReason::Immobilization => statistics.immobilization_wins += 1,
    }
}

fn mean_turns(total_turns: u64, games: u64) -> String {
    let scaled = total_turns * 1000 / games;

    format!("{}.{:03}", scaled / 1000, scaled % 1000)
}
