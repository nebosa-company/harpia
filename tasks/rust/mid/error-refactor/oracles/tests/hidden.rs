use cfgparse::{try_parse_bool, try_parse_config, try_parse_port, ConfigError, ServerConfig};

#[test]
fn try_parse_config_happy_path() {
    let cfg = try_parse_config("host = example.com\nport = 8080\nworkers = 16\ndebug = true\n")
        .unwrap();
    assert_eq!(
        cfg,
        ServerConfig { host: "example.com".into(), port: 8080, workers: 16, debug: true }
    );
}

#[test]
fn try_parse_config_defaults() {
    let cfg = try_parse_config("host = h\nport = 1\n").unwrap();
    assert_eq!(cfg.workers, 4);
    assert!(!cfg.debug);
}

#[test]
fn missing_required_keys() {
    assert_eq!(try_parse_config(""), Err(ConfigError::Missing("host")));
    assert_eq!(try_parse_config("port = 1\n"), Err(ConfigError::Missing("host")));
    assert_eq!(try_parse_config("host = h\n"), Err(ConfigError::Missing("port")));
    // host is reported before port when both are missing
    assert_eq!(try_parse_config("workers = 2\n"), Err(ConfigError::Missing("host")));
}

#[test]
fn unknown_key() {
    assert_eq!(
        try_parse_config("host = h\nport = 1\ncolor = red\n"),
        Err(ConfigError::UnknownKey("color".to_string()))
    );
}

#[test]
fn invalid_scalars() {
    assert_eq!(try_parse_port("70000"), Err(ConfigError::InvalidPort("70000".to_string())));
    assert_eq!(try_parse_port("nope"), Err(ConfigError::InvalidPort("nope".to_string())));
    assert_eq!(try_parse_port(" -1 "), Err(ConfigError::InvalidPort("-1".to_string())));
    assert_eq!(try_parse_bool("maybe"), Err(ConfigError::InvalidBool("maybe".to_string())));
    assert_eq!(
        try_parse_config("host = h\nport = 1\nworkers = lots\n"),
        Err(ConfigError::InvalidWorkers("lots".to_string()))
    );
}

#[test]
fn valid_scalars() {
    assert_eq!(try_parse_port(" 443 "), Ok(443));
    assert_eq!(try_parse_bool("TRUE"), Ok(true));
    assert_eq!(try_parse_bool(" 0 "), Ok(false));
}

#[test]
fn bad_line_number_counts_comments_and_blanks() {
    assert_eq!(
        try_parse_config("# c\n\nhost = h\nport is 80\n"),
        Err(ConfigError::BadLine(4))
    );
}

#[test]
fn display_messages_are_exact() {
    assert_eq!(ConfigError::Missing("host").to_string(), "missing required key `host`");
    assert_eq!(ConfigError::UnknownKey("foo".into()).to_string(), "unknown key `foo`");
    assert_eq!(ConfigError::InvalidPort("70000".into()).to_string(), "invalid port `70000`");
    assert_eq!(ConfigError::InvalidWorkers("x".into()).to_string(), "invalid workers `x`");
    assert_eq!(ConfigError::InvalidBool("maybe".into()).to_string(), "invalid bool `maybe`");
    assert_eq!(ConfigError::BadLine(3).to_string(), "malformed line 3");
}

#[test]
fn works_as_boxed_error() {
    fn load(src: &str) -> Result<ServerConfig, Box<dyn std::error::Error>> {
        let cfg = try_parse_config(src)?;
        Ok(cfg)
    }
    let err = load("host = h\nport = bad\n").unwrap_err();
    assert_eq!(err.to_string(), "invalid port `bad`");
    assert!(load("host = h\nport = 9\n").is_ok());
}
