use super::{GameState, Move, Outcome, Player, apply_move, legal_moves, outcome};

/// A way of choosing a move.
///
/// A policy sees one round and nothing else. It is handed the state and
/// returns a legal move, or `None` when the round offers none, which is the
/// engine's own signal that the round has ended.
pub trait Policy {
    fn choose(&mut self, state: &GameState) -> Option<Move>;
}

/// The xorshift generator the simulator has always used, shared so that the
/// policies and the simulator cannot drift into two definitions.
#[derive(Clone, Debug)]
pub struct Rng {
    state: u64,
}

impl Rng {
    pub const fn new(seed: u64) -> Self {
        Self {
            state: if seed == 0 {
                0x9e37_79b9_7f4a_7c15
            } else {
                seed
            },
        }
    }

    pub fn choose_index(&mut self, length: usize) -> usize {
        self.state ^= self.state >> 12;
        self.state ^= self.state << 25;
        self.state ^= self.state >> 27;
        let value = self.state.wrapping_mul(0x2545_f491_4f6c_dd1d);

        (value % length as u64) as usize
    }
}

/// Picks uniformly among the legal moves.
#[derive(Clone, Debug)]
pub struct RandomBot {
    rng: Rng,
}

impl RandomBot {
    pub const fn new(seed: u64) -> Self {
        Self {
            rng: Rng::new(seed),
        }
    }
}

impl Policy for RandomBot {
    fn choose(&mut self, state: &GameState) -> Option<Move> {
        let moves = legal_moves(state);
        if moves.is_empty() {
            return None;
        }

        Some(moves[self.rng.choose_index(moves.len())])
    }
}

/// Wins where it can, and otherwise declines to hand the opponent a win.
///
/// One ply of lookahead, kept separate from the search on purpose: the whole
/// value of this policy is that its reasoning reads off in three steps.
#[derive(Clone, Debug)]
pub struct GreedyBot {
    rng: Rng,
}

impl GreedyBot {
    pub const fn new(seed: u64) -> Self {
        Self {
            rng: Rng::new(seed),
        }
    }
}

impl Policy for GreedyBot {
    fn choose(&mut self, state: &GameState) -> Option<Move> {
        let moves = legal_moves(state);
        if moves.is_empty() {
            return None;
        }

        let mover = state.current_player();
        let mut safe = Vec::with_capacity(moves.len());
        for candidate in &moves {
            let Ok(next) = apply_move(state, *candidate) else {
                continue;
            };
            if wins_for(&next, mover) {
                return Some(*candidate);
            }
            if !opponent_wins_next(&next, mover) {
                safe.push(*candidate);
            }
        }

        // Every move loses, so there is nothing to prefer among them.
        let choices = if safe.is_empty() { &moves } else { &safe };

        Some(choices[self.rng.choose_index(choices.len())])
    }
}

/// Searches to a fixed depth and scores the leaves.
#[derive(Clone, Debug)]
pub struct MinimaxBot {
    depth: u8,
    rng: Rng,
}

impl MinimaxBot {
    /// A win, far enough above any positional score that it always outranks
    /// one.
    const WIN: i32 = 1_000_000;

    pub const fn new(depth: u8, seed: u64) -> Self {
        Self {
            depth: if depth == 0 { 1 } else { depth },
            rng: Rng::new(seed),
        }
    }

    fn search(state: &GameState, mover: Player, depth: u8) -> i32 {
        if let Outcome::Winner(winner, _) = outcome(state) {
            // Deeper wins score lower, so a faster win is preferred and a
            // loss is delayed rather than walked into.
            let score = Self::WIN - i32::from(depth);
            return if winner == mover { score } else { -score };
        }
        if depth == 0 {
            return Self::evaluate(state, mover);
        }

        let moves = legal_moves(state);
        if moves.is_empty() {
            return Self::evaluate(state, mover);
        }

        let maximizing = state.current_player() == mover;
        let mut best = if maximizing { i32::MIN } else { i32::MAX };
        for candidate in moves {
            let Ok(next) = apply_move(state, candidate) else {
                continue;
            };
            let score = Self::search(&next, mover, depth - 1);
            best = if maximizing {
                best.max(score)
            } else {
                best.min(score)
            };
        }

        best
    }

    /// Scores a leaf by how much room the side to move has.
    ///
    /// Material is deliberately absent: a knockout ends the round outright,
    /// so in any position that is still being played both sides hold every
    /// piece they started with, and a material term could never be anything
    /// but zero. Mobility is what actually varies, and running the opponent
    /// out of moves is the other way a round is won.
    fn evaluate(state: &GameState, mover: Player) -> i32 {
        let mobility = legal_moves(state).len() as i32;

        if state.current_player() == mover {
            mobility
        } else {
            -mobility
        }
    }
}

impl Policy for MinimaxBot {
    fn choose(&mut self, state: &GameState) -> Option<Move> {
        let moves = legal_moves(state);
        if moves.is_empty() {
            return None;
        }

        let mover = state.current_player();
        let mut best_score = i32::MIN;
        let mut best_moves = Vec::new();
        for candidate in moves {
            let Ok(next) = apply_move(state, candidate) else {
                continue;
            };
            let score = Self::search(&next, mover, self.depth - 1);
            if score > best_score {
                best_score = score;
                best_moves.clear();
            }
            if score == best_score {
                best_moves.push(candidate);
            }
        }

        // Ties are broken by the seed rather than by move order, so equal
        // positions do not always produce the same opening.
        Some(best_moves[self.rng.choose_index(best_moves.len())])
    }
}

fn wins_for(state: &GameState, player: Player) -> bool {
    matches!(outcome(state), Outcome::Winner(winner, _) if winner == player)
}

fn opponent_wins_next(state: &GameState, mover: Player) -> bool {
    legal_moves(state)
        .into_iter()
        .any(|reply| apply_move(state, reply).is_ok_and(|after| wins_for(&after, mover.opponent())))
}
