use crate::finder::get_lovely_mods_dir;
use anyhow::{anyhow, Context, Result};
use log::info;
use reqwest::header::{HeaderMap, HeaderValue, USER_AGENT};
use serde::{Deserialize, Serialize};
use std::fs;
use std::io::Cursor;
use tokio::fs as tokio_fs;
use zip::ZipArchive;

#[derive(Debug, Serialize, Deserialize)]
struct Release {
    tag_name: String,
    name: String,
    assets: Vec<ReleaseAsset>,
    published_at: String,
    html_url: String,
    prerelease: bool,
    zipball_url: String, // Add this field
}

#[derive(Debug, Clone)]
pub enum ModType {
    Steamodded,
    Talisman,
}

impl std::fmt::Display for ModType {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            ModType::Steamodded => write!(f, "Steamodded"),
            ModType::Talisman => write!(f, "Talisman"),
        }
    }
}

impl ModType {
    fn get_repo_url(&self) -> &str {
        match self {
            ModType::Steamodded => "Steamodded/smods",
            ModType::Talisman => "MathIsFun0/Talisman",
        }
    }

    pub async fn check_installation(&self, installation_path: Option<&String>) -> bool {
        match self {
            ModType::Steamodded => {
                let installer = ModInstaller::new(installation_path, ModType::Steamodded);
                installer.is_installed()
            }
            ModType::Talisman => {
                let installer = ModInstaller::new(installation_path, ModType::Talisman);
                installer.is_installed()
            }
        }
    }
}

#[derive(Debug, Serialize, Deserialize)]
struct ReleaseAsset {
    name: String,
    browser_download_url: String,
}
#[derive(Debug)]
pub struct ModInstaller {
    client: reqwest::Client,
    pub mod_type: ModType,
    pub installation_path: Option<String>,
}

impl ModInstaller {
    #[must_use]
    pub fn new(installation_path: Option<&String>, mod_type: ModType) -> Self {
        Self {
            client: reqwest::Client::new(),
            mod_type,
            installation_path: installation_path.cloned(),
        }
    }

    #[must_use]
    pub fn is_installed(&self) -> bool {
        let mods_dir = get_lovely_mods_dir(self.installation_path.as_ref());

        fs::read_dir(mods_dir)
            .map(|mut entries| {
                entries.any(|e| {
                    e.ok().is_some_and(|entry| {
                        let binding = entry.file_name();
                        let name = binding.to_str().unwrap_or("");
                        match self.mod_type {
                            ModType::Steamodded => name.starts_with("Steamodded-smods-"),
                            ModType::Talisman => name.contains("Talisman"),
                        }
                    })
                })
            })
            .unwrap_or(false)
    }

    pub async fn get_latest_release(&self) -> Result<String> {
        let versions = self.get_available_versions().await?;
        Ok(versions[0].clone())
    }

    pub async fn get_available_versions(&self) -> Result<Vec<String>> {
        let mut headers = HeaderMap::new();
        headers.insert(
            USER_AGENT,
            HeaderValue::from_static("Balatro-Mod-Manager/1.0"),
        );
        headers.insert(
            "Accept",
            HeaderValue::from_static("application/vnd.github.v3+json"),
        );

        let url = format!(
            "https://api.github.com/repos/{}/releases",
            self.mod_type.get_repo_url()
        );

        let response = self
            .client
            .get(&url)
            .headers(headers)
            .send()
            .await
            .context("Failed to fetch Steamodded releases")?;

        if !response.status().is_success() {
            let status = response.status();
            let error_text = response.text().await?;
            return Err(anyhow::anyhow!(
                "GitHub API error: {} - {}",
                status,
                error_text
            ));
        }

        let releases: Vec<Release> = response
            .json()
            .await
            .context("Failed to decode Steamodded releases")?;

        let mut versions: Vec<String> = releases
            .into_iter()
            .filter(|r| !r.prerelease) // Filter out pre-releases
            .map(|r| r.tag_name)
            .collect();

        versions.sort_by(|a, b| b.cmp(a));

        Ok(versions)
    }

    async fn get_default_branch_download_url(&self) -> Result<String> {
        use reqwest::header::{ACCEPT, USER_AGENT};

        let response = self
            .client
            .get(format!(
                "https://api.github.com/repos/{}",
                self.mod_type.get_repo_url()
            ))
            .header(ACCEPT, "application/vnd.github+json")
            .header("X-GitHub-Api-Version", "2022-11-28")
            .header(USER_AGENT, "Balatro-Mod-Manager/1.0")
            .send()
            .await?
            .error_for_status()?;

        let body = response.json::<serde_json::Value>().await?;
        body["default_branch"]
            .as_str()
            .map(|b| {
                format!(
                    "https://github.com/{}/archive/refs/heads/{b}.zip",
                    self.mod_type.get_repo_url(),
                )
            })
            .ok_or(anyhow::anyhow!(
                "repo {} has no default branch",
                self.mod_type.get_repo_url()
            ))
    }

    pub async fn install_version(&self, version: &str) -> Result<String> {
        let mods_dir = get_lovely_mods_dir(self.installation_path.as_ref());
        let url = match version {
            "newest" => self.get_default_branch_download_url().await?,
            _ => format!(
                "https://github.com/{}/archive/refs/tags/{}.zip",
                self.mod_type.get_repo_url(),
                version
            ),
        };

        info!(
            "Installing {:?} version {} to {:?}",
            self.mod_type, version, mods_dir
        );

        let mut headers = HeaderMap::new();
        headers.insert(
            USER_AGENT,
            HeaderValue::from_static("Balatro-Mod-Manager/1.0"),
        );

        // Download the zip file
        let response = self.client.get(&url).headers(headers).send().await?;
        let bytes = response.bytes().await?;

        // Create temp directory
        let temp_dir = mods_dir.join(format!(
            "temp_{}",
            match self.mod_type {
                ModType::Steamodded => "smods",
                ModType::Talisman => "talisman",
            }
        ));
        if temp_dir.exists() {
            fs::remove_dir_all(&temp_dir)?;
        }
        fs::create_dir_all(&temp_dir)?;

        // Extract to temp directory
        let cursor = Cursor::new(bytes);
        let mut archive = ZipArchive::new(cursor)?;
        archive.extract(&temp_dir)?;

        // Find the root directory name (GitHub format: Steamodded-smods-commitHash)
        let root_dir = fs::read_dir(&temp_dir)?
            .next()
            .ok_or(anyhow!("Empty archive"))??
            .file_name()
            .into_string()
            .map_err(|_| anyhow!("Invalid directory name"))?;

        // Move to final location
        let final_dir = match self.mod_type {
            ModType::Steamodded => mods_dir.join(&root_dir),
            ModType::Talisman => mods_dir.join("Talisman"),
        };
        if final_dir.exists() {
            fs::remove_dir_all(&final_dir)?;
        }
        fs::rename(temp_dir.join(&root_dir), &final_dir)?;

        // Cleanup
        fs::remove_dir_all(temp_dir)?;

        info!(
            "Successfully installed {:?} version {} to {:?}",
            self.mod_type, version, final_dir
        );

        Ok(final_dir.to_string_lossy().to_string())
    }

    pub async fn uninstall(&self) -> Result<()> {
        let mods_dir = get_lovely_mods_dir(self.installation_path.as_ref());
        if !mods_dir.exists() {
            info!("Mods directory not found");
            return Ok(());
        }

        let mut entries = tokio::fs::read_dir(&mods_dir).await?;
        let mut found = false;

        while let Some(entry) = entries.next_entry().await? {
            let path = entry.path();
            if path.is_dir() {
                if let Some(dir_name) = path.file_name().and_then(|n| n.to_str()) {
                    // Match both Steamodded and specific commit formats
                    if dir_name.to_lowercase().contains("steamodded")
                        || dir_name.starts_with("smods-")
                        || dir_name.starts_with("Steamodded-smods-")
                    {
                        found = true;
                        info!("Removing mod directory: {path:?}");
                        tokio_fs::remove_dir_all(&path).await?;
                    }
                }
            }
        }

        if !found {
            info!("No Steamodded installations found");
        }

        Ok(())
    }
}
