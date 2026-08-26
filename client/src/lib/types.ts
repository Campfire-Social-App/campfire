export interface User {
  id: string;
  username: string;
  is_admin: boolean;
  /** A bot account, driven by the bots service rather than by a person. It is
   * online like anyone else; the badge is what tells the two apart. */
  is_bot?: boolean;
  is_banned?: boolean;
  timed_out_until?: string | null;
  avatar_url: string | null;
  banner_url: string | null;
  created_at: string;
}

export interface AuthResponse {
  access_token: string;
  refresh_token: string;
  token_type: string;
  user: User;
}

export interface AccessTokenResponse {
  access_token: string;
  token_type: string;
}

/** "dm" channels are never listed as server channels — they reach the client as
 * DMConversation entries instead (see /api/dms). */
export type ChannelType = "text" | "voice" | "dm";

export interface Channel {
  id: string;
  name: string;
  type: ChannelType;
  position: number;
  created_at: string;
}

/** A 1:1 conversation as seen by the signed-in user: `id` is the underlying
 * channel id (so the message endpoints take it as-is), `recipient` is the other
 * member, and `unread_count` is relative to us. */
export interface DMConversation {
  id: string;
  recipient: User;
  last_message_at: string | null;
  unread_count: number;
}

export interface Attachment {
  id: string;
  filename: string;
  content_type: string;
  size_bytes: number;
  url: string;
  created_at: string;
}

export interface MessageReplyPreview {
  id: string;
  author: User;
  content: string;
  has_attachments: boolean;
}

export type ReactionType = "like" | "love" | "laugh";

export interface MessageReaction {
  type: ReactionType;
  count: number;
  reacted_by_me: boolean;
}

export interface MessageReactionUpdate {
  message_id: string;
  channel_id: string;
  type: ReactionType;
  count: number;
  user_id: string;
  reacted: boolean;
}

export interface Message {
  id: string;
  channel_id: string;
  author: User;
  content: string;
  created_at: string;
  edited_at: string | null;
  attachments: Attachment[];
  reply_to: MessageReplyPreview | null;
  reactions: MessageReaction[];
}

export interface MessagePage {
  messages: Message[];
  has_more: boolean;
}

export interface ModerationMessage {
  id: string;
  channel_id: string;
  channel_name: string;
  content: string;
  created_at: string;
  edited_at: string | null;
  attachments: Attachment[];
}

export interface UserModerationOverview {
  user: User;
  messages: ModerationMessage[];
}

export interface Invite {
  id: string;
  code: string;
  created_by_id: string;
  max_uses: number | null;
  uses_count: number;
  expires_at: string | null;
  created_at: string;
}

export interface ServerSettings {
  name: string;
  icon_url: string | null;
  /** Upload ceiling of this deployment — the client turns away bigger files
   * itself rather than spending an upload to be told no. */
  max_upload_bytes: number;
}

/** One slash command the server's bots answer to, as offered in the composer's
 * `/` menu. The list comes from GET /api/commands and is empty on a deployment
 * with no bots service. */
export interface SlashCommand {
  name: string;
  description: string;
  /** Argument hint shown next to the name, e.g. "<url ou busca>". */
  usage: string;
  /** The bot enforces this; the client only uses it to explain the requirement. */
  requires_voice: boolean;
}

export interface VoiceTokenResponse {
  token: string;
  url: string;
  room: string;
}

export interface VoiceParticipantState {
  user_id: string;
  username: string;
  channel_id: string;
  muted: boolean;
  deafened?: boolean;
  speaking: boolean;
  screen_sharing?: boolean;
}

export type PresenceStatus = "online" | "offline";

export type GatewayEventType =
  | "READY"
  | "MESSAGE_CREATE"
  | "MESSAGE_UPDATE"
  | "MESSAGE_DELETE"
  | "MESSAGE_REACTION_UPDATE"
  | "USER_UPDATE"
  | "TYPING_START"
  | "PRESENCE_UPDATE"
  | "VOICE_STATE_UPDATE"
  | "CHANNEL_CREATE"
  | "CHANNEL_UPDATE"
  | "CHANNEL_DELETE"
  | "DM_UPDATE"
  | "DM_CALL";

export interface GatewayEvent<T = unknown> {
  op: GatewayEventType;
  data: T;
}

export interface ReadyEventData {
  user: {
    id: string;
    username: string;
    is_admin: boolean;
    is_bot?: boolean;
    avatar_url: string | null;
    banner_url: string | null;
  };
  server: ServerSettings;
  channels: Channel[];
  dms: DMConversation[];
  online_user_ids: string[];
  voice_states: VoiceParticipantState[];
}

export interface PresenceUpdateData {
  user_id: string;
  status: PresenceStatus;
}

export interface TypingStartData {
  user_id: string;
  channel_id: string;
}

export interface VoiceStateUpdateData {
  action: "joined" | "left" | "room_finished" | "updated";
  user_id?: string;
  username?: string;
  channel_id: string | null;
  muted?: boolean;
  deafened?: boolean;
  screen_sharing?: boolean;
}


/** A step in a DM call's ring: `from` is whoever caused it — the caller when
 * ringing or cancelling, the callee when accepting or declining. Once a call is
 * answered it leaves this channel entirely and lives as LiveKit room state. */
export interface DMCallData {
  action: "ringing" | "accepted" | "declined" | "cancelled" | "unavailable";
  channel_id: string;
  from: { id: string; username: string };
}

export interface MessageDeleteData {
  id: string;
  channel_id: string;
}

export interface ChannelDeleteData {
  id: string;
}

export class ApiError extends Error {
  constructor(
    public status: number,
    message: string,
  ) {
    super(message);
    this.name = "ApiError";
  }
}
