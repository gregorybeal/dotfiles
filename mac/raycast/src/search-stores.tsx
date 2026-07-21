import { useEffect, useRef, useState } from "react";
import { Action, ActionPanel, List, showToast, Toast } from "@raycast/api";
import { AlfredItem, Proto, connect, fetchStores, parseStoreRegisters } from "./lib/scripts";

// Same reasoning as search-registers.tsx: don't fetch/render the full store
// list on an empty query, and cap it defensively even for a broad match.
const MAX_RESULTS = 200;

export default function SearchStores() {
  const [query, setQuery] = useState("");
  const [items, setItems] = useState<AlfredItem[]>([]);
  const [isLoading, setIsLoading] = useState(false);
  const generation = useRef(0);

  useEffect(() => {
    const mine = ++generation.current;
    const trimmed = query.trim();
    if (trimmed === "") {
      setItems([]);
      setIsLoading(false);
      return;
    }
    setIsLoading(true);
    fetchStores(query)
      .then((result) => {
        if (generation.current === mine) setItems(result);
      })
      .catch((error) => {
        if (generation.current === mine) {
          showToast({ style: Toast.Style.Failure, title: "Failed to load stores", message: String(error) });
          setItems([]);
        }
      })
      .finally(() => {
        if (generation.current === mine) setIsLoading(false);
      });
  }, [query]);

  async function run(proto: Proto, store: string, label: string) {
    try {
      await connect("store-connect.zsh", proto, store);
      await showToast({
        style: Toast.Style.Success,
        title: `Opening ${label}`,
        message: `every register at ${store}`,
      });
    } catch (error) {
      await showToast({ style: Toast.Style.Failure, title: `Failed to open ${label}`, message: String(error) });
    }
  }

  const visible = items.slice(0, MAX_RESULTS);
  const hiddenCount = items.length - visible.length;

  return (
    <List
      isLoading={isLoading}
      isShowingDetail={items.length > 0}
      searchBarPlaceholder="Search by store #, city, state, or regional…"
      onSearchTextChange={setQuery}
      throttle
    >
      {query.trim() === "" ? (
        <List.EmptyView title="Type to search" description="Search by store #, city, state, or regional" />
      ) : items.length === 0 && !isLoading ? (
        <List.EmptyView title="No stores" description="Check REG_DB and the ssh config" />
      ) : (
        <>
          {visible.map((item) => {
            const v = item.variables ?? {};
            const store = item.uid || item.title;
            const registers = parseStoreRegisters(v.registers);
            const markdown =
              `## ${item.title}\n\n` +
              (registers.length
                ? registers.map((r) => `- \`${r.host}\`${r.ip ? ` — ${r.ip}` : ""}`).join("\n")
                : "_No registers found._");

            return (
              <List.Item
                key={item.uid ?? item.title}
                title={item.title}
                subtitle={item.subtitle}
                detail={
                  <List.Item.Detail
                    markdown={markdown}
                    metadata={
                      <List.Item.Detail.Metadata>
                        <List.Item.Detail.Metadata.Label title="City" text={v.city || "—"} />
                        <List.Item.Detail.Metadata.Label title="State" text={v.state || "—"} />
                        <List.Item.Detail.Metadata.Label title="Regional" text={v.regional || "—"} />
                        <List.Item.Detail.Metadata.Label title="Registers" text={String(registers.length)} />
                      </List.Item.Detail.Metadata>
                    }
                  />
                }
                actions={
                  <ActionPanel>
                    <Action title="Open All (VNC)" onAction={() => run("vnc", store, "VNC")} />
                    <Action
                      title="Open All via SSH"
                      shortcut={{ modifiers: ["cmd"], key: "return" }}
                      onAction={() => run("ssh", store, "SSH")}
                    />
                    <Action
                      title="Open All via SFTP"
                      shortcut={{ modifiers: ["opt"], key: "return" }}
                      onAction={() => run("sftp", store, "SFTP")}
                    />
                    <Action.CopyToClipboard title="Copy Store Number" content={store} />
                  </ActionPanel>
                }
              />
            );
          })}
          {hiddenCount > 0 && (
            <List.Item
              title={`+ ${hiddenCount} more match${hiddenCount === 1 ? "" : "es"}`}
              subtitle="Refine your search to narrow this down"
            />
          )}
        </>
      )}
    </List>
  );
}
