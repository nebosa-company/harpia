use clap::{Parser, Subcommand};

#[derive(Parser)]
#[command(name = "harpia", version, about = "Agentic harness benchmark")]
struct Cli {
    #[command(subcommand)]
    cmd: Cmd,
}

#[derive(Subcommand)]
enum Cmd {
    /// Run a benchmark round: a harness+model over the task corpus.
    Run,
    /// Resume an interrupted round from the database.
    Resume,
    /// Validate the task corpus (reference solutions pass, starters fail).
    Validate,
    /// Render a round's scorecard.
    Report,
    /// Paired statistical comparison of two rounds.
    Compare,
}

fn main() -> anyhow::Result<()> {
    let cli = Cli::parse();
    match cli.cmd {
        Cmd::Run | Cmd::Resume | Cmd::Validate | Cmd::Report | Cmd::Compare => {
            eprintln!("not implemented yet");
            std::process::exit(2);
        }
    }
}
