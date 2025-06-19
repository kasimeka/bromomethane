// stores/modCache.ts
import { writable, get } from 'svelte/store';
import { invoke } from '@tauri-apps/api/core';
import type { InstalledMod } from './modStore';

// Create a self-contained cache system
const createModCache = () => {
	// Private variables inside closure
	const cache = writable<InstalledMod[]>([]);
	let lastFetchTime = 0;
	const CACHE_TIMEOUT = 2000; // 2 seconds

	// Core cache function that handles all operations
	async function getModsFromCache(forceRefresh = false): Promise<InstalledMod[]> {
		const now = Date.now();

		if (forceRefresh || lastFetchTime === 0 || now - lastFetchTime > CACHE_TIMEOUT) {
			try {
				const installed: InstalledMod[] = await invoke("get_installed_mods_from_db");
				const formattedMods = installed.map((mod) => ({
					name: mod.name,
					path: mod.path,
				}));

				cache.set(formattedMods);
				lastFetchTime = now;
				return formattedMods;
			} catch (error) {
				console.error("Failed to get installed mods:", error);
				return [];
			}
		}

		// Return current value from store
		return get(cache);
	}

	// Public interface
	return {
		// Exported store for reactive access
		installedModsCache: cache,

		// Get mods with optional force refresh
		fetchCachedMods: async (forceRefresh = false) => {
			return getModsFromCache(forceRefresh);
		},

		// Check if a specific mod is in the cache
		checkModInCache: async (modTitle: string) => {
			if (!modTitle) return false;
			const mods = await getModsFromCache();
			return mods.some(m => m.name.toLowerCase() === modTitle.toLowerCase());
		},

		// Force refresh the cache
		forceRefreshCache: async () => {
			return getModsFromCache(true);
		}
	};
};

// Create a single instance of the cache system
const modCache = createModCache();

// Export the public interface
export const {
	installedModsCache,
	fetchCachedMods,
	checkModInCache,
	forceRefreshCache
} = modCache;

