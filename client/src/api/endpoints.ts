import { apiFetch, apiUpload } from "./client";
import type {
  Attachment,
  Channel,
  ChannelType,
  DMConversation,
  Invite,
  Message,
  MessagePage,
  MessageReaction,
  ReactionType,
  ServerSettings,
  User,
  VoiceTokenResponse,
} from "@/lib/types";

export const listChannels = () => apiFetch<Channel[]>("/api/channels");

export const createChannel = (name: string, type: ChannelType) =>
  apiFetch<Channel>("/api/channels", { method: "POST", body: { name, type } });

export const updateChannel = (id: string, name: string) =>
  apiFetch<Channel>(`/api/channels/${id}`, { method: "PATCH", body: { name } });

export const deleteChannel = (id: string) =>
  apiFetch<void>(`/api/channels/${id}`, { method: "DELETE" });

export const listMessages = (channelId: string, opts: { before?: string; limit?: number } = {}) => {
  const params = new URLSearchParams();
  if (opts.before) params.set("before", opts.before);
  params.set("limit", String(opts.limit ?? 50));
  return apiFetch<MessagePage>(`/api/channels/${channelId}/messages?${params.toString()}`);
};

export const sendMessage = (
  channelId: string,
  content: string,
  attachmentIds: string[] = [],
  replyToId?: string,
) =>
  apiFetch<Message>(`/api/channels/${channelId}/messages`, {
    method: "POST",
    body: { content, attachment_ids: attachmentIds, reply_to_id: replyToId ?? null },
  });

export const editMessage = (messageId: string, content: string) =>
  apiFetch<Message>(`/api/messages/${messageId}`, { method: "PATCH", body: { content } });

export const deleteMessage = (messageId: string) =>
  apiFetch<void>(`/api/messages/${messageId}`, { method: "DELETE" });

export const addMessageReaction = (messageId: string, type: ReactionType) =>
  apiFetch<MessageReaction>(`/api/messages/${messageId}/reactions/${type}`, { method: "PUT" });

export const removeMessageReaction = (messageId: string, type: ReactionType) =>
  apiFetch<MessageReaction>(`/api/messages/${messageId}/reactions/${type}`, { method: "DELETE" });

export const uploadAttachment = (file: File, onProgress?: (fraction: number) => void) =>
  apiUpload<Attachment>("/api/uploads", file, onProgress);

export const listDms = () => apiFetch<DMConversation[]>("/api/dms");

/** Get-or-create the conversation with `userId` — safe to call on every click. */
export const openDmWith = (userId: string) =>
  apiFetch<DMConversation>("/api/dms", { method: "POST", body: { user_id: userId } });

/** Rings the other member. Joining the call itself is a separate step — the
 * LiveKit room is the DM channel (see getVoiceToken). */
export const startDmCall = (channelId: string) =>
  apiFetch<void>(`/api/dms/${channelId}/call`, { method: "POST" });

export const acceptDmCall = (channelId: string) =>
  apiFetch<void>(`/api/dms/${channelId}/call/accept`, { method: "POST" });

/** Ends a call that is still ringing — a cancel from the caller, a decline from
 * the callee. A no-op once the call has been answered. */
export const endDmCall = (channelId: string) =>
  apiFetch<void>(`/api/dms/${channelId}/call`, { method: "DELETE" });

export const markDmRead = (channelId: string) =>
  apiFetch<void>(`/api/dms/${channelId}/read`, { method: "POST" });

export const listUsers = () => apiFetch<User[]>("/api/users");

export const getServerSettings = () => apiFetch<ServerSettings>("/api/server");

export const createInvite = (maxUses?: number, expiresInHours?: number) =>
  apiFetch<Invite>("/api/invites", {
    method: "POST",
    body: { max_uses: maxUses, expires_in_hours: expiresInHours },
  });

export const listInvites = () => apiFetch<Invite[]>("/api/invites");

export const deleteInvite = (id: string) => apiFetch<void>(`/api/invites/${id}`, { method: "DELETE" });

export const getVoiceToken = (channelId: string) =>
  apiFetch<VoiceTokenResponse>(`/api/voice/${channelId}/token`, { method: "POST" });
