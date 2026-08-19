use cfgparse::{parse_bool, parse_config, parse_port, ServerConfig};

#[test]
fn full_config_parses() {
    let cfg = parse_config("host = example.com\nport = 8080\nworkers = 16\ndebug = true\n");
    assert_eq!(
        cfg,
        ServerConfig { host: "example.com".into(), port: 8080, workers: 16, debug: true }
    );
}

#[test]
fn defaults_apply() {
    let cfg = parse_config("host = localhost\nport = 80");
    assert_eq!(cfg.workers, 4);
    assert!(!cfg.debug);
}

#[test]
fn comments_and_blanks_are_skipped() {
    let cfg = parse_config("# comment\n\nhost = h\nport = 1\n");
    assert_eq!(cfg.host, "h");
    assert_eq!(cfg.port, 1);
}

#[test]
fn scalar_helpers() {
    assert_eq!(parse_port("8080"), 8080);
    assert_eq!(parse_port(" 443 "), 443);
    assert!(parse_bool("TRUE"));
    assert!(parse_bool("1"));
    assert!(!parse_bool("0"));
    assert!(!parse_bool("False"));
}
