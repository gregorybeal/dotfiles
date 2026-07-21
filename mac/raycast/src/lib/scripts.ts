// Thin wrapper around the existing Alfred scripts — this extension has no
// register-lookup or Royal TSX logic of its own. It shells out to the exact
// same reg-filter.zsh / store-filter.zsh (for search results) and
// reg-connect.zsh / store-connect.zsh (for the connect actions) that the
// Alfred workflow uses, so both stay identical by construction.
import { execFile } from "node:child_process";
import { homedir } from "node:os";
import { join } from "node:path";
import { promisify } from "node:util";

const execFileAsync = promisify(execFile);

// Same convention the Alfred Script Filter fields themselves use — see
// ../../alfred/README.md. Override with REG_ALFRED_DIR if your checkout of
// this repo isn't at ~/dotfiles.
const ALFRED_DIR = process.env.REG_ALFRED_DIR || join(homedir(), "dotfiles", "mac", "alfred");

export interface AlfredMod {
  subtitle?: string;
  arg?: string;
  valid?: boolean;
}

export interface AlfredItem {
  uid?: string;
  title: string;
  subtitle?: string;
  arg?: string;
  valid?: boolean;
  mods?: {
    cmd?: AlfredMod;
    alt?: AlfredMod;
    shift?: AlfredMod;
  };
  text?: { copy?: string; largetype?: string };
  variables?: Record<string, string>;
}

interface AlfredOutput {
  items: AlfredItem[];
}

async function runScript(script: string, args: string[]): Promise<string> {
  const { stdout } = await execFileAsync("zsh", [join(ALFRED_DIR, script), ...args], {
    maxBuffer: 10 * 1024 * 1024,
    env: process.env,
  });
  return stdout;
}

async function fetchItems(script: string, query: string): Promise<AlfredItem[]> {
  const stdout = await runScript(script, [query]);
  const parsed = JSON.parse(stdout) as AlfredOutput;
  // Drop the "No matches"/"No registers" placeholder items — the extension
  // renders its own List.EmptyView instead.
  return parsed.items.filter((item) => item.valid !== false);
}

export function fetchRegisters(query: string): Promise<AlfredItem[]> {
  return fetchItems("reg-filter.zsh", query);
}

export function fetchStores(query: string): Promise<AlfredItem[]> {
  return fetchItems("store-filter.zsh", query);
}

export type Proto = "vnc" | "ssh" | "sftp";

/** Opens a connection the same way reg-connect.zsh / store-connect.zsh do for
 * Alfred — same stored-Royal-TSX-object-first, ad-hoc-fallback logic. */
export function connect(
  script: "reg-connect.zsh" | "store-connect.zsh",
  proto: Proto,
  target: string,
): Promise<string> {
  return runScript(script, [proto, target]);
}

export interface StoreRegister {
  host: string;
  ip: string;
}

/** Parses the "registers" workflow variable store-json.py emits: a JSON
 * array of {host, ip} for every register at that store. */
export function parseStoreRegisters(json: string | undefined): StoreRegister[] {
  if (!json) return [];
  try {
    const parsed: unknown = JSON.parse(json);
    return Array.isArray(parsed) ? (parsed as StoreRegister[]) : [];
  } catch {
    return [];
  }
}
