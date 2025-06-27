use crate::errors::AppError;

use std::fs::File;

use std::path::PathBuf;

#[cfg(any(target_os = "windows", target_os = "linux"))]
pub async fn ensure_version_dll_exists(
    game_path: &std::path::Path,
) -> Result<Option<PathBuf>, AppError> {
    use std::fs::File;

    let dll_path = game_path.join("version.dll");

    if dll_path.exists() {
        return Ok(Some(dll_path));
    }
    // if the dll doesn't exist, download it

    let mut outfile = match File::create(&dll_path) {
        Ok(f) => f,
        Err(e) => {
            #[cfg(target_os = "linux")]
            if let Some(errno) = e.raw_os_error() {
                if errno == /* (30) - Read-only filesystem */ libc::EROFS
                    || errno == /* (13) - Permission denied */ libc::EACCES
                {
                    log::error!(
                        "Failed to create file '{}', path not writable ({}). This error will be ignored and you have to manually install lovely instead.",
                        dll_path.display(),
                        errno,
                    );
                    return Ok(None);
                }
            }
            return Err(AppError::FileWrite {
                path: dll_path.clone(),
                source: e.to_string(),
            })
            .inspect_err(|e| {
                log::error!("Failed to create file '{}': {}", dll_path.display(), e);
            });
        }
    };
    download_version_dll(&mut outfile).await?;

    Ok(Some(dll_path))
}

#[cfg(target_os = "macos")]
fn detect_architecture() -> Result<&'static str, AppError> {
    use libc::{c_void, size_t, sysctl};

    let mut size: size_t = 0;
    let mut mib = [libc::CTL_HW, libc::HW_MACHINE];

    // First call to get buffer size
    unsafe {
        if sysctl(
            mib.as_mut_ptr(),
            2,
            std::ptr::null_mut(),
            &mut size,
            std::ptr::null_mut(),
            0,
        ) != 0
        {
            return Err(AppError::SystemDetection(
                "Failed to get architecture buffer size".into(),
            ));
        }
    }

    let mut buf = vec![0u8; size];

    // Second call to get actual value
    unsafe {
        if sysctl(
            mib.as_mut_ptr(),
            2,
            buf.as_mut_ptr() as *mut c_void,
            &mut size,
            std::ptr::null_mut(),
            0,
        ) != 0
        {
            return Err(AppError::SystemDetection(
                "Failed to retrieve architecture".into(),
            ));
        }
    }

    // Convert buffer to string and match architecture
    match String::from_utf8_lossy(&buf).trim_end_matches('\0') {
        "arm64" => Ok("aarch64"),
        "x86_64" => Ok("x86_64"),
        other => Err(AppError::UnsupportedArchitecture(other.into())),
    }
}

pub async fn ensure_lovely_exists() -> Result<PathBuf, AppError> {
    #[cfg(target_os = "macos")]
    {
        use std::fs;

        let config_dir = dirs::config_dir()
            .ok_or_else(|| AppError::DirNotFound(PathBuf::from("config directory")))?;

        let bins_dir = config_dir.join("Balatro/bins");
        fs::create_dir_all(&bins_dir).map_err(|e| AppError::DirCreate {
            path: bins_dir.clone(),
            source: e.to_string(),
        })?;

        let lovely_path = bins_dir.join("liblovely.dylib");

        if !lovely_path.exists() {
            download_and_install_lovely(&lovely_path).await?;
        }

        Ok(lovely_path)
    }

    #[cfg(target_os = "windows")]
    {
        let balatro_paths = crate::finder::get_balatro_paths();
        if balatro_paths.is_empty() {
            return Err(AppError::DirNotFound(PathBuf::from("Balatro installation")));
        }

        // Ensure version.dll exists in the game directory
        let game_path = &balatro_paths[0];
        ensure_version_dll_exists(game_path).await?;

        Ok(game_path.join("Balatro.exe"))
    }

    #[cfg(target_os = "linux")]
    {
        let balatro_paths = crate::finder::get_balatro_paths();
        if balatro_paths.is_empty() {
            return Err(AppError::DirNotFound(PathBuf::from("Balatro installation")));
        }

        // Ensure version.dll exists in the game directory
        let game_path = &balatro_paths[0];
        ensure_version_dll_exists(game_path).await?;

        // For Linux/Proton, we return the path to version.dll
        Ok(game_path.join("version.dll"))
    }

    #[cfg(not(any(target_os = "macos", target_os = "windows", target_os = "linux")))]
    {
        Err(AppError::InvalidState(
            "Lovely injection is not supported on this platform.".into(),
        ))
    }
}

#[cfg(target_os = "macos")]
async fn download_and_install_lovely(target_path: &Path) -> Result<(), AppError> {
    use std::{fs, os::unix::fs::PermissionsExt};

    let temp_dir = tempfile::tempdir().map_err(|e| AppError::FileWrite {
        path: PathBuf::from("temp directory"),
        source: e.to_string(),
    })?;

    let arch = detect_architecture()?;
    let url = format!(
        "https://github.com/ethangreen-dev/lovely-injector/releases/latest/download/\
    lovely-{}-apple-darwin.tar.gz",
        arch
    );

    // Download latest release
    let client = reqwest::Client::new();
    let response = client
        .get(url)
        .send()
        .await
        .map_err(|e| AppError::Network(e.to_string()))?;

    // Save to temp file
    let temp_tar_gz = temp_dir.path().join("lovely.tar.gz");
    let mut file = File::create(&temp_tar_gz).map_err(|e| AppError::FileWrite {
        path: temp_tar_gz.clone(),
        source: e.to_string(),
    })?;

    let bytes = response
        .bytes()
        .await
        .map_err(|e| AppError::Network(e.to_string()))?;
    std::io::copy(&mut bytes.as_ref(), &mut file).map_err(|e| AppError::FileWrite {
        path: temp_tar_gz.clone(),
        source: e.to_string(),
    })?;

    // Extract and install
    let tar_gz = File::open(&temp_tar_gz).map_err(|e| AppError::FileRead {
        path: temp_tar_gz.clone(),
        source: e.to_string(),
    })?;
    let tar = flate2::read::GzDecoder::new(tar_gz);
    let mut archive = tar::Archive::new(tar);

    archive.unpack(&temp_dir).map_err(|e| AppError::FileRead {
        path: temp_tar_gz.clone(),
        source: e.to_string(),
    })?;

    // Find the library in extracted files
    let extracted_lib = temp_dir.path().join("liblovely.dylib");
    fs::copy(&extracted_lib, target_path).map_err(|e| AppError::FileCopy {
        source: extracted_lib.display().to_string(),
        dest: target_path.display().to_string(),
        source_error: e.to_string(),
    })?;

    // Set permissions
    std::fs::set_permissions(target_path, std::fs::Permissions::from_mode(0o755))?;

    Ok(())
}

#[cfg(any(target_os = "windows", target_os = "linux"))]
async fn download_version_dll(outfile: &mut File) -> Result<(), AppError> {
    let temp_dir = tempfile::tempdir().map_err(|e| AppError::FileWrite {
        path: PathBuf::from("temp directory"),
        source: e.to_string(),
    })?;

    // URL to the latest version.dll in the lovely injector repository
    let url = "https://github.com/ethangreen-dev/lovely-injector/releases/latest/download/lovely-x86_64-pc-windows-msvc.zip";

    #[cfg(target_os = "windows")]
    log::info!("Downloading lovely injector for Windows from {}", url);

    #[cfg(target_os = "linux")]
    log::info!("Downloading lovely injector for Linux/Proton from {url}");

    // Download the ZIP file
    let client = reqwest::Client::new();
    let response = client
        .get(url)
        .send()
        .await
        .map_err(|e| AppError::Network(format!("Failed to download lovely injector: {e}")))?;

    // Save to temp zip file
    let temp_zip = temp_dir.path().join("lovely.zip");
    let mut file = File::create(&temp_zip).map_err(|e| AppError::FileWrite {
        path: temp_zip.clone(),
        source: e.to_string(),
    })?;

    let bytes = response
        .bytes()
        .await
        .map_err(|e| AppError::Network(format!("Failed to read download response: {e}")))?;

    std::io::copy(&mut bytes.as_ref(), &mut file).map_err(|e| AppError::FileWrite {
        path: temp_zip.clone(),
        source: e.to_string(),
    })?;

    // Extract the ZIP file
    let zip_file = File::open(&temp_zip).map_err(|e| AppError::FileRead {
        path: temp_zip.clone(),
        source: e.to_string(),
    })?;

    let mut archive = zip::ZipArchive::new(zip_file).map_err(|e| AppError::FileRead {
        path: temp_zip.clone(),
        source: e.to_string(),
    })?;

    // Find and extract version.dll from the ZIP
    for i in 0..archive.len() {
        let mut file = match archive.by_index(i) {
            Ok(file) => file,
            Err(e) => {
                log::warn!("Failed to access zip entry: {e}");
                continue;
            }
        };

        let entry_name = file.name().to_string();

        if entry_name.ends_with("version.dll") {
            log::info!("Found version.dll in zip archive");
            std::io::copy(&mut file, outfile)?;
            return Ok(());
        }
    }

    Err(AppError::InvalidState(
        "version.dll not found in downloaded zip".to_string(),
    ))
}
