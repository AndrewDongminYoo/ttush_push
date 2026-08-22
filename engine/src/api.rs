use std::collections::{BTreeMap, BTreeSet};

use flutter_rust_bridge::frb;

use super::{
    BoardConfig, CounterPush, Direction, GameState, IllegalMove, MatchPhase, MatchState, Move,
    Outcome, Piece, PieceId, Player, Position, StateError, Tile, WinReason,
};

const SNAPSHOT_HASH_OFFSET_BASIS: u64 = 0xcbf2_9ce4_8422_2325;
const SNAPSHOT_HASH_PRIME: u64 = 0x0000_0100_0000_01b3;
const SNAPSHOT_HASH_PREFIX: &[u8] = b"ttush-push:snapshot:v1\0";
const MATCH_HASH_PREFIX: &[u8] = b"ttush-push:match:v1\0";

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum GamePlayer {
    First,
    Second,
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum GameDirection {
    Up,
    Down,
    Left,
    Right,
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum GameTileKind {
    Normal,
    Damaged,
    Hole,
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum GameWinReason {
    Knockout,
    Immobilization,
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct GameTile {
    pub x: u8,
    pub y: u8,
    pub kind: GameTileKind,
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct GamePiece {
    pub id: u8,
    pub owner: GamePlayer,
    pub x: u8,
    pub y: u8,
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct GameMove {
    pub piece_id: u8,
    pub direction: GameDirection,
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct CounterPushRestriction {
    pub pusher_piece_id: u8,
    pub pushed_piece_id: u8,
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct GameSnapshot {
    pub current_player: GamePlayer,
    pub tiles: Vec<GameTile>,
    pub pieces: Vec<GamePiece>,
    pub counter_push: Option<CounterPushRestriction>,
    pub winner: Option<GamePlayer>,
    pub win_reason: Option<GameWinReason>,
    pub snapshot_hash: String,
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum GameMatchPhase {
    Playing,
    RoundOver,
    MatchOver,
}

/// A best-of-three match, carried across the bridge by value.
///
/// `starting_pieces` is the layout each round resets to. The round's own
/// tiles cannot stand in for it: they carry the damage taken since, not the
/// board a reset restores.
#[derive(Clone, Debug, Eq, PartialEq)]
pub struct MatchSnapshot {
    pub round: GameSnapshot,
    pub starting_pieces: Vec<GamePiece>,
    pub first_player_wins: u8,
    pub second_player_wins: u8,
    pub phase: GameMatchPhase,
    pub round_winner: Option<GamePlayer>,
    pub round_win_reason: Option<GameWinReason>,
    pub match_winner: Option<GamePlayer>,
    pub snapshot_hash: String,
}

#[frb(sync)]
pub fn initial_match() -> MatchSnapshot {
    match_snapshot_from_state(
        &MatchState::new(BoardConfig::baseline(), Player::First)
            .expect("the baseline board configuration must produce a valid match"),
    )
}

#[frb(sync)]
pub fn match_legal_moves(snapshot: MatchSnapshot) -> Result<Vec<GameMove>, String> {
    let state = match_state_from_snapshot(snapshot)?;

    Ok(super::legal_moves(state.round())
        .into_iter()
        .map(game_move_from_engine)
        .collect())
}

#[frb(sync)]
pub fn match_apply_move(
    snapshot: MatchSnapshot,
    game_move: GameMove,
) -> Result<MatchSnapshot, String> {
    let state = match_state_from_snapshot(snapshot)?;
    let next = state
        .apply_move(move_to_engine(game_move))
        .map_err(illegal_move_error)?;

    Ok(match_snapshot_from_state(&next))
}

#[frb(sync)]
pub fn advance_round(snapshot: MatchSnapshot) -> Result<MatchSnapshot, String> {
    let state = match_state_from_snapshot(snapshot)?;
    let next = state.advance_round().map_err(illegal_move_error)?;

    Ok(match_snapshot_from_state(&next))
}

fn match_snapshot_from_state(state: &MatchState) -> MatchSnapshot {
    let (phase, round_winner, round_win_reason, match_winner) = match state.phase() {
        MatchPhase::Playing => (GameMatchPhase::Playing, None, None, None),
        MatchPhase::RoundOver { winner, reason } => (
            GameMatchPhase::RoundOver,
            Some(winner.into()),
            Some(reason.into()),
            None,
        ),
        MatchPhase::MatchOver { winner, reason } => (
            GameMatchPhase::MatchOver,
            Some(winner.into()),
            Some(reason.into()),
            Some(winner.into()),
        ),
    };

    let mut snapshot = MatchSnapshot {
        round: snapshot_from_state(state.round()),
        starting_pieces: state
            .board()
            .initial_pieces()
            .iter()
            .map(|piece| GamePiece {
                id: piece.id.0,
                owner: piece.owner.into(),
                x: piece.position.x,
                y: piece.position.y,
            })
            .collect(),
        first_player_wins: state.round_wins(Player::First),
        second_player_wins: state.round_wins(Player::Second),
        phase,
        round_winner,
        round_win_reason,
        match_winner,
        snapshot_hash: String::new(),
    };
    snapshot.snapshot_hash = match_hash(&snapshot);
    snapshot
}

fn match_state_from_snapshot(snapshot: MatchSnapshot) -> Result<MatchState, String> {
    if snapshot.snapshot_hash != match_hash(&snapshot) {
        return Err("match snapshot hash does not match its value fields".to_owned());
    }

    let playable_cells = snapshot
        .round
        .tiles
        .iter()
        .map(|tile| Position::new(tile.x, tile.y))
        .collect::<BTreeSet<_>>();
    let starting_pieces = snapshot
        .starting_pieces
        .iter()
        .map(|piece| {
            Piece::new(
                PieceId(piece.id),
                piece.owner.into(),
                Position::new(piece.x, piece.y),
            )
        })
        .collect::<Vec<_>>();
    let board = BoardConfig::new(playable_cells, starting_pieces).map_err(state_error)?;
    let round = state_from_snapshot(snapshot.round)?;

    MatchState::from_parts(
        board,
        round,
        [snapshot.first_player_wins, snapshot.second_player_wins],
    )
    .map_err(state_error)
}

/// Hashes the match's own fields over the round's hash.
///
/// The round hash covers only the round, so reusing it would leave the score
/// editable while the board stayed tamper-proof.
fn match_hash(snapshot: &MatchSnapshot) -> String {
    let mut hash = SNAPSHOT_HASH_OFFSET_BASIS;
    hash_bytes(&mut hash, MATCH_HASH_PREFIX);
    hash_bytes(&mut hash, snapshot.round.snapshot_hash.as_bytes());
    hash_byte(&mut hash, snapshot.starting_pieces.len() as u8);
    for piece in &snapshot.starting_pieces {
        hash_bytes(
            &mut hash,
            &[piece.id, player_byte(piece.owner), piece.x, piece.y],
        );
    }
    hash_bytes(
        &mut hash,
        &[
            snapshot.first_player_wins,
            snapshot.second_player_wins,
            match snapshot.phase {
                GameMatchPhase::Playing => 0,
                GameMatchPhase::RoundOver => 1,
                GameMatchPhase::MatchOver => 2,
            },
        ],
    );
    match (snapshot.round_winner, snapshot.round_win_reason) {
        (Some(player), Some(reason)) => hash_bytes(
            &mut hash,
            &[1, player_byte(player), win_reason_byte(reason)],
        ),
        (None, None) => hash_byte(&mut hash, 0),
        _ => hash_byte(&mut hash, 0xff),
    }
    match snapshot.match_winner {
        Some(player) => hash_bytes(&mut hash, &[1, player_byte(player)]),
        None => hash_byte(&mut hash, 0),
    }

    format!("{hash:016x}")
}

fn snapshot_from_state(state: &GameState) -> GameSnapshot {
    let (winner, win_reason) = match state.outcome {
        Outcome::Ongoing => (None, None),
        Outcome::Winner(player, reason) => (Some(player.into()), Some(reason.into())),
    };
    let mut snapshot = GameSnapshot {
        current_player: state.current_player.into(),
        tiles: state
            .tiles
            .iter()
            .map(|(position, tile)| GameTile {
                x: position.x,
                y: position.y,
                kind: (*tile).into(),
            })
            .collect(),
        pieces: state
            .pieces
            .values()
            .map(|piece| GamePiece {
                id: piece.id.0,
                owner: piece.owner.into(),
                x: piece.position.x,
                y: piece.position.y,
            })
            .collect(),
        counter_push: state
            .counter_push
            .map(|restriction| CounterPushRestriction {
                pusher_piece_id: restriction.pusher.0,
                pushed_piece_id: restriction.pushed.0,
            }),
        winner,
        win_reason,
        snapshot_hash: String::new(),
    };
    snapshot.snapshot_hash = snapshot_hash(&snapshot);
    snapshot
}

fn state_from_snapshot(snapshot: GameSnapshot) -> Result<GameState, String> {
    if snapshot.snapshot_hash != snapshot_hash(&snapshot) {
        return Err("snapshot hash does not match its value fields".to_owned());
    }

    let tiles = snapshot
        .tiles
        .iter()
        .map(|tile| (Position::new(tile.x, tile.y), tile.kind.into()))
        .collect::<BTreeMap<_, _>>();
    if tiles.len() != snapshot.tiles.len() {
        return Err("snapshot contains duplicate tile positions".to_owned());
    }

    let pieces = snapshot
        .pieces
        .iter()
        .map(|piece| {
            Piece::new(
                PieceId(piece.id),
                piece.owner.into(),
                Position::new(piece.x, piece.y),
            )
        })
        .collect::<Vec<_>>();
    let playable_cells = tiles.keys().copied().collect::<BTreeSet<_>>();
    let board = BoardConfig::new(playable_cells, pieces).map_err(state_error)?;
    let mut state =
        GameState::from_parts(board, tiles, snapshot.current_player.into()).map_err(state_error)?;

    state.counter_push = snapshot.counter_push.map(|restriction| CounterPush {
        pusher: PieceId(restriction.pusher_piece_id),
        pushed: PieceId(restriction.pushed_piece_id),
    });
    state.outcome = match (snapshot.winner, snapshot.win_reason) {
        (None, None) => Outcome::Ongoing,
        (Some(player), Some(reason)) => Outcome::Winner(player.into(), reason.into()),
        _ => return Err("snapshot winner and win reason must be provided together".to_owned()),
    };
    if state.outcome == Outcome::Ongoing && super::legal_moves(&state).is_empty() {
        state.outcome = Outcome::Winner(state.current_player.opponent(), WinReason::Immobilization);
    }

    Ok(state)
}

fn snapshot_hash(snapshot: &GameSnapshot) -> String {
    let mut hash = SNAPSHOT_HASH_OFFSET_BASIS;
    hash_bytes(&mut hash, SNAPSHOT_HASH_PREFIX);
    hash_byte(&mut hash, player_byte(snapshot.current_player));
    hash_byte(&mut hash, snapshot.tiles.len() as u8);
    for tile in &snapshot.tiles {
        hash_bytes(&mut hash, &[tile.x, tile.y, tile_byte(tile.kind)]);
    }
    hash_byte(&mut hash, snapshot.pieces.len() as u8);
    for piece in &snapshot.pieces {
        hash_bytes(
            &mut hash,
            &[piece.id, player_byte(piece.owner), piece.x, piece.y],
        );
    }
    match &snapshot.counter_push {
        Some(restriction) => hash_bytes(
            &mut hash,
            &[1, restriction.pusher_piece_id, restriction.pushed_piece_id],
        ),
        None => hash_byte(&mut hash, 0),
    }
    match (snapshot.winner, snapshot.win_reason) {
        (Some(player), Some(reason)) => hash_bytes(
            &mut hash,
            &[1, player_byte(player), win_reason_byte(reason)],
        ),
        (None, None) => hash_byte(&mut hash, 0),
        _ => hash_byte(&mut hash, 0xff),
    }

    format!("{hash:016x}")
}

fn hash_bytes(hash: &mut u64, bytes: &[u8]) {
    for byte in bytes {
        hash_byte(hash, *byte);
    }
}

fn hash_byte(hash: &mut u64, byte: u8) {
    *hash ^= u64::from(byte);
    *hash = hash.wrapping_mul(SNAPSHOT_HASH_PRIME);
}

fn player_byte(player: GamePlayer) -> u8 {
    match player {
        GamePlayer::First => 0,
        GamePlayer::Second => 1,
    }
}

fn tile_byte(tile: GameTileKind) -> u8 {
    match tile {
        GameTileKind::Normal => 0,
        GameTileKind::Damaged => 1,
        GameTileKind::Hole => 2,
    }
}

fn win_reason_byte(reason: GameWinReason) -> u8 {
    match reason {
        GameWinReason::Knockout => 0,
        GameWinReason::Immobilization => 1,
    }
}

fn game_move_from_engine(game_move: Move) -> GameMove {
    GameMove {
        piece_id: game_move.piece.0,
        direction: game_move.direction.into(),
    }
}

fn move_to_engine(game_move: GameMove) -> Move {
    Move::new(PieceId(game_move.piece_id), game_move.direction.into())
}

fn state_error(error: StateError) -> String {
    format!("invalid snapshot: {error:?}")
}

fn illegal_move_error(error: IllegalMove) -> String {
    format!("illegal move: {error:?}")
}

impl From<Player> for GamePlayer {
    fn from(player: Player) -> Self {
        match player {
            Player::First => Self::First,
            Player::Second => Self::Second,
        }
    }
}

impl From<GamePlayer> for Player {
    fn from(player: GamePlayer) -> Self {
        match player {
            GamePlayer::First => Self::First,
            GamePlayer::Second => Self::Second,
        }
    }
}

impl From<Direction> for GameDirection {
    fn from(direction: Direction) -> Self {
        match direction {
            Direction::Up => Self::Up,
            Direction::Down => Self::Down,
            Direction::Left => Self::Left,
            Direction::Right => Self::Right,
        }
    }
}

impl From<GameDirection> for Direction {
    fn from(direction: GameDirection) -> Self {
        match direction {
            GameDirection::Up => Self::Up,
            GameDirection::Down => Self::Down,
            GameDirection::Left => Self::Left,
            GameDirection::Right => Self::Right,
        }
    }
}

impl From<Tile> for GameTileKind {
    fn from(tile: Tile) -> Self {
        match tile {
            Tile::Normal => Self::Normal,
            Tile::Damaged => Self::Damaged,
            Tile::Hole => Self::Hole,
        }
    }
}

impl From<GameTileKind> for Tile {
    fn from(tile: GameTileKind) -> Self {
        match tile {
            GameTileKind::Normal => Self::Normal,
            GameTileKind::Damaged => Self::Damaged,
            GameTileKind::Hole => Self::Hole,
        }
    }
}

impl From<WinReason> for GameWinReason {
    fn from(reason: WinReason) -> Self {
        match reason {
            WinReason::Knockout => Self::Knockout,
            WinReason::Immobilization => Self::Immobilization,
        }
    }
}

impl From<GameWinReason> for WinReason {
    fn from(reason: GameWinReason) -> Self {
        match reason {
            GameWinReason::Knockout => Self::Knockout,
            GameWinReason::Immobilization => Self::Immobilization,
        }
    }
}
