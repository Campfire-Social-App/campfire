import { useEffect, useState } from "react";
import { Loader2 } from "lucide-react";
import { ServerRail } from "@/components/ServerRail";
import { ChannelSidebar } from "@/components/ChannelSidebar";
import { MemberList } from "@/components/MemberList";
import { TextChannelView } from "@/screens/TextChannelView";
import { VoiceChannelView } from "@/screens/VoiceChannelView";
import { useChannelsStore } from "@/state/channels";
import { useUsersStore } from "@/state/users";
import { gatewayClient } from "@/ws/gateway";
import { getServerSettings } from "@/api/endpoints";

export function ServerShell() {
  const channels = useChannelsStore((s) => s.channels);
  const selectedChannelId = useChannelsStore((s) => s.selectedChannelId);
  const gatewayReady = useChannelsStore((s) => s.ready);
  const fetchUsers = useUsersStore((s) => s.fetch);
  const [serverName, setServerName] = useState("Campfire");

  useEffect(() => {
    gatewayClient.connect();
    void getServerSettings().then((s) => setServerName(s.name));
    void fetchUsers();
    return () => gatewayClient.disconnect();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const selectedChannel = channels.find((c) => c.id === selectedChannelId) ?? null;

  if (!gatewayReady) {
    return (
      <div className="flex h-screen w-screen items-center justify-center bg-background">
        <Loader2 className="size-6 animate-spin text-muted-foreground" />
      </div>
    );
  }

  return (
    <div className="flex h-screen w-screen overflow-hidden bg-background">
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
          Nenhum canal ainda. {channels.length === 0 && "Crie um para começar."}
        </div>
      )}

      <MemberList />
    </div>
  );
}
