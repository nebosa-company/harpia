use cfgparse::{parse_bool, parse_config, parse_port, ConfigError, ServerConfig};

fn panic_message(f: impl FnOnce() + std::panic::UnwindSafe) -> String {
    let payload = std::panic::catch_unwind(f).expect_err("expected a panic");
    if let Some(s) = payload.downcast_ref::<String>() {
        s.clone()
    } else if let Some(s) = payload.downcast_ref::<&str>() {
        (*s).to_string()
    } else {
        panic!("panic payload was not a string")
    }
}

#[test]
fn old_api_happy_paths_unchanged() {
    let cfg = parse_config("host = example.com\nport = 8080\nworkers = 2\ndebug = 1\n");
    assert_eq!(
        cfg,
        ServerConfig { host: "example.com".into(), port: 8080, workers: 2, debug: true }
    );
    assert_eq!(parse_port("65535"), 65535);
    assert!(!parse_bool("FALSE"));
}

#[test]
fn old_api_panics_with_display_messages() {
    let msg = panic_message(|| {
        parse_port("nope");
    });
    assert_eq!(msg, "invalid port `nope`");

    let msg = panic_message(|| {
        parse_bool("maybe");
    });
    assert_eq!(msg, "invalid bool `maybe`");

    let msg = panic_message(|| {
        parse_config("port = 80\n");
    });
    assert_eq!(msg, "missing required key `host`");

    let msg = panic_message(|| {
        parse_config("host = h\nport = 80\nzzz = 1\n");
    });
    assert_eq!(msg, "unknown key `zzz`");
}

#[test]
fn error_type_is_a_std_error() {
    fn assert_error<E: std::error::Error>() {}
    assert_error::<ConfigError>();
}

#[test]
fn variant_equality_is_derived() {
    assert_eq!(ConfigError::BadLine(2), ConfigError::BadLine(2));
    assert_ne!(ConfigError::BadLine(2), ConfigError::BadLine(3));
    assert_ne!(
        ConfigError::InvalidPort("1".into()),
        ConfigError::InvalidWorkers("1".into())
    );
}
