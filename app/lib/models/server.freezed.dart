// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'server.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ServerSettings {

 String get name; String? get iconUrl;/// Upload ceiling of this deployment — the client turns away bigger files
/// itself rather than spending an upload to be told no.
 int get maxUploadBytes;
/// Create a copy of ServerSettings
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ServerSettingsCopyWith<ServerSettings> get copyWith => _$ServerSettingsCopyWithImpl<ServerSettings>(this as ServerSettings, _$identity);

  /// Serializes this ServerSettings to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ServerSettings&&(identical(other.name, name) || other.name == name)&&(identical(other.iconUrl, iconUrl) || other.iconUrl == iconUrl)&&(identical(other.maxUploadBytes, maxUploadBytes) || other.maxUploadBytes == maxUploadBytes));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,name,iconUrl,maxUploadBytes);

@override
String toString() {
  return 'ServerSettings(name: $name, iconUrl: $iconUrl, maxUploadBytes: $maxUploadBytes)';
}


}

/// @nodoc
abstract mixin class $ServerSettingsCopyWith<$Res>  {
  factory $ServerSettingsCopyWith(ServerSettings value, $Res Function(ServerSettings) _then) = _$ServerSettingsCopyWithImpl;
@useResult
$Res call({
 String name, String? iconUrl, int maxUploadBytes
});




}
/// @nodoc
class _$ServerSettingsCopyWithImpl<$Res>
    implements $ServerSettingsCopyWith<$Res> {
  _$ServerSettingsCopyWithImpl(this._self, this._then);

  final ServerSettings _self;
  final $Res Function(ServerSettings) _then;

/// Create a copy of ServerSettings
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? name = null,Object? iconUrl = freezed,Object? maxUploadBytes = null,}) {
  return _then(_self.copyWith(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,iconUrl: freezed == iconUrl ? _self.iconUrl : iconUrl // ignore: cast_nullable_to_non_nullable
as String?,maxUploadBytes: null == maxUploadBytes ? _self.maxUploadBytes : maxUploadBytes // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [ServerSettings].
extension ServerSettingsPatterns on ServerSettings {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ServerSettings value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ServerSettings() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ServerSettings value)  $default,){
final _that = this;
switch (_that) {
case _ServerSettings():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ServerSettings value)?  $default,){
final _that = this;
switch (_that) {
case _ServerSettings() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String name,  String? iconUrl,  int maxUploadBytes)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ServerSettings() when $default != null:
return $default(_that.name,_that.iconUrl,_that.maxUploadBytes);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String name,  String? iconUrl,  int maxUploadBytes)  $default,) {final _that = this;
switch (_that) {
case _ServerSettings():
return $default(_that.name,_that.iconUrl,_that.maxUploadBytes);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String name,  String? iconUrl,  int maxUploadBytes)?  $default,) {final _that = this;
switch (_that) {
case _ServerSettings() when $default != null:
return $default(_that.name,_that.iconUrl,_that.maxUploadBytes);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ServerSettings implements ServerSettings {
  const _ServerSettings({required this.name, required this.iconUrl, required this.maxUploadBytes});
  factory _ServerSettings.fromJson(Map<String, dynamic> json) => _$ServerSettingsFromJson(json);

@override final  String name;
@override final  String? iconUrl;
/// Upload ceiling of this deployment — the client turns away bigger files
/// itself rather than spending an upload to be told no.
@override final  int maxUploadBytes;

/// Create a copy of ServerSettings
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ServerSettingsCopyWith<_ServerSettings> get copyWith => __$ServerSettingsCopyWithImpl<_ServerSettings>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ServerSettingsToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ServerSettings&&(identical(other.name, name) || other.name == name)&&(identical(other.iconUrl, iconUrl) || other.iconUrl == iconUrl)&&(identical(other.maxUploadBytes, maxUploadBytes) || other.maxUploadBytes == maxUploadBytes));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,name,iconUrl,maxUploadBytes);

@override
String toString() {
  return 'ServerSettings(name: $name, iconUrl: $iconUrl, maxUploadBytes: $maxUploadBytes)';
}


}

/// @nodoc
abstract mixin class _$ServerSettingsCopyWith<$Res> implements $ServerSettingsCopyWith<$Res> {
  factory _$ServerSettingsCopyWith(_ServerSettings value, $Res Function(_ServerSettings) _then) = __$ServerSettingsCopyWithImpl;
@override @useResult
$Res call({
 String name, String? iconUrl, int maxUploadBytes
});




}
/// @nodoc
class __$ServerSettingsCopyWithImpl<$Res>
    implements _$ServerSettingsCopyWith<$Res> {
  __$ServerSettingsCopyWithImpl(this._self, this._then);

  final _ServerSettings _self;
  final $Res Function(_ServerSettings) _then;

/// Create a copy of ServerSettings
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? name = null,Object? iconUrl = freezed,Object? maxUploadBytes = null,}) {
  return _then(_ServerSettings(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,iconUrl: freezed == iconUrl ? _self.iconUrl : iconUrl // ignore: cast_nullable_to_non_nullable
as String?,maxUploadBytes: null == maxUploadBytes ? _self.maxUploadBytes : maxUploadBytes // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}


/// @nodoc
mixin _$VoiceTokenResponse {

 String get token; String get url; String get room;
/// Create a copy of VoiceTokenResponse
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VoiceTokenResponseCopyWith<VoiceTokenResponse> get copyWith => _$VoiceTokenResponseCopyWithImpl<VoiceTokenResponse>(this as VoiceTokenResponse, _$identity);

  /// Serializes this VoiceTokenResponse to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is VoiceTokenResponse&&(identical(other.token, token) || other.token == token)&&(identical(other.url, url) || other.url == url)&&(identical(other.room, room) || other.room == room));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,token,url,room);

@override
String toString() {
  return 'VoiceTokenResponse(token: $token, url: $url, room: $room)';
}


}

/// @nodoc
abstract mixin class $VoiceTokenResponseCopyWith<$Res>  {
  factory $VoiceTokenResponseCopyWith(VoiceTokenResponse value, $Res Function(VoiceTokenResponse) _then) = _$VoiceTokenResponseCopyWithImpl;
@useResult
$Res call({
 String token, String url, String room
});




}
/// @nodoc
class _$VoiceTokenResponseCopyWithImpl<$Res>
    implements $VoiceTokenResponseCopyWith<$Res> {
  _$VoiceTokenResponseCopyWithImpl(this._self, this._then);

  final VoiceTokenResponse _self;
  final $Res Function(VoiceTokenResponse) _then;

/// Create a copy of VoiceTokenResponse
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? token = null,Object? url = null,Object? room = null,}) {
  return _then(_self.copyWith(
token: null == token ? _self.token : token // ignore: cast_nullable_to_non_nullable
as String,url: null == url ? _self.url : url // ignore: cast_nullable_to_non_nullable
as String,room: null == room ? _self.room : room // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [VoiceTokenResponse].
extension VoiceTokenResponsePatterns on VoiceTokenResponse {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _VoiceTokenResponse value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _VoiceTokenResponse() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _VoiceTokenResponse value)  $default,){
final _that = this;
switch (_that) {
case _VoiceTokenResponse():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _VoiceTokenResponse value)?  $default,){
final _that = this;
switch (_that) {
case _VoiceTokenResponse() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String token,  String url,  String room)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _VoiceTokenResponse() when $default != null:
return $default(_that.token,_that.url,_that.room);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String token,  String url,  String room)  $default,) {final _that = this;
switch (_that) {
case _VoiceTokenResponse():
return $default(_that.token,_that.url,_that.room);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String token,  String url,  String room)?  $default,) {final _that = this;
switch (_that) {
case _VoiceTokenResponse() when $default != null:
return $default(_that.token,_that.url,_that.room);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _VoiceTokenResponse implements VoiceTokenResponse {
  const _VoiceTokenResponse({required this.token, required this.url, required this.room});
  factory _VoiceTokenResponse.fromJson(Map<String, dynamic> json) => _$VoiceTokenResponseFromJson(json);

@override final  String token;
@override final  String url;
@override final  String room;

/// Create a copy of VoiceTokenResponse
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$VoiceTokenResponseCopyWith<_VoiceTokenResponse> get copyWith => __$VoiceTokenResponseCopyWithImpl<_VoiceTokenResponse>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$VoiceTokenResponseToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _VoiceTokenResponse&&(identical(other.token, token) || other.token == token)&&(identical(other.url, url) || other.url == url)&&(identical(other.room, room) || other.room == room));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,token,url,room);

@override
String toString() {
  return 'VoiceTokenResponse(token: $token, url: $url, room: $room)';
}


}

/// @nodoc
abstract mixin class _$VoiceTokenResponseCopyWith<$Res> implements $VoiceTokenResponseCopyWith<$Res> {
  factory _$VoiceTokenResponseCopyWith(_VoiceTokenResponse value, $Res Function(_VoiceTokenResponse) _then) = __$VoiceTokenResponseCopyWithImpl;
@override @useResult
$Res call({
 String token, String url, String room
});




}
/// @nodoc
class __$VoiceTokenResponseCopyWithImpl<$Res>
    implements _$VoiceTokenResponseCopyWith<$Res> {
  __$VoiceTokenResponseCopyWithImpl(this._self, this._then);

  final _VoiceTokenResponse _self;
  final $Res Function(_VoiceTokenResponse) _then;

/// Create a copy of VoiceTokenResponse
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? token = null,Object? url = null,Object? room = null,}) {
  return _then(_VoiceTokenResponse(
token: null == token ? _self.token : token // ignore: cast_nullable_to_non_nullable
as String,url: null == url ? _self.url : url // ignore: cast_nullable_to_non_nullable
as String,room: null == room ? _self.room : room // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$VoiceParticipantState {

 String get userId; String get username; String get channelId; bool get muted; bool get speaking;
/// Create a copy of VoiceParticipantState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VoiceParticipantStateCopyWith<VoiceParticipantState> get copyWith => _$VoiceParticipantStateCopyWithImpl<VoiceParticipantState>(this as VoiceParticipantState, _$identity);

  /// Serializes this VoiceParticipantState to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is VoiceParticipantState&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.username, username) || other.username == username)&&(identical(other.channelId, channelId) || other.channelId == channelId)&&(identical(other.muted, muted) || other.muted == muted)&&(identical(other.speaking, speaking) || other.speaking == speaking));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,userId,username,channelId,muted,speaking);

@override
String toString() {
  return 'VoiceParticipantState(userId: $userId, username: $username, channelId: $channelId, muted: $muted, speaking: $speaking)';
}


}

/// @nodoc
abstract mixin class $VoiceParticipantStateCopyWith<$Res>  {
  factory $VoiceParticipantStateCopyWith(VoiceParticipantState value, $Res Function(VoiceParticipantState) _then) = _$VoiceParticipantStateCopyWithImpl;
@useResult
$Res call({
 String userId, String username, String channelId, bool muted, bool speaking
});




}
/// @nodoc
class _$VoiceParticipantStateCopyWithImpl<$Res>
    implements $VoiceParticipantStateCopyWith<$Res> {
  _$VoiceParticipantStateCopyWithImpl(this._self, this._then);

  final VoiceParticipantState _self;
  final $Res Function(VoiceParticipantState) _then;

/// Create a copy of VoiceParticipantState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? userId = null,Object? username = null,Object? channelId = null,Object? muted = null,Object? speaking = null,}) {
  return _then(_self.copyWith(
userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,username: null == username ? _self.username : username // ignore: cast_nullable_to_non_nullable
as String,channelId: null == channelId ? _self.channelId : channelId // ignore: cast_nullable_to_non_nullable
as String,muted: null == muted ? _self.muted : muted // ignore: cast_nullable_to_non_nullable
as bool,speaking: null == speaking ? _self.speaking : speaking // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [VoiceParticipantState].
extension VoiceParticipantStatePatterns on VoiceParticipantState {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _VoiceParticipantState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _VoiceParticipantState() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _VoiceParticipantState value)  $default,){
final _that = this;
switch (_that) {
case _VoiceParticipantState():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _VoiceParticipantState value)?  $default,){
final _that = this;
switch (_that) {
case _VoiceParticipantState() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String userId,  String username,  String channelId,  bool muted,  bool speaking)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _VoiceParticipantState() when $default != null:
return $default(_that.userId,_that.username,_that.channelId,_that.muted,_that.speaking);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String userId,  String username,  String channelId,  bool muted,  bool speaking)  $default,) {final _that = this;
switch (_that) {
case _VoiceParticipantState():
return $default(_that.userId,_that.username,_that.channelId,_that.muted,_that.speaking);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String userId,  String username,  String channelId,  bool muted,  bool speaking)?  $default,) {final _that = this;
switch (_that) {
case _VoiceParticipantState() when $default != null:
return $default(_that.userId,_that.username,_that.channelId,_that.muted,_that.speaking);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _VoiceParticipantState implements VoiceParticipantState {
  const _VoiceParticipantState({required this.userId, required this.username, required this.channelId, this.muted = false, this.speaking = false});
  factory _VoiceParticipantState.fromJson(Map<String, dynamic> json) => _$VoiceParticipantStateFromJson(json);

@override final  String userId;
@override final  String username;
@override final  String channelId;
@override@JsonKey() final  bool muted;
@override@JsonKey() final  bool speaking;

/// Create a copy of VoiceParticipantState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$VoiceParticipantStateCopyWith<_VoiceParticipantState> get copyWith => __$VoiceParticipantStateCopyWithImpl<_VoiceParticipantState>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$VoiceParticipantStateToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _VoiceParticipantState&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.username, username) || other.username == username)&&(identical(other.channelId, channelId) || other.channelId == channelId)&&(identical(other.muted, muted) || other.muted == muted)&&(identical(other.speaking, speaking) || other.speaking == speaking));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,userId,username,channelId,muted,speaking);

@override
String toString() {
  return 'VoiceParticipantState(userId: $userId, username: $username, channelId: $channelId, muted: $muted, speaking: $speaking)';
}


}

/// @nodoc
abstract mixin class _$VoiceParticipantStateCopyWith<$Res> implements $VoiceParticipantStateCopyWith<$Res> {
  factory _$VoiceParticipantStateCopyWith(_VoiceParticipantState value, $Res Function(_VoiceParticipantState) _then) = __$VoiceParticipantStateCopyWithImpl;
@override @useResult
$Res call({
 String userId, String username, String channelId, bool muted, bool speaking
});




}
/// @nodoc
class __$VoiceParticipantStateCopyWithImpl<$Res>
    implements _$VoiceParticipantStateCopyWith<$Res> {
  __$VoiceParticipantStateCopyWithImpl(this._self, this._then);

  final _VoiceParticipantState _self;
  final $Res Function(_VoiceParticipantState) _then;

/// Create a copy of VoiceParticipantState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? userId = null,Object? username = null,Object? channelId = null,Object? muted = null,Object? speaking = null,}) {
  return _then(_VoiceParticipantState(
userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,username: null == username ? _self.username : username // ignore: cast_nullable_to_non_nullable
as String,channelId: null == channelId ? _self.channelId : channelId // ignore: cast_nullable_to_non_nullable
as String,muted: null == muted ? _self.muted : muted // ignore: cast_nullable_to_non_nullable
as bool,speaking: null == speaking ? _self.speaking : speaking // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
