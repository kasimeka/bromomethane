#![deny(
    missing_debug_implementations,
    rust_2018_idioms,
    clippy::complexity,
    clippy::correctness
)]
#![warn(clippy::perf, clippy::pedantic)]
#![allow(clippy::missing_errors_doc)]

pub mod cache;
pub mod database;
pub mod errors;
pub mod finder;
pub mod installer;
pub mod local_mod_detection;
pub mod logging;
pub mod lovely;
pub mod mod_collections;
pub mod smods_installer;
