import 'package:campfire/api/client.dart';
import 'package:campfire/models/attachment.dart';
import 'package:campfire/models/channel.dart';
import 'package:campfire/models/dm.dart';
import 'package:campfire/models/invite.dart';
import 'package:campfire/models/message.dart';
import 'package:campfire/models/server.dart';
import 'package:campfire/models/user.dart';
import 'package:dio/dio.dart';

/// Typed view of the server's REST surface — a straight port of
/// `api/endpoints.ts`, one method per route, no logic beyond shaping.
class CampfireApi {
  const CampfireApi(this.client);

  final ApiClient client;

  // ------------------------------------------------------------------ health

  /// Cheap liveness probe used by the connect screen before a URL is saved, so
  /// a typo is caught there instead of at the login button.
  Future<bool> health() async {
    try {
      await client.request<void>('/health', anonymous: true);
      return true;
    } on Object {
      return false;
    }
  }

  // -------------------------------------------------------------------- auth

  Future<AuthResponse> login(String username, String password) => client.request(
        '/api/auth/login',
        method: 'POST',
        anonymous: true,
        body: {'username': username, 'password': password},
        decode: (json) => AuthResponse.fromJson(json as Map<String, dynamic>),
      );

  Future<AuthResponse> register(String inviteCode, String username, String password) =>
      client.request(
        '/api/auth/register',
        method: 'POST',
        anonymous: true,
        body: {'invite_code': inviteCode, 'username': username, 'password': password},
        decode: (json) => AuthResponse.fromJson(json as Map<String, dynamic>),
      );

  /// Only for restoring a session at boot. The 401 path refreshes inside
  /// [ApiClient] instead, where it can be kept single-flight.
  Future<AccessTokenResponse> refresh(String refreshToken) => client.request(
        '/api/auth/refresh',
        method: 'POST',
        anonymous: true,
        body: {'refresh_token': refreshToken},
        decode: (json) => AccessTokenResponse.fromJson(json as Map<String, dynamic>),
      );

  Future<void> logout() => client.request<void>('/api/auth/logout', method: 'POST');

  // ---------------------------------------------------------------- channels

  Future<List<Channel>> listChannels() => client.request(
        '/api/channels',
        decode: (json) => _listOf(json, Channel.fromJson),
      );

  Future<Channel> createChannel(String name, ChannelType type) => client.request(
        '/api/channels',
        method: 'POST',
        body: {'name': name, 'type': type.name},
        decode: (json) => Channel.fromJson(json as Map<String, dynamic>),
      );

  Future<Channel> updateChannel(String id, String name) => client.request(
        '/api/channels/$id',
        method: 'PATCH',
        body: {'name': name},
        decode: (json) => Channel.fromJson(json as Map<String, dynamic>),
      );

  Future<void> deleteChannel(String id) =>
      client.request<void>('/api/channels/$id', method: 'DELETE');

  // ---------------------------------------------------------------- messages

  Future<MessagePage> listMessages(String channelId, {String? before, int limit = 50}) =>
      client.request(
        '/api/channels/$channelId/messages',
        query: {'before': ?before, 'limit': limit},
        decode: (json) => MessagePage.fromJson(json as Map<String, dynamic>),
      );

  Future<Message> sendMessage(
    String channelId,
    String content, {
    List<String> attachmentIds = const [],
    String? replyToId,
  }) =>
      client.request(
        '/api/channels/$channelId/messages',
        method: 'POST',
        body: {
          'content': content,
          'attachment_ids': attachmentIds,
          'reply_to_id': replyToId,
        },
        decode: (json) => Message.fromJson(json as Map<String, dynamic>),
      );

  Future<Message> editMessage(String messageId, String content) => client.request(
        '/api/messages/$messageId',
        method: 'PATCH',
        body: {'content': content},
        decode: (json) => Message.fromJson(json as Map<String, dynamic>),
      );

  Future<void> deleteMessage(String messageId) =>
      client.request<void>('/api/messages/$messageId', method: 'DELETE');

  // -------------------------------------------------------------- attachments

  Future<Attachment> uploadAttachment(
    String filePath, {
    String? filename,
    void Function(double fraction)? onProgress,
    CancelToken? cancelToken,
  }) =>
      client.upload(
        '/api/uploads',
        filePath,
        filename: filename,
        onProgress: onProgress,
        cancelToken: cancelToken,
        decode: (json) => Attachment.fromJson(json as Map<String, dynamic>),
      );

  // --------------------------------------------------------------------- DMs

  Future<List<DMConversation>> listDms() => client.request(
        '/api/dms',
        decode: (json) => _listOf(json, DMConversation.fromJson),
      );

  /// Get-or-create the conversation with [userId] — safe to call on every click.
  Future<DMConversation> openDmWith(String userId) => client.request(
        '/api/dms',
        method: 'POST',
        body: {'user_id': userId},
        decode: (json) => DMConversation.fromJson(json as Map<String, dynamic>),
      );

  /// Rings the other member. Joining the call itself is a separate step — the
  /// LiveKit room is the DM channel (see [voiceToken]).
  Future<void> startDmCall(String channelId) =>
      client.request<void>('/api/dms/$channelId/call', method: 'POST');

  Future<void> acceptDmCall(String channelId) =>
      client.request<void>('/api/dms/$channelId/call/accept', method: 'POST');

  /// Ends a call that is still ringing — a cancel from the caller, a decline
  /// from the callee. A no-op once the call has been answered.
  Future<void> endDmCall(String channelId) =>
      client.request<void>('/api/dms/$channelId/call', method: 'DELETE');

  Future<void> markDmRead(String channelId) =>
      client.request<void>('/api/dms/$channelId/read', method: 'POST');

  // ------------------------------------------------------------------- users

  Future<List<User>> listUsers() => client.request(
        '/api/users',
        decode: (json) => _listOf(json, User.fromJson),
      );

  // ------------------------------------------------------------------ server

  Future<ServerSettings> serverSettings() => client.request(
        '/api/server',
        decode: (json) => ServerSettings.fromJson(json as Map<String, dynamic>),
      );

  // ----------------------------------------------------------------- invites

  Future<List<Invite>> listInvites() => client.request(
        '/api/invites',
        decode: (json) => _listOf(json, Invite.fromJson),
      );

  Future<Invite> createInvite({int? maxUses, int? expiresInHours}) => client.request(
        '/api/invites',
        method: 'POST',
        body: {'max_uses': maxUses, 'expires_in_hours': expiresInHours},
        decode: (json) => Invite.fromJson(json as Map<String, dynamic>),
      );

  Future<void> deleteInvite(String id) =>
      client.request<void>('/api/invites/$id', method: 'DELETE');

  // ------------------------------------------------------------------- voice

  Future<VoiceTokenResponse> voiceToken(String channelId) => client.request(
        '/api/voice/$channelId/token',
        method: 'POST',
        decode: (json) => VoiceTokenResponse.fromJson(json as Map<String, dynamic>),
      );
}

List<T> _listOf<T>(dynamic json, T Function(Map<String, dynamic>) fromJson) =>
    (json as List<dynamic>).map((e) => fromJson(e as Map<String, dynamic>)).toList();
