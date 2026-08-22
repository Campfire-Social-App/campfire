import 'package:freezed_annotation/freezed_annotation.dart';

part 'user.freezed.dart';
part 'user.g.dart';

@freezed
abstract class User with _$User {
  const factory User({
    required String id,
    required String username,
    required bool isAdmin,

    /// Server-relative path to the profile photo (`/api/uploads/...`), or null
    /// for the initials fallback. Both REST and the READY frame carry it, so
    /// unlike [createdAt] this one is never absent for a reason — it is just
    /// optional. Render it through `ApiClient.resolveAssetUrl`.
    String? avatarUrl,

    /// Null when the user arrived on a gateway frame rather than from REST: the
    /// READY payload builds its `user` dict by hand and leaves `created_at` out,
    /// while `/api/users` includes it. Nothing in the UI needs it, so the model
    /// tolerates the gap instead of the frame failing to parse.
    DateTime? createdAt,
  }) = _User;

  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);
}

@freezed
abstract class AuthResponse with _$AuthResponse {
  const factory AuthResponse({
    required String accessToken,
    required String refreshToken,
    required String tokenType,
    required User user,
  }) = _AuthResponse;

  factory AuthResponse.fromJson(Map<String, dynamic> json) => _$AuthResponseFromJson(json);
}

@freezed
abstract class AccessTokenResponse with _$AccessTokenResponse {
  const factory AccessTokenResponse({
    required String accessToken,
    required String tokenType,
  }) = _AccessTokenResponse;

  factory AccessTokenResponse.fromJson(Map<String, dynamic> json) =>
      _$AccessTokenResponseFromJson(json);
}

enum PresenceStatus {
  @JsonValue('online')
  online,
  @JsonValue('offline')
  offline,
}
