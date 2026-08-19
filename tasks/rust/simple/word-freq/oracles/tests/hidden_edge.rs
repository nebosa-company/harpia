use std::process::Command;

fn write_temp(name: &str, contents: &str) -> std::path::PathBuf {
    let dir = std::path::Path::new("target").join("test-tmp");
    std::fs::create_dir_all(&dir).unwrap();
    let path = dir.join(name);
    std::fs::write(&path, contents).unwrap();
    path
}

#[test]
fn cli_prints_ranked_words() {
    let file = write_temp("cli_basic.txt", "Red green RED blue red GREEN");
    let out = Command::new(env!("CARGO_BIN_EXE_word_freq"))
        .arg(&file)
        .output()
        .unwrap();
    assert_eq!(out.status.code(), Some(0));
    let stdout = String::from_utf8(out.stdout).unwrap().replace("\r\n", "\n");
    assert_eq!(stdout, "red 3\ngreen 2\nblue 1\n");
}

#[test]
fn cli_honors_limit_argument() {
    let file = write_temp("cli_limit.txt", "one two two three three three");
    let out = Command::new(env!("CARGO_BIN_EXE_word_freq"))
        .arg(&file)
        .arg("1")
        .output()
        .unwrap();
    assert_eq!(out.status.code(), Some(0));
    let stdout = String::from_utf8(out.stdout).unwrap().replace("\r\n", "\n");
    assert_eq!(stdout, "three 3\n");
}

#[test]
fn cli_missing_argument_is_exit_2() {
    let out = Command::new(env!("CARGO_BIN_EXE_word_freq")).output().unwrap();
    assert_eq!(out.status.code(), Some(2));
}

#[test]
fn cli_unreadable_file_is_exit_2() {
    let out = Command::new(env!("CARGO_BIN_EXE_word_freq"))
        .arg("target/test-tmp/definitely-missing-file.txt")
        .output()
        .unwrap();
    assert_eq!(out.status.code(), Some(2));
}

#[test]
fn cli_bad_limit_is_exit_2() {
    let file = write_temp("cli_badn.txt", "alpha beta");
    let out = Command::new(env!("CARGO_BIN_EXE_word_freq"))
        .arg(&file)
        .arg("many")
        .output()
        .unwrap();
    assert_eq!(out.status.code(), Some(2));
}
