export interface User {
  id: string;
  username: string;
  is_admin: boolean;
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

export type ChannelType = "text" | "voice";

export interface Channel {
  id: string;
  name: string;
  type: ChannelType;
  position: number;
  created_at: string;
}

export interface Attachment {
  id: string;
  filename: string;
  content_type: string;
  size_bytes: number;
  url: string;
  created_at: string;
}

export interface Message {
  id: string;
  channel_id: string;
  author: User;
  content: string;
  created_at: string;
  edited_at: string | null;
  attachments: Attachment[];
}

export interface MessagePage {
  messages: Message[];
  has_more: boolean;
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
  speaking: boolean;
}

export type PresenceStatus = "online" | "offline";

export type GatewayEventType =
  | "READY"
  | "MESSAGE_CREATE"
  | "MESSAGE_UPDATE"
  | "MESSAGE_DELETE"
  | "TYPING_START"
  | "PRESENCE_UPDATE"
  | "VOICE_STATE_UPDATE"
  | "CHANNEL_CREATE"
  | "CHANNEL_UPDATE"
  | "CHANNEL_DELETE";

export interface GatewayEvent<T = unknown> {
  op: GatewayEventType;
  data: T;
}

export interface ReadyEventData {
  user: { id: string; username: string; is_admin: boolean };
  server: ServerSettings;
  channels: Channel[];
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
  action: "joined" | "left" | "room_finished";
  user_id?: string;
  username?: string;
  channel_id: string | null;
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
