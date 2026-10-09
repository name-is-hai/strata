mod cli;
mod commands;

use clap::Parser;

fn main() -> anyhow::Result<()> {
    cli::Cli::parse().command.run()
}
