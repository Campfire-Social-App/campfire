import { apiFetch, apiUpload } from "./client";
import type {
  Attachment,
  Channel,
  ChannelType,
  DMConversation,
  Invite,
  Message,
  MessagePage,
  ServerSettings,
  User,
  VoiceTokenResponse,
} from "@/lib/types";

export const listChannels = () => apiFetch<Channel[]>("/api/channels");

export const createChannel = (name: string, type: ChannelType) =>
  apiFetch<Channel>("/api/channels", { method: "POST", body: { name, type } });

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

export const uploadAttachment = (file: File) => apiUpload<Attachment>("/api/uploads", file);

export const listDms = () => apiFetch<DMConversation[]>("/api/dms");

/** Get-or-create the conversation with `userId` — safe to call on every click. */
export const openDmWith = (userId: string) =>
  apiFetch<DMConversation>("/api/dms", { method: "POST", body: { user_id: userId } });

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
