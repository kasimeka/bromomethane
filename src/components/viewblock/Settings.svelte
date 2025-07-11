<script lang="ts">
  import PathSelector from "../PathSelector.svelte";
  import {Settings2, RefreshCw, Folder} from "lucide-svelte";
  import {addMessage} from "$lib/stores";
  import {invoke} from "@tauri-apps/api/core";

  let isReindexing = false;
  let isClearingCache = false;
  let lastReindexStats = {
    removedFiles: 0,
    cleanedEntries: 0,
  };

  export async function performReindexMods() {
    isReindexing = true;
    try {
      const result = await invoke<[number, number]>("reindex_mods");
      lastReindexStats = {
        removedFiles: result[0], // Will always be 0
        cleanedEntries: result[1],
      };
      addMessage(`Reindex complete: Cleaned ${result[1]} database entries`, "success");
    } catch (error) {
      addMessage("Reindex failed: " + error, "error");
    } finally {
      isReindexing = false;
    }
  }

  async function clearCache() {
    isClearingCache = true;
    try {
      await invoke("clear_cache");
      addMessage("Successfully cleared all caches!", "success");
    } catch (error) {
      addMessage("Failed to clear cache: " + error, "error");
    } finally {
      isClearingCache = false;
    }
  }

  async function openModsFolder() {
    try {
      // Get the repository path (which should be config_dir/Balatro/mod_index)
      const modsFolderPath: string = await invoke("get_mods_folder");

      // Get the parent directory (config_dir/Balatro) by finding the last path separator
      const lastSeparatorIndex = Math.max(
        modsFolderPath.lastIndexOf("/"),
        modsFolderPath.lastIndexOf("\\"),
      );
      if (lastSeparatorIndex === -1) {
        addMessage("Failed to determine the parent directory of the repository path.", "error");
        return;
      }

      const parentPath = modsFolderPath.substring(0, lastSeparatorIndex);
      const separator = modsFolderPath.includes("/") ? "/" : "\\"; // Determine the separator used in the path

      // Construct the mods path
      const modsPath = `${parentPath}${separator}Mods`;

      // Check if the path exists
      const pathExists = await invoke("path_exists", {path: modsPath});

      if (!pathExists) {
        addMessage("Mods directory not found. It might not have been created yet.", "warning");
        addMessage("Install a mod using the mod manager to create the mods directory.", "info");
        return;
      }

      // Open the directory
      await invoke("open_directory", {path: modsPath});
    } catch (error) {
      addMessage(`Failed to open mods directory: ${error}`, "error");
    }
  }
</script>

<div class="container default-scrollbar">
  <div class="settings-container">
    <h2>Settings</h2>
    <div class="content">
      <h3>Game Path</h3>
      <PathSelector />
      <h3>Cache</h3>
      <button class="clear-cache-button" on:click={clearCache} disabled={isClearingCache}>
        {#if isClearingCache}
          <div class="throbber"></div>
        {:else}
          <RefreshCw size={20} />
          Clear Cache
        {/if}
      </button>

      <p class="description warning">
        <span class="warning-icon">⚠️</span>
        Frequent cache clearing may trigger API rate limits
      </p>

      <h3>Mods</h3>

      <div class="mods-settings">
        <button class="open-folder-button" on:click={openModsFolder} title="Open mods folder">
          <Folder size={20} />
          Open Mods Folder
        </button>

        <p class="description">Open the folder where mods are stored on your system.</p>

        <button
          class="reindex-button"
          on:click={performReindexMods}
          disabled={isReindexing}
          title="Synchronize database with filesystem state"
        >
          {#if isReindexing}
            <div class="throbber"></div>
            Scanning...
          {:else}
            <Settings2 size={20} />
            Validate Mod Database
          {/if}
        </button>

        {#if lastReindexStats.removedFiles + lastReindexStats.cleanedEntries > 0}
          <div class="reindex-stats">
            <strong>Last cleanup:</strong>
            <span>Files removed: {lastReindexStats.removedFiles}</span>
            <span>Database entries cleaned: {lastReindexStats.cleanedEntries}</span>
          </div>
        {/if}
        <p class="description-small">
          Performs consistency check on the mod database. Will only remove:
          <br />• Database entries for missing mod installations
        </p>
      </div>
    </div>
  </div>
</div>

<style>
  .settings-container {
    padding: 0rem 2rem;
    padding-bottom: 2rem;
  }

  h2 {
    font-size: 2.5rem;
    margin-bottom: 2rem;
    color: #fdcf51;
  }
  h3 {
    font-size: 1.8rem;
    margin-bottom: 1rem;
    align-self: flex-start;
    color: #fdcf51;
  }
  .content {
    flex: 1;
  }
  .reindex-button {
    background: #56a786;
    color: #f4eee0;
    border: none;
    outline: #459373 solid 2px;
    border-radius: 4px;
    padding: 0.75rem 1.5rem;
    font-family: "M6X11", sans-serif;
    font-size: 1.2rem;
    cursor: pointer;
    transition: all 0.2s ease;
    align-self: flex-start;
    display: flex;
    align-items: center;
    gap: 0.5rem;
  }
  .reindex-button:hover {
    background: #74cca8;
    transform: translateY(-2px);
  }
  .throbber {
    width: 20px;
    height: 20px;
    border: 3px solid #f4eee0;
    border-radius: 50%;
    border-top-color: transparent;
    animation: spin 1s linear infinite;
  }
  .warning {
    color: #ffd700;
    font-size: 1.1rem;
    border-left: 3px solid #ffd700;
    padding-left: 0.8rem;
    margin-top: 0.8rem;
    max-width: 600px !important;
  }
  @keyframes spin {
    to {
      transform: rotate(360deg);
    }
  }
  .reindex-button:disabled {
    cursor: not-allowed;
    opacity: 0.8;
    transform: none;
  }
  .clear-cache-button {
    background: #6d28d9;
    color: #f4eee0;
    border: none;
    outline: #5b21b6 solid 2px;
    border-radius: 4px;
    padding: 0.75rem 1.5rem;
    font-family: "M6X11", sans-serif;
    font-size: 1.2rem;
    cursor: pointer;
    transition: all 0.2s ease;
    display: flex;
    align-items: center;
    gap: 0.5rem;
  }
  .clear-cache-button:hover:not(:disabled) {
    background: #7c3aed;
    transform: translateY(-2px);
  }
  .clear-cache-button:disabled {
    cursor: not-allowed;
    opacity: 0.8;
    transform: none;
  }

  .open-folder-button {
    background: #4caf50;
    color: #f4eee0;
    border: none;
    outline: #3d8b40 solid 2px;
    border-radius: 4px;
    padding: 0.75rem 1.5rem;
    font-family: "M6X11", sans-serif;
    font-size: 1.2rem;
    cursor: pointer;
    transition: all 0.2s ease;
    align-self: flex-start;
    display: flex;
    align-items: center;
    gap: 0.5rem;
    margin-top: 1rem;
  }

  .open-folder-button:hover {
    background: #45a049;
    transform: translateY(-2px);
  }

  .open-folder-button:active {
    transform: translateY(1px);
  }
  .description {
    color: #f4eee0;
    font-size: 1.2rem;
    margin-top: 0.5rem;
    opacity: 0.9;
    max-width: 400px;
    line-height: 1.4;
  } /* Custom Toggle Switch Styles */
  .description-small {
    /* color a bit grayer but still light */
    color: #c4c2c2;
    font-size: 1.1rem;
    margin-top: 0.5rem;
    opacity: 0.9;
    max-width: 400px;
    line-height: 1.4;
  }
  @media (max-width: 1160px) {
    h2 {
      font-size: 2rem;
      transition: all 0.2s ease;
    }
    h3 {
      font-size: 1.5rem;
      transition: all 0.2s ease;
    }
    .reindex-button {
      font-size: 1rem;
      padding: 0.6rem 1.2rem;
    }
    .open-folder-button {
      font-size: 1rem;
      padding: 0.6rem 1.2rem;
    }
    .clear-cache-button {
      font-size: 1rem;
      padding: 0.6rem 1.2rem;
    }
    .description {
      font-size: 1.1rem;
      max-width: 100%;
    }
    .description-small {
      font-size: 1rem;
      max-width: 100%;
    }
  }
</style>
