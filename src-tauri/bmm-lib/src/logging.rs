use crate::errors::AppError;
use chrono::Local;
use log::LevelFilter;
use std::fs;
use std::io::{self, Write};
use std::path::PathBuf;
use std::sync::atomic::{AtomicBool, Ordering};

static LOGGER_INITIALIZED: AtomicBool = AtomicBool::new(false);

pub fn init_logger() -> Result<(), AppError> {
    // Only initialize once
    if LOGGER_INITIALIZED.swap(true, Ordering::SeqCst) {
        return Ok(());
    }

    // Create log directory in config dir
    let config_dir = dirs::config_dir()
        .ok_or_else(|| AppError::DirNotFound(PathBuf::from("config directory")))?;
    let log_dir = config_dir.join("Balatro").join("logs");

    fs::create_dir_all(&log_dir).map_err(|e| AppError::DirCreate {
        path: log_dir.clone(),
        source: e.to_string(),
    })?;

    // Create a unique log file with timestamp
    let timestamp = Local::now().format("%Y-%m-%d_%H-%M-%S").to_string();
    let log_file = log_dir.join(format!("bmm_{}.log", timestamp));

    // Clean up old log files
    cleanup_old_logs(&log_dir)?;

    // Open log file
    let file = fs::OpenOptions::new()
        .create(true)
        .append(true)  // removed .write(true)
        .open(&log_file)
        .map_err(|e| AppError::FileWrite {
            path: log_file.clone(),
            source: e.to_string(),
        })?;

    // Create a combined writer for both file and stdout
    let file_writer = CustomWriter { file };

    // Initialize env_logger with our custom writer
    env_logger::Builder::new()
        .format(|buf, record| {
            writeln!(
                buf,
                "[{}] {} [{}] {}",
                Local::now().format("%Y-%m-%d %H:%M:%S"),
                record.level(),
                record.target(),
                record.args()
            )
        })
        .filter(None, LevelFilter::Debug) // Capture all logs
        .write_style(env_logger::WriteStyle::Never)
        .target(env_logger::Target::Pipe(Box::new(file_writer)))
        .init();

    // Log some initial messages to test
    log::info!("Logging system initialized at {}", Local::now());
    log::info!("Log file: {}", log_file.display());
    log::debug!("Debug logging is enabled");

    Ok(())
}

// Custom writer that writes to both a file and stdout
struct CustomWriter {
    file: fs::File,
}

impl Write for CustomWriter {
    fn write(&mut self, buf: &[u8]) -> io::Result<usize> {
        // Print to stdout
        let stdout_result = io::stdout().write(buf);

        // Write to file
        match self.file.write(buf) {
            Ok(bytes_written) => {
                let _ = self.file.flush();
                Ok(bytes_written)
            }
            Err(e) => {
                eprintln!("Failed to write to log file: {}", e);
                stdout_result // Return stdout result if file write fails
            }
        }
    }

    fn flush(&mut self) -> io::Result<()> {
        let _ = io::stdout().flush();
        self.file.flush()
    }
}

fn cleanup_old_logs(log_dir: &PathBuf) -> Result<(), AppError> {
    let max_logs = 10;

    if let Ok(entries) = fs::read_dir(log_dir) {
        let mut log_files: Vec<_> = entries
            .filter_map(Result::ok)
            .filter(|entry| {
                entry.path().extension().is_some_and(|ext| ext == "log")
                    && entry
                        .path()
                        .file_name()
                        .is_some_and(|name| name.to_string_lossy().starts_with("bmm_"))
            })
            .collect();

        // Sort files by modification time (oldest first)
        log_files.sort_by(|a, b| {
            let a_time = a
                .metadata()
                .and_then(|m| m.modified())
                .unwrap_or_else(|_| std::time::SystemTime::now());
            let b_time = b
                .metadata()
                .and_then(|m| m.modified())
                .unwrap_or_else(|_| std::time::SystemTime::now());
            a_time.cmp(&b_time)
        });

        // Remove older logs if we have more than max_logs
        if log_files.len() > max_logs {
            for old_file in log_files.iter().take(log_files.len() - max_logs) {
                let _ = fs::remove_file(old_file.path());
            }
        }
    }

    Ok(())
}

