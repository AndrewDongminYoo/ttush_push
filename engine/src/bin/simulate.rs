use std::collections::HashSet;
use std::env;
use std::process;

use engine::{GameState, Outcome, Player, WinReason, apply_move, legal_moves, outcome};

#[derive(Debug)]
struct Options {
    games: u64,
    seed: u64,
    max_turns: u64,
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

struct Rng {
    state: u64,
}

impl Rng {
    const fn new(seed: u64) -> Self {
        Self {
            state: if seed == 0 {
                0x9e37_79b9_7f4a_7c15
            } else {
                seed
            },
        }
    }

    fn choose_index(&mut self, length: usize) -> usize {
        self.state ^= self.state >> 12;
        self.state ^= self.state << 25;
        self.state ^= self.state >> 27;
        let value = self.state.wrapping_mul(0x2545_f491_4f6c_dd1d);

        (value % length as u64) as usize
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
    let statistics = simulate(&options);

    println!("games={}", options.games);
    println!("seed={}", options.seed);
    println!("turn_limit={}", options.max_turns);
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
            _ => return Err(format!("unknown argument: {flag}\n{}", usage())),
        }
    }

    Ok(Options {
        games: games.ok_or_else(|| format!("--games is required\n{}", usage()))?,
        seed: seed.ok_or_else(|| format!("--seed is required\n{}", usage()))?,
        max_turns,
    })
}

fn parse_positive(flag: &str, value: &str) -> Result<u64, String> {
    match value.parse() {
        Ok(number) if number > 0 => Ok(number),
        _ => Err(format!("{flag} must be a positive integer: {value}")),
    }
}

fn usage() -> &'static str {
    "usage: simulate --games <positive integer> --seed <u64> [--max-turns <positive integer>]"
}

fn simulate(options: &Options) -> Statistics {
    let mut rng = Rng::new(options.seed);
    let mut statistics = Statistics::default();

    for _ in 0..options.games {
        let mut state = GameState::baseline();
        let mut seen_states = HashSet::new();
        let mut turns = 0;

        loop {
            if !seen_states.insert(state.clone()) {
                statistics.repetitions += 1;
                break;
            }
            if turns == options.max_turns {
                statistics.turn_limits += 1;
                break;
            }

            let moves = legal_moves(&state);
            let selected_move = moves[rng.choose_index(moves.len())];
            state = apply_move(&state, selected_move)
                .expect("a move selected from legal_moves must be legal");
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
