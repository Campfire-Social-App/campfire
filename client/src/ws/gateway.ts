import { useAuthStore } from "@/state/auth";
import { useSettingsStore } from "@/state/settings";
import { useChannelsStore } from "@/state/channels";
import { useMessagesStore } from "@/state/messages";
import { usePresenceStore } from "@/state/presence";
import { useVoiceStore } from "@/state/voice";
import { useUsersStore } from "@/state/users";
import { useDmsStore } from "@/state/dms";
import { useCallsStore } from "@/state/calls";
import { leaveVoiceChannel } from "@/livekit/voice";
import { playJoinSound, playLeaveSound } from "@/lib/sounds";
import { messageMentionsUser } from "@/lib/mentions";
import { notify } from "@/lib/notifications";
import { toast } from "sonner";
import type {
  Channel,
  ChannelDeleteData,
  DMCallData,
  DMConversation,
  GatewayEvent,
  Message,
  MessageDeleteData,
  PresenceUpdateData,
  ReadyEventData,
  TypingStartData,
  VoiceStateUpdateData,
} from "@/lib/types";

const MAX_BACKOFF_MS = 30_000;
const HEARTBEAT_INTERVAL_MS = 30_000;

class GatewayClient {
  private ws: WebSocket | null = null;
  private heartbeatTimer: number | null = null;
  private reconnectTimer: number | null = null;
  private reconnectAttempt = 0;
  private manualDisconnect = true;

  connect(): void {
    this.manualDisconnect = false;
    this.reconnectAttempt = 0;
    this.openSocket();
  }

  disconnect(): void {
    this.manualDisconnect = true;
    if (this.reconnectTimer !== null) window.clearTimeout(this.reconnectTimer);
    this.stopHeartbeat();
    this.ws?.close();
    this.ws = null;
  }

  sendTyping(channelId: string): void {
    this.send({ op: "TYPING_START", data: { channel_id: channelId } });
  }

  private send(payload: unknown): void {
    if (this.ws?.readyState === WebSocket.OPEN) {
      this.ws.send(JSON.stringify(payload));
    }
  }

  private openSocket(): void {
    const serverUrl = useSettingsStore.getState().serverUrl;
    const accessToken = useAuthStore.getState().accessToken;
    if (!serverUrl || !accessToken) return;

    const wsUrl = `${serverUrl.replace(/^http/i, "ws")}/gateway?token=${encodeURIComponent(accessToken)}`;
    const socket = new WebSocket(wsUrl);
    this.ws = socket;

    socket.onopen = () => {
      this.reconnectAttempt = 0;
      this.startHeartbeat();
    };

    socket.onmessage = (event) => {
      try {
        this.handleMessage(JSON.parse(event.data as string) as GatewayEvent);
      } catch {
        // ignore malformed frames
      }
    };

    socket.onclose = (event) => {
      this.stopHeartbeat();
      if (this.manualDisconnect) return;

      if (event.code === 1008) {
        // Auth rejected — access token was likely stale. Refresh before retrying.
        void useAuthStore.getState().restoreSession();
      }
      this.scheduleReconnect();
    };

    socket.onerror = () => socket.close();
  }

  private scheduleReconnect(): void {
    const delay = Math.min(1000 * 2 ** this.reconnectAttempt, MAX_BACKOFF_MS);
    this.reconnectAttempt += 1;
    this.reconnectTimer = window.setTimeout(() => this.openSocket(), delay);
  }

  private startHeartbeat(): void {
    this.heartbeatTimer = window.setInterval(() => this.send({ op: "HEARTBEAT" }), HEARTBEAT_INTERVAL_MS);
  }

  private stopHeartbeat(): void {
    if (this.heartbeatTimer !== null) window.clearInterval(this.heartbeatTimer);
    this.heartbeatTimer = null;
  }

  /** Fires an OS notification for an incoming message the user should know about
   * — a mention (directly or via @everyone), or any direct message, which is
   * addressed to them by definition — unless they're already looking at it. */
  private notifyIfRelevant(message: Message): void {
    const currentUser = useAuthStore.getState().user;
    if (!currentUser || message.author.id === currentUser.id) return;

    const dmState = useDmsStore.getState();
    const isDm = dmState.conversations.some((c) => c.id === message.channel_id);
    if (!isDm && !messageMentionsUser(message.content, currentUser.username)) return;

    const isViewing = isDm
      ? dmState.activeDmId === message.channel_id
      : useChannelsStore.getState().selectedChannelId === message.channel_id;
    if (document.hasFocus() && isViewing) return;

    const channel = useChannelsStore.getState().channels.find((c) => c.id === message.channel_id);
    notify(
      `${message.author.username}${!isDm && channel ? ` in #${channel.name}` : ""}`,
      message.content,
    );
  }

  /** Ring lifecycle. The tones themselves are left to the CallCenter, which
   * watches the store — so a signal frame never has to know about audio. */
  private handleCallSignal(data: DMCallData): void {
    const calls = useCallsStore.getState();

    switch (data.action) {
      case "ringing":
        calls.setIncoming(data.channel_id, data.from);
        notify(data.from.username, "Incoming call");
        break;
      case "accepted":
        // They're joining the room we're already in — nothing to do but stop waiting.
        calls.clearOutgoing(data.channel_id);
        break;
      case "declined":
      case "unavailable":
        calls.clearOutgoing(data.channel_id);
        void leaveVoiceChannel();
        toast(
          data.action === "declined"
            ? `${data.from.username} declined the call.`
            : `${data.from.username} is unavailable.`,
        );
        break;
      case "cancelled":
        calls.clearIncoming(data.channel_id);
        toast(`Missed call from ${data.from.username}.`);
        break;
    }
  }

  private handleMessage(event: GatewayEvent): void {
    switch (event.op) {
      case "READY": {
        const data = event.data as ReadyEventData;
        useAuthStore.getState().setUser({
          id: data.user.id,
          username: data.user.username,
          is_admin: data.user.is_admin,
          created_at: useAuthStore.getState().user?.created_at ?? new Date().toISOString(),
        });
        useChannelsStore.getState().setChannels(data.channels);
        useDmsStore.getState().setConversations(data.dms);
        useVoiceStore.getState().setVoiceStates(data.voice_states);
        for (const userId of data.online_user_ids) usePresenceStore.getState().setOnline(userId);
        break;
      }
      case "MESSAGE_CREATE": {
        const data = event.data as Message;
        useMessagesStore.getState().addMessage(data);
        useUsersStore.getState().upsertUser(data.author);
        this.notifyIfRelevant(data);
        break;
      }
      case "MESSAGE_UPDATE": {
        const data = event.data as Message;
        useMessagesStore.getState().updateMessage(data);
        useUsersStore.getState().upsertUser(data.author);
        break;
      }
      case "MESSAGE_DELETE": {
        const data = event.data as MessageDeleteData;
        useMessagesStore.getState().removeMessage(data.channel_id, data.id);
        break;
      }
      case "TYPING_START": {
        const data = event.data as TypingStartData;
        usePresenceStore.getState().setTyping(data.channel_id, data.user_id);
        if (!useUsersStore.getState().byId[data.user_id]) {
          void useUsersStore.getState().fetch();
        }
        break;
      }
      case "PRESENCE_UPDATE": {
        const data = event.data as PresenceUpdateData;
        if (data.status === "online") usePresenceStore.getState().setOnline(data.user_id);
        else usePresenceStore.getState().setOffline(data.user_id);
        break;
      }
      case "VOICE_STATE_UPDATE": {
        const data = event.data as VoiceStateUpdateData;
        useVoiceStore.getState().applyVoiceStateUpdate(data);
        // Our own join/leave sound plays directly from the LiveKit room lifecycle
        // (see livekit/voice.ts) — here we only sound off for other participants
        // in the voice channel we're currently connected to.
        const isOwnUpdate = data.user_id === useAuthStore.getState().user?.id;
        if (!isOwnUpdate && data.channel_id === useVoiceStore.getState().connectedChannelId) {
          if (data.action === "joined") playJoinSound();
          else if (data.action === "left") playLeaveSound();
        }
        break;
      }
      case "CHANNEL_CREATE":
      case "CHANNEL_UPDATE":
        useChannelsStore.getState().upsertChannel(event.data as Channel);
        break;
      case "CHANNEL_DELETE":
        useChannelsStore.getState().removeChannel((event.data as ChannelDeleteData).id);
        break;
      case "DM_CALL": {
        this.handleCallSignal(event.data as DMCallData);
        break;
      }
      case "DM_UPDATE":
        // Arrives just before the DM's own MESSAGE_CREATE, so a conversation the
        // recipient has never opened shows up in the rail before its first message.
        useDmsStore.getState().upsertConversation(event.data as DMConversation);
        break;
    }
  }
}

export const gatewayClient = new GatewayClient();
