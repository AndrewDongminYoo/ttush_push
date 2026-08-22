mod frb_generated; /* AUTO INJECTED BY flutter_rust_bridge. This line may not be accurate, and you can change it according to your needs. */
use std::collections::{BTreeMap, BTreeSet};

pub mod api;

#[derive(Clone, Copy, Debug, Eq, Hash, Ord, PartialEq, PartialOrd)]
pub enum Player {
    First,
    Second,
}

impl Player {
    fn opponent(self) -> Self {
        match self {
            Self::First => Self::Second,
            Self::Second => Self::First,
        }
    }
}

#[derive(Clone, Copy, Debug, Eq, Hash, Ord, PartialEq, PartialOrd)]
pub struct Position {
    x: u8,
    y: u8,
}

impl Position {
    pub const fn new(x: u8, y: u8) -> Self {
        Self { x, y }
    }

    fn step(self, direction: Direction) -> Option<Self> {
        let (x_offset, y_offset) = match direction {
            Direction::Up => (0, -1),
            Direction::Down => (0, 1),
            Direction::Left => (-1, 0),
            Direction::Right => (1, 0),
        };

        Some(Self {
            x: self.x.checked_add_signed(x_offset)?,
            y: self.y.checked_add_signed(y_offset)?,
        })
    }
}

#[derive(Clone, Copy, Debug, Eq, Hash, PartialEq)]
pub enum Direction {
    Up,
    Down,
    Left,
    Right,
}

#[derive(Clone, Copy, Debug, Eq, Hash, Ord, PartialEq, PartialOrd)]
pub struct PieceId(pub u8);

#[derive(Clone, Debug, Eq, Hash, Ord, PartialEq, PartialOrd)]
pub struct Piece {
    pub id: PieceId,
    pub owner: Player,
    pub position: Position,
}

impl Piece {
    pub const fn new(id: PieceId, owner: Player, position: Position) -> Self {
        Self {
            id,
            owner,
            position,
        }
    }
}

#[derive(Clone, Copy, Debug, Eq, Hash, Ord, PartialEq, PartialOrd)]
pub enum Tile {
    Normal,
    Damaged,
    Hole,
}

#[derive(Clone, Copy, Debug, Eq, Hash, Ord, PartialEq, PartialOrd)]
pub enum WinReason {
    Knockout,
    Immobilization,
}

#[derive(Clone, Copy, Debug, Eq, Hash, Ord, PartialEq, PartialOrd)]
pub enum Outcome {
    Ongoing,
    Winner(Player, WinReason),
}

/// Where a match stands, and what the caller may do next.
///
/// A finished round is a state rather than a step taken inside the move that
/// finished it, so the position that ended it can be shown before the next
/// round replaces the board.
#[derive(Clone, Copy, Debug, Eq, Ord, PartialEq, PartialOrd)]
pub enum MatchPhase {
    Playing,
    RoundOver { winner: Player, reason: WinReason },
    MatchOver { winner: Player, reason: WinReason },
}

#[derive(Clone, Debug, Eq, Hash, Ord, PartialEq, PartialOrd)]
pub struct BoardConfig {
    playable_cells: BTreeSet<Position>,
    initial_pieces: Vec<Piece>,
}

impl BoardConfig {
    /// The pieces every round resets to.
    pub fn initial_pieces(&self) -> &[Piece] {
        &self.initial_pieces
    }

    /// The symmetric five-by-five layout the app starts from.
    pub fn baseline() -> Self {
        Self::rectangular(
            5,
            5,
            vec![
                Piece::new(PieceId(0), Player::First, Position::new(1, 0)),
                Piece::new(PieceId(1), Player::First, Position::new(3, 0)),
                Piece::new(PieceId(2), Player::Second, Position::new(1, 4)),
                Piece::new(PieceId(3), Player::Second, Position::new(3, 4)),
            ],
        )
        .expect("the baseline board configuration must be valid")
    }

    pub fn rectangular(
        width: u8,
        height: u8,
        initial_pieces: Vec<Piece>,
    ) -> Result<Self, StateError> {
        let playable_cells = (0..width)
            .flat_map(|x| (0..height).map(move |y| Position::new(x, y)))
            .collect();

        Self::new(playable_cells, initial_pieces)
    }

    pub fn new(
        playable_cells: BTreeSet<Position>,
        initial_pieces: Vec<Piece>,
    ) -> Result<Self, StateError> {
        if playable_cells.is_empty() {
            return Err(StateError::EmptyBoard);
        }

        let mut occupied_cells = BTreeSet::new();
        let mut piece_ids = BTreeSet::new();
        for piece in &initial_pieces {
            if !playable_cells.contains(&piece.position) {
                return Err(StateError::PieceOutsideBoard(piece.id));
            }
            if !occupied_cells.insert(piece.position) {
                return Err(StateError::OverlappingPieces);
            }
            if !piece_ids.insert(piece.id) {
                return Err(StateError::DuplicatePieceId(piece.id));
            }
        }

        Ok(Self {
            playable_cells,
            initial_pieces,
        })
    }

    fn contains(&self, position: Position) -> bool {
        self.playable_cells.contains(&position)
    }
}

#[derive(Clone, Debug, Eq, Hash, Ord, PartialEq, PartialOrd)]
pub struct GameState {
    board: BoardConfig,
    tiles: BTreeMap<Position, Tile>,
    pieces: BTreeMap<PieceId, Piece>,
    current_player: Player,
    counter_push: Option<CounterPush>,
    outcome: Outcome,
}

#[derive(Clone, Copy, Debug, Eq, Hash, Ord, PartialEq, PartialOrd)]
struct CounterPush {
    pusher: PieceId,
    pushed: PieceId,
}

impl GameState {
    pub fn baseline() -> Self {
        Self::new(BoardConfig::baseline(), Player::First)
            .expect("the baseline game state must be valid")
    }

    pub fn new(board: BoardConfig, current_player: Player) -> Result<Self, StateError> {
        let tiles = board
            .playable_cells
            .iter()
            .copied()
            .map(|position| (position, Tile::Normal))
            .collect();

        Self::from_parts(board, tiles, current_player)
    }

    pub fn from_parts(
        board: BoardConfig,
        tiles: BTreeMap<Position, Tile>,
        current_player: Player,
    ) -> Result<Self, StateError> {
        if tiles.len() != board.playable_cells.len()
            || tiles.keys().any(|position| !board.contains(*position))
        {
            return Err(StateError::TilesDoNotMatchBoard);
        }
        let pieces: BTreeMap<PieceId, Piece> = board
            .initial_pieces
            .iter()
            .cloned()
            .map(|piece| (piece.id, piece))
            .collect();

        if pieces
            .values()
            .any(|piece| tiles[&piece.position] == Tile::Hole)
        {
            return Err(StateError::PieceOnHole);
        }

        let mut state = Self {
            board,
            tiles,
            pieces,
            current_player,
            counter_push: None,
            outcome: Outcome::Ongoing,
        };
        if legal_moves(&state).is_empty() {
            state.outcome = Outcome::Winner(current_player.opponent(), WinReason::Immobilization);
        }

        Ok(state)
    }

    pub fn piece(&self, id: PieceId) -> Option<&Piece> {
        self.pieces.get(&id)
    }

    pub fn tile_at(&self, position: Position) -> Option<Tile> {
        self.tiles.get(&position).copied()
    }

    pub const fn current_player(&self) -> Player {
        self.current_player
    }

    fn piece_at(&self, position: Position) -> Option<&Piece> {
        self.pieces
            .values()
            .find(|piece| piece.position == position)
    }
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub struct Move {
    piece: PieceId,
    direction: Direction,
}

impl Move {
    pub const fn new(piece: PieceId, direction: Direction) -> Self {
        Self { piece, direction }
    }
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub enum StateError {
    ImpossibleScore,
    EmptyBoard,
    PieceOutsideBoard(PieceId),
    OverlappingPieces,
    DuplicatePieceId(PieceId),
    TilesDoNotMatchBoard,
    PieceOnHole,
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub enum IllegalMove {
    RoundFinished,
    RoundInProgress,
    MatchFinished,
    UnknownPiece(PieceId),
    WrongPlayer(PieceId),
    OutsideBoard,
    Hole,
    Occupied,
    BlockedPush,
    ImmediateCounterPush,
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct MatchState {
    board: BoardConfig,
    round: GameState,
    round_wins: [u8; 2],
    phase: MatchPhase,
}

impl MatchState {
    pub const WINS_REQUIRED: u8 = 2;

    pub fn new(board: BoardConfig, starting_player: Player) -> Result<Self, StateError> {
        let mut state = Self {
            round: GameState::new(board.clone(), starting_player)?,
            board,
            round_wins: [0, 0],
            phase: MatchPhase::Playing,
        };
        state.settle_round();

        Ok(state)
    }

    pub fn apply_move(&self, mv: Move) -> Result<Self, IllegalMove> {
        match self.phase {
            MatchPhase::Playing => {}
            MatchPhase::RoundOver { .. } => return Err(IllegalMove::RoundFinished),
            MatchPhase::MatchOver { .. } => return Err(IllegalMove::MatchFinished),
        }

        let mut next = self.clone();
        next.round = apply_move(&self.round, mv)?;
        next.settle_round();

        Ok(next)
    }

    /// Starts the next round. The loser of the round that just ended plays
    /// first.
    ///
    /// The reset board can be immobilized on arrival, so this may settle
    /// straight back into `RoundOver`; the caller advances through that the
    /// same way, and never sees a `Playing` state with no legal move.
    pub fn advance_round(&self) -> Result<Self, IllegalMove> {
        let MatchPhase::RoundOver { winner, .. } = self.phase else {
            return Err(match self.phase {
                MatchPhase::MatchOver { .. } => IllegalMove::MatchFinished,
                _ => IllegalMove::RoundInProgress,
            });
        };

        let mut next = self.clone();
        next.round = GameState::new(self.board.clone(), winner.opponent())
            .expect("a previously valid board must reset into a valid round");
        next.settle_round();

        Ok(next)
    }

    /// Records the round's result when it has one, and stops there.
    fn settle_round(&mut self) {
        let Outcome::Winner(winner, reason) = outcome(&self.round) else {
            self.phase = MatchPhase::Playing;
            return;
        };

        let winner_index = match winner {
            Player::First => 0,
            Player::Second => 1,
        };
        self.round_wins[winner_index] += 1;
        self.phase = if self.round_wins[winner_index] == Self::WINS_REQUIRED {
            MatchPhase::MatchOver { winner, reason }
        } else {
            MatchPhase::RoundOver { winner, reason }
        };
    }

    pub const fn round(&self) -> &GameState {
        &self.round
    }

    pub const fn round_wins(&self, player: Player) -> u8 {
        self.round_wins[match player {
            Player::First => 0,
            Player::Second => 1,
        }]
    }

    pub const fn phase(&self) -> MatchPhase {
        self.phase
    }

    /// The layout every round resets to.
    pub const fn board(&self) -> &BoardConfig {
        &self.board
    }

    /// Rebuilds a match from its parts, for callers that carry it as a value.
    ///
    /// The phase is derived rather than accepted, so a caller cannot claim a
    /// round is still running after it ended, or that it ended when it did
    /// not.
    pub fn from_parts(
        board: BoardConfig,
        round: GameState,
        round_wins: [u8; 2],
    ) -> Result<Self, StateError> {
        if round_wins.iter().any(|wins| *wins > Self::WINS_REQUIRED) {
            return Err(StateError::ImpossibleScore);
        }

        let mut state = Self {
            board,
            round,
            round_wins,
            phase: MatchPhase::Playing,
        };
        // The stored wins already include this round's, if it has ended.
        if let Outcome::Winner(winner, reason) = outcome(&state.round) {
            let winner_index = match winner {
                Player::First => 0,
                Player::Second => 1,
            };
            if state.round_wins[winner_index] == 0 {
                return Err(StateError::ImpossibleScore);
            }
            state.phase = if state.round_wins[winner_index] == Self::WINS_REQUIRED {
                MatchPhase::MatchOver { winner, reason }
            } else {
                MatchPhase::RoundOver { winner, reason }
            };
        }

        Ok(state)
    }
}

#[derive(Clone, Debug)]
struct ResolvedMove {
    moving_piece: Piece,
    destination: Position,
    pushed_piece: Option<Piece>,
    knockout: bool,
}

pub fn legal_moves(state: &GameState) -> Vec<Move> {
    if outcome(state) != Outcome::Ongoing {
        return Vec::new();
    }

    [
        Direction::Up,
        Direction::Down,
        Direction::Left,
        Direction::Right,
    ]
    .into_iter()
    .flat_map(|direction| {
        state
            .pieces
            .values()
            .filter(move |piece| piece.owner == state.current_player)
            .map(move |piece| Move::new(piece.id, direction))
    })
    .filter(|mv| resolve_move(state, *mv).is_ok())
    .collect()
}

pub fn apply_move(state: &GameState, mv: Move) -> Result<GameState, IllegalMove> {
    let resolution = resolve_move(state, mv)?;

    let mut next = state.clone();
    let departure_tile = next
        .tiles
        .get_mut(&resolution.moving_piece.position)
        .expect("a piece must occupy a playable tile");
    *departure_tile = match *departure_tile {
        Tile::Normal => Tile::Damaged,
        Tile::Damaged => Tile::Hole,
        Tile::Hole => unreachable!("a piece cannot occupy a hole"),
    };
    next.pieces
        .get_mut(&mv.piece)
        .expect("the moving piece must remain in the cloned state")
        .position = resolution.destination;
    if resolution.knockout {
        let pushed_piece = resolution
            .pushed_piece
            .expect("only a push can knock a piece out");
        next.pieces.remove(&pushed_piece.id);
        next.outcome = Outcome::Winner(state.current_player, WinReason::Knockout);
        return Ok(next);
    }
    if let Some(pushed_piece) = resolution.pushed_piece {
        next.pieces
            .get_mut(&pushed_piece.id)
            .expect("the pushed piece must remain in the cloned state")
            .position = resolution
            .destination
            .step(mv.direction)
            .expect("the validated push destination must be on the board");
        next.counter_push = Some(CounterPush {
            pusher: mv.piece,
            pushed: pushed_piece.id,
        });
    } else {
        next.counter_push = None;
    }
    next.current_player = state.current_player.opponent();
    if legal_moves(&next).is_empty() {
        next.outcome = Outcome::Winner(state.current_player, WinReason::Immobilization);
    }

    Ok(next)
}

fn resolve_move(state: &GameState, mv: Move) -> Result<ResolvedMove, IllegalMove> {
    if outcome(state) != Outcome::Ongoing {
        return Err(IllegalMove::RoundFinished);
    }

    let moving_piece = state
        .piece(mv.piece)
        .cloned()
        .ok_or(IllegalMove::UnknownPiece(mv.piece))?;
    if moving_piece.owner != state.current_player {
        return Err(IllegalMove::WrongPlayer(mv.piece));
    }

    let destination = moving_piece
        .position
        .step(mv.direction)
        .ok_or(IllegalMove::OutsideBoard)?;
    if !state.board.contains(destination) {
        return Err(IllegalMove::OutsideBoard);
    }
    if state.tile_at(destination) == Some(Tile::Hole) {
        return Err(IllegalMove::Hole);
    }
    if state.counter_push.is_some_and(|counter_push| {
        counter_push.pushed == mv.piece
            && state
                .piece_at(destination)
                .is_some_and(|piece| piece.id == counter_push.pusher)
    }) {
        return Err(IllegalMove::ImmediateCounterPush);
    }
    let pushed_piece = state.piece_at(destination).cloned();
    if let Some(piece) = &pushed_piece
        && piece.owner == moving_piece.owner
    {
        return Err(IllegalMove::Occupied);
    }
    let knockout = if pushed_piece.is_some() {
        match destination.step(mv.direction) {
            None => true,
            Some(push_destination)
                if !state.board.contains(push_destination)
                    || state.tile_at(push_destination) == Some(Tile::Hole) =>
            {
                true
            }
            Some(push_destination) if state.piece_at(push_destination).is_some() => {
                return Err(IllegalMove::BlockedPush);
            }
            Some(_) => false,
        }
    } else {
        false
    };

    Ok(ResolvedMove {
        moving_piece,
        destination,
        pushed_piece,
        knockout,
    })
}

pub const fn outcome(state: &GameState) -> Outcome {
    state.outcome
}
