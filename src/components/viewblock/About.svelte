<script lang="ts">
  import {RefreshCw} from "lucide-svelte";

  let {onCheckForUpdates}: {onCheckForUpdates?: () => void} = $props();

  const repoUrl = `https://github.com/${__APP_REPO_SLUG__}`;
</script>

<div class="container default-scrollbar">
  <div class="about-container">
    <div class="content">
      <h2>about bromomethane</h2>

      <p>
        bromomethane is a tool to help you manage and install mods for the game Balatro, it also
        installs lovely -the game's defacto standard mod loader & code injector- for you.
      </p>

      <p>
        the project is fully open source and licenesed under gplv3, you can find its source code at
        &lt;<a href={repoUrl} target="_blank" rel="noopener noreferrer">{repoUrl}</a>&gt;.
      </p>

      {#if onCheckForUpdates}
        <button class="update-button" onclick={onCheckForUpdates}>
          <RefreshCw size={20} />
          <span>check for updates</span>
        </button>
      {/if}
    </div>
  </div>
</div>

<style>
  .about-container {
    display: flex;
    justify-content: space-between;
    gap: 2rem;
    align-items: center;

    padding: 0rem 2rem;

    &::-webkit-scrollbar {
      width: 10px;
    }

    &::-webkit-scrollbar-track {
      background: transparent;
      border-radius: 15px;
    }

    &::-webkit-scrollbar-thumb {
      background: #f4eee0;
      border: 2px solid rgba(193, 65, 57, 0.8);
      border-radius: 15px;
    }

    &::-webkit-scrollbar:horizontal {
      display: none;
    }

    &::-webkit-scrollbar-corner {
      background-color: transparent;
    }
  }

  .content {
    flex: 1;
  }

  a {
    color: #74cca8;
  }

  .update-button {
    background-color: #56a786;
    border: 4px solid #f4eee0;
    border-radius: 8px;
    color: #fff;
    padding: 0.5rem 1rem;
    font-family: "M6X11", sans-serif;
    font-size: 1.2rem;
    cursor: pointer;
    transition: all 0.2s ease;
    box-shadow: 0 0 10px rgba(0, 0, 0, 0.3);
    margin-top: 1.5rem;
    display: flex;
    align-items: center;
    gap: 0.5rem;
    position: relative;
  }

  .update-button:hover {
    background-color: #74cca8;
    transform: scale(1.05);
  }

  .update-button:active {
    transform: scale(0.95);
  }

  h2 {
    font-size: 2.5rem;
    margin-bottom: 1rem;
    color: #fdcf51;
  }

  div,
  p {
    font-size: 1.3rem;
    margin-bottom: 1rem;
  }
</style>
