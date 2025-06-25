<script lang="ts">
  import "@total-typescript/ts-reset";

  import {invoke} from "@tauri-apps/api/core";
  import {modsStore, type Mod} from "../../stores/modStore";
  import * as tauri from "../../lib/tauri-wrappers";
  import ModCard from "./ModCard.svelte";
  import {onMount} from "svelte";

  type Props = {
    indices: Array<number>;
    onmodclick?: (mod: Mod) => void;
    oninstallclick?: (mod: Mod) => void;
    onuninstallclick?: (mod: Mod) => void;
    onToggleEnabled?: () => Promise<void>;
    hasLocalMods?: boolean;
  };

  let {
    indices,
    oninstallclick,
    onuninstallclick,
    onmodclick,
    onToggleEnabled,
    hasLocalMods,
  }: Props = $props();

  const fetchThumbnails = async (indices: Array<number>) => {
    console.log("indices", indices);
    await invoke("fetch_thumbnails_by_indices", {indices});
    const modlist = await tauri.get_mod_list();
    indices
      .map(i => modlist[i])
      .filter(Boolean)
      .forEach(m => {
        m.image ||= "images/cover.jpg";
      });
    modsStore.set(modlist);
    await invoke("update_last_fetched");
  };

  onMount(async () => {
    await fetchThumbnails(indices);
  });
</script>

<div class="mods-grid" class:has-local-mods={hasLocalMods}>
  {#each indices.map(i => $modsStore[i]).filter(Boolean) as mod (`${mod.publisher}@${mod.title}`)}
    <ModCard {mod} {onmodclick} {oninstallclick} {onuninstallclick} {onToggleEnabled} />
  {/each}
</div>

<style>
  .mods-grid:last-child {
    padding-bottom: 2rem;
  }
  .mods-grid {
    padding: 1rem 2rem 2rem 2rem;
    flex: 1;
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(280px, 1fr));
    gap: 30px;
  }
</style>
