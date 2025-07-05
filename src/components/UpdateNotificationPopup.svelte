<script lang="ts">
  import {fade, scale} from "svelte/transition";
  import {onMount} from "svelte";
  import {marked} from "marked";
  import {open} from "@tauri-apps/plugin-shell";

  interface GitHubRelease {
    latest_tag: string;
    notes: string;
    assets: Array<{
      name: string;
      url: string;
    }>;
  }

  let {
    visible = $bindable(false),
    onDismiss: dismiss,
    isAutoCheck = false,
  }: {
    visible: boolean;
    onDismiss: () => void;
    isAutoCheck?: boolean;
  } = $props();

  let isLoading = $state(false);
  let errorMessage = $state<string | null>(null);
  let hasUpdate = $state(false);
  let release = $state<GitHubRelease | null>(null);
  let releaseNotes = $state<string>("");

  async function checkForUpdates() {
    try {
      visible = !isAutoCheck;
      isLoading = true;
      errorMessage = null;

      const response = await fetch(
        `https://api.github.com/repos/${__APP_REPO_SLUG__}/releases/latest`,
      );

      if (!response.ok) {
        throw new Error(`GitHub API error: ${response.status}`);
      }

      // TODO: arktype here?
      const data = await response.json();

      // Transform the data to match the requested format
      const transformedData: GitHubRelease = {
        latest_tag: data.tag_name,
        notes: data.body,
        assets: data.assets.map(asset => ({
          name: asset.name,
          url: asset.browser_download_url,
        })),
      };

      release = transformedData;

      // Compare versions - remove 'v' prefix if present for comparison
      const latestVersion = transformedData.latest_tag.replace(/^v/, "");

      hasUpdate = latestVersion !== __APP_VERSION__;

      if (isAutoCheck) {
        if (hasUpdate) {
          const ignoredVersion = localStorage.getItem("ignoredUpdateVersion");
          if (ignoredVersion === transformedData.latest_tag) {
            hasUpdate = false;
          } else {
            visible = true;
          }
        } else {
          dismiss();
        }
      }
    } catch (error) {
      console.error("failed to check for updates:", error);
      errorMessage = "failed to check for updates. please try again later.";
    } finally {
      isLoading = false;
    }
  }

  onMount(() => {
    if (visible) {
      checkForUpdates();
    }
  });

  $effect(() => {
    if (visible && !release) {
      checkForUpdates();
    }
  });

  $effect(() => {
    if (release?.notes) {
      Promise.resolve(marked(release.notes)).then(result => {
        releaseNotes = result;
      });
    } else {
      releaseNotes = "";
    }
  });

  function handleKeydown(event: KeyboardEvent) {
    if (event.key === "Escape" && visible) {
      dismiss();
    }
  }
</script>

<svelte:window on:keydown={handleKeydown} />

{#if visible}
  <div
    class="modal-background"
    role="button"
    tabindex="0"
    transition:fade={{duration: 100}}
    onclick={dismiss}
    onkeydown={handleKeydown}
  >
    <div
      class="modal"
      role="dialog"
      tabindex="0"
      transition:scale={{duration: 200, start: 0.95, opacity: 1}}
      onclick={e => e.stopPropagation()}
      onkeydown={e => e.stopPropagation()}
    >
      {#if isLoading}
        <h2>checking for updates...</h2>
        <p>please wait while we check for the latest version.</p>
      {:else if errorMessage}
        <h2>update check failed</h2>
        <p class="error-message">{errorMessage}</p>
        <div class="buttons">
          <button class="cancel-button" onclick={dismiss}>close</button>
          <button class="confirm-button" onclick={checkForUpdates}>try again</button>
        </div>
      {:else if hasUpdate && release}
        <h2>update available!</h2>
        <div class="update-info">
          <p><strong>latest release:</strong> {release.latest_tag}</p>
          <p><strong>current version:</strong> v{__APP_VERSION__}</p>

          {#if releaseNotes}
            <div class="release-notes">
              <h3>release notes:</h3>
              <!-- eslint-disable-next-line svelte/no-at-html-tags : i write the release notes :) -->
              <div class="release-content"><div>{@html releaseNotes}</div></div>
            </div>
          {/if}

          {#if release.assets.length > 0}
            <div class="download-assets">
              <h3>downloads:</h3>
              <ul>
                {#each release.assets as asset (asset.name)}
                  <li>
                    <a href={asset.url} target="_blank" rel="noopener noreferrer">
                      {asset.name}
                    </a>
                  </li>
                {/each}
              </ul>
            </div>
          {/if}
        </div>

        <div class="buttons">
          <button
            class="confirm-button"
            onclick={() => open(`https://github.com/${__APP_REPO_SLUG__}/releases/latest`)}
            >open release page</button
          >
          <button
            class="ignore-button"
            onclick={() => {
              localStorage.setItem("ignoredUpdateVersion", release?.latest_tag || "");
              dismiss();
            }}>ignore this version</button
          >
          <button class="cancel-button" onclick={dismiss}>dismiss</button>
        </div>
      {:else}
        <h2>you're up to date!</h2>
        <p>you have the latest version of bromomethane.</p>
        <p><strong>current version:</strong> v{__APP_VERSION__}</p>

        <div class="buttons">
          <button class="confirm-button" onclick={dismiss}>close</button>
        </div>
      {/if}
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
    outline: 2px solid #56a786;
    padding: 2rem;
    border-radius: 8px;
    box-shadow: 0 0 15px rgba(0, 0, 0, 0.7);
    max-width: 800px;
    width: 92%;
    text-align: center;
    max-height: 85vh;
  }

  h2 {
    color: #56a786;
    margin-bottom: 1.5rem;
    font-family: "M6X11", sans-serif;
    font-size: 2rem;
  }

  h3 {
    color: #74cca8;
    margin-bottom: 0.75rem;
    font-family: "M6X11", sans-serif;
    font-size: 1.4rem;
  }

  p {
    color: #f4eee0;
    font-size: 1.2rem;
    margin-bottom: 1.2rem;
    font-family: "M6X11", sans-serif;
  }

  .error-message {
    color: #f87171;
    font-size: 1rem;
    margin-bottom: 1rem;
    font-family: "M6X11", sans-serif;
  }

  .update-info {
    text-align: left;
    margin-bottom: 2rem;
    padding: 0 1rem;
  }

  .release-notes {
    margin: 1.5rem 0;
  }

  .release-content {
    font-family: "M6X11", sans-serif;
    font-size: 1.1rem;
    color: #d1d5db;
    line-height: 1.7;
    margin: 0.75rem 0;
    max-height: 250px;
    overflow-y: auto;
    word-wrap: break-word;
  }

  .release-content :global(h1),
  .release-content :global(h2),
  .release-content :global(h3),
  .release-content :global(h4),
  .release-content :global(h5),
  .release-content :global(h6) {
    color: #74cca8;
    margin: 0.75rem 0 0.5rem 0;
    font-family: "M6X11", sans-serif;
  }

  .release-content :global(h1) {
    font-size: 1.4rem;
  }

  .release-content :global(h2) {
    font-size: 1.2rem;
  }

  .release-content :global(h3) {
    font-size: 1.1rem;
  }

  .release-content :global(p) {
    margin: 0.5rem 0;
    color: #d1d5db;
  }

  .release-content :global(ul),
  .release-content :global(ol) {
    margin: 0.5rem 0;
    padding-left: 1.5rem;
  }

  .release-content :global(li) {
    margin: 0.25rem 0;
    color: #d1d5db;
  }

  .release-content :global(a) {
    color: #74cca8;
    text-decoration: underline;
  }

  .release-content :global(a:hover) {
    color: #56a786;
  }

  .release-content :global(code) {
    background: #2a2a2a;
    padding: 0.125rem 0.25rem;
    border-radius: 3px;
    font-family: monospace;
    font-size: 0.8rem;
  }

  .release-content :global(pre) {
    background: #2a2a2a;
    padding: 0.5rem;
    border-radius: 4px;
    overflow-x: auto;
    margin: 0.5rem 0;
  }

  .release-content :global(pre code) {
    background: none;
    padding: 0;
  }

  .release-content :global(blockquote) {
    border-left: 3px solid #56a786;
    margin: 0.5rem 0;
    padding-left: 1rem;
    color: #b0b0b0;
    font-style: italic;
  }

  .release-content :global(hr) {
    border: none;
    height: 1px;
    background: #56a786;
    margin: 1rem 0;
  }

  .download-assets {
    margin: 1.5rem 0;
  }

  .download-assets ul {
    list-style: none;
    padding: 0;
    margin: 0;
  }

  .download-assets li {
    margin: 0.75rem 0;
  }

  .download-assets a {
    color: #74cca8;
    text-decoration: none;
    font-family: "M6X11", sans-serif;
    font-size: 1.1rem;
    padding: 0.5rem 1rem;
    border-radius: 6px;
    background: #1a1a1a;
    display: inline-block;
    transition: background 0.2s ease;
    border: 2px solid #56a786;
  }

  .download-assets a:hover {
    background: #2a2a2a;
    text-decoration: underline;
    transform: scale(1.02);
  }

  .buttons {
    display: flex;
    justify-content: center;
    gap: 1.5rem;
    margin-top: 2rem;
    flex-wrap: wrap;
  }

  button {
    padding: 1rem 2rem;
    border: none;
    border-radius: 6px;
    cursor: pointer;
    font-size: 1.3rem;
    transition: all 0.2s ease;
    font-family: "M6X11", sans-serif;
    min-width: 120px;
  }

  button:disabled {
    opacity: 0.6;
    cursor: not-allowed;
  }

  .cancel-button {
    background: #6b7280;
    outline: #9ca3af solid 2px;
    color: #fff;
  }

  .ignore-button {
    background: #ef4444;
    outline: #f87171 solid 2px;
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
