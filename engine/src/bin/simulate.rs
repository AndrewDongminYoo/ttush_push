use std::collections::HashSet;
use std::env;
use std::fmt;
use std::process;

use engine::bot::{GreedyBot, MinimaxBot, Policy, RandomBot};
use engine::{GameState, Outcome, Player, WinReason, apply_move, outcome};

#[derive(Debug)]
struct Options {
    games: u64,
    seed: u64,
    max_turns: u64,
    first: PolicyKind,
    second: PolicyKind,
}

/// Which way of playing a side uses. Named rather than boxed in the options
/// so a run's configuration prints back as the flags that produced it.
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
enum PolicyKind {
    Random,
    Greedy,
    Minimax(u8),
}

impl PolicyKind {
    fn parse(value: &str) -> Result<Self, String> {
        match value {
            "random" => Ok(Self::Random),
            "greedy" => Ok(Self::Greedy),
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
        }
    }
}

#[derive(Default)]
struct Statistics {
    first_mover_wins: u64,
    second_mover_wins: u64,
    knockout_wins: u64,
    immobilization_wins: u64,
    repetitions: u64,
    turn_limits: u64,
    total_turns: u64,
    max_observed_turns: u64,
}

fn main() {
    if let Err(message) = run() {
        eprintln!("{message}");
        process::exit(2);
    }
}

fn run() -> Result<(), String> {
    let options = parse_options(env::args().skip(1))?;
    let statistics = simulate(&options);

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

    Ok(())
}

fn parse_options(arguments: impl IntoIterator<Item = String>) -> Result<Options, String> {
    let mut games = None;
    let mut seed = None;
    let mut max_turns = 10_000;
    let mut first = PolicyKind::Random;
    let mut second = PolicyKind::Random;
    let mut arguments = arguments.into_iter();

    while let Some(flag) = arguments.next() {
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
            _ => return Err(format!("unknown argument: {flag}\n{}", usage())),
        }
    }

    Ok(Options {
        games: games.ok_or_else(|| format!("--games is required\n{}", usage()))?,
        seed: seed.ok_or_else(|| format!("--seed is required\n{}", usage()))?,
        max_turns,
        first,
        second,
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
[--max-turns <positive integer>] [--first <policy>] [--second <policy>]\n\
policies: random | greedy | minimax | minimax:<depth>"
}

fn simulate(options: &Options) -> Statistics {
    let mut statistics = Statistics::default();

    for game in 0..options.games {
        // Each game gets its own seed, so a policy's choices vary between
        // games while the run as a whole stays reproducible.
        let mut first = options.first.build(options.seed.wrapping_add(game));
        let mut second = options
            .second
            .build(options.seed.wrapping_add(game).wrapping_mul(0x9e37_79b9));
        let mut state = GameState::baseline();
        let mut seen_states = HashSet::new();
        let mut turns = 0;

        loop {
            if let Outcome::Winner(player, reason) = outcome(&state) {
                record_winner(&mut statistics, player, reason);
                break;
            }
            if !seen_states.insert(state.clone()) {
                statistics.repetitions += 1;
                break;
            }
            if turns == options.max_turns {
                statistics.turn_limits += 1;
                break;
            }

            let selected_move = if state.current_player() == Player::First {
                first.choose(&state)
            } else {
                second.choose(&state)
            };
            let Some(selected_move) = selected_move else {
                break;
            };
            state = apply_move(&state, selected_move).expect("a policy must return a legal move");
            turns += 1;

            if let Outcome::Winner(player, reason) = outcome(&state) {
                record_winner(&mut statistics, player, reason);
                break;
            }
        }

        statistics.total_turns += turns;
        statistics.max_observed_turns = statistics.max_observed_turns.max(turns);
    }

    statistics
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
