import { useEffect, useRef, useState } from "react";
import { Action, ActionPanel, List, showToast, Toast } from "@raycast/api";
import { AlfredItem, Proto, connect, fetchRegisters } from "./lib/scripts";

export default function SearchRegisters() {
  const [query, setQuery] = useState("");
  const [items, setItems] = useState<AlfredItem[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  // Guards against a slow earlier keystroke's fetch clobbering a faster
  // later one — mirrors why reg-filter.zsh itself is invoked fresh per
  // keystroke rather than trusting result ordering.
  const generation = useRef(0);

  useEffect(() => {
    const mine = ++generation.current;
    setIsLoading(true);
    fetchRegisters(query)
      .then((result) => {
        if (generation.current === mine) setItems(result);
      })
      .catch((error) => {
        if (generation.current === mine) {
          showToast({ style: Toast.Style.Failure, title: "Failed to load registers", message: String(error) });
          setItems([]);
        }
      })
      .finally(() => {
        if (generation.current === mine) setIsLoading(false);
      });
  }, [query]);

  async function run(proto: Proto, host: string, label: string) {
    try {
      await connect("reg-connect.zsh", proto, host);
      await showToast({ style: Toast.Style.Success, title: `Opening ${label}`, message: host });
    } catch (error) {
      await showToast({ style: Toast.Style.Failure, title: `Failed to open ${label}`, message: String(error) });
    }
  }

  return (
    <List
      isLoading={isLoading}
      isShowingDetail
      searchBarPlaceholder="Search by hostname, store #, city, state, or regional…"
      onSearchTextChange={setQuery}
      throttle
    >
      {items.length === 0 && !isLoading ? (
        <List.EmptyView title="No registers" description="Check REG_DB and the ssh config" />
      ) : (
        items.map((item) => {
          const v = item.variables ?? {};
          const host = v.host || item.uid || item.title;
          const ip = v.ip || "";
          const hasIp = Boolean(ip) && item.mods?.shift?.valid !== false;

          return (
            <List.Item
              key={item.uid ?? host}
              title={item.title}
              subtitle={item.subtitle}
              detail={
                <List.Item.Detail
                  metadata={
                    <List.Item.Detail.Metadata>
                      <List.Item.Detail.Metadata.Label title="Host" text={host} />
                      <List.Item.Detail.Metadata.Label title="Store" text={v.store || "—"} />
                      <List.Item.Detail.Metadata.Label title="City" text={v.city || "—"} />
                      <List.Item.Detail.Metadata.Label title="State" text={v.state || "—"} />
                      <List.Item.Detail.Metadata.Label title="Regional" text={v.regional || "—"} />
                      <List.Item.Detail.Metadata.Separator />
                      <List.Item.Detail.Metadata.Label title="IP Address" text={ip || "not in inventory"} />
                    </List.Item.Detail.Metadata>
                  }
                />
              }
              actions={
                <ActionPanel>
                  <Action title="Open (VNC)" onAction={() => run("vnc", host, "VNC")} />
                  <Action
                    title="Open via SSH"
                    shortcut={{ modifiers: ["cmd"], key: "return" }}
                    onAction={() => run("ssh", host, "SSH")}
                  />
                  <Action
                    title="Open via SFTP"
                    shortcut={{ modifiers: ["opt"], key: "return" }}
                    onAction={() => run("sftp", host, "SFTP")}
                  />
                  {hasIp && (
                    <Action.CopyToClipboard
                      title="Copy IP Address"
                      content={ip}
                      shortcut={{ modifiers: ["cmd", "shift"], key: "c" }}
                    />
                  )}
                  <Action.CopyToClipboard
                    title="Copy Hostname"
                    content={host}
                    shortcut={{ modifiers: ["cmd"], key: "." }}
                  />
                </ActionPanel>
              }
            />
          );
        })
      )}
    </List>
  );
}
