<script lang="ts">
	import { invoke } from "@tauri-apps/api/core";
	import { FolderDot, FileDigit } from "lucide-svelte";
	import { addMessage } from "$lib/stores";

	let selectedPath = "";
	let placeholder = "Choose Balatro Path";
	let isLoading = false;
	let selectMode = "directory"; // Can be "directory" or "executable"

	const truncatePath = (path: string) => {
		const maxLength = 50;
		return path.length > maxLength
			? path.substring(0, maxLength - 3) + "..."
			: path;
	};

	const getBalatroPath = async () => {
		const path = await invoke("get_balatro_path");
		if (path) {
			selectedPath = path as string;
			placeholder = path as string;
		} else {
			placeholder = "Choose Balatro Path";
		}
	};

	getBalatroPath();

	const handlePathSelect = async () => {
		const { open } = await import("@tauri-apps/plugin-dialog");

		const selected = await open({
			directory: selectMode === "directory",
			multiple: false,
			title:
				selectMode === "directory"
					? "Select Balatro Directory"
					: "Select Balatro Executable",
			filters:
				selectMode === "executable"
					? [{ name: "Executable", extensions: ["exe"] }]
					: undefined,
		});

		if (selected) {
			selectedPath = selected as string;

			// If executable was selected, get the parent directory
			let pathToCheck = selectedPath;
			if (selectMode === "executable") {
				// Extract directory from file path
				const lastSlashIndex =
					selectedPath.lastIndexOf("/") !== -1
						? selectedPath.lastIndexOf("/")
						: selectedPath.lastIndexOf("\\");

				if (lastSlashIndex !== -1) {
					pathToCheck = selectedPath.substring(0, lastSlashIndex);
				}
			}

			const isValid = await invoke("check_custom_balatro", {
				path: pathToCheck,
			});

			if (isValid) {
				await invoke("set_balatro_path", { path: pathToCheck });
				addMessage(
					"Balatro path set successfully! You can now manage mods for this installation.",
					"success",
				);
			} else {
				addMessage(
					"Invalid Balatro path. Please select a directory containing the game files.",
					"error",
				);
				selectedPath = "";
			}
		}
	};

	const setSteamPath = async () => {
		isLoading = true;
		try {
			const paths: string[] = await invoke("find_steam_balatro");
			if (paths.length === 0) {
				addMessage("Balatro not found in Steam installation", "error");
			} else {
				selectedPath = paths[0];
				await invoke("set_balatro_path", { path: selectedPath });
				addMessage("Successfully set Steam path", "success");
			}
		} catch (error) {
			addMessage("Error finding Steam path: " + error, "error");
		} finally {
			isLoading = false;
		}
	};
</script>

<div class="path-selector">
	<div class="toggle-buttons">
		<button
			class="path-type-button"
			class:active={selectMode === "directory"}
			on:click={() => (selectMode = "directory")}
		>
			<FolderDot size={16} />
			Select Directory
		</button>
		<button
			class="path-type-button"
			class:active={selectMode === "executable"}
			on:click={() => (selectMode = "executable")}
		>
			<FileDigit size={16} />
			Select Executable
		</button>
	</div>

	<p class="description-small">
		{#if selectMode === "executable"}
			Select a Balatro executable to manage mods for a specific
			installation. This is useful for separate vanilla/modded setups.
		{:else}
			Select the Balatro game directory. This is the standard method.
		{/if}
	</p>

	<div class="input-container">
		<input
			type="text"
			placeholder={truncatePath(placeholder)}
			value={selectedPath ? truncatePath(selectedPath) : ""}
			on:click={handlePathSelect}
			readonly
			disabled={isLoading}
		/>
	</div>
	<button class="steam-button" on:click={setSteamPath} disabled={isLoading}>
		{#if isLoading}
			<div class="throbber"></div>
		{:else}
			<FolderDot size={20} />
			Set to Steam Path
		{/if}
	</button>
</div>

<style>
	.path-selector {
		display: flex;
		flex-direction: column;
		gap: 0.5rem;
		margin: 1rem 0;
	}

	.toggle-buttons {
		display: flex;
		gap: 0.75rem;
		margin-bottom: 0.5rem;
	}

	.path-type-button {
		background: #4dabf7; /* Bright blue */
		outline: #3b8fd2 solid 2px;
		color: #ffffff;
		border: none;
		border-radius: 4px;
		padding: 0.6rem 1rem;
		font-family: "M6X11", sans-serif;
		font-size: 1.1rem;
		cursor: pointer;
		transition: all 0.2s ease;
		display: flex;
		align-items: center;
		gap: 0.5rem;
	}
	
	.path-type-button:hover:not(.active) {
		background: #6cbbf7; /* Lighter blue on hover */
		transform: translateY(-2px);
	}
	
	.path-type-button.active {
		background: #1864ab; /* Dark blue when active */
		outline: #134c7e solid 2px;
	}

	.description-small {
		color: #c4c2c2;
		font-size: 1.1rem;
		margin-top: 0.25rem;
		margin-bottom: 0.5rem;
		opacity: 0.9;
		line-height: 1.4;
		max-width: 600px;
	}

	/* Rest of the styles remain unchanged */
	.input-container {
		width: 20rem;
	}

	input[type="text"] {
		width: 100%;
		padding: 0.75rem;
		border: 2px solid #fda200;
		border-radius: 8px;
		background-color: #c88000;
		font-family: "M6X11", sans-serif;
		color: white;
		font-size: 1rem;
		cursor: pointer;
		transition: all 0.2s ease;
		white-space: nowrap;
		overflow: hidden;
		text-overflow: ellipsis;
		-webkit-user-select: none;
		user-select: none;
	}

	input[type="text"]:hover:not(:disabled) {
		border-color: #f4eee0;
	}

	input[type="text"]::placeholder {
		color: white;
		-webkit-user-select: none;
		user-select: none;
	}

	.steam-button {
		padding: 0.5rem 1rem;
		border: 2px solid #2e6b9a;
		border-radius: 8px;
		background-color: #1a9fff;
		color: #ffffff;
		font-family: inherit;
		font-size: 1.1rem;
		cursor: pointer;
		width: 13rem;
		height: 40px;
		display: flex;
		align-items: center;
		justify-content: center;
		gap: 0.5rem;
		transition: all 0.2s ease;
		overflow: hidden;
	}

	.steam-button:hover {
		background-color: #3daeff;
		border: 2px solid #8fc8ff;
	}

	.steam-button:active {
		transform: scale(0.98);
	}

	.steam-button:disabled {
		cursor: not-allowed;
		opacity: 0.8;
		background-color: #7fc8ff;
		transform: none;
	}
	.throbber {
		width: 20px;
		height: 20px;
		border: 3px solid #f4eee0;
		border-radius: 50%;
		border-top-color: transparent;
		animation: spin 1s linear infinite;
	}

	@media (max-width: 1160px) {
		.steam-button {
			width: 12rem;
			font-size: 1rem;
		}
		.steam-button :global(svg) {
			scale: 0.8;
		}
		.steam-button .throbber {
			width: 15px;
			height: 15px;
		}
		
		.path-type-button {
			font-size: 1rem;
			padding: 0.5rem 0.75rem;
		}
		
		.description-small {
			font-size: 1rem;
		}
	}

	@keyframes spin {
		to {
			transform: rotate(360deg);
		}
	}
</style>
