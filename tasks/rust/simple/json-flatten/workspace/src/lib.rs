//! Flatten a JSON object into dotted-path keys, std-only (no serde).

use std::collections::BTreeMap;

/// Flatten the JSON object in `input` into `path.to.leaf -> rendered value`
/// entries. See the crate documentation for the accepted subset. Returns
/// `Err(message)` on any malformed input.
pub fn flatten(input: &str) -> Result<BTreeMap<String, String>, String> {
    let _ = input;
    todo!("parse the JSON subset and flatten it")
}
