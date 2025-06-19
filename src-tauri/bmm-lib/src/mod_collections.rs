use rusqlite::{Connection, Result};
use std::collections::HashMap;
use std::hash::{Hash, Hasher};
use std::path::PathBuf;

#[derive(Clone)]
pub struct ModCollection {
    pub name: String,
    pub path: PathBuf,
    pub hash: u64,
}

impl ModCollection {
    pub fn new(name: String, path: PathBuf) -> Self {
        use std::hash::DefaultHasher;
        let mut hasher = DefaultHasher::new();
        name.hash(&mut hasher);
        path.to_string_lossy().hash(&mut hasher);
        let hash = hasher.finish();

        Self { name, path, hash }
    }
}

pub struct ModCollectionManager {
    collections: HashMap<u64, ModCollection>,
}

impl Default for ModCollectionManager {
    fn default() -> Self {
        Self::new()
    }
}

impl ModCollectionManager {
    pub fn new() -> Self {
        Self {
            collections: HashMap::new(),
        }
    }

    pub fn initialize_table(conn: &Connection) -> Result<()> {
        conn.execute(
            "CREATE TABLE IF NOT EXISTS mod_collections (
                hash INTEGER PRIMARY KEY,
                name TEXT NOT NULL,
                path TEXT NOT NULL
            )",
            [],
        )?;
        Ok(())
    }

    pub fn add_collection(&mut self, conn: &Connection, collection: ModCollection) -> Result<()> {
        self.collections.insert(collection.hash, collection.clone());

        conn.execute(
            "INSERT OR REPLACE INTO mod_collections (hash, name, path) VALUES (?1, ?2, ?3)",
            [
                &collection.hash.to_string(),
                &collection.name,
                &collection.path.to_string_lossy().to_string(),
            ],
        )?;

        Ok(())
    }

    pub fn get_collection(&self, hash: u64) -> Option<&ModCollection> {
        self.collections.get(&hash)
    }

    pub fn remove_collection(&mut self, conn: &Connection, hash: u64) -> Result<()> {
        self.collections.remove(&hash);
        conn.execute(
            "DELETE FROM mod_collections WHERE hash = ?1",
            [hash.to_string()],
        )?;
        Ok(())
    }

    pub fn load_collections(&mut self, conn: &Connection) -> Result<Vec<ModCollection>> {
        let mut stmt = conn.prepare("SELECT hash, name, path FROM mod_collections")?;

        let collections = stmt.query_map([], |row| {
            let hash: u64 = row.get::<_, String>(0)?.parse().unwrap();
            let name: String = row.get(1)?;
            let path: String = row.get(2)?;

            Ok(ModCollection {
                hash,
                name,
                path: PathBuf::from(path),
            })
        })?;

        let mut result = Vec::new();
        for collection in collections {
            let collection = collection?;
            self.collections.insert(collection.hash, collection.clone());
            result.push(collection);
        }

        Ok(result)
    }

    pub fn get_all_collections(&self, conn: &Connection) -> Result<Vec<ModCollection>> {
        let mut stmt = conn.prepare("SELECT hash, name, path FROM mod_collections")?;

        let collections = stmt.query_map([], |row| {
            let hash: u64 = row.get::<_, String>(0)?.parse().unwrap();
            let name: String = row.get(1)?;
            let path: String = row.get(2)?;

            Ok(ModCollection {
                hash,
                name,
                path: PathBuf::from(path),
            })
        })?;

        let mut result = Vec::new();
        for collection in collections {
            result.push(collection?);
        }

        Ok(result)
    }
}

