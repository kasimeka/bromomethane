<script lang="ts">
  import {RefreshCw} from "lucide-svelte";

  let {onCheckForUpdates}: {onCheckForUpdates?: () => void} = $props();
</script>

<div class="container default-scrollbar">
  <div class="about-container">
    <div class="content">
      <h2>About bromomethane</h2>

      <div>
        <p>
          bromomethane is a tool designed to help you manage and install mods for the game Balatro.
          It provides an easy-to-use interface for mod management while maintaining the game's
          unique aesthetic.
        </p>
      </div>

      <div>
        <h3>Features</h3>
        <ul>
          <li>Easy mod installation and management</li>
          <li>Automatic game path detection</li>
          <li>Mod compatibility checks</li>
        </ul>
      </div>

      <div class="button-container">
        {#if onCheckForUpdates}
          <button class="update-button" onclick={onCheckForUpdates}>
            <RefreshCw size={20} />
            <span>Check for Updates</span>
          </button>
        {/if}
      </div>

      <p id="versiontext">{`Current version: v${__APP_VERSION__}`}</p>
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
    margin: 0;
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

  h3 {
    font-size: 1.8rem;
    margin-bottom: 0.5rem;
    color: #fdcf51;
  }

  p {
    font-size: 1.2rem;
    margin-bottom: 1rem;
  }

  #versiontext {
    color: #fde700;
    margin-top: 1rem;
  }

  ul {
    list-style-type: disc;
    margin-left: 1rem;
    margin-bottom: 1rem;
  }

  li {
    font-size: 1.2rem;
    margin-bottom: 0.5rem;
  }
  .button-container {
    display: flex;
    gap: 1rem;
    margin: 1rem 0;
    flex-wrap: wrap;
  }

  @media (max-width: 1160px) {
    p {
      font-size: 1rem;
    }
    li {
      font-size: 1rem;
    }

    h2 {
      font-size: 2rem;
    }
    h3 {
      font-size: 1.5rem;
    }
  }
</style>
