<script lang="ts">
	import { blur } from "svelte/transition";
	import MessageStack from "../components/MessageStack.svelte";
	import { backgroundEnabled } from "../stores/modStore";
	import { onMount } from "svelte";
	import DragDropOverlay from "../components/DragDropOverlay.svelte";
	import { Window } from "@tauri-apps/api/window";

	import "../app.css";

	export let data;

	let isWindows = false;

	async function setupAppWindow() {
		const appWindow = Window.getCurrent();

		await appWindow.show();
		await appWindow.setFocus();
	}

	onMount(() => {
		isWindows = navigator.userAgent.indexOf("Windows") !== -1;
		setupAppWindow();
	});
</script>

<MessageStack />
<DragDropOverlay />
<div
	class="layout-container"
	style:--gradient-opacity={$backgroundEnabled ? 0 : 1}
	style:--dot-size={isWindows ? "1.5px" : "0.45px"}
	style:--dot-color={isWindows ? "#ff9999" : "#d66060"}
>
	{#key data.url}
		<div
			in:blur={{ duration: 300, delay: 150 }}
			out:blur={{ duration: 150 }}
			class="page-content"
		>
			<slot />
		</div>
	{/key}
</div>

<style>
	.layout-container {
		width: 100%;
		height: 100%;
		position: fixed;
		top: 0;
		left: 0;
		overflow: hidden;
		background-color: #a53535; /* Fallback background color */
	}

	.layout-container::before {
		content: "";
		position: fixed;
		top: 0;
		left: 0;
		width: 100%;
		height: 100%;
		opacity: var(--gradient-opacity, 1);
		transition: opacity 0.4s cubic-bezier(0.4, 0, 0.2, 1);
		background-color: #a53535;
		background-image: radial-gradient(
				var(--dot-color, #d66060) var(--dot-size, 0.45px),
				transparent var(--dot-size, 0.45px)
			),
			radial-gradient(
				var(--dot-color, #d66060) var(--dot-size, 0.45px),
				#a53535 var(--dot-size, 0.45px)
			);
		background-size: 18px 18px;
		background-position:
			0 0,
			9px 9px;
		z-index: -2; /* Adjust z-index to ensure proper layering */
		pointer-events: none; /* Ensure the background doesn't block interactions */
	}

	.page-content {
		width: 100%;
		height: 100%;
		position: relative;
		overflow: hidden;
		z-index: 1; /* Ensure content sits above the background */
	}

	@media screen and (min-width: 1920px) {
		.layout-container::before {
			background-size: 24px 24px;
			background-position:
				0 0,
				12px 12px;
		}
	}
</style>
