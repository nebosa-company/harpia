//! The manifests shipped in `harnesses/` must always load.

use harpia_harness::{Lifecycle, Manifest, TelemetryKind};
use std::path::Path;

#[test]
fn shipped_manifests_load() {
    let dir = Path::new(env!("CARGO_MANIFEST_DIR")).join("../../harnesses");
    let all = Manifest::load_dir(&dir).unwrap();
    assert!(all.len() >= 3, "expected perpetum, dsh, claude-code; got {:?}", all.keys());

    let perp = &all["perpetum"];
    assert_eq!(perp.lifecycle, Lifecycle::Perpetum);
    assert_eq!(perp.telemetry, TelemetryKind::PerpetumJournal);
    assert_eq!(perp.telemetry_path.as_deref(), Some(".harness/journal.jsonl"));

    let dsh = &all["dsh"];
    assert_eq!(dsh.telemetry, TelemetryKind::ProxyJsonl);
    assert_eq!(dsh.telemetry_path.as_deref(), Some("../dsh-usage.jsonl"));
    assert!(dsh.upstream.is_some());

    let cc = &all["claude-code"];
    assert_eq!(cc.telemetry, TelemetryKind::ClaudeStreamJson);
    assert!(cc.command.iter().any(|a| a == "stream-json"));
}
