use log::error;
use log::info;
use std::path::PathBuf;

#[cfg(target_os = "windows")]
fn read_path_from_registry() -> Result<String, std::io::Error> {
    use winreg::enums::HKEY_LOCAL_MACHINE;

    let hklm = winreg::RegKey::predef(HKEY_LOCAL_MACHINE);
    let steam_path = hklm.open_subkey("SOFTWARE\\WOW6432Node\\Valve\\Steam")?;

    Ok(steam_path.get_value("InstallPath")?)
}

fn remove_unexisting_paths(paths: &mut Vec<PathBuf>) {
    let mut i = 0;
    while i < paths.len() {
        if paths[i].exists() {
            i += 1;
        } else {
            paths.remove(i);
        }
    }
    info!("Found {} Balatro installations.", paths.len());
}

#[cfg(target_os = "windows")]
pub fn get_balatro_paths() -> Vec<PathBuf> {
    use std::fs::File;
    use std::io::{BufReader, Read};
    use std::path::Path;

    let steam_path = read_path_from_registry();
    let mut steam_path = steam_path.unwrap_or_else(|_| {
        error!("Could not read steam install path from Registry! Trying standard installation path in C:\\");
        String::from("C:\\Program Files (x86)\\Steam")
    });

    steam_path.push_str("\\steamapps\\libraryfolders.vdf");
    let libraryfolders_path = Path::new(&steam_path);
    if !libraryfolders_path.exists() {
        error!("'{}' not found.", libraryfolders_path.to_str().unwrap());
        return vec![];
    }

    let libraryfolders_file =
        File::open(libraryfolders_path).expect("Failed to open libraryfolders.vdf");
    let mut libraryfolders_contents = String::new();
    let mut libraryfolders_reader = BufReader::new(libraryfolders_file);
    libraryfolders_reader
        .read_to_string(&mut libraryfolders_contents)
        .expect("Failed to read libraryfolders.vdf");

    let mut paths: Vec<PathBuf> = vec![];
    let libraryfolders_contents = libraryfolders_contents.split('\n').collect::<Vec<&str>>();
    let mut libraryfolders_contents = libraryfolders_contents.iter();
    while let Some(line) = libraryfolders_contents.next() {
        if line.contains("\t\t\"path\"\t\t") {
            let path = line.split('\"').collect::<Vec<&str>>()[3];
            paths.push(PathBuf::from(path).join("steamapps\\common\\Balatro"));
        }
    }
    remove_unexisting_paths(&mut paths);
    paths
}

#[cfg(target_os = "macos")]
pub fn get_balatro_paths() -> Vec<PathBuf> {
    let mut paths: Vec<PathBuf> = vec![];
    match home::home_dir() {
        Some(path) => {
            let mut path = path;
            path.push("Library/Application Support/Steam/steamapps/common/Balatro");
            paths.push(path);
        }
        None => error!("Impossible to get your home dir!"),
    }
    remove_unexisting_paths(&mut paths);
    paths
}

pub fn get_lovely_mods_dir(
    #[cfg(target_os = "linux")] installation_path: Option<&String>,
    #[cfg(not(target_os = "linux"))] _installation_path: Option<&String>,
) -> PathBuf {
    #[cfg(target_os = "linux")]
    {
        // probably ~/.steam/steam/steamapps/
        let prefix = {
            let installation_path = installation_path.map_or(PathBuf::new(), PathBuf::from);
            log::debug!("installation_path: {installation_path:?}");
            if installation_path.ends_with("steamapps/common/Balatro/") {
                installation_path
                    .parent()
                    .unwrap()
                    .parent()
                    .unwrap()
                    .to_path_buf()
            } else {
                dirs::home_dir().unwrap().join(".steam/steam/steamapps/")
            }
        };
        log::info!("Assuming steam wineprefix: `{}`", prefix.to_string_lossy());

        prefix.join("compatdata/2379780/pfx/drive_c/users/steamuser/AppData/Roaming/Balatro/Mods")
    }
    #[cfg(not(target_os = "linux"))]
    {
        let mut path = dirs::config_dir().unwrap();
        path.push("Balatro");
        path.push("Mods");
        path
    }
}

#[cfg(target_os = "linux")]
#[must_use]
pub fn get_balatro_paths() -> Vec<PathBuf> {
    let mut paths: Vec<PathBuf> = vec![];
    match home::home_dir() {
        Some(path) => {
            let mut path = path;
            path.push(".local/share/Steam/steamapps/common/Balatro");
            paths.push(path);
        }
        None => error!("Impossible to get your home dir!"),
    }
    remove_unexisting_paths(&mut paths);
    paths
}

#[must_use]
pub fn is_steam_running() -> bool {
    #[cfg(target_os = "windows")]
    {
        let system = sysinfo::System::new_all();
        let x = system
            .processes_by_exact_name(std::ffi::OsStr::new("steam.exe"))
            .next()
            .is_some();
        x
    }

    #[cfg(target_os = "macos")]
    {
        use libproc::proc_pid::name;
        use libproc::processes;

        if let Ok(pids) = processes::pids_by_type(processes::ProcFilter::All) {
            for pid in pids {
                if let Ok(name) = name(pid as i32) {
                    if name.to_lowercase().contains("steam") {
                        return true;
                    }
                }
            }
        }
        false
    }

    #[cfg(target_os = "linux")]
    {
        use std::ffi::OsStr;
        let system = sysinfo::System::new_all();
        ["steam", "steamwebhelper", "steamwebhelper.exe"]
            .iter()
            .any(|p| system.processes_by_name(OsStr::new(p)).next().is_some())
    }
}

#[must_use]
pub fn get_installed_mods(installation_path: Option<&String>) -> Vec<String> {
    let mut installed_mods_paths: Vec<PathBuf> = vec![];
    // let game_path = get_balatro_paths();
    // let game_name: PathBuf = game_path
    //     .first()
    //     .unwrap_or_else(|| panic!("Failed to find Balatro installation path. Is it installed?"))
    //     .to_path_buf();

    let mod_dir = get_lovely_mods_dir(installation_path);

    // dbg!(&mod_dir);

    for entry in mod_dir.read_dir().unwrap() {
        let entry = entry.unwrap();
        if entry.file_type().unwrap().is_dir() {
            installed_mods_paths.push(entry.path());
        }
    }
    // dbg!(&installed_mods_paths);
    let res: Vec<String> = installed_mods_paths
        .iter()
        .map(|p| p.to_str().unwrap().to_string())
        .collect();

    // ignore .lovely and lovely directory
    res.iter()
        .filter(|p| !p.contains(".lovely") && !p.contains("lovely"))
        .map(std::string::ToString::to_string)
        .collect()
}
