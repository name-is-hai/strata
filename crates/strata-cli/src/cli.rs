use clap::{Parser, Subcommand};
use crate::commands::bar::BarCommand;

#[derive(Parser)]
#[command(name = "strata", version, about = "Strata desktop command line")]
pub struct Cli {
    #[command(subcommand)]
    pub command: Command,
}

#[derive(Subcommand)]
pub enum Command {
    Bar {
        #[command(subcommand)]
        command: BarCommand,
    },
}

impl Command {
    pub fn run(self) -> anyhow::Result<()> {
        match self {
            Self::Bar { command } => command.run(),
        }
    }
}
