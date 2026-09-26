use std::collections::{BTreeMap, BTreeSet};
use std::fs;

use engine::{BoardConfig, Piece, PieceId, Player, Position, Tile};

#[derive(Debug)]
pub struct SelectedBoard {
    pub id: String,
    pub config: BoardConfig,
    pub initial_tiles: Vec<InitialTile>,
    pub initial_pieces: Vec<InitialPiece>,
}

#[derive(Debug)]
pub struct InitialTile {
    pub x: u8,
    pub y: u8,
    pub kind: Tile,
}

#[derive(Debug)]
pub struct InitialPiece {
    pub id: u8,
    pub owner: Player,
    pub x: u8,
    pub y: u8,
}

pub fn read(path: &str) -> Result<SelectedBoard, String> {
    let contents = fs::read_to_string(path)
        .map_err(|error| format!("cannot read board file {path}: {error}"))?;
    let mut lines = contents.lines().enumerate();
    let Some((_, header)) = lines.next() else {
        return Err("missing board file header".to_owned());
    };
    let mut header = header.split_whitespace();
    let version = header
        .next()
        .ok_or_else(|| "missing board file header".to_owned())?;
    if version != "ttush-board-v1" {
        return Err(format!("unknown board file version: {version}"));
    }
    let id = header
        .next()
        .ok_or_else(|| "missing board identifier".to_owned())?;
    if header.next().is_some() || !valid_identifier(id) {
        return Err(format!("invalid board identifier: {id}"));
    }

    let mut cells = BTreeSet::new();
    let mut pieces = Vec::new();
    let mut tiles = Vec::new();
    for (index, row) in lines {
        let line = index + 1;
        let fields = row.split_whitespace().collect::<Vec<_>>();
        let Some(kind) = fields.first() else {
            return Err(format!("invalid board row {line}"));
        };
        match *kind {
            "cell" => {
                if fields.len() != 3 {
                    return Err(format!("invalid board row {line}"));
                }
                let x = parse_coordinate(fields[1], "x", line)?;
                let y = parse_coordinate(fields[2], "y", line)?;
                if !cells.insert((x, y)) {
                    return Err(format!("duplicate cell at row {line}"));
                }
            }
            "piece" => {
                if fields.len() != 5 {
                    return Err(format!("invalid board row {line}"));
                }
                pieces.push(InitialPiece {
                    id: parse_coordinate(fields[1], "piece id", line)?,
                    owner: parse_player(fields[2], line)?,
                    x: parse_coordinate(fields[3], "x", line)?,
                    y: parse_coordinate(fields[4], "y", line)?,
                });
            }
            "tile" => {
                if fields.len() != 4 {
                    return Err(format!("invalid board row {line}"));
                }
                tiles.push(InitialTile {
                    x: parse_coordinate(fields[1], "x", line)?,
                    y: parse_coordinate(fields[2], "y", line)?,
                    kind: parse_tile(fields[3], line)?,
                });
            }
            _ => return Err(format!("unknown board row at row {line}: {kind}")),
        }
    }

    let playable_cells = cells
        .iter()
        .map(|&(x, y)| Position::new(x, y))
        .collect::<BTreeSet<_>>();
    let config_pieces = pieces
        .iter()
        .map(|piece| {
            Piece::new(
                PieceId(piece.id),
                piece.owner,
                Position::new(piece.x, piece.y),
            )
        })
        .collect();
    let config_tiles = tiles
        .iter()
        .map(|tile| (Position::new(tile.x, tile.y), tile.kind))
        .collect();
    let config = BoardConfig::new(playable_cells, config_pieces)
        .map_err(|error| format!("invalid board configuration: {error:?}"))?
        .with_initial_tiles(config_tiles)
        .map_err(|error| format!("invalid board configuration: {error:?}"))?;

    let initial_tiles = cells
        .iter()
        .copied()
        .map(|(x, y)| {
            let kind = config
                .initial_tiles()
                .get(&Position::new(x, y))
                .copied()
                .ok_or_else(|| format!("configured tile missing at {x},{y}"))?;
            Ok(InitialTile { x, y, kind })
        })
        .collect::<Result<Vec<_>, String>>()?;
    let piece_positions = pieces
        .iter()
        .map(|piece| (piece.id, (piece.x, piece.y)))
        .collect::<BTreeMap<_, _>>();
    let mut initial_pieces = config
        .initial_pieces()
        .iter()
        .map(|piece| {
            let (x, y) = piece_positions
                .get(&piece.id.0)
                .copied()
                .ok_or_else(|| format!("configured piece {} is missing coordinates", piece.id.0))?;
            Ok(InitialPiece {
                id: piece.id.0,
                owner: piece.owner,
                x,
                y,
            })
        })
        .collect::<Result<Vec<_>, String>>()?;
    initial_pieces.sort_by_key(|piece| piece.id);

    Ok(SelectedBoard {
        id: id.to_owned(),
        config,
        initial_tiles,
        initial_pieces,
    })
}

fn valid_identifier(id: &str) -> bool {
    !id.is_empty()
        && id
            .bytes()
            .all(|character| character.is_ascii_alphanumeric() || character == b'-')
}

fn parse_coordinate(value: &str, field: &str, line: usize) -> Result<u8, String> {
    value
        .parse()
        .map_err(|_| format!("invalid {field} coordinate at row {line}: {value}"))
}

fn parse_player(value: &str, line: usize) -> Result<Player, String> {
    match value {
        "first" => Ok(Player::First),
        "second" => Ok(Player::Second),
        _ => Err(format!("invalid piece owner at row {line}: {value}")),
    }
}

fn parse_tile(value: &str, line: usize) -> Result<Tile, String> {
    match value {
        "normal" => Ok(Tile::Normal),
        "damaged" => Ok(Tile::Damaged),
        "hole" => Ok(Tile::Hole),
        _ => Err(format!("invalid tile kind at row {line}: {value}")),
    }
}
