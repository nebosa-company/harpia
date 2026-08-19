//! Oracle execution: hidden tests, builds, static checks, security probes.
//! Oracles run after the harness has exited, against the mutated workspace,
//! with the network and the harness's credentials out of reach.

pub struct OracleOutcome {
    pub passed: bool,
    pub weight: f64,
    pub detail: String,
}
