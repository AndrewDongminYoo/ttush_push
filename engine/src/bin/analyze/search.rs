use engine::{GameState, Move, Outcome, Player, apply_move, legal_moves, outcome};

#[derive(Debug, Eq, PartialEq)]
pub struct Analysis {
    pub winner: Option<Player>,
    pub alternatives: Vec<Alternative>,
}

#[derive(Debug, Eq, PartialEq)]
pub struct Alternative {
    pub selected_move: Move,
    pub winner: Option<Player>,
    pub nodes: usize,
    pub depth_cutoffs: usize,
    pub node_cutoffs: usize,
}

struct Search {
    node_budget: usize,
    nodes: usize,
    depth_cutoffs: usize,
    node_cutoffs: usize,
}

impl Search {
    fn new(node_budget: usize) -> Self {
        Self {
            node_budget,
            nodes: 0,
            depth_cutoffs: 0,
            node_cutoffs: 0,
        }
    }

    fn winner(&mut self, state: &GameState, depth: u8) -> Option<Player> {
        if self.nodes >= self.node_budget {
            self.node_cutoffs += 1;
            return None;
        }
        self.nodes += 1;
        if let Outcome::Winner(winner, _) = outcome(state) {
            return Some(winner);
        }
        if depth == 0 {
            self.depth_cutoffs += 1;
            return None;
        }

        let mover = state.current_player();
        let mut has_unknown_reply = false;
        for candidate in legal_moves(state) {
            let child = apply_move(state, candidate).expect("legal moves must apply");
            match self.winner(&child, depth - 1) {
                Some(winner) if winner == mover => return Some(mover),
                Some(_) => {}
                None => has_unknown_reply = true,
            }
        }

        if has_unknown_reply {
            None
        } else {
            Some(opponent(mover))
        }
    }
}

pub fn analyze(state: &GameState, depth: u8, nodes_per_alternative: usize) -> Analysis {
    if let Outcome::Winner(winner, _) = outcome(state) {
        return Analysis {
            winner: Some(winner),
            alternatives: Vec::new(),
        };
    }

    let mover = state.current_player();
    let alternatives = legal_moves(state)
        .into_iter()
        .map(|selected_move| {
            let child = apply_move(state, selected_move).expect("legal moves must apply");
            let mut search = Search::new(nodes_per_alternative);
            let winner = search.winner(&child, depth.saturating_sub(1));
            Alternative {
                selected_move,
                winner,
                nodes: search.nodes,
                depth_cutoffs: search.depth_cutoffs,
                node_cutoffs: search.node_cutoffs,
            }
        })
        .collect::<Vec<_>>();
    let winner = if alternatives
        .iter()
        .any(|alternative| alternative.winner == Some(mover))
    {
        Some(mover)
    } else if alternatives
        .iter()
        .all(|alternative| alternative.winner == Some(opponent(mover)))
    {
        Some(opponent(mover))
    } else {
        None
    };

    Analysis {
        winner,
        alternatives,
    }
}

fn opponent(player: Player) -> Player {
    match player {
        Player::First => Player::Second,
        Player::Second => Player::First,
    }
}
