<script lang="ts">
	import { CircleAlert } from "lucide-svelte";
	import { fade, scale } from "svelte/transition";
	import { invoke } from "@tauri-apps/api/core";

	let {
		show = $bindable(false),
		requiresSteamodded = false,
		requiresTalisman = false,
		onProceed = () => {},
		onDependencyClick = () => {}, // New prop to handle dependency clicks
	}: {
		show?: boolean;
		requiresSteamodded?: boolean;
		requiresTalisman?: boolean;
		onProceed?: () => void;
		onDependencyClick?: (dependency: string) => void; // New type
	} = $props();

	let steamoddedInstalled = $state(false);
	let talismanInstalled = $state(false);

	async function checkInstallations() {
		if (requiresSteamodded) {
			steamoddedInstalled = await invoke("check_mod_installation", {
				modType: "Steamodded",
			});
		}
		if (requiresTalisman) {
			talismanInstalled = await invoke("check_mod_installation", {
				modType: "Talisman",
			});
		}
	}

	function handleProceedClick() {
		if (onProceed) {
			onProceed();
		}
		show = false;
	}

	$effect(() => {
		if (show) {
			checkInstallations();
		}
	});
</script>

{#if show}
	<div class="popup-overlay" transition:fade={{ duration: 100 }}>
		<div
			class="popup-content"
			transition:scale={{ duration: 200, start: 0.95, opacity: 1 }}
		>
			<div class="popup-header">
				<CircleAlert size={32} color="#fdcf51" />
				<h2>Required Dependencies</h2>
			</div>
			<div class="popup-body">
				<p>This mod requires the following missing dependencies:</p>
				<ul>
					{#if requiresSteamodded && !steamoddedInstalled}
						<li>
							<!-- Accessible clickable Steamodded link -->
							<span
								class="dependency clickable"
								role="button"
								tabindex="0"
								onclick={(e) => {
									e.stopPropagation();
									onDependencyClick("Steamodded");
									show = false;
								}}
								onkeydown={(e) => {
									if (e.key === "Enter" || e.key === " ") {
										e.preventDefault();
										onDependencyClick("Steamodded");
										show = false;
									}
								}}
							>
								Steamodded
							</span>
							- Core modding framework
						</li>
					{/if}
					{#if requiresTalisman && !talismanInstalled}
						<li>
							<!-- Accessible clickable Talisman link -->
							<span
								class="dependency clickable"
								role="button"
								tabindex="0"
								onclick={(e) => {
									e.stopPropagation();
									onDependencyClick("Talisman");
									show = false;
								}}
								onkeydown={(e) => {
									if (e.key === "Enter" || e.key === " ") {
										e.preventDefault();
										onDependencyClick("Talisman");
										show = false;
									}
								}}
							>
								Talisman
							</span>
							- Extended modding API
						</li>
					{/if}
				</ul>

				{#if (requiresSteamodded && !steamoddedInstalled) || (requiresTalisman && !talismanInstalled)}
					<p>It's recommended to install these first.</p>
				{:else}
					<p>All required dependencies seem to be installed.</p>
				{/if}

				<div class="button-container">
					<button class="proceed-button" onclick={handleProceedClick}>
						Download Anyway
					</button>
					<button
						class="cancel-button"
						onclick={() => (show = false)}
					>
						Close
					</button>
				</div>
			</div>
		</div>
	</div>
{/if}

<style>
	.dependency.clickable {
		cursor: pointer;
		transition: all 0.2s ease;
		position: relative;
		display: inline-block;
		text-decoration: underline; /* Add underline to indicate it's clickable */
		text-underline-offset: 5px; /* Add some space between text and underline */
	}

	.dependency.clickable:hover {
		color: #ffffff;
		transform: translateY(-1px);
		text-decoration-thickness: 2px; /* Make underline thicker on hover */
	}

	.dependency.clickable:hover::after {
		content: "Open mod page";
		position: absolute;
		bottom: -25px;
		left: 0;
		background: rgba(0, 0, 0, 0.8);
		color: #f4eee0;
		padding: 4px 8px;
		border-radius: 4px;
		font-size: 0.8rem;
		white-space: nowrap;
		pointer-events: none;
		z-index: 10;
	}
	/* Styles remain the same */
	.popup-overlay {
		position: fixed;
		top: 0;
		left: 0;
		width: 100%;
		height: 100%;
		background: rgba(0, 0, 0, 0.8);
		display: flex;
		justify-content: center;
		align-items: center;
		z-index: 1000;
	}

	.popup-content {
		background: #393646;
		border: 2px solid #f4eee0;
		border-radius: 12px;
		padding: 2rem;
		width: 500px;
		max-width: 90%;
	}

	.popup-header {
		display: flex;
		align-items: center;
		gap: 0.75rem;
		margin-bottom: 1.5rem;
	}

	.popup-header h2 {
		color: #fdcf51;
		font-size: 2rem;
		margin: 0;
	}

	.popup-body {
		color: #f4eee0;
		font-size: 1.2rem;
	}

	.popup-body p {
		margin-bottom: 1.5rem;
	}

	.popup-body ul {
		list-style: none;
		padding: 0;
		margin-bottom: 2rem;
	}

	.popup-body li {
		margin-bottom: 1rem;
		display: flex;
		align-items: center;
		gap: 0.75rem;
		font-size: 1.2rem;
	}

	.dependency {
		color: #fdcf51;
		font-weight: bold;
		font-size: 1.3rem;
	}

	.button-container {
		display: flex;
		gap: 1rem;
		justify-content: flex-end;
	}

	.cancel-button,
	.proceed-button {
		padding: 1rem 1.5rem;
		color: #f4eee0;
		border: none;
		border-radius: 6px;
		font-family: "M6X11", sans-serif;
		font-size: 1.2rem;
		cursor: pointer;
		transition: all 0.2s ease;
	}

	.cancel-button {
		background: #c14139;
		outline: #a13029 solid 2px;
	}

	.cancel-button:hover {
		background: #d4524a;
		transform: translateY(-2px);
	}

	.proceed-button {
		background: #4f5a9c;
		outline: #3a4275 solid 2px;
	}

	.proceed-button:hover {
		background: #606db7;
		transform: translateY(-2px);
	}

	@media (max-width: 1160px) {
		.popup-content {
			padding: 1.5rem;
			width: 90%;
			max-width: 400px;
		}
		.popup-header h2 {
			font-size: 1.5rem;
		}
		.popup-body {
			font-size: 1rem;
		}
		.popup-body li {
			font-size: 1rem;
			margin-bottom: 0.75rem;
		}
		.dependency {
			font-size: 1.1rem;
		}
		.cancel-button,
		.proceed-button {
			padding: 0.75rem 1.25rem;
			font-size: 1rem;
			border-radius: 4px;
		}
		.popup-header {
			gap: 0.5rem;
			margin-bottom: 1rem;
		}
	}
</style>
