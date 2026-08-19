//! Trial orchestration: one sandbox directory per trial, a worker pool sized
//! to the machine, hard wall-clock kills, and every result written to the
//! store before the sandbox is torn down.
