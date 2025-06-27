#![deny(
    missing_debug_implementations,
    rust_2018_idioms,
    clippy::complexity,
    clippy::correctness
)]
#![warn(clippy::perf, clippy::pedantic)]
// Prevents additional console window on Windows in release, DO NOT REMOVE!!
#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]
fn main() {
    let _ = fix_path_env::fix();
    if let Err(e) = bmm_lib::logging::init_logger() {
        eprintln!("Failed to initialize logging: {e}");
    }
    bromomethane::run();
    log::logger().flush();
}
