use clap::{Subcommand, ValueEnum};
use strata_core::desktop::bar;

#[derive(Subcommand, Debug)]
pub enum BarCommand {
    Use { id: String },
    Reset,
    Defaults,
    Position { position: PositionArg },
}

impl BarCommand {
    pub fn run(self) -> anyhow::Result<()> {
        Ok(())
    }
}

#[derive(Subcommand, Debug)]
pub enum Transparent {
    Top,
}

#[derive(Debug, ValueEnum, Clone, Copy)]
pub enum PositionArg {
    Top,
    Bottom,
    Left,
    Right,
}
impl From<PositionArg> for bar::Position {
    fn from(value: PositionArg) -> Self {
        match value {
            PositionArg::Top => Self::Top,
            PositionArg::Bottom => Self::Bottom,
            PositionArg::Left => Self::Left,
            PositionArg::Right => Self::Right,
        }
    }
}
