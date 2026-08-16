import { useEffect } from "react";
import { Loader2 } from "lucide-react";
import { CallCenter } from "@/components/CallCenter";
import { ServerRail } from "@/components/ServerRail";
import { ChannelSidebar } from "@/components/ChannelSidebar";
import { DirectMessageSidebar } from "@/components/DirectMessageSidebar";
import { MemberList } from "@/components/MemberList";
import { TextChannelView } from "@/screens/TextChannelView";
import { VoiceChannelView } from "@/screens/VoiceChannelView";
import { DirectMessageView } from "@/screens/DirectMessageView";
import { useChannelsStore } from "@/state/channels";
import { useDmsStore } from "@/state/dms";
import { useServerStore } from "@/state/server";
import { useUsersStore } from "@/state/users";
import { gatewayClient } from "@/ws/gateway";
import { initNotifications } from "@/lib/notifications";

export function ServerShell() {
  const channels = useChannelsStore((s) => s.channels);
  const selectedChannelId = useChannelsStore((s) => s.selectedChannelId);
  const gatewayReady = useChannelsStore((s) => s.ready);
  const activeDmId = useDmsStore((s) => s.activeDmId);
  const conversations = useDmsStore((s) => s.conversations);
  const fetchUsers = useUsersStore((s) => s.fetch);
  const serverName = useServerStore((s) => s.name);

  useEffect(() => {
    gatewayClient.connect();
    void fetchUsers();
    void initNotifications();
    return () => gatewayClient.disconnect();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const selectedChannel = channels.find((c) => c.id === selectedChannelId) ?? null;
  const activeConversation = conversations.find((c) => c.id === activeDmId) ?? null;

  if (!gatewayReady) {
    return (
      <div className="flex h-full w-full items-center justify-center bg-background">
        <Loader2 className="size-6 animate-spin text-muted-foreground" />
      </div>
    );
  }

  // A DM takes over the two right-hand panes; the rail stays put so the server
  // is always one click away, and the member list gives way (a 1:1 has no roster).
  if (activeConversation) {
    return (
      <div className="bg-night-sky flex h-full w-full overflow-hidden">
        <ServerRail serverName={serverName} />
        <DirectMessageSidebar />
        <DirectMessageView conversation={activeConversation} />
        <CallCenter />
      </div>
    );
  }

  return (
    <div className="bg-night-sky flex h-full w-full overflow-hidden">
      <ServerRail serverName={serverName} />
      <ChannelSidebar serverName={serverName} />

      {selectedChannel ? (
        selectedChannel.type === "text" ? (
          <TextChannelView channel={selectedChannel} />
        ) : (
          <VoiceChannelView channel={selectedChannel} />
        )
      ) : (
        <div className="flex flex-1 items-center justify-center text-muted-foreground">
          No channel yet. {channels.length === 0 && "Create one to get started."}
        </div>
      )}

      <MemberList />
      {/* A call can ring while the server's channels are on screen, not just
          from inside a conversation — so this lives outside the DM branch too. */}
      <CallCenter />
    </div>
  );
}
