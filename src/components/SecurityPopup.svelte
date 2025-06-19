<script lang="ts">
	import { fade, scale } from "svelte/transition";
	import { invoke } from "@tauri-apps/api/core";

	export let visible: boolean = false;
	export let onAcknowledge: () => void;
	export let onCancel: () => void;

	let isLoading: boolean = false;
	let errorMessage: string | null = null;

	async function handleAcknowledge() {
		try {
			isLoading = true;
			errorMessage = null;

			// Always store acknowledgment when user clicks "I Understand"
			await invoke("set_security_warning_acknowledged", {
				acknowledged: true,
			});

			// Then call the parent component's callback
			onAcknowledge();
		} catch (error) {
			console.error("Failed to save security acknowledgment:", error);
			errorMessage = "Failed to save your preference. Please try again.";
		} finally {
			isLoading = false;
		}
	}

	function handleQuit() {
		// Close the application
		invoke("exit_application");
		onCancel();
	}
</script>

{#if visible}
	<div class="modal-background" transition:fade={{ duration: 100 }}>
		<div
			class="modal"
			transition:scale={{ duration: 200, start: 0.95, opacity: 1 }}
		>
			<h2>Security Notice</h2>
			<p>
				Mods are created and maintained by third-party developers. While
				the index is curated, we cannot guarantee their safety. Please
				install only if you trust the source.
			</p>
			{#if errorMessage}
				<p class="error-message">{errorMessage}</p>
			{/if}
			<div class="buttons">
				<button
					class="cancel-button"
					on:click={handleQuit}
					disabled={isLoading}
				>
					Quit
				</button>
				<button
					class="confirm-button"
					on:click={handleAcknowledge}
					disabled={isLoading}
				>
					{#if isLoading}
						Saving...
					{:else}
						I Understand
					{/if}
				</button>
			</div>
		</div>
	</div>
{/if}

<style>
	.modal-background {
		position: fixed;
		top: 0;
		left: 0;
		width: 100%;
		height: 100%;
		background: rgba(0, 0, 0, 0.6);
		display: flex;
		align-items: center;
		justify-content: center;
		z-index: 999;
	}
	.modal {
		background: #2d2d2d;
		outline: 2px solid #f87171;
		padding: 2rem;
		border-radius: 8px;
		box-shadow: 0 0 15px rgba(0, 0, 0, 0.7);
		max-width: 500px;
		width: 90%;
		text-align: center;
	}
	h2 {
		color: #f87171;
		margin-bottom: 1rem;
		font-family: "M6X11", sans-serif;
	}
	p {
		color: #f4eee0;
		font-size: 1.2rem;
		margin-bottom: 1.5rem;
		font-family: "M6X11", sans-serif;
	}
	.error-message {
		color: #f87171;
		font-size: 0.9rem;
		margin-bottom: 1rem;
		font-family: "M6X11", sans-serif;
	}
	.buttons {
		display: flex;
		justify-content: center;
		gap: 1rem;
	}
	button {
		padding: 0.8rem 1.5rem;
		border: none;
		border-radius: 4px;
		cursor: pointer;
		font-size: 1rem;
		transition: all 0.2s ease;
		font-family: "M6X11", sans-serif;
	}
	button:disabled {
		opacity: 0.6;
		cursor: not-allowed;
	}
	.cancel-button {
		background: #f87171;
		outline: #f0a7a7 solid 2px;
		color: #fff;
	}
	.confirm-button {
		background: #56a786;
		outline: #74cca8 solid 2px;
		color: #fff;
	}
	button:hover:not(:disabled) {
		opacity: 0.9;
		scale: 1.05;
		transition: all 0.2s ease;
	}
</style>
