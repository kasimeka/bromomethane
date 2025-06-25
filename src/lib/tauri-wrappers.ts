import {invoke} from "@tauri-apps/api/core";
import type {Mod} from "../stores/modStore";

export const get_mod_list = async () => {
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  const response = (await invoke("get_mod_list")) as any;
  response.forEach((m: Mod) => {
    m.categories = new Set(m.categories);
  });
  return response as Array<Mod>;
};
