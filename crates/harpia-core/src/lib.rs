// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

//! Harpia domain model: tasks, oracles, trials, metrics, scoring, statistics.
//!
//! The modules split along one line: `metrics`/`scoring` describe how a
//! harness did, while `matrix`/`psychometrics`/`robustness` describe how well
//! the benchmark itself measured that. The second group never reads the
//! database or the filesystem — it takes a score matrix and returns numbers,
//! so every meta-evaluation claim is unit-testable against a hand-built case.

pub mod hash;
pub mod matrix;
pub mod metrics;
pub mod psychometrics;
pub mod rng;
pub mod robustness;
pub mod scoring;
pub mod stats;
pub mod task;
