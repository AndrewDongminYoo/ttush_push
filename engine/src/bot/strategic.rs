use std::collections::HashMap;

use super::{Policy, Rng};
use crate::{GameState, Move, Outcome, Player, Tile, apply_move, legal_moves, outcome};

const BASE_NODE_BUDGET: usize = 18_000;
const BASE_COMPLEXITY: usize = 25 + (4 * 4);
const WIN_SCORE: i32 = 1_000_000;
const MAX_POSITIONAL_SCORE: i32 = 100_000;

const IMMEDIATE_WIN_WEIGHT: i32 = 40_000;
const KNOCKOUT_WEIGHT: i32 = 12_000;
const SAFE_MOVE_WEIGHT: i32 = 1_200;
const MOBILITY_WEIGHT: i32 = 120;
const FOOTHOLD_WEIGHT: i32 = 4;

/// Searches beyond the fixed-depth policies with a deterministic work budget.
#[derive(Clone, Debug)]
pub struct StrategicBot {
    seed: u64,
    last_search_diagnostics: StrategicSearchDiagnostics,
}

/// Work completed by the most recent Strategic search.
#[derive(Clone, Copy, Debug, Default, Eq, PartialEq)]
pub struct StrategicSearchDiagnostics {
    completed_depth: u16,
    expanded_nodes: usize,
}

impl StrategicSearchDiagnostics {
    pub const fn completed_depth(self) -> u16 {
        self.completed_depth
    }

    pub const fn expanded_nodes(self) -> usize {
        self.expanded_nodes
    }
}

impl StrategicBot {
    pub const fn new(seed: u64) -> Self {
        Self {
            seed,
            last_search_diagnostics: StrategicSearchDiagnostics {
                completed_depth: 0,
                expanded_nodes: 0,
            },
        }
    }

    pub const fn last_search_diagnostics(&self) -> StrategicSearchDiagnostics {
        self.last_search_diagnostics
    }

    fn search_with_budget(
        &self,
        state: &GameState,
        node_budget: usize,
        use_table: bool,
    ) -> SearchResult {
        let root_moves = legal_moves(state);
        if root_moves.is_empty() {
            return SearchResult::default();
        }

        let fallback_index = Rng::new(self.seed).choose_index(root_moves.len());
        let mut result = SearchResult {
            best_move: Some(root_moves[fallback_index]),
            ..SearchResult::default()
        };
        let mut search = Search::new(
            state.current_player(),
            node_budget.max(root_moves.len()),
            use_table,
        );

        for depth in 1..=u16::MAX {
            let Ok(completed) = search.search_root(state, depth, self.seed) else {
                break;
            };
            result.best_move = Some(completed.best_move);
            result.score = completed.score;
            result.completed_depth = depth;
            result.expanded_nodes = search.expanded_nodes;
            if completed.solved || completed.score == terminal_score(true, 1) {
                break;
            }
        }

        result.expanded_nodes = search.expanded_nodes;
        result
    }
}

impl Policy for StrategicBot {
    fn choose(&mut self, state: &GameState) -> Option<Move> {
        let root_moves = legal_moves(state);
        let budget = scaled_node_budget(state.tiles.len(), state.pieces.len(), root_moves.len());
        let result = self.search_with_budget(state, budget, true);
        self.last_search_diagnostics = StrategicSearchDiagnostics {
            completed_depth: result.completed_depth,
            expanded_nodes: result.expanded_nodes,
        };

        result.best_move
    }
}

#[derive(Clone, Copy, Debug, Default, Eq, PartialEq)]
struct SearchResult {
    best_move: Option<Move>,
    score: i32,
    completed_depth: u16,
    expanded_nodes: usize,
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
struct CompletedRoot {
    best_move: Move,
    score: i32,
    solved: bool,
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
struct NodeValue {
    score: i32,
    solved: bool,
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
enum SearchExhausted {
    NodeBudget,
}

#[derive(Clone, Debug, Eq, Hash, PartialEq)]
struct TableKey {
    state: GameState,
    depth: u16,
    root: Player,
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
enum Bound {
    Exact,
    Lower,
    Upper,
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
struct TableEntry {
    score: i32,
    bound: Bound,
    best_move: Move,
    solved: bool,
}

struct Search {
    root: Player,
    node_budget: usize,
    expanded_nodes: usize,
    use_table: bool,
    table: HashMap<TableKey, TableEntry>,
    preferred_moves: HashMap<GameState, Move>,
}

impl Search {
    fn new(root: Player, node_budget: usize, use_table: bool) -> Self {
        Self {
            root,
            node_budget,
            expanded_nodes: 0,
            use_table,
            table: HashMap::new(),
            preferred_moves: HashMap::new(),
        }
    }

    fn search_root(
        &mut self,
        state: &GameState,
        depth: u16,
        seed: u64,
    ) -> Result<CompletedRoot, SearchExhausted> {
        let preferred = self.preferred_moves.get(state).copied();
        let moves = ordered_moves(state, preferred);
        let mut best_score = i32::MIN;
        let mut best_moves = Vec::new();
        let mut solved = true;

        for candidate in moves {
            let next = apply_move(state, candidate)
                .expect("a move returned by legal_moves must remain legal");
            let value = self.search(&next, depth - 1, 1, i32::MIN, i32::MAX)?;
            solved &= value.solved;
            if value.score > best_score {
                best_score = value.score;
                best_moves.clear();
            }
            if value.score == best_score {
                best_moves.push(candidate);
            }
        }

        let best_move = best_moves[Rng::new(seed).choose_index(best_moves.len())];
        self.preferred_moves.insert(state.clone(), best_move);

        Ok(CompletedRoot {
            best_move,
            score: best_score,
            solved,
        })
    }

    fn search(
        &mut self,
        state: &GameState,
        depth: u16,
        ply: u16,
        mut alpha: i32,
        mut beta: i32,
    ) -> Result<NodeValue, SearchExhausted> {
        self.consume_node()?;

        if let Outcome::Winner(winner, _) = outcome(state) {
            return Ok(NodeValue {
                score: terminal_score(winner == self.root, ply),
                solved: true,
            });
        }
        if depth == 0 {
            return Ok(NodeValue {
                score: evaluate(state, self.root),
                solved: false,
            });
        }

        let key = TableKey {
            state: state.clone(),
            depth,
            root: self.root,
        };
        let mut table_move = None;
        if self.use_table
            && let Some(entry) = self.table.get(&key).copied()
        {
            table_move = Some(entry.best_move);
            match entry.bound {
                Bound::Exact => {
                    return Ok(NodeValue {
                        score: entry.score,
                        solved: entry.solved,
                    });
                }
                Bound::Lower => alpha = alpha.max(entry.score),
                Bound::Upper => beta = beta.min(entry.score),
            }
            if alpha >= beta {
                return Ok(NodeValue {
                    score: entry.score,
                    solved: false,
                });
            }
        }

        let alpha_at_start = alpha;
        let beta_at_start = beta;
        let maximizing = state.current_player() == self.root;
        let mut best_score = if maximizing { i32::MIN } else { i32::MAX };
        let mut best_move = None;
        let mut all_solved = true;
        let mut searched_every_move = true;

        for candidate in ordered_moves(state, table_move) {
            let next = apply_move(state, candidate)
                .expect("a move returned by legal_moves must remain legal");
            let child = self.search(&next, depth - 1, ply.saturating_add(1), alpha, beta)?;
            all_solved &= child.solved;

            let improves = if maximizing {
                child.score > best_score
            } else {
                child.score < best_score
            };
            if improves {
                best_score = child.score;
                best_move = Some(candidate);
            }

            if maximizing {
                alpha = alpha.max(best_score);
            } else {
                beta = beta.min(best_score);
            }
            if alpha >= beta {
                searched_every_move = false;
                break;
            }
        }

        let best_move = best_move.expect("an ongoing state must offer a legal move");
        let bound = if best_score <= alpha_at_start {
            Bound::Upper
        } else if best_score >= beta_at_start {
            Bound::Lower
        } else {
            Bound::Exact
        };
        let solved = searched_every_move && all_solved && bound == Bound::Exact;
        if self.use_table {
            self.table.insert(
                key,
                TableEntry {
                    score: best_score,
                    bound,
                    best_move,
                    solved,
                },
            );
            self.preferred_moves.insert(state.clone(), best_move);
        }

        Ok(NodeValue {
            score: best_score,
            solved,
        })
    }

    fn consume_node(&mut self) -> Result<(), SearchExhausted> {
        if self.expanded_nodes >= self.node_budget {
            return Err(SearchExhausted::NodeBudget);
        }
        self.expanded_nodes += 1;
        Ok(())
    }
}

const fn terminal_score(won: bool, ply: u16) -> i32 {
    if won {
        WIN_SCORE - ply as i32
    } else {
        -WIN_SCORE + ply as i32
    }
}

fn scaled_node_budget(tile_count: usize, piece_count: usize, root_moves: usize) -> usize {
    let complexity = tile_count
        .saturating_add(piece_count.saturating_mul(4))
        .max(1);
    let scaled = BASE_NODE_BUDGET
        .saturating_mul(BASE_COMPLEXITY)
        .checked_div(complexity)
        .unwrap_or(BASE_NODE_BUDGET)
        .min(BASE_NODE_BUDGET);

    scaled.max(root_moves.saturating_add(1))
}

fn evaluate(state: &GameState, root: Player) -> i32 {
    let mover = state.current_player();
    let moves = legal_moves(state);
    let mut safe_moves = 0_i32;
    let mut immediate_wins = 0_i32;
    let mut knockouts = 0_i32;
    let mut foothold_durability = 0_i32;

    for candidate in &moves {
        let next = apply_move(state, *candidate)
            .expect("a move returned by legal_moves must remain legal");
        let wins = matches!(outcome(&next), Outcome::Winner(winner, _) if winner == mover);
        if wins {
            immediate_wins += 1;
            if matches!(
                outcome(&next),
                Outcome::Winner(_, crate::WinReason::Knockout)
            ) {
                knockouts += 1;
            }
        }
        if wins || !has_immediate_win(&next, mover.opponent()) {
            safe_moves += 1;
        }

        let moving_piece = state
            .piece(candidate.piece)
            .expect("a legal move must name an existing piece");
        if let Some(destination) = moving_piece.position.step(candidate.direction) {
            foothold_durability += match state.tile_at(destination) {
                Some(Tile::Normal) => 2,
                Some(Tile::Damaged) => 1,
                Some(Tile::Hole) | None => 0,
            };
        }
    }

    let tile_count = i32::try_from(state.tiles.len()).unwrap_or(i32::MAX).max(1);
    let normalized_footholds = foothold_durability.saturating_mul(100) / tile_count;
    let raw = immediate_wins
        .saturating_mul(IMMEDIATE_WIN_WEIGHT)
        .saturating_add(knockouts.saturating_mul(KNOCKOUT_WEIGHT))
        .saturating_add(safe_moves.saturating_mul(SAFE_MOVE_WEIGHT))
        .saturating_add(
            i32::try_from(moves.len())
                .unwrap_or(i32::MAX)
                .saturating_mul(MOBILITY_WEIGHT),
        )
        .saturating_add(normalized_footholds.saturating_mul(FOOTHOLD_WEIGHT))
        .clamp(-MAX_POSITIONAL_SCORE, MAX_POSITIONAL_SCORE);

    if mover == root { raw } else { -raw }
}

fn has_immediate_win(state: &GameState, player: Player) -> bool {
    state.current_player() == player
        && legal_moves(state).into_iter().any(|candidate| {
            apply_move(state, candidate).is_ok_and(
                |next| matches!(outcome(&next), Outcome::Winner(winner, _) if winner == player),
            )
        })
}

fn ordered_moves(state: &GameState, table_move: Option<Move>) -> Vec<Move> {
    let mover = state.current_player();
    let mut moves = legal_moves(state)
        .into_iter()
        .enumerate()
        .map(|(index, candidate)| {
            let next = apply_move(state, candidate)
                .expect("a move returned by legal_moves must remain legal");
            let immediate_win =
                matches!(outcome(&next), Outcome::Winner(winner, _) if winner == mover);
            let priority = if immediate_win {
                0
            } else if Some(candidate) == table_move {
                1
            } else if !has_immediate_win(&next, mover.opponent()) {
                2
            } else {
                3
            };

            (priority, index, candidate)
        })
        .collect::<Vec<_>>();
    moves.sort_by_key(|(priority, index, _)| (*priority, *index));
    moves
        .into_iter()
        .map(|(_, _, candidate)| candidate)
        .collect()
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::{
        BoardConfig, Direction, GameState, Piece, PieceId, Player, Position, apply_move,
        legal_moves,
    };

    fn position(x: u8, y: u8) -> Position {
        Position::new(x, y)
    }

    fn knockout_state() -> GameState {
        let board = BoardConfig::rectangular(
            5,
            5,
            vec![
                Piece::new(PieceId(0), Player::First, position(3, 2)),
                Piece::new(PieceId(1), Player::Second, position(4, 2)),
            ],
        )
        .unwrap();

        GameState::new(board, Player::First).unwrap()
    }

    #[test]
    fn terminal_scores_keep_the_required_ordering() {
        assert!(terminal_score(true, 1) > terminal_score(true, 3));
        assert!(terminal_score(false, 3) > terminal_score(false, 1));
        assert!(terminal_score(true, u16::MAX) > MAX_POSITIONAL_SCORE);
        assert!(terminal_score(false, u16::MAX) < -MAX_POSITIONAL_SCORE);
    }

    #[test]
    fn scaled_budget_is_bounded_and_completes_the_root() {
        assert_eq!(scaled_node_budget(25, 4, 8), BASE_NODE_BUDGET);
        assert!(scaled_node_budget(100, 16, 8) < BASE_NODE_BUDGET);
        assert_eq!(scaled_node_budget(100_000, 10_000, 99), 100);
    }

    #[test]
    fn exhaustion_returns_the_last_completed_depth() {
        let state = GameState::baseline();
        let root_moves = legal_moves(&state).len();
        let first_pass = StrategicBot::new(7).search_with_budget(&state, root_moves, true);
        let mut budget_probe = Search::new(Player::First, usize::MAX, true);
        budget_probe.search_root(&state, 1, 7).unwrap();
        let preferred = budget_probe.preferred_moves.get(&state).copied();
        let first_deeper_move = ordered_moves(&state, preferred)[0];
        let first_deeper_state = apply_move(&state, first_deeper_move).unwrap();
        budget_probe
            .search(&first_deeper_state, 1, 1, i32::MIN, i32::MAX)
            .unwrap();
        let budget_after_one_deeper_candidate = budget_probe.expanded_nodes;
        let interrupted = StrategicBot::new(7).search_with_budget(
            &state,
            budget_after_one_deeper_candidate,
            true,
        );

        assert_eq!(first_pass.completed_depth, 1);
        assert_eq!(first_pass.expanded_nodes, root_moves);
        assert_eq!(interrupted.completed_depth, 1);
        assert_eq!(
            interrupted.expanded_nodes,
            budget_after_one_deeper_candidate,
        );
        assert_eq!(interrupted.best_move, first_pass.best_move);
        assert_eq!(interrupted.score, first_pass.score);
        assert!(apply_move(&state, interrupted.best_move.unwrap()).is_ok());
    }

    #[test]
    fn a_proven_fastest_win_stops_the_search() {
        let state = knockout_state();
        let root_moves = legal_moves(&state).len();

        let result = StrategicBot::new(7).search_with_budget(&state, 1_000, true);

        assert_eq!(
            result.best_move,
            Some(Move::new(PieceId(0), Direction::Right))
        );
        assert_eq!(result.completed_depth, 1);
        assert_eq!(result.expanded_nodes, root_moves);
    }

    #[test]
    fn transposition_table_does_not_change_the_move() {
        let state = GameState::baseline();
        let mut without_table = Search::new(Player::First, 100_000, false);
        let mut with_table = Search::new(Player::First, 100_000, true);

        let without_result = without_table.search_root(&state, 4, 91).unwrap();
        let with_result = with_table.search_root(&state, 4, 91).unwrap();

        assert_eq!(without_result.best_move, with_result.best_move);
        assert_eq!(without_result.score, with_result.score);
        assert!(with_table.expanded_nodes <= without_table.expanded_nodes);
    }

    #[test]
    fn cached_narrow_bounds_do_not_change_a_wide_window_result() {
        let state = GameState::baseline();
        let depth = 3;
        let mut exact_search = Search::new(Player::First, 1_000_000, false);
        let exact = exact_search
            .search(&state, depth, 0, i32::MIN, i32::MAX)
            .unwrap();

        for (alpha, beta) in [
            (exact.score - 2, exact.score - 1),
            (exact.score + 1, exact.score + 2),
        ] {
            let mut cached_search = Search::new(Player::First, 1_000_000, true);
            cached_search.search(&state, depth, 0, alpha, beta).unwrap();
            let key = TableKey {
                state: state.clone(),
                depth,
                root: Player::First,
            };
            assert_ne!(cached_search.table.get(&key).unwrap().bound, Bound::Exact);

            let wide = cached_search
                .search(&state, depth, 0, i32::MIN, i32::MAX)
                .unwrap();

            assert_eq!(wide.score, exact.score, "window {alpha}..{beta}");
        }
    }
}
