<script lang="ts">
	import { invoke } from "@tauri-apps/api/core";
	import { onMount } from "svelte";

	let selectedModLoader: "steamodded" | "lovely-only"; // Default value

	onMount(async () => {
		try {
			selectedModLoader = (await invoke("get_modloader")) as
				| "lovely-only"
				| "steamodded";
		} catch (error) {
			console.error("Failed to get modloader:", error);
		}
	});

	async function handleModLoaderChange() {
		const newValue =
			selectedModLoader === "lovely-only" ? "steamodded" : "lovely-only";
		try {
			await invoke("set_modloader", { modloader: newValue });
			selectedModLoader = newValue;
		} catch (error) {
			console.error("Failed to set modloader:", error);
			// Revert the switch if database update fails
			selectedModLoader =
				selectedModLoader === "lovely-only" ? "steamodded" : "lovely-only";
		}
	}
</script>

<div class="switch-container">
	<div class="switch-wrapper">
		<span class:active={selectedModLoader === "lovely-only"} id="lovely-only">
			lovely-only	
		</span>
		<label class="switch">
			<input
				type="checkbox"
				checked={selectedModLoader === "steamodded"}
				on:change={handleModLoaderChange}
			/>
			<span class="slider"></span>
		</label>
		<span class:active={selectedModLoader === "steamodded"} id="steamodded">
			Steamodded
		</span>
	</div>
</div>

<style>
	.switch-container {
		display: flex;
	}

	.switch-wrapper {
		display: flex;
		align-items: center;
		gap: 0.5rem;
	}

	span {
		color: #808080;
		font-family: "M6X11", sans-serif;
		font-size: 1.4rem;
		transition: color 0.3s ease;
	}

	#steamodded.active {
		color: #7c89f0;
	}

	#lovely-only.active {
		color: #ee8242;
	}

	.switch {
		position: relative;
		display: inline-block;
		bottom: 2px;
		width: 60px;
		height: 32px;
	}

	.switch input {
		opacity: 0;
		width: 0;
		height: 0;
	}

	.slider {
		position: absolute;
		cursor: pointer;
		top: 0;
		left: 0;
		right: 0;
		bottom: 0;
		background-color: rgba(57, 54, 70, 0.5);
		transition: 0.3s;
		border-radius: 10px;
		border: 2px solid #f4eee0;
	}

	.slider:before {
		position: absolute;
		content: "";
		height: 24px;
		width: 24px;
		left: 2px;
		bottom: 2px;
		background-color: #f4eee0;
		transition: 0.3s;
		border-radius: 5px;
	}

	input:checked + .slider:before {
		transform: translateX(28px);
	}

	@media (max-width: 1160px) {
		span {
			font-size: 1.3rem;
		}
		.slider {
			width: 50px;
			height: 24px;
		}
		.slider:before {
			height: 20px;
			width: 18px;
		}
		.switch {
			width: 50px;
			height: 24px;
			bottom: 3px;
		}
		.switch input {
			width: 0;
			height: 0;
		}
		.switch-wrapper {
			gap: 0.7rem;
		}
		#steamodded {
			margin-left: 0.25rem;
		}
	}
</style>
