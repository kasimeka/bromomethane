<script lang="ts">
	import ShaderBackground from "../../components/ShaderBackground.svelte";
	import About from "../../components/viewblock/About.svelte";
	import LaunchButton from "../../components/LaunchButton.svelte";
	import Mods from "../../components/viewblock/Mods.svelte";
	import Settings from "../../components/viewblock/Settings.svelte";
	import RequiresPopup from "../../components/RequiresPopup.svelte";
	import WarningPopup from "../../components/WarningPopup.svelte";
	import SecurityPopup from "../../components/SecurityPopup.svelte";
	import type { DependencyCheck, InstalledMod } from "../../stores/modStore";
	import { currentModView, modsStore } from "../../stores/modStore";
	import { backgroundEnabled } from "../../stores/modStore";
	import { selectedModStore, dependentsStore } from "../../stores/modStore";
	import {
		installationStatus,
		showWarningPopup,
	} from "../../stores/modStore";
	import { invoke } from "@tauri-apps/api/core";
	import { addMessage } from "$lib/stores";
	import UninstallDialog from "../../components/UninstallDialog.svelte";
	import { onMount } from "svelte";

	let currentSection = $state("mods");
	let showSecurityPopup = $state(false); // Control visibility of the security popup

	$effect(() => {
		// Cleanup
		return () => {
			// Cleanup
		};
	});

	// Add these for the RequiresPopup
	let showRequiresPopup = $state(false);

	let storedDownloadAction: (() => Promise<void>) | null = $state(null);
	let originalDownloadAction: (() => Promise<void>) | null = $state(null);

	// Function to check if security warning needs to be shown
	async function checkSecurityAcknowledgment(): Promise<boolean> {
		try {
			const isAcknowledged = await invoke<boolean>(
				"is_security_warning_acknowledged",
			);
			return isAcknowledged;
		} catch (error) {
			console.error("Failed to check security acknowledgment:", error);
			return false; // If there's an error, show the popup anyway
		}
	}

	// Modified to include security check
	async function handleDependencyCheck(
		requirements: DependencyCheck,
		downloadAction?: () => Promise<void>,
	) {
		modRequirements = requirements;
		if (downloadAction) {
			originalDownloadAction = downloadAction;

			// Check if we need to show the security popup first
			const isSecurityAcknowledged = await checkSecurityAcknowledgment();

			if (!isSecurityAcknowledged) {
				// Store the action but don't execute it yet - show security popup first
				storedDownloadAction = null;
				showSecurityPopup = true;
			} else {
				// Security already acknowledged, proceed with dependency check
				storedDownloadAction = downloadAction;
				showRequiresPopup = true;
			}
		} else {
			console.warn(
				"handleDependencyCheck called without a download action",
			);
			storedDownloadAction = null;
			originalDownloadAction = null;
		}
	}

	// Handle security acknowledgment
	async function handleSecurityAcknowledge() {
		showSecurityPopup = false;

		// Now proceed with dependency check if there was an action
		if (originalDownloadAction) {
			storedDownloadAction = originalDownloadAction;
			showRequiresPopup = true;
		}
	}

	// Handle security cancellation
	function handleSecurityCancel() {
		showSecurityPopup = false;
		storedDownloadAction = null;
		originalDownloadAction = null;
	}

	function handleProceedDownload() {
		if (storedDownloadAction) {
			storedDownloadAction().catch((error) => {
				console.error("Error during download action execution:", error);
				showError(error);
			});
		} else {
			console.warn(
				"Proceed action requested, but no download action was stored.",
			);
		}
		storedDownloadAction = null; // Clear the stored action
		originalDownloadAction = null; // Clear the original action too
	}

	let contentElement: HTMLDivElement;

	let showUninstallDialog = $state(false);
	const selectedMod = $derived($selectedModStore);

	async function handleRefresh() {
		const installedMods: InstalledMod[] = await invoke(
			"get_installed_mods_from_db",
		);
		installationStatus.set(
			Object.fromEntries(
				installedMods.map((mod: InstalledMod) => [mod.name, true]),
			),
		);
	}

	function showError(error: unknown) {
		addMessage(
			`Uninstall failed: ${error instanceof Error ? error.message : String(error)}`,
			"error",
		);
	}

	function onError(event: { detail: unknown }) {
		showError(event.detail);
	}

	function onUninstalled(_event: {
		detail: { modName: string; success: boolean; action: string };
	}) {
		handleRefresh();
	}

	let modRequirements = $state({
		steamodded: false,
		talisman: false,
	});

	function handleDependencyClick(dependency: string) {
		// Find the mod in the store
		let foundMod = null;
		const unsubscribe = modsStore.subscribe((mods) => {
			foundMod = mods.find(
				(m) => m.title.toLowerCase() === dependency.toLowerCase(),
			);
		});
		unsubscribe(); // Important to prevent memory leaks

		// If found, open it in the mod view
		if (foundMod) {
			currentModView.set(foundMod);
		} else {
			console.warn(`Dependency mod not found: ${dependency}`);
		}
	}

	function handleRequestUninstall(
		event: CustomEvent<{ mod: InstalledMod; dependents: string[] }>,
	) {
		selectedModStore.set(event.detail.mod);
		dependentsStore.set(event.detail.dependents);
		showUninstallDialog = true;
	}

	onMount(async () => {
		handleRefresh();

		// Check if we need to show the security popup on first launch
		const isFirstLaunch = await invoke<boolean>(
			"is_security_warning_acknowledged",
		);
		if (!isFirstLaunch) {
			// It's the first launch, check if security is already acknowledged
			const isSecurityAcknowledged = await checkSecurityAcknowledgment();
			if (!isSecurityAcknowledged) {
				showSecurityPopup = true;
			}
		}
	});
</script>

{#if $backgroundEnabled}
	<ShaderBackground />
{/if}

<div class="main-page">
	<header>
		<div class="header-content">
			<h1>Balatro Mod Manager</h1>
			<LaunchButton />
		</div>
		<nav>
			<button
				class:active={currentSection === "mods"}
				onclick={() => (currentSection = "mods")}
			>
				Mods
			</button>
			<button
				class:active={currentSection === "settings"}
				onclick={() => (currentSection = "settings")}
			>
				Settings
			</button>
			<button
				class:active={currentSection === "about"}
				onclick={() => (currentSection = "about")}
			>
				About
			</button>
		</nav>
	</header>

	<div
		class="content"
		class:modal-open={!!$currentModView && currentSection == "mods"}
		bind:this={contentElement}
	>
		{#if currentSection === "mods"}
			<Mods
				mod={null}
				{handleDependencyCheck}
				on:request_uninstall={handleRequestUninstall}
			/>
		{/if}

		{#if currentSection === "settings"}
			<Settings />
		{/if}

		{#if currentSection === "about"}
			<About />
		{/if}
	</div>

	<RequiresPopup
		bind:show={showRequiresPopup}
		requiresSteamodded={modRequirements.steamodded}
		requiresTalisman={modRequirements.talisman}
		onProceed={handleProceedDownload}
		onDependencyClick={handleDependencyClick}
	/>

	<WarningPopup
		visible={$showWarningPopup.visible}
		message={$showWarningPopup.message}
		onConfirm={$showWarningPopup.onConfirm}
		onCancel={$showWarningPopup.onCancel}
	/>

	<!-- Add the SecurityPopup component -->
	<SecurityPopup
		visible={showSecurityPopup}
		onAcknowledge={handleSecurityAcknowledge}
		onCancel={handleSecurityCancel}
	/>

	<UninstallDialog
		bind:show={showUninstallDialog}
		modName={selectedMod?.name ?? ""}
		modPath={selectedMod?.path ?? ""}
		bind:dependents={$dependentsStore}
		{onUninstalled}
		{onError}
	/>

	<div class="version-text">v0.2.6</div>
</div>

<style>
	.main-page {
		width: 100vw;
		height: 100vh;
		display: flex;
		flex-direction: column;
		padding: 2rem;
		box-sizing: border-box;
		background: transparent;
	}
	header {
		margin-bottom: -1rem;
	}

	h1 {
		color: #f4eee0;
		font-size: 3rem;
		margin-bottom: 2rem;
		font-family: "M6X11", sans-serif;
		text-shadow:
			-2px -2px 0 #000,
			2px -2px 0 #000,
			-2px 2px 0 #000,
			2px 2px 0 #000;
	}

	nav {
		display: flex;
		gap: 1rem;
		margin-bottom: 2rem;
	}

	button {
		background: transparent;
		border: 2px solid #f4eee0;
		color: #f4eee0;
		padding: 0.7rem 1.4rem;
		border-radius: 8px;
		font-family: "M6X11", sans-serif;
		font-size: 1.2rem;
		cursor: pointer;
		transition: all 0.2s ease;
	}

	button:hover,
	button.active {
		background: #f4eee0;
		color: #393646;
	}

	.content {
		flex: 1;
		background: rgba(193, 65, 57, 0.8);
		border-radius: 5px;
		backdrop-filter: blur(10px);
		margin-bottom: 2rem;
		outline: 2px solid #f4eee0;
		/* overflow-y: auto; Enable vertical scrolling */
		overflow: hidden;
		max-height: calc(100vh - 12rem);
		min-height: 0;
	}

	.content.modal-open {
		overflow: hidden !important;
		/* scrollbar-gutter: stable; */
	}

	/* Add scrollbar width variable for consistency */
	:root {
		--scrollbar-width: 10px;
	}

	.content.modal-open {
		/* padding-right: var(--scrollbar-width); */
		padding-right: 0;
	}

	.version-text {
		position: fixed;
		bottom: 1rem;
		right: 1rem;
		color: #f4eee0;
		font-family: "M6X11", sans-serif;
		text-shadow:
			-1px -1px 0 #000,
			1px -1px 0 #000,
			-1px 1px 0 #000,
			1px 1px 0 #000;
	}
	.header-content {
		position: relative;
		margin-bottom: 2rem;
	}
	header {
		margin-bottom: -1rem;
	}

	@media (max-width: 1160px) {
		button {
			padding: 0.6rem 1.2rem;
			border-radius: 8px;
			font-family: "M6X11", sans-serif;
			font-size: 0.9rem;
			cursor: pointer;
			transition: all 0.2s ease;
		}
	}
</style>
