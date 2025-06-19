<script lang="ts">
	import {
		Trash2,
		ArrowDownToLine,
		CornerDownRight,
		Folder,
	} from "lucide-svelte";
	import { invoke } from "@tauri-apps/api/core";
	import { addMessage } from "$lib/stores";
	import { modsStore } from "../../stores/modStore";
	import { modEnabledStore } from "../../stores/modStore";

	export let mod: any;
	export let onUninstall: (mod: any) => void;
	export let onToggleEnabled: (() => Promise<void>) | undefined = undefined;

	// Local state for loading and enabled status
	let isInstalling = false;
	let isEnabled = true; // Default to enabled if not yet checked

	// Check mod enabled status when component mounts
	import { onMount } from "svelte";

	onMount(() => {
		checkModEnabled(mod.name);
	});

	async function checkModEnabled(modName: string) {
		try {
			// Use the full path for local mods
			const enabled = await invoke<boolean>("is_mod_enabled_by_path", {
				modPath: mod.path,
			});

			modEnabledStore.update((enabledMods: Record<string, boolean>) => ({
				...enabledMods,
				[modName]: enabled,
			}));

			// Also update local variable for reactive binding
			isEnabled = enabled;
		} catch (error) {
			console.error(
				`Failed to check if mod ${modName} is enabled:`,
				error,
			);
			// Default to enabled on error
			modEnabledStore.update((enabledMods: Record<string, boolean>) => ({
				...enabledMods,
				[modName]: true,
			}));
			isEnabled = true;
		}
	}

	async function toggleModEnabled(e: Event) {
		e.stopPropagation();
		try {
			const currentState = $modEnabledStore[mod.name] ?? isEnabled;
			const newState = !currentState;

			// Use the full path for local mods instead of just the name
			await invoke("toggle_mod_enabled_by_path", {
				modPath: mod.path,
				enabled: newState,
			});

			// Update both the store and local variable
			modEnabledStore.update((enabledMods) => ({
				...enabledMods,
				[mod.name]: newState,
			}));
			isEnabled = newState;

			// Call the parent callback to update the filtered lists
			if (onToggleEnabled) {
				await onToggleEnabled();
			}
		} catch (error) {
			console.error(
				`Failed to toggle mod ${mod.name} enabled state:`,
				error,
			);
		}
	}
	// Function to open the mod's directory
	async function openModDirectory(e: Event) {
		e.stopPropagation();

		try {
			// Check if path exists first
			const pathExists = await invoke("path_exists", { path: mod.path });

			if (!pathExists) {
				addMessage(`Directory not found: ${mod.path}`, "error");
				return;
			}

			// Use the custom command to open the directory
			await invoke("open_directory", { path: mod.path });
		} catch (error) {
			addMessage(`Failed to open directory: ${error}`, "error");
		}
	}

	async function installOfficialVersion(e: Event) {
		e.stopPropagation();
		if (!mod.catalog_match) return;

		try {
			isInstalling = true;

			// Create a simplified version of the catalog mod for installation
			const catalogMod = {
				title: mod.catalog_match.title,
				downloadURL: mod.catalog_match.download_url,
				version: mod.catalog_match.version || "",
				requires_steamodded: false,
				requires_talisman: false,
			};

			// Find the full catalog mod if available
			const fullCatalogMod = $modsStore.find(
				(m) =>
					m.title.toLowerCase() ===
					mod.catalog_match.title.toLowerCase(),
			);

			// Use the dependency info from the full catalog mod if found
			const dependencies = [];
			if (fullCatalogMod) {
				if (fullCatalogMod.requires_steamodded)
					dependencies.push("Steamodded");
				if (fullCatalogMod.requires_talisman)
					dependencies.push("Talisman");
			}

			// Save the local mod path for later removal
			const localModPath = mod.path;

			// Create a temporary copy of the local mod in case installation fails
			await invoke("backup_local_mod", { path: localModPath });

			try {
				// Install the mod
				const installedPath: string = await invoke("install_mod", {
					url: catalogMod.downloadURL,
					folderName:
						fullCatalogMod?.folderName ||
						catalogMod.title.replace(/\s+/g, ""),
				});

				// Verify the installed path exists before proceeding
				const pathExists = await invoke("path_exists", {
					path: installedPath,
				});
				if (!pathExists) {
					throw new Error(
						`Failed to verify installed path: ${installedPath}`,
					);
				}

				// Add to database
				await invoke("add_installed_mod", {
					name: catalogMod.title,
					path: installedPath,
					dependencies,
					currentVersion: catalogMod.version,
				});

				// Now check if we should delete the local mod
				const localPathExists = await invoke("path_exists", {
					path: localModPath,
				});

				// Normalize paths for comparison (especially important for Windows)
				const normalizedLocal = localModPath
					.toLowerCase()
					.replace(/\\/g, "/");
				const normalizedInstalled = installedPath
					.toLowerCase()
					.replace(/\\/g, "/");

				// Only delete the local mod if:
				// 1. It exists
				// 2. It's not the same as the installed path
				// 3. It's not a parent directory of the installed path
				if (
					localPathExists &&
					normalizedLocal !== normalizedInstalled &&
					!normalizedInstalled.startsWith(normalizedLocal + "/")
				) {
					await invoke("delete_manual_mod", {
						path: localModPath,
					});
				}

				addMessage(
					`Installed official version of ${mod.catalog_match.title}`,
					"success",
				);

				// Clean up the backup
				await invoke("remove_backup", { path: localModPath });

				// Refresh the view
				onUninstall(mod);
			} catch (error) {
				// If installation failed, restore from backup
				await invoke("restore_from_backup", { path: localModPath });
				throw error;
			}
		} catch (error) {
			addMessage(`Failed to install official version: ${error}`, "error");
		} finally {
			isInstalling = false;
		}
	}

	async function uninstallMod(e: Event) {
		e.stopPropagation(); // Prevent card click if we have one
		try {
			await invoke("delete_manual_mod", {
				path: mod.path,
			});

			addMessage(`Removed ${mod.name}`, "success");
			onUninstall(mod);
		} catch (error) {
			addMessage(`Failed to remove mod: ${error}`, "error");
		}
	}

	// Generate random colors like the ModCard does
	const bgColor = getRandomColor();
	const bgColor2 = darkenColor(bgColor, 20);

	function getRandomColor() {
		const colors = [
			"#4f6367",
			"#AA778D",
			"#A2615E",
			"#A48447",
			"#4F7869",
			"#728DBF",
			"#5D5E8F",
			"#796E9E",
			"#64825D",
			"#86A367",
			"#748C8A",
		];
		return colors[Math.floor(Math.random() * colors.length)];
	}

	function darkenColor(color: string, percent: number) {
		const num = parseInt(color.replace("#", ""), 16);
		const amt = Math.round(2.55 * percent);
		const R = (num >> 16) - amt;
		const G = ((num >> 8) & 0x00ff) - amt;
		const B = (num & 0x0000ff) - amt;
		return (
			"#" +
			(
				0x1000000 +
				(R < 0 ? 0 : R) * 0x10000 +
				(G < 0 ? 0 : G) * 0x100 +
				(B < 0 ? 0 : B)
			)
				.toString(16)
				.slice(1)
		);
	}

	// Check for version differences if we have a catalog match
	let hasNewerVersion = false;
	if (mod.catalog_match && mod.catalog_match.version && mod.version) {
		hasNewerVersion = mod.catalog_match.version !== mod.version;
	}
</script>

<div class="mod-card" style="--bg-color: {bgColor}; --bg-color-2: {bgColor2};">
	<!-- Dark overlay to improve readability -->
	<div class="overlay"></div>

	{#if mod.catalog_match}
		<div class="catalog-badge">
			<CornerDownRight size={14} />
			<span>In Catalog</span>
		</div>
	{/if}

	<div class="mod-content">
		<h3>{mod.name}</h3>
		<p class="description">{mod.description}</p>

		<div class="mod-meta">
			<div class="author">
				<span>By: {mod.author.join(", ")}</span>
			</div>
			{#if mod.version}
				<div class="version">
					<span>Version: {mod.version}</span>
				</div>
			{/if}

			{#if mod.catalog_match && hasNewerVersion}
				<div class="catalog-version">
					<span>Catalog version: {mod.catalog_match.version}</span>
				</div>
			{/if}
		</div>
	</div>

	<div class="button-container">
		{#if mod.catalog_match}
			<button
				class="folder-button"
				title="Open mod directory"
				on:click={openModDirectory}
			>
				<Folder size={18} />
			</button>
			<!-- Enable/Disable toggle button -->
			<button
				class="toggle-button"
				class:enabled={$modEnabledStore[mod.name] ?? isEnabled}
				class:disabled={!($modEnabledStore[mod.name] ?? isEnabled)}
				title={($modEnabledStore[mod.name] ?? isEnabled)
					? "Disable Mod"
					: "Enable Mod"}
				on:click={toggleModEnabled}
			>
				{#if $modEnabledStore[mod.name] ?? isEnabled}
					ON
				{:else}
					OFF
				{/if}
			</button>
			<button
				class="install-button"
				title="Install official version"
				on:click={installOfficialVersion}
				disabled={isInstalling}
			>
				{#if isInstalling}
					<div class="spinner"></div>
				{:else}
					<ArrowDownToLine size={15} />
					<span class="smaller-text">Get Official</span>
				{/if}
			</button>
			<button
				class="trash-button"
				title="Remove Mod"
				on:click={uninstallMod}
			>
				<Trash2 size={18} />
			</button>
		{:else}
			<button
				class="folder-button"
				title="Open mod directory"
				on:click={openModDirectory}
			>
				<Folder size={18} />
			</button>
			<!-- Added toggle button here -->
			<button
				class="toggle-button"
				class:enabled={$modEnabledStore[mod.name] ?? isEnabled}
				class:disabled={!($modEnabledStore[mod.name] ?? isEnabled)}
				title={($modEnabledStore[mod.name] ?? isEnabled)
					? "Disable Mod"
					: "Enable Mod"}
				on:click={toggleModEnabled}
			>
				{#if $modEnabledStore[mod.name] ?? isEnabled}
					ON
				{:else}
					OFF
				{/if}
			</button>
			<button
				class="delete-button"
				title="Remove Mod"
				on:click={uninstallMod}
			>
				<Trash2 size={18} />
				Remove
			</button>
		{/if}
	</div>
</div>

<style>
	.mod-card {
		--bg-color: var(--bg-color, #4f6367);
		--bg-color-2: var(--bg-color-2, #334461);

		display: flex;
		flex-direction: column;
		position: relative;
		border-radius: 8px;
		overflow: hidden;
		border: 2px solid #f4eee0;
		width: 300px;
		max-width: 300px;
		height: 330px;
		margin: 0 auto;
		padding: 1rem;
		box-sizing: border-box;
		background-size: 100% 200%;
		transition: all 0.3s ease;
		background-image: repeating-linear-gradient(
			-45deg,
			var(--bg-color),
			var(--bg-color) 10px,
			var(--bg-color-2) 10px,
			var(--bg-color-2) 20px
		);
	}

	/* Dark overlay for better text readability */
	.overlay {
		position: absolute;
		top: 0;
		left: 0;
		right: 0;
		bottom: 0;
		background-color: rgba(0, 0, 0, 0.5);
		backdrop-filter: blur(1px);
		-webkit-backdrop-filter: blur(1px);
		z-index: 1;
	}

	.catalog-badge {
		position: absolute;
		top: 1rem;
		right: 1rem;
		background: #56a786;
		color: #f4eee0;
		padding: 0.3rem 0.5rem;
		border-radius: 4px;
		font-size: 0.9rem;
		display: flex;
		align-items: center;
		gap: 0.3rem;
		z-index: 3;
		box-shadow: 0 2px 4px rgba(0, 0, 0, 0.2);
		border: 1px solid rgba(244, 238, 224, 0.3);
	}

	.mod-card:hover {
		animation: stripe-slide-up 1.5s linear infinite;
		scale: 1.05;
	}

	@keyframes stripe-slide-up {
		0% {
			background-position: 0 0;
		}
		100% {
			background-position: 0 -55px;
		}
	}

	.mod-content {
		flex: 1;
		padding: 0.5rem;
		position: relative;
		z-index: 2;
	}

	h3 {
		color: #fdcf51;
		font-size: 1.5rem;
		margin-bottom: 0.5rem;
		text-shadow: 1px 1px 2px rgba(0, 0, 0, 0.5);
	}

	.description {
		color: #f4eee0;
		font-size: 1.1rem;
		line-height: 1.3;
		margin-bottom: 1rem;
		overflow: hidden;
		display: -webkit-box;
		-webkit-line-clamp: 3;
		line-clamp: 3;
		-webkit-box-orient: vertical;
		padding: 0 0.1rem;
	}

	.mod-meta {
		font-size: 1rem;
		color: #f4eee0;
		margin-bottom: 1rem;
	}

	.version,
	.catalog-version {
		margin-top: 0.3rem;
	}

	.catalog-version {
		color: #56a786;
		font-weight: bold;
	}

	/* Button container styling */
	.button-container {
		display: flex;
		gap: 0.5rem;
		position: absolute;
		bottom: 1rem;
		left: 1rem;
		width: calc(100% - 2rem);
		z-index: 2;
	}

	/* Button styles */
	.delete-button {
		flex: 1;
		display: flex;
		align-items: center;
		justify-content: center;
		gap: 0.5rem;
		padding: 0.75rem;
		color: #f4eee0;
		border: none;
		border-radius: 4px;
		cursor: pointer;
		transition: all 0.2s ease;
		font-family: "M6X11", sans-serif;
		font-size: 1.1rem;
		min-height: 42px;
		position: relative;
	}

	.install-button {
		flex: 1;
		display: flex;
		align-items: center;
		justify-content: center;
		gap: 0.4rem;
		padding: 0.75rem 0.5rem;
		color: #f4eee0;
		border: none;
		border-radius: 4px;
		cursor: pointer;
		transition: all 0.2s ease;
		font-family: "M6X11", sans-serif;
		min-height: 42px;
		position: relative;
		background: #56a786;
		outline: #459373 solid 2px;
	}

	.delete-button {
		background: #c14139;
		outline: #a13029 solid 2px;
	}

	.delete-button:hover {
		background: #d4524a;
		transform: translateY(-2px);
	}

	.delete-button:active,
	.install-button:active {
		transform: translateY(1px);
	}

	.install-button:not(:disabled):active {
		transform: translateY(1px);
		background: #63b897;
		box-shadow: 0 1px 2px rgba(0, 0, 0, 0.2);
	}

	.install-button:disabled {
		opacity: 0.8;
		cursor: not-allowed;
	}

	.folder-button {
		display: flex;
		align-items: center;
		justify-content: center;
		min-width: 42px;
		height: 42px;
		padding: 8px;
		border-radius: 4px;
		cursor: pointer;
		transition: all 0.2s ease;
		background-color: #4caf50;
		color: white;
		border: none;
		outline: #3d8b40 solid 2px;
		flex-shrink: 0;
	}

	.folder-button:hover {
		background-color: #45a049;
		transform: translateY(-2px);
		box-shadow: 0 2px 4px rgba(0, 0, 0, 0.2);
	}

	.folder-button:active {
		transform: translateY(1px);
		box-shadow: 0 1px 2px rgba(0, 0, 0, 0.2);
	}

	/* Toggle button styles */
	.toggle-button {
		display: flex;
		align-items: center;
		justify-content: center;
		min-width: 42px;
		height: 42px;
		padding: 8px;
		border-radius: 4px;
		cursor: pointer;
		transition: all 0.2s ease;
		color: white;
		border: none;
		flex-shrink: 0;
		font-family: "M6X11", sans-serif;
		font-size: 1.1rem;
	}

	.toggle-button.enabled {
		background: #27ae60; /* Bright green when enabled */
		outline: #219653 solid 2px;
	}

	.toggle-button.disabled {
		background: #7f8c8d; /* Gray when disabled, instead of red */
		outline: #636e72 solid 2px;
	}

	.toggle-button:hover.enabled {
		background: #2ecc71; /* Lighter green on hover */
		transform: translateY(-2px);
		box-shadow: 0 2px 4px rgba(0, 0, 0, 0.2);
	}

	.toggle-button:hover.disabled {
		background: #95a5a6; /* Lighter gray on hover */
		transform: translateY(-2px);
		box-shadow: 0 2px 4px rgba(0, 0, 0, 0.2);
	}

	.toggle-button:active {
		transform: translateY(1px);
		box-shadow: 0 1px 2px rgba(0, 0, 0, 0.2);
	}

	.trash-button {
		display: flex;
		align-items: center;
		justify-content: center;
		min-width: 42px;
		height: 42px;
		padding: 8px;
		border-radius: 4px;
		cursor: pointer;
		transition: all 0.2s ease;
		background-color: #c14139;
		color: white;
		border: none;
		outline: #a13029 solid 2px;
		flex-shrink: 0;
	}

	.trash-button:hover {
		background-color: #d4524a;
		transform: translateY(-2px);
		box-shadow: 0 2px 4px rgba(0, 0, 0, 0.2);
	}

	.trash-button:active {
		transform: translateY(1px);
		box-shadow: 0 1px 2px rgba(0, 0, 0, 0.2);
	}

	.install-button:hover:not(:disabled) {
		background: #63b897;
		transform: translateY(-2px);
		box-shadow: 0 4px 6px rgba(0, 0, 0, 0.15);
	}

	.smaller-text {
		font-size: 0.8rem;
		font-weight: 500;
	}

	/* Spinner for loading state */
	.spinner {
		border: 2px solid rgba(255, 255, 255, 0.3);
		border-top: 2px solid #ffffff;
		border-radius: 50%;
		width: 16px;
		height: 16px;
		animation: spin 1s linear infinite;
		margin: 0 auto;
		display: inline-block;
	}

	@keyframes spin {
		0% {
			transform: rotate(0deg);
		}
		100% {
			transform: rotate(360deg);
		}
	}

	@media (max-width: 1160px) {
		.mod-card {
			width: 100%;
		}
	}
</style>
