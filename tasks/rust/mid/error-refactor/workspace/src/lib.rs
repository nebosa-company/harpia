//! Server-config parsing. Historical behavior: invalid input panics.

/// Parsed server configuration.
#[derive(Debug, PartialEq, Clone)]
pub struct ServerConfig {
    pub host: String,
    pub port: u16,
    pub workers: u32,
    pub debug: bool,
}

/// Parse `key = value` lines into a config.
///
/// Lines are trimmed; blank lines and lines starting with '#' are skipped.
/// Keys: host (required), port (required), workers (default 4), debug
/// (default false). Panics on any invalid input.
pub fn parse_config(src: &str) -> ServerConfig {
    let mut host: Option<String> = None;
    let mut port: Option<u16> = None;
    let mut workers: u32 = 4;
    let mut debug = false;
    for (idx, raw) in src.lines().enumerate() {
        let line = raw.trim();
        if line.is_empty() || line.starts_with('#') {
            continue;
        }
        let (key, value) = line
            .split_once('=')
            .unwrap_or_else(|| panic!("malformed line {}", idx + 1));
        let (key, value) = (key.trim(), value.trim());
        match key {
            "host" => host = Some(value.to_string()),
            "port" => port = Some(parse_port(value)),
            "workers" => workers = value.parse().unwrap(),
            "debug" => debug = parse_bool(value),
            other => panic!("unknown key `{other}`"),
        }
    }
    ServerConfig {
        host: host.expect("missing required key `host`"),
        port: port.expect("missing required key `port`"),
        workers,
        debug,
    }
}

/// Parse a TCP port. Panics when the text is not a valid port number.
pub fn parse_port(s: &str) -> u16 {
    s.trim().parse().unwrap()
}

/// Parse a boolean flag: true/false/1/0, case-insensitive. Panics otherwise.
pub fn parse_bool(s: &str) -> bool {
    match s.trim().to_ascii_lowercase().as_str() {
        "true" | "1" => true,
        "false" | "0" => false,
        other => panic!("invalid bool `{other}`"),
    }
}
