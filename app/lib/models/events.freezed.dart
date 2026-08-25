// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'events.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$GatewayEvent {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GatewayEvent);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'GatewayEvent()';
}


}

/// @nodoc
class $GatewayEventCopyWith<$Res>  {
$GatewayEventCopyWith(GatewayEvent _, $Res Function(GatewayEvent) __);
}


/// Adds pattern-matching-related methods to [GatewayEvent].
extension GatewayEventPatterns on GatewayEvent {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( ReadyEvent value)?  ready,TResult Function( MessageCreateEvent value)?  messageCreate,TResult Function( MessageUpdateEvent value)?  messageUpdate,TResult Function( MessageDeleteEvent value)?  messageDelete,TResult Function( MessageReactionUpdateEvent value)?  messageReactionUpdate,TResult Function( UserUpdateEvent value)?  userUpdate,TResult Function( TypingStartEvent value)?  typingStart,TResult Function( PresenceUpdateEvent value)?  presenceUpdate,TResult Function( VoiceStateUpdateEvent value)?  voiceStateUpdate,TResult Function( ChannelCreateEvent value)?  channelCreate,TResult Function( ChannelUpdateEvent value)?  channelUpdate,TResult Function( ChannelDeleteEvent value)?  channelDelete,TResult Function( DMUpdateEvent value)?  dmUpdate,TResult Function( DMCallEvent value)?  dmCall,TResult Function( UnknownEvent value)?  unknown,required TResult orElse(),}){
final _that = this;
switch (_that) {
case ReadyEvent() when ready != null:
return ready(_that);case MessageCreateEvent() when messageCreate != null:
return messageCreate(_that);case MessageUpdateEvent() when messageUpdate != null:
return messageUpdate(_that);case MessageDeleteEvent() when messageDelete != null:
return messageDelete(_that);case MessageReactionUpdateEvent() when messageReactionUpdate != null:
return messageReactionUpdate(_that);case UserUpdateEvent() when userUpdate != null:
return userUpdate(_that);case TypingStartEvent() when typingStart != null:
return typingStart(_that);case PresenceUpdateEvent() when presenceUpdate != null:
return presenceUpdate(_that);case VoiceStateUpdateEvent() when voiceStateUpdate != null:
return voiceStateUpdate(_that);case ChannelCreateEvent() when channelCreate != null:
return channelCreate(_that);case ChannelUpdateEvent() when channelUpdate != null:
return channelUpdate(_that);case ChannelDeleteEvent() when channelDelete != null:
return channelDelete(_that);case DMUpdateEvent() when dmUpdate != null:
return dmUpdate(_that);case DMCallEvent() when dmCall != null:
return dmCall(_that);case UnknownEvent() when unknown != null:
return unknown(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( ReadyEvent value)  ready,required TResult Function( MessageCreateEvent value)  messageCreate,required TResult Function( MessageUpdateEvent value)  messageUpdate,required TResult Function( MessageDeleteEvent value)  messageDelete,required TResult Function( MessageReactionUpdateEvent value)  messageReactionUpdate,required TResult Function( UserUpdateEvent value)  userUpdate,required TResult Function( TypingStartEvent value)  typingStart,required TResult Function( PresenceUpdateEvent value)  presenceUpdate,required TResult Function( VoiceStateUpdateEvent value)  voiceStateUpdate,required TResult Function( ChannelCreateEvent value)  channelCreate,required TResult Function( ChannelUpdateEvent value)  channelUpdate,required TResult Function( ChannelDeleteEvent value)  channelDelete,required TResult Function( DMUpdateEvent value)  dmUpdate,required TResult Function( DMCallEvent value)  dmCall,required TResult Function( UnknownEvent value)  unknown,}){
final _that = this;
switch (_that) {
case ReadyEvent():
return ready(_that);case MessageCreateEvent():
return messageCreate(_that);case MessageUpdateEvent():
return messageUpdate(_that);case MessageDeleteEvent():
return messageDelete(_that);case MessageReactionUpdateEvent():
return messageReactionUpdate(_that);case UserUpdateEvent():
return userUpdate(_that);case TypingStartEvent():
return typingStart(_that);case PresenceUpdateEvent():
return presenceUpdate(_that);case VoiceStateUpdateEvent():
return voiceStateUpdate(_that);case ChannelCreateEvent():
return channelCreate(_that);case ChannelUpdateEvent():
return channelUpdate(_that);case ChannelDeleteEvent():
return channelDelete(_that);case DMUpdateEvent():
return dmUpdate(_that);case DMCallEvent():
return dmCall(_that);case UnknownEvent():
return unknown(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( ReadyEvent value)?  ready,TResult? Function( MessageCreateEvent value)?  messageCreate,TResult? Function( MessageUpdateEvent value)?  messageUpdate,TResult? Function( MessageDeleteEvent value)?  messageDelete,TResult? Function( MessageReactionUpdateEvent value)?  messageReactionUpdate,TResult? Function( UserUpdateEvent value)?  userUpdate,TResult? Function( TypingStartEvent value)?  typingStart,TResult? Function( PresenceUpdateEvent value)?  presenceUpdate,TResult? Function( VoiceStateUpdateEvent value)?  voiceStateUpdate,TResult? Function( ChannelCreateEvent value)?  channelCreate,TResult? Function( ChannelUpdateEvent value)?  channelUpdate,TResult? Function( ChannelDeleteEvent value)?  channelDelete,TResult? Function( DMUpdateEvent value)?  dmUpdate,TResult? Function( DMCallEvent value)?  dmCall,TResult? Function( UnknownEvent value)?  unknown,}){
final _that = this;
switch (_that) {
case ReadyEvent() when ready != null:
return ready(_that);case MessageCreateEvent() when messageCreate != null:
return messageCreate(_that);case MessageUpdateEvent() when messageUpdate != null:
return messageUpdate(_that);case MessageDeleteEvent() when messageDelete != null:
return messageDelete(_that);case MessageReactionUpdateEvent() when messageReactionUpdate != null:
return messageReactionUpdate(_that);case UserUpdateEvent() when userUpdate != null:
return userUpdate(_that);case TypingStartEvent() when typingStart != null:
return typingStart(_that);case PresenceUpdateEvent() when presenceUpdate != null:
return presenceUpdate(_that);case VoiceStateUpdateEvent() when voiceStateUpdate != null:
return voiceStateUpdate(_that);case ChannelCreateEvent() when channelCreate != null:
return channelCreate(_that);case ChannelUpdateEvent() when channelUpdate != null:
return channelUpdate(_that);case ChannelDeleteEvent() when channelDelete != null:
return channelDelete(_that);case DMUpdateEvent() when dmUpdate != null:
return dmUpdate(_that);case DMCallEvent() when dmCall != null:
return dmCall(_that);case UnknownEvent() when unknown != null:
return unknown(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( ReadyData data)?  ready,TResult Function( Message message)?  messageCreate,TResult Function( Message message)?  messageUpdate,TResult Function( MessageDeleteData data)?  messageDelete,TResult Function( MessageReactionUpdateData data)?  messageReactionUpdate,TResult Function( User user)?  userUpdate,TResult Function( TypingStartData data)?  typingStart,TResult Function( PresenceUpdateData data)?  presenceUpdate,TResult Function( VoiceStateUpdateData data)?  voiceStateUpdate,TResult Function( Channel channel)?  channelCreate,TResult Function( Channel channel)?  channelUpdate,TResult Function( ChannelDeleteData data)?  channelDelete,TResult Function( DMConversation conversation)?  dmUpdate,TResult Function( DMCallData data)?  dmCall,TResult Function( String op)?  unknown,required TResult orElse(),}) {final _that = this;
switch (_that) {
case ReadyEvent() when ready != null:
return ready(_that.data);case MessageCreateEvent() when messageCreate != null:
return messageCreate(_that.message);case MessageUpdateEvent() when messageUpdate != null:
return messageUpdate(_that.message);case MessageDeleteEvent() when messageDelete != null:
return messageDelete(_that.data);case MessageReactionUpdateEvent() when messageReactionUpdate != null:
return messageReactionUpdate(_that.data);case UserUpdateEvent() when userUpdate != null:
return userUpdate(_that.user);case TypingStartEvent() when typingStart != null:
return typingStart(_that.data);case PresenceUpdateEvent() when presenceUpdate != null:
return presenceUpdate(_that.data);case VoiceStateUpdateEvent() when voiceStateUpdate != null:
return voiceStateUpdate(_that.data);case ChannelCreateEvent() when channelCreate != null:
return channelCreate(_that.channel);case ChannelUpdateEvent() when channelUpdate != null:
return channelUpdate(_that.channel);case ChannelDeleteEvent() when channelDelete != null:
return channelDelete(_that.data);case DMUpdateEvent() when dmUpdate != null:
return dmUpdate(_that.conversation);case DMCallEvent() when dmCall != null:
return dmCall(_that.data);case UnknownEvent() when unknown != null:
return unknown(_that.op);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( ReadyData data)  ready,required TResult Function( Message message)  messageCreate,required TResult Function( Message message)  messageUpdate,required TResult Function( MessageDeleteData data)  messageDelete,required TResult Function( MessageReactionUpdateData data)  messageReactionUpdate,required TResult Function( User user)  userUpdate,required TResult Function( TypingStartData data)  typingStart,required TResult Function( PresenceUpdateData data)  presenceUpdate,required TResult Function( VoiceStateUpdateData data)  voiceStateUpdate,required TResult Function( Channel channel)  channelCreate,required TResult Function( Channel channel)  channelUpdate,required TResult Function( ChannelDeleteData data)  channelDelete,required TResult Function( DMConversation conversation)  dmUpdate,required TResult Function( DMCallData data)  dmCall,required TResult Function( String op)  unknown,}) {final _that = this;
switch (_that) {
case ReadyEvent():
return ready(_that.data);case MessageCreateEvent():
return messageCreate(_that.message);case MessageUpdateEvent():
return messageUpdate(_that.message);case MessageDeleteEvent():
return messageDelete(_that.data);case MessageReactionUpdateEvent():
return messageReactionUpdate(_that.data);case UserUpdateEvent():
return userUpdate(_that.user);case TypingStartEvent():
return typingStart(_that.data);case PresenceUpdateEvent():
return presenceUpdate(_that.data);case VoiceStateUpdateEvent():
return voiceStateUpdate(_that.data);case ChannelCreateEvent():
return channelCreate(_that.channel);case ChannelUpdateEvent():
return channelUpdate(_that.channel);case ChannelDeleteEvent():
return channelDelete(_that.data);case DMUpdateEvent():
return dmUpdate(_that.conversation);case DMCallEvent():
return dmCall(_that.data);case UnknownEvent():
return unknown(_that.op);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( ReadyData data)?  ready,TResult? Function( Message message)?  messageCreate,TResult? Function( Message message)?  messageUpdate,TResult? Function( MessageDeleteData data)?  messageDelete,TResult? Function( MessageReactionUpdateData data)?  messageReactionUpdate,TResult? Function( User user)?  userUpdate,TResult? Function( TypingStartData data)?  typingStart,TResult? Function( PresenceUpdateData data)?  presenceUpdate,TResult? Function( VoiceStateUpdateData data)?  voiceStateUpdate,TResult? Function( Channel channel)?  channelCreate,TResult? Function( Channel channel)?  channelUpdate,TResult? Function( ChannelDeleteData data)?  channelDelete,TResult? Function( DMConversation conversation)?  dmUpdate,TResult? Function( DMCallData data)?  dmCall,TResult? Function( String op)?  unknown,}) {final _that = this;
switch (_that) {
case ReadyEvent() when ready != null:
return ready(_that.data);case MessageCreateEvent() when messageCreate != null:
return messageCreate(_that.message);case MessageUpdateEvent() when messageUpdate != null:
return messageUpdate(_that.message);case MessageDeleteEvent() when messageDelete != null:
return messageDelete(_that.data);case MessageReactionUpdateEvent() when messageReactionUpdate != null:
return messageReactionUpdate(_that.data);case UserUpdateEvent() when userUpdate != null:
return userUpdate(_that.user);case TypingStartEvent() when typingStart != null:
return typingStart(_that.data);case PresenceUpdateEvent() when presenceUpdate != null:
return presenceUpdate(_that.data);case VoiceStateUpdateEvent() when voiceStateUpdate != null:
return voiceStateUpdate(_that.data);case ChannelCreateEvent() when channelCreate != null:
return channelCreate(_that.channel);case ChannelUpdateEvent() when channelUpdate != null:
return channelUpdate(_that.channel);case ChannelDeleteEvent() when channelDelete != null:
return channelDelete(_that.data);case DMUpdateEvent() when dmUpdate != null:
return dmUpdate(_that.conversation);case DMCallEvent() when dmCall != null:
return dmCall(_that.data);case UnknownEvent() when unknown != null:
return unknown(_that.op);case _:
  return null;

}
}

}

/// @nodoc


class ReadyEvent extends GatewayEvent {
  const ReadyEvent(this.data): super._();
  

 final  ReadyData data;

/// Create a copy of GatewayEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ReadyEventCopyWith<ReadyEvent> get copyWith => _$ReadyEventCopyWithImpl<ReadyEvent>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ReadyEvent&&(identical(other.data, data) || other.data == data));
}


@override
int get hashCode => Object.hash(runtimeType,data);

@override
String toString() {
  return 'GatewayEvent.ready(data: $data)';
}


}

/// @nodoc
abstract mixin class $ReadyEventCopyWith<$Res> implements $GatewayEventCopyWith<$Res> {
  factory $ReadyEventCopyWith(ReadyEvent value, $Res Function(ReadyEvent) _then) = _$ReadyEventCopyWithImpl;
@useResult
$Res call({
 ReadyData data
});


$ReadyDataCopyWith<$Res> get data;

}
/// @nodoc
class _$ReadyEventCopyWithImpl<$Res>
    implements $ReadyEventCopyWith<$Res> {
  _$ReadyEventCopyWithImpl(this._self, this._then);

  final ReadyEvent _self;
  final $Res Function(ReadyEvent) _then;

/// Create a copy of GatewayEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? data = null,}) {
  return _then(ReadyEvent(
null == data ? _self.data : data // ignore: cast_nullable_to_non_nullable
as ReadyData,
  ));
}

/// Create a copy of GatewayEvent
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ReadyDataCopyWith<$Res> get data {
  
  return $ReadyDataCopyWith<$Res>(_self.data, (value) {
    return _then(_self.copyWith(data: value));
  });
}
}

/// @nodoc


class MessageCreateEvent extends GatewayEvent {
  const MessageCreateEvent(this.message): super._();
  

 final  Message message;

/// Create a copy of GatewayEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MessageCreateEventCopyWith<MessageCreateEvent> get copyWith => _$MessageCreateEventCopyWithImpl<MessageCreateEvent>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MessageCreateEvent&&(identical(other.message, message) || other.message == message));
}


@override
int get hashCode => Object.hash(runtimeType,message);

@override
String toString() {
  return 'GatewayEvent.messageCreate(message: $message)';
}


}

/// @nodoc
abstract mixin class $MessageCreateEventCopyWith<$Res> implements $GatewayEventCopyWith<$Res> {
  factory $MessageCreateEventCopyWith(MessageCreateEvent value, $Res Function(MessageCreateEvent) _then) = _$MessageCreateEventCopyWithImpl;
@useResult
$Res call({
 Message message
});


$MessageCopyWith<$Res> get message;

}
/// @nodoc
class _$MessageCreateEventCopyWithImpl<$Res>
    implements $MessageCreateEventCopyWith<$Res> {
  _$MessageCreateEventCopyWithImpl(this._self, this._then);

  final MessageCreateEvent _self;
  final $Res Function(MessageCreateEvent) _then;

/// Create a copy of GatewayEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? message = null,}) {
  return _then(MessageCreateEvent(
null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as Message,
  ));
}

/// Create a copy of GatewayEvent
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$MessageCopyWith<$Res> get message {
  
  return $MessageCopyWith<$Res>(_self.message, (value) {
    return _then(_self.copyWith(message: value));
  });
}
}

/// @nodoc


class MessageUpdateEvent extends GatewayEvent {
  const MessageUpdateEvent(this.message): super._();
  

 final  Message message;

/// Create a copy of GatewayEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MessageUpdateEventCopyWith<MessageUpdateEvent> get copyWith => _$MessageUpdateEventCopyWithImpl<MessageUpdateEvent>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MessageUpdateEvent&&(identical(other.message, message) || other.message == message));
}


@override
int get hashCode => Object.hash(runtimeType,message);

@override
String toString() {
  return 'GatewayEvent.messageUpdate(message: $message)';
}


}

/// @nodoc
abstract mixin class $MessageUpdateEventCopyWith<$Res> implements $GatewayEventCopyWith<$Res> {
  factory $MessageUpdateEventCopyWith(MessageUpdateEvent value, $Res Function(MessageUpdateEvent) _then) = _$MessageUpdateEventCopyWithImpl;
@useResult
$Res call({
 Message message
});


$MessageCopyWith<$Res> get message;

}
/// @nodoc
class _$MessageUpdateEventCopyWithImpl<$Res>
    implements $MessageUpdateEventCopyWith<$Res> {
  _$MessageUpdateEventCopyWithImpl(this._self, this._then);

  final MessageUpdateEvent _self;
  final $Res Function(MessageUpdateEvent) _then;

/// Create a copy of GatewayEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? message = null,}) {
  return _then(MessageUpdateEvent(
null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as Message,
  ));
}

/// Create a copy of GatewayEvent
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$MessageCopyWith<$Res> get message {
  
  return $MessageCopyWith<$Res>(_self.message, (value) {
    return _then(_self.copyWith(message: value));
  });
}
}

/// @nodoc


class MessageDeleteEvent extends GatewayEvent {
  const MessageDeleteEvent(this.data): super._();
  

 final  MessageDeleteData data;

/// Create a copy of GatewayEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MessageDeleteEventCopyWith<MessageDeleteEvent> get copyWith => _$MessageDeleteEventCopyWithImpl<MessageDeleteEvent>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MessageDeleteEvent&&(identical(other.data, data) || other.data == data));
}


@override
int get hashCode => Object.hash(runtimeType,data);

@override
String toString() {
  return 'GatewayEvent.messageDelete(data: $data)';
}


}

/// @nodoc
abstract mixin class $MessageDeleteEventCopyWith<$Res> implements $GatewayEventCopyWith<$Res> {
  factory $MessageDeleteEventCopyWith(MessageDeleteEvent value, $Res Function(MessageDeleteEvent) _then) = _$MessageDeleteEventCopyWithImpl;
@useResult
$Res call({
 MessageDeleteData data
});


$MessageDeleteDataCopyWith<$Res> get data;

}
/// @nodoc
class _$MessageDeleteEventCopyWithImpl<$Res>
    implements $MessageDeleteEventCopyWith<$Res> {
  _$MessageDeleteEventCopyWithImpl(this._self, this._then);

  final MessageDeleteEvent _self;
  final $Res Function(MessageDeleteEvent) _then;

/// Create a copy of GatewayEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? data = null,}) {
  return _then(MessageDeleteEvent(
null == data ? _self.data : data // ignore: cast_nullable_to_non_nullable
as MessageDeleteData,
  ));
}

/// Create a copy of GatewayEvent
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$MessageDeleteDataCopyWith<$Res> get data {
  
  return $MessageDeleteDataCopyWith<$Res>(_self.data, (value) {
    return _then(_self.copyWith(data: value));
  });
}
}

/// @nodoc


class MessageReactionUpdateEvent extends GatewayEvent {
  const MessageReactionUpdateEvent(this.data): super._();
  

 final  MessageReactionUpdateData data;

/// Create a copy of GatewayEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MessageReactionUpdateEventCopyWith<MessageReactionUpdateEvent> get copyWith => _$MessageReactionUpdateEventCopyWithImpl<MessageReactionUpdateEvent>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MessageReactionUpdateEvent&&(identical(other.data, data) || other.data == data));
}


@override
int get hashCode => Object.hash(runtimeType,data);

@override
String toString() {
  return 'GatewayEvent.messageReactionUpdate(data: $data)';
}


}

/// @nodoc
abstract mixin class $MessageReactionUpdateEventCopyWith<$Res> implements $GatewayEventCopyWith<$Res> {
  factory $MessageReactionUpdateEventCopyWith(MessageReactionUpdateEvent value, $Res Function(MessageReactionUpdateEvent) _then) = _$MessageReactionUpdateEventCopyWithImpl;
@useResult
$Res call({
 MessageReactionUpdateData data
});


$MessageReactionUpdateDataCopyWith<$Res> get data;

}
/// @nodoc
class _$MessageReactionUpdateEventCopyWithImpl<$Res>
    implements $MessageReactionUpdateEventCopyWith<$Res> {
  _$MessageReactionUpdateEventCopyWithImpl(this._self, this._then);

  final MessageReactionUpdateEvent _self;
  final $Res Function(MessageReactionUpdateEvent) _then;

/// Create a copy of GatewayEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? data = null,}) {
  return _then(MessageReactionUpdateEvent(
null == data ? _self.data : data // ignore: cast_nullable_to_non_nullable
as MessageReactionUpdateData,
  ));
}

/// Create a copy of GatewayEvent
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$MessageReactionUpdateDataCopyWith<$Res> get data {
  
  return $MessageReactionUpdateDataCopyWith<$Res>(_self.data, (value) {
    return _then(_self.copyWith(data: value));
  });
}
}

/// @nodoc


class UserUpdateEvent extends GatewayEvent {
  const UserUpdateEvent(this.user): super._();
  

 final  User user;

/// Create a copy of GatewayEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UserUpdateEventCopyWith<UserUpdateEvent> get copyWith => _$UserUpdateEventCopyWithImpl<UserUpdateEvent>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UserUpdateEvent&&(identical(other.user, user) || other.user == user));
}


@override
int get hashCode => Object.hash(runtimeType,user);

@override
String toString() {
  return 'GatewayEvent.userUpdate(user: $user)';
}


}

/// @nodoc
abstract mixin class $UserUpdateEventCopyWith<$Res> implements $GatewayEventCopyWith<$Res> {
  factory $UserUpdateEventCopyWith(UserUpdateEvent value, $Res Function(UserUpdateEvent) _then) = _$UserUpdateEventCopyWithImpl;
@useResult
$Res call({
 User user
});


$UserCopyWith<$Res> get user;

}
/// @nodoc
class _$UserUpdateEventCopyWithImpl<$Res>
    implements $UserUpdateEventCopyWith<$Res> {
  _$UserUpdateEventCopyWithImpl(this._self, this._then);

  final UserUpdateEvent _self;
  final $Res Function(UserUpdateEvent) _then;

/// Create a copy of GatewayEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? user = null,}) {
  return _then(UserUpdateEvent(
null == user ? _self.user : user // ignore: cast_nullable_to_non_nullable
as User,
  ));
}

/// Create a copy of GatewayEvent
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$UserCopyWith<$Res> get user {
  
  return $UserCopyWith<$Res>(_self.user, (value) {
    return _then(_self.copyWith(user: value));
  });
}
}

/// @nodoc


class TypingStartEvent extends GatewayEvent {
  const TypingStartEvent(this.data): super._();
  

 final  TypingStartData data;

/// Create a copy of GatewayEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TypingStartEventCopyWith<TypingStartEvent> get copyWith => _$TypingStartEventCopyWithImpl<TypingStartEvent>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TypingStartEvent&&(identical(other.data, data) || other.data == data));
}


@override
int get hashCode => Object.hash(runtimeType,data);

@override
String toString() {
  return 'GatewayEvent.typingStart(data: $data)';
}


}

/// @nodoc
abstract mixin class $TypingStartEventCopyWith<$Res> implements $GatewayEventCopyWith<$Res> {
  factory $TypingStartEventCopyWith(TypingStartEvent value, $Res Function(TypingStartEvent) _then) = _$TypingStartEventCopyWithImpl;
@useResult
$Res call({
 TypingStartData data
});


$TypingStartDataCopyWith<$Res> get data;

}
/// @nodoc
class _$TypingStartEventCopyWithImpl<$Res>
    implements $TypingStartEventCopyWith<$Res> {
  _$TypingStartEventCopyWithImpl(this._self, this._then);

  final TypingStartEvent _self;
  final $Res Function(TypingStartEvent) _then;

/// Create a copy of GatewayEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? data = null,}) {
  return _then(TypingStartEvent(
null == data ? _self.data : data // ignore: cast_nullable_to_non_nullable
as TypingStartData,
  ));
}

/// Create a copy of GatewayEvent
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TypingStartDataCopyWith<$Res> get data {
  
  return $TypingStartDataCopyWith<$Res>(_self.data, (value) {
    return _then(_self.copyWith(data: value));
  });
}
}

/// @nodoc


class PresenceUpdateEvent extends GatewayEvent {
  const PresenceUpdateEvent(this.data): super._();
  

 final  PresenceUpdateData data;

/// Create a copy of GatewayEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PresenceUpdateEventCopyWith<PresenceUpdateEvent> get copyWith => _$PresenceUpdateEventCopyWithImpl<PresenceUpdateEvent>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PresenceUpdateEvent&&(identical(other.data, data) || other.data == data));
}


@override
int get hashCode => Object.hash(runtimeType,data);

@override
String toString() {
  return 'GatewayEvent.presenceUpdate(data: $data)';
}


}

/// @nodoc
abstract mixin class $PresenceUpdateEventCopyWith<$Res> implements $GatewayEventCopyWith<$Res> {
  factory $PresenceUpdateEventCopyWith(PresenceUpdateEvent value, $Res Function(PresenceUpdateEvent) _then) = _$PresenceUpdateEventCopyWithImpl;
@useResult
$Res call({
 PresenceUpdateData data
});


$PresenceUpdateDataCopyWith<$Res> get data;

}
/// @nodoc
class _$PresenceUpdateEventCopyWithImpl<$Res>
    implements $PresenceUpdateEventCopyWith<$Res> {
  _$PresenceUpdateEventCopyWithImpl(this._self, this._then);

  final PresenceUpdateEvent _self;
  final $Res Function(PresenceUpdateEvent) _then;

/// Create a copy of GatewayEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? data = null,}) {
  return _then(PresenceUpdateEvent(
null == data ? _self.data : data // ignore: cast_nullable_to_non_nullable
as PresenceUpdateData,
  ));
}

/// Create a copy of GatewayEvent
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PresenceUpdateDataCopyWith<$Res> get data {
  
  return $PresenceUpdateDataCopyWith<$Res>(_self.data, (value) {
    return _then(_self.copyWith(data: value));
  });
}
}

/// @nodoc


class VoiceStateUpdateEvent extends GatewayEvent {
  const VoiceStateUpdateEvent(this.data): super._();
  

 final  VoiceStateUpdateData data;

/// Create a copy of GatewayEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VoiceStateUpdateEventCopyWith<VoiceStateUpdateEvent> get copyWith => _$VoiceStateUpdateEventCopyWithImpl<VoiceStateUpdateEvent>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is VoiceStateUpdateEvent&&(identical(other.data, data) || other.data == data));
}


@override
int get hashCode => Object.hash(runtimeType,data);

@override
String toString() {
  return 'GatewayEvent.voiceStateUpdate(data: $data)';
}


}

/// @nodoc
abstract mixin class $VoiceStateUpdateEventCopyWith<$Res> implements $GatewayEventCopyWith<$Res> {
  factory $VoiceStateUpdateEventCopyWith(VoiceStateUpdateEvent value, $Res Function(VoiceStateUpdateEvent) _then) = _$VoiceStateUpdateEventCopyWithImpl;
@useResult
$Res call({
 VoiceStateUpdateData data
});


$VoiceStateUpdateDataCopyWith<$Res> get data;

}
/// @nodoc
class _$VoiceStateUpdateEventCopyWithImpl<$Res>
    implements $VoiceStateUpdateEventCopyWith<$Res> {
  _$VoiceStateUpdateEventCopyWithImpl(this._self, this._then);

  final VoiceStateUpdateEvent _self;
  final $Res Function(VoiceStateUpdateEvent) _then;

/// Create a copy of GatewayEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? data = null,}) {
  return _then(VoiceStateUpdateEvent(
null == data ? _self.data : data // ignore: cast_nullable_to_non_nullable
as VoiceStateUpdateData,
  ));
}

/// Create a copy of GatewayEvent
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$VoiceStateUpdateDataCopyWith<$Res> get data {
  
  return $VoiceStateUpdateDataCopyWith<$Res>(_self.data, (value) {
    return _then(_self.copyWith(data: value));
  });
}
}

/// @nodoc


class ChannelCreateEvent extends GatewayEvent {
  const ChannelCreateEvent(this.channel): super._();
  

 final  Channel channel;

/// Create a copy of GatewayEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ChannelCreateEventCopyWith<ChannelCreateEvent> get copyWith => _$ChannelCreateEventCopyWithImpl<ChannelCreateEvent>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ChannelCreateEvent&&(identical(other.channel, channel) || other.channel == channel));
}


@override
int get hashCode => Object.hash(runtimeType,channel);

@override
String toString() {
  return 'GatewayEvent.channelCreate(channel: $channel)';
}


}

/// @nodoc
abstract mixin class $ChannelCreateEventCopyWith<$Res> implements $GatewayEventCopyWith<$Res> {
  factory $ChannelCreateEventCopyWith(ChannelCreateEvent value, $Res Function(ChannelCreateEvent) _then) = _$ChannelCreateEventCopyWithImpl;
@useResult
$Res call({
 Channel channel
});


$ChannelCopyWith<$Res> get channel;

}
/// @nodoc
class _$ChannelCreateEventCopyWithImpl<$Res>
    implements $ChannelCreateEventCopyWith<$Res> {
  _$ChannelCreateEventCopyWithImpl(this._self, this._then);

  final ChannelCreateEvent _self;
  final $Res Function(ChannelCreateEvent) _then;

/// Create a copy of GatewayEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? channel = null,}) {
  return _then(ChannelCreateEvent(
null == channel ? _self.channel : channel // ignore: cast_nullable_to_non_nullable
as Channel,
  ));
}

/// Create a copy of GatewayEvent
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ChannelCopyWith<$Res> get channel {
  
  return $ChannelCopyWith<$Res>(_self.channel, (value) {
    return _then(_self.copyWith(channel: value));
  });
}
}

/// @nodoc


class ChannelUpdateEvent extends GatewayEvent {
  const ChannelUpdateEvent(this.channel): super._();
  

 final  Channel channel;

/// Create a copy of GatewayEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ChannelUpdateEventCopyWith<ChannelUpdateEvent> get copyWith => _$ChannelUpdateEventCopyWithImpl<ChannelUpdateEvent>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ChannelUpdateEvent&&(identical(other.channel, channel) || other.channel == channel));
}


@override
int get hashCode => Object.hash(runtimeType,channel);

@override
String toString() {
  return 'GatewayEvent.channelUpdate(channel: $channel)';
}


}

/// @nodoc
abstract mixin class $ChannelUpdateEventCopyWith<$Res> implements $GatewayEventCopyWith<$Res> {
  factory $ChannelUpdateEventCopyWith(ChannelUpdateEvent value, $Res Function(ChannelUpdateEvent) _then) = _$ChannelUpdateEventCopyWithImpl;
@useResult
$Res call({
 Channel channel
});


$ChannelCopyWith<$Res> get channel;

}
/// @nodoc
class _$ChannelUpdateEventCopyWithImpl<$Res>
    implements $ChannelUpdateEventCopyWith<$Res> {
  _$ChannelUpdateEventCopyWithImpl(this._self, this._then);

  final ChannelUpdateEvent _self;
  final $Res Function(ChannelUpdateEvent) _then;

/// Create a copy of GatewayEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? channel = null,}) {
  return _then(ChannelUpdateEvent(
null == channel ? _self.channel : channel // ignore: cast_nullable_to_non_nullable
as Channel,
  ));
}

/// Create a copy of GatewayEvent
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ChannelCopyWith<$Res> get channel {
  
  return $ChannelCopyWith<$Res>(_self.channel, (value) {
    return _then(_self.copyWith(channel: value));
  });
}
}

/// @nodoc


class ChannelDeleteEvent extends GatewayEvent {
  const ChannelDeleteEvent(this.data): super._();
  

 final  ChannelDeleteData data;

/// Create a copy of GatewayEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ChannelDeleteEventCopyWith<ChannelDeleteEvent> get copyWith => _$ChannelDeleteEventCopyWithImpl<ChannelDeleteEvent>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ChannelDeleteEvent&&(identical(other.data, data) || other.data == data));
}


@override
int get hashCode => Object.hash(runtimeType,data);

@override
String toString() {
  return 'GatewayEvent.channelDelete(data: $data)';
}


}

/// @nodoc
abstract mixin class $ChannelDeleteEventCopyWith<$Res> implements $GatewayEventCopyWith<$Res> {
  factory $ChannelDeleteEventCopyWith(ChannelDeleteEvent value, $Res Function(ChannelDeleteEvent) _then) = _$ChannelDeleteEventCopyWithImpl;
@useResult
$Res call({
 ChannelDeleteData data
});


$ChannelDeleteDataCopyWith<$Res> get data;

}
/// @nodoc
class _$ChannelDeleteEventCopyWithImpl<$Res>
    implements $ChannelDeleteEventCopyWith<$Res> {
  _$ChannelDeleteEventCopyWithImpl(this._self, this._then);

  final ChannelDeleteEvent _self;
  final $Res Function(ChannelDeleteEvent) _then;

/// Create a copy of GatewayEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? data = null,}) {
  return _then(ChannelDeleteEvent(
null == data ? _self.data : data // ignore: cast_nullable_to_non_nullable
as ChannelDeleteData,
  ));
}

/// Create a copy of GatewayEvent
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ChannelDeleteDataCopyWith<$Res> get data {
  
  return $ChannelDeleteDataCopyWith<$Res>(_self.data, (value) {
    return _then(_self.copyWith(data: value));
  });
}
}

/// @nodoc


class DMUpdateEvent extends GatewayEvent {
  const DMUpdateEvent(this.conversation): super._();
  

 final  DMConversation conversation;

/// Create a copy of GatewayEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DMUpdateEventCopyWith<DMUpdateEvent> get copyWith => _$DMUpdateEventCopyWithImpl<DMUpdateEvent>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DMUpdateEvent&&(identical(other.conversation, conversation) || other.conversation == conversation));
}


@override
int get hashCode => Object.hash(runtimeType,conversation);

@override
String toString() {
  return 'GatewayEvent.dmUpdate(conversation: $conversation)';
}


}

/// @nodoc
abstract mixin class $DMUpdateEventCopyWith<$Res> implements $GatewayEventCopyWith<$Res> {
  factory $DMUpdateEventCopyWith(DMUpdateEvent value, $Res Function(DMUpdateEvent) _then) = _$DMUpdateEventCopyWithImpl;
@useResult
$Res call({
 DMConversation conversation
});


$DMConversationCopyWith<$Res> get conversation;

}
/// @nodoc
class _$DMUpdateEventCopyWithImpl<$Res>
    implements $DMUpdateEventCopyWith<$Res> {
  _$DMUpdateEventCopyWithImpl(this._self, this._then);

  final DMUpdateEvent _self;
  final $Res Function(DMUpdateEvent) _then;

/// Create a copy of GatewayEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? conversation = null,}) {
  return _then(DMUpdateEvent(
null == conversation ? _self.conversation : conversation // ignore: cast_nullable_to_non_nullable
as DMConversation,
  ));
}

/// Create a copy of GatewayEvent
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$DMConversationCopyWith<$Res> get conversation {
  
  return $DMConversationCopyWith<$Res>(_self.conversation, (value) {
    return _then(_self.copyWith(conversation: value));
  });
}
}

/// @nodoc


class DMCallEvent extends GatewayEvent {
  const DMCallEvent(this.data): super._();
  

 final  DMCallData data;

/// Create a copy of GatewayEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DMCallEventCopyWith<DMCallEvent> get copyWith => _$DMCallEventCopyWithImpl<DMCallEvent>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DMCallEvent&&(identical(other.data, data) || other.data == data));
}


@override
int get hashCode => Object.hash(runtimeType,data);

@override
String toString() {
  return 'GatewayEvent.dmCall(data: $data)';
}


}

/// @nodoc
abstract mixin class $DMCallEventCopyWith<$Res> implements $GatewayEventCopyWith<$Res> {
  factory $DMCallEventCopyWith(DMCallEvent value, $Res Function(DMCallEvent) _then) = _$DMCallEventCopyWithImpl;
@useResult
$Res call({
 DMCallData data
});


$DMCallDataCopyWith<$Res> get data;

}
/// @nodoc
class _$DMCallEventCopyWithImpl<$Res>
    implements $DMCallEventCopyWith<$Res> {
  _$DMCallEventCopyWithImpl(this._self, this._then);

  final DMCallEvent _self;
  final $Res Function(DMCallEvent) _then;

/// Create a copy of GatewayEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? data = null,}) {
  return _then(DMCallEvent(
null == data ? _self.data : data // ignore: cast_nullable_to_non_nullable
as DMCallData,
  ));
}

/// Create a copy of GatewayEvent
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$DMCallDataCopyWith<$Res> get data {
  
  return $DMCallDataCopyWith<$Res>(_self.data, (value) {
    return _then(_self.copyWith(data: value));
  });
}
}

/// @nodoc


class UnknownEvent extends GatewayEvent {
  const UnknownEvent(this.op): super._();
  

 final  String op;

/// Create a copy of GatewayEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UnknownEventCopyWith<UnknownEvent> get copyWith => _$UnknownEventCopyWithImpl<UnknownEvent>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UnknownEvent&&(identical(other.op, op) || other.op == op));
}


@override
int get hashCode => Object.hash(runtimeType,op);

@override
String toString() {
  return 'GatewayEvent.unknown(op: $op)';
}


}

/// @nodoc
abstract mixin class $UnknownEventCopyWith<$Res> implements $GatewayEventCopyWith<$Res> {
  factory $UnknownEventCopyWith(UnknownEvent value, $Res Function(UnknownEvent) _then) = _$UnknownEventCopyWithImpl;
@useResult
$Res call({
 String op
});




}
/// @nodoc
class _$UnknownEventCopyWithImpl<$Res>
    implements $UnknownEventCopyWith<$Res> {
  _$UnknownEventCopyWithImpl(this._self, this._then);

  final UnknownEvent _self;
  final $Res Function(UnknownEvent) _then;

/// Create a copy of GatewayEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? op = null,}) {
  return _then(UnknownEvent(
null == op ? _self.op : op // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$ReadyData {

 User get user; ServerSettings get server; List<Channel> get channels; List<DMConversation> get dms; List<String> get onlineUserIds; List<VoiceParticipantState> get voiceStates;
/// Create a copy of ReadyData
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ReadyDataCopyWith<ReadyData> get copyWith => _$ReadyDataCopyWithImpl<ReadyData>(this as ReadyData, _$identity);

  /// Serializes this ReadyData to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ReadyData&&(identical(other.user, user) || other.user == user)&&(identical(other.server, server) || other.server == server)&&const DeepCollectionEquality().equals(other.channels, channels)&&const DeepCollectionEquality().equals(other.dms, dms)&&const DeepCollectionEquality().equals(other.onlineUserIds, onlineUserIds)&&const DeepCollectionEquality().equals(other.voiceStates, voiceStates));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,user,server,const DeepCollectionEquality().hash(channels),const DeepCollectionEquality().hash(dms),const DeepCollectionEquality().hash(onlineUserIds),const DeepCollectionEquality().hash(voiceStates));

@override
String toString() {
  return 'ReadyData(user: $user, server: $server, channels: $channels, dms: $dms, onlineUserIds: $onlineUserIds, voiceStates: $voiceStates)';
}


}

/// @nodoc
abstract mixin class $ReadyDataCopyWith<$Res>  {
  factory $ReadyDataCopyWith(ReadyData value, $Res Function(ReadyData) _then) = _$ReadyDataCopyWithImpl;
@useResult
$Res call({
 User user, ServerSettings server, List<Channel> channels, List<DMConversation> dms, List<String> onlineUserIds, List<VoiceParticipantState> voiceStates
});


$UserCopyWith<$Res> get user;$ServerSettingsCopyWith<$Res> get server;

}
/// @nodoc
class _$ReadyDataCopyWithImpl<$Res>
    implements $ReadyDataCopyWith<$Res> {
  _$ReadyDataCopyWithImpl(this._self, this._then);

  final ReadyData _self;
  final $Res Function(ReadyData) _then;

/// Create a copy of ReadyData
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? user = null,Object? server = null,Object? channels = null,Object? dms = null,Object? onlineUserIds = null,Object? voiceStates = null,}) {
  return _then(_self.copyWith(
user: null == user ? _self.user : user // ignore: cast_nullable_to_non_nullable
as User,server: null == server ? _self.server : server // ignore: cast_nullable_to_non_nullable
as ServerSettings,channels: null == channels ? _self.channels : channels // ignore: cast_nullable_to_non_nullable
as List<Channel>,dms: null == dms ? _self.dms : dms // ignore: cast_nullable_to_non_nullable
as List<DMConversation>,onlineUserIds: null == onlineUserIds ? _self.onlineUserIds : onlineUserIds // ignore: cast_nullable_to_non_nullable
as List<String>,voiceStates: null == voiceStates ? _self.voiceStates : voiceStates // ignore: cast_nullable_to_non_nullable
as List<VoiceParticipantState>,
  ));
}
/// Create a copy of ReadyData
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$UserCopyWith<$Res> get user {
  
  return $UserCopyWith<$Res>(_self.user, (value) {
    return _then(_self.copyWith(user: value));
  });
}/// Create a copy of ReadyData
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ServerSettingsCopyWith<$Res> get server {
  
  return $ServerSettingsCopyWith<$Res>(_self.server, (value) {
    return _then(_self.copyWith(server: value));
  });
}
}


/// Adds pattern-matching-related methods to [ReadyData].
extension ReadyDataPatterns on ReadyData {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ReadyData value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ReadyData() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ReadyData value)  $default,){
final _that = this;
switch (_that) {
case _ReadyData():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ReadyData value)?  $default,){
final _that = this;
switch (_that) {
case _ReadyData() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( User user,  ServerSettings server,  List<Channel> channels,  List<DMConversation> dms,  List<String> onlineUserIds,  List<VoiceParticipantState> voiceStates)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ReadyData() when $default != null:
return $default(_that.user,_that.server,_that.channels,_that.dms,_that.onlineUserIds,_that.voiceStates);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( User user,  ServerSettings server,  List<Channel> channels,  List<DMConversation> dms,  List<String> onlineUserIds,  List<VoiceParticipantState> voiceStates)  $default,) {final _that = this;
switch (_that) {
case _ReadyData():
return $default(_that.user,_that.server,_that.channels,_that.dms,_that.onlineUserIds,_that.voiceStates);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( User user,  ServerSettings server,  List<Channel> channels,  List<DMConversation> dms,  List<String> onlineUserIds,  List<VoiceParticipantState> voiceStates)?  $default,) {final _that = this;
switch (_that) {
case _ReadyData() when $default != null:
return $default(_that.user,_that.server,_that.channels,_that.dms,_that.onlineUserIds,_that.voiceStates);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ReadyData implements ReadyData {
  const _ReadyData({required this.user, required this.server, required final  List<Channel> channels, required final  List<DMConversation> dms, final  List<String> onlineUserIds = const <String>[], final  List<VoiceParticipantState> voiceStates = const <VoiceParticipantState>[]}): _channels = channels,_dms = dms,_onlineUserIds = onlineUserIds,_voiceStates = voiceStates;
  factory _ReadyData.fromJson(Map<String, dynamic> json) => _$ReadyDataFromJson(json);

@override final  User user;
@override final  ServerSettings server;
 final  List<Channel> _channels;
@override List<Channel> get channels {
  if (_channels is EqualUnmodifiableListView) return _channels;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_channels);
}

 final  List<DMConversation> _dms;
@override List<DMConversation> get dms {
  if (_dms is EqualUnmodifiableListView) return _dms;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_dms);
}

 final  List<String> _onlineUserIds;
@override@JsonKey() List<String> get onlineUserIds {
  if (_onlineUserIds is EqualUnmodifiableListView) return _onlineUserIds;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_onlineUserIds);
}

 final  List<VoiceParticipantState> _voiceStates;
@override@JsonKey() List<VoiceParticipantState> get voiceStates {
  if (_voiceStates is EqualUnmodifiableListView) return _voiceStates;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_voiceStates);
}


/// Create a copy of ReadyData
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ReadyDataCopyWith<_ReadyData> get copyWith => __$ReadyDataCopyWithImpl<_ReadyData>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ReadyDataToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ReadyData&&(identical(other.user, user) || other.user == user)&&(identical(other.server, server) || other.server == server)&&const DeepCollectionEquality().equals(other._channels, _channels)&&const DeepCollectionEquality().equals(other._dms, _dms)&&const DeepCollectionEquality().equals(other._onlineUserIds, _onlineUserIds)&&const DeepCollectionEquality().equals(other._voiceStates, _voiceStates));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,user,server,const DeepCollectionEquality().hash(_channels),const DeepCollectionEquality().hash(_dms),const DeepCollectionEquality().hash(_onlineUserIds),const DeepCollectionEquality().hash(_voiceStates));

@override
String toString() {
  return 'ReadyData(user: $user, server: $server, channels: $channels, dms: $dms, onlineUserIds: $onlineUserIds, voiceStates: $voiceStates)';
}


}

/// @nodoc
abstract mixin class _$ReadyDataCopyWith<$Res> implements $ReadyDataCopyWith<$Res> {
  factory _$ReadyDataCopyWith(_ReadyData value, $Res Function(_ReadyData) _then) = __$ReadyDataCopyWithImpl;
@override @useResult
$Res call({
 User user, ServerSettings server, List<Channel> channels, List<DMConversation> dms, List<String> onlineUserIds, List<VoiceParticipantState> voiceStates
});


@override $UserCopyWith<$Res> get user;@override $ServerSettingsCopyWith<$Res> get server;

}
/// @nodoc
class __$ReadyDataCopyWithImpl<$Res>
    implements _$ReadyDataCopyWith<$Res> {
  __$ReadyDataCopyWithImpl(this._self, this._then);

  final _ReadyData _self;
  final $Res Function(_ReadyData) _then;

/// Create a copy of ReadyData
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? user = null,Object? server = null,Object? channels = null,Object? dms = null,Object? onlineUserIds = null,Object? voiceStates = null,}) {
  return _then(_ReadyData(
user: null == user ? _self.user : user // ignore: cast_nullable_to_non_nullable
as User,server: null == server ? _self.server : server // ignore: cast_nullable_to_non_nullable
as ServerSettings,channels: null == channels ? _self._channels : channels // ignore: cast_nullable_to_non_nullable
as List<Channel>,dms: null == dms ? _self._dms : dms // ignore: cast_nullable_to_non_nullable
as List<DMConversation>,onlineUserIds: null == onlineUserIds ? _self._onlineUserIds : onlineUserIds // ignore: cast_nullable_to_non_nullable
as List<String>,voiceStates: null == voiceStates ? _self._voiceStates : voiceStates // ignore: cast_nullable_to_non_nullable
as List<VoiceParticipantState>,
  ));
}

/// Create a copy of ReadyData
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$UserCopyWith<$Res> get user {
  
  return $UserCopyWith<$Res>(_self.user, (value) {
    return _then(_self.copyWith(user: value));
  });
}/// Create a copy of ReadyData
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ServerSettingsCopyWith<$Res> get server {
  
  return $ServerSettingsCopyWith<$Res>(_self.server, (value) {
    return _then(_self.copyWith(server: value));
  });
}
}


/// @nodoc
mixin _$MessageReactionUpdateData {

 String get messageId; String get channelId; ReactionType get type; int get count; String get userId; bool get reacted;
/// Create a copy of MessageReactionUpdateData
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MessageReactionUpdateDataCopyWith<MessageReactionUpdateData> get copyWith => _$MessageReactionUpdateDataCopyWithImpl<MessageReactionUpdateData>(this as MessageReactionUpdateData, _$identity);

  /// Serializes this MessageReactionUpdateData to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MessageReactionUpdateData&&(identical(other.messageId, messageId) || other.messageId == messageId)&&(identical(other.channelId, channelId) || other.channelId == channelId)&&(identical(other.type, type) || other.type == type)&&(identical(other.count, count) || other.count == count)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.reacted, reacted) || other.reacted == reacted));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,messageId,channelId,type,count,userId,reacted);

@override
String toString() {
  return 'MessageReactionUpdateData(messageId: $messageId, channelId: $channelId, type: $type, count: $count, userId: $userId, reacted: $reacted)';
}


}

/// @nodoc
abstract mixin class $MessageReactionUpdateDataCopyWith<$Res>  {
  factory $MessageReactionUpdateDataCopyWith(MessageReactionUpdateData value, $Res Function(MessageReactionUpdateData) _then) = _$MessageReactionUpdateDataCopyWithImpl;
@useResult
$Res call({
 String messageId, String channelId, ReactionType type, int count, String userId, bool reacted
});




}
/// @nodoc
class _$MessageReactionUpdateDataCopyWithImpl<$Res>
    implements $MessageReactionUpdateDataCopyWith<$Res> {
  _$MessageReactionUpdateDataCopyWithImpl(this._self, this._then);

  final MessageReactionUpdateData _self;
  final $Res Function(MessageReactionUpdateData) _then;

/// Create a copy of MessageReactionUpdateData
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? messageId = null,Object? channelId = null,Object? type = null,Object? count = null,Object? userId = null,Object? reacted = null,}) {
  return _then(_self.copyWith(
messageId: null == messageId ? _self.messageId : messageId // ignore: cast_nullable_to_non_nullable
as String,channelId: null == channelId ? _self.channelId : channelId // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as ReactionType,count: null == count ? _self.count : count // ignore: cast_nullable_to_non_nullable
as int,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,reacted: null == reacted ? _self.reacted : reacted // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [MessageReactionUpdateData].
extension MessageReactionUpdateDataPatterns on MessageReactionUpdateData {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MessageReactionUpdateData value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MessageReactionUpdateData() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MessageReactionUpdateData value)  $default,){
final _that = this;
switch (_that) {
case _MessageReactionUpdateData():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MessageReactionUpdateData value)?  $default,){
final _that = this;
switch (_that) {
case _MessageReactionUpdateData() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String messageId,  String channelId,  ReactionType type,  int count,  String userId,  bool reacted)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MessageReactionUpdateData() when $default != null:
return $default(_that.messageId,_that.channelId,_that.type,_that.count,_that.userId,_that.reacted);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String messageId,  String channelId,  ReactionType type,  int count,  String userId,  bool reacted)  $default,) {final _that = this;
switch (_that) {
case _MessageReactionUpdateData():
return $default(_that.messageId,_that.channelId,_that.type,_that.count,_that.userId,_that.reacted);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String messageId,  String channelId,  ReactionType type,  int count,  String userId,  bool reacted)?  $default,) {final _that = this;
switch (_that) {
case _MessageReactionUpdateData() when $default != null:
return $default(_that.messageId,_that.channelId,_that.type,_that.count,_that.userId,_that.reacted);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _MessageReactionUpdateData implements MessageReactionUpdateData {
  const _MessageReactionUpdateData({required this.messageId, required this.channelId, required this.type, required this.count, required this.userId, required this.reacted});
  factory _MessageReactionUpdateData.fromJson(Map<String, dynamic> json) => _$MessageReactionUpdateDataFromJson(json);

@override final  String messageId;
@override final  String channelId;
@override final  ReactionType type;
@override final  int count;
@override final  String userId;
@override final  bool reacted;

/// Create a copy of MessageReactionUpdateData
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MessageReactionUpdateDataCopyWith<_MessageReactionUpdateData> get copyWith => __$MessageReactionUpdateDataCopyWithImpl<_MessageReactionUpdateData>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MessageReactionUpdateDataToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _MessageReactionUpdateData&&(identical(other.messageId, messageId) || other.messageId == messageId)&&(identical(other.channelId, channelId) || other.channelId == channelId)&&(identical(other.type, type) || other.type == type)&&(identical(other.count, count) || other.count == count)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.reacted, reacted) || other.reacted == reacted));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,messageId,channelId,type,count,userId,reacted);

@override
String toString() {
  return 'MessageReactionUpdateData(messageId: $messageId, channelId: $channelId, type: $type, count: $count, userId: $userId, reacted: $reacted)';
}


}

/// @nodoc
abstract mixin class _$MessageReactionUpdateDataCopyWith<$Res> implements $MessageReactionUpdateDataCopyWith<$Res> {
  factory _$MessageReactionUpdateDataCopyWith(_MessageReactionUpdateData value, $Res Function(_MessageReactionUpdateData) _then) = __$MessageReactionUpdateDataCopyWithImpl;
@override @useResult
$Res call({
 String messageId, String channelId, ReactionType type, int count, String userId, bool reacted
});




}
/// @nodoc
class __$MessageReactionUpdateDataCopyWithImpl<$Res>
    implements _$MessageReactionUpdateDataCopyWith<$Res> {
  __$MessageReactionUpdateDataCopyWithImpl(this._self, this._then);

  final _MessageReactionUpdateData _self;
  final $Res Function(_MessageReactionUpdateData) _then;

/// Create a copy of MessageReactionUpdateData
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? messageId = null,Object? channelId = null,Object? type = null,Object? count = null,Object? userId = null,Object? reacted = null,}) {
  return _then(_MessageReactionUpdateData(
messageId: null == messageId ? _self.messageId : messageId // ignore: cast_nullable_to_non_nullable
as String,channelId: null == channelId ? _self.channelId : channelId // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as ReactionType,count: null == count ? _self.count : count // ignore: cast_nullable_to_non_nullable
as int,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,reacted: null == reacted ? _self.reacted : reacted // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}


/// @nodoc
mixin _$PresenceUpdateData {

 String get userId; PresenceStatus get status;
/// Create a copy of PresenceUpdateData
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PresenceUpdateDataCopyWith<PresenceUpdateData> get copyWith => _$PresenceUpdateDataCopyWithImpl<PresenceUpdateData>(this as PresenceUpdateData, _$identity);

  /// Serializes this PresenceUpdateData to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PresenceUpdateData&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.status, status) || other.status == status));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,userId,status);

@override
String toString() {
  return 'PresenceUpdateData(userId: $userId, status: $status)';
}


}

/// @nodoc
abstract mixin class $PresenceUpdateDataCopyWith<$Res>  {
  factory $PresenceUpdateDataCopyWith(PresenceUpdateData value, $Res Function(PresenceUpdateData) _then) = _$PresenceUpdateDataCopyWithImpl;
@useResult
$Res call({
 String userId, PresenceStatus status
});




}
/// @nodoc
class _$PresenceUpdateDataCopyWithImpl<$Res>
    implements $PresenceUpdateDataCopyWith<$Res> {
  _$PresenceUpdateDataCopyWithImpl(this._self, this._then);

  final PresenceUpdateData _self;
  final $Res Function(PresenceUpdateData) _then;

/// Create a copy of PresenceUpdateData
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? userId = null,Object? status = null,}) {
  return _then(_self.copyWith(
userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as PresenceStatus,
  ));
}

}


/// Adds pattern-matching-related methods to [PresenceUpdateData].
extension PresenceUpdateDataPatterns on PresenceUpdateData {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PresenceUpdateData value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PresenceUpdateData() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PresenceUpdateData value)  $default,){
final _that = this;
switch (_that) {
case _PresenceUpdateData():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PresenceUpdateData value)?  $default,){
final _that = this;
switch (_that) {
case _PresenceUpdateData() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String userId,  PresenceStatus status)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PresenceUpdateData() when $default != null:
return $default(_that.userId,_that.status);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String userId,  PresenceStatus status)  $default,) {final _that = this;
switch (_that) {
case _PresenceUpdateData():
return $default(_that.userId,_that.status);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String userId,  PresenceStatus status)?  $default,) {final _that = this;
switch (_that) {
case _PresenceUpdateData() when $default != null:
return $default(_that.userId,_that.status);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _PresenceUpdateData implements PresenceUpdateData {
  const _PresenceUpdateData({required this.userId, required this.status});
  factory _PresenceUpdateData.fromJson(Map<String, dynamic> json) => _$PresenceUpdateDataFromJson(json);

@override final  String userId;
@override final  PresenceStatus status;

/// Create a copy of PresenceUpdateData
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PresenceUpdateDataCopyWith<_PresenceUpdateData> get copyWith => __$PresenceUpdateDataCopyWithImpl<_PresenceUpdateData>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PresenceUpdateDataToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PresenceUpdateData&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.status, status) || other.status == status));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,userId,status);

@override
String toString() {
  return 'PresenceUpdateData(userId: $userId, status: $status)';
}


}

/// @nodoc
abstract mixin class _$PresenceUpdateDataCopyWith<$Res> implements $PresenceUpdateDataCopyWith<$Res> {
  factory _$PresenceUpdateDataCopyWith(_PresenceUpdateData value, $Res Function(_PresenceUpdateData) _then) = __$PresenceUpdateDataCopyWithImpl;
@override @useResult
$Res call({
 String userId, PresenceStatus status
});




}
/// @nodoc
class __$PresenceUpdateDataCopyWithImpl<$Res>
    implements _$PresenceUpdateDataCopyWith<$Res> {
  __$PresenceUpdateDataCopyWithImpl(this._self, this._then);

  final _PresenceUpdateData _self;
  final $Res Function(_PresenceUpdateData) _then;

/// Create a copy of PresenceUpdateData
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? userId = null,Object? status = null,}) {
  return _then(_PresenceUpdateData(
userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as PresenceStatus,
  ));
}


}


/// @nodoc
mixin _$TypingStartData {

 String get userId; String get channelId;
/// Create a copy of TypingStartData
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TypingStartDataCopyWith<TypingStartData> get copyWith => _$TypingStartDataCopyWithImpl<TypingStartData>(this as TypingStartData, _$identity);

  /// Serializes this TypingStartData to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TypingStartData&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.channelId, channelId) || other.channelId == channelId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,userId,channelId);

@override
String toString() {
  return 'TypingStartData(userId: $userId, channelId: $channelId)';
}


}

/// @nodoc
abstract mixin class $TypingStartDataCopyWith<$Res>  {
  factory $TypingStartDataCopyWith(TypingStartData value, $Res Function(TypingStartData) _then) = _$TypingStartDataCopyWithImpl;
@useResult
$Res call({
 String userId, String channelId
});




}
/// @nodoc
class _$TypingStartDataCopyWithImpl<$Res>
    implements $TypingStartDataCopyWith<$Res> {
  _$TypingStartDataCopyWithImpl(this._self, this._then);

  final TypingStartData _self;
  final $Res Function(TypingStartData) _then;

/// Create a copy of TypingStartData
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? userId = null,Object? channelId = null,}) {
  return _then(_self.copyWith(
userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,channelId: null == channelId ? _self.channelId : channelId // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [TypingStartData].
extension TypingStartDataPatterns on TypingStartData {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TypingStartData value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TypingStartData() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TypingStartData value)  $default,){
final _that = this;
switch (_that) {
case _TypingStartData():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TypingStartData value)?  $default,){
final _that = this;
switch (_that) {
case _TypingStartData() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String userId,  String channelId)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TypingStartData() when $default != null:
return $default(_that.userId,_that.channelId);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String userId,  String channelId)  $default,) {final _that = this;
switch (_that) {
case _TypingStartData():
return $default(_that.userId,_that.channelId);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String userId,  String channelId)?  $default,) {final _that = this;
switch (_that) {
case _TypingStartData() when $default != null:
return $default(_that.userId,_that.channelId);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TypingStartData implements TypingStartData {
  const _TypingStartData({required this.userId, required this.channelId});
  factory _TypingStartData.fromJson(Map<String, dynamic> json) => _$TypingStartDataFromJson(json);

@override final  String userId;
@override final  String channelId;

/// Create a copy of TypingStartData
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TypingStartDataCopyWith<_TypingStartData> get copyWith => __$TypingStartDataCopyWithImpl<_TypingStartData>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TypingStartDataToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TypingStartData&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.channelId, channelId) || other.channelId == channelId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,userId,channelId);

@override
String toString() {
  return 'TypingStartData(userId: $userId, channelId: $channelId)';
}


}

/// @nodoc
abstract mixin class _$TypingStartDataCopyWith<$Res> implements $TypingStartDataCopyWith<$Res> {
  factory _$TypingStartDataCopyWith(_TypingStartData value, $Res Function(_TypingStartData) _then) = __$TypingStartDataCopyWithImpl;
@override @useResult
$Res call({
 String userId, String channelId
});




}
/// @nodoc
class __$TypingStartDataCopyWithImpl<$Res>
    implements _$TypingStartDataCopyWith<$Res> {
  __$TypingStartDataCopyWithImpl(this._self, this._then);

  final _TypingStartData _self;
  final $Res Function(_TypingStartData) _then;

/// Create a copy of TypingStartData
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? userId = null,Object? channelId = null,}) {
  return _then(_TypingStartData(
userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,channelId: null == channelId ? _self.channelId : channelId // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$VoiceStateUpdateData {

 VoiceStateAction get action;/// Absent on `room_finished`, which is about the room rather than a person.
 String? get userId; String? get username;/// Null when someone left voice altogether rather than a specific channel.
 String? get channelId; bool? get muted; bool? get deafened; bool? get screenSharing;
/// Create a copy of VoiceStateUpdateData
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VoiceStateUpdateDataCopyWith<VoiceStateUpdateData> get copyWith => _$VoiceStateUpdateDataCopyWithImpl<VoiceStateUpdateData>(this as VoiceStateUpdateData, _$identity);

  /// Serializes this VoiceStateUpdateData to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is VoiceStateUpdateData&&(identical(other.action, action) || other.action == action)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.username, username) || other.username == username)&&(identical(other.channelId, channelId) || other.channelId == channelId)&&(identical(other.muted, muted) || other.muted == muted)&&(identical(other.deafened, deafened) || other.deafened == deafened)&&(identical(other.screenSharing, screenSharing) || other.screenSharing == screenSharing));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,action,userId,username,channelId,muted,deafened,screenSharing);

@override
String toString() {
  return 'VoiceStateUpdateData(action: $action, userId: $userId, username: $username, channelId: $channelId, muted: $muted, deafened: $deafened, screenSharing: $screenSharing)';
}


}

/// @nodoc
abstract mixin class $VoiceStateUpdateDataCopyWith<$Res>  {
  factory $VoiceStateUpdateDataCopyWith(VoiceStateUpdateData value, $Res Function(VoiceStateUpdateData) _then) = _$VoiceStateUpdateDataCopyWithImpl;
@useResult
$Res call({
 VoiceStateAction action, String? userId, String? username, String? channelId, bool? muted, bool? deafened, bool? screenSharing
});




}
/// @nodoc
class _$VoiceStateUpdateDataCopyWithImpl<$Res>
    implements $VoiceStateUpdateDataCopyWith<$Res> {
  _$VoiceStateUpdateDataCopyWithImpl(this._self, this._then);

  final VoiceStateUpdateData _self;
  final $Res Function(VoiceStateUpdateData) _then;

/// Create a copy of VoiceStateUpdateData
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? action = null,Object? userId = freezed,Object? username = freezed,Object? channelId = freezed,Object? muted = freezed,Object? deafened = freezed,Object? screenSharing = freezed,}) {
  return _then(_self.copyWith(
action: null == action ? _self.action : action // ignore: cast_nullable_to_non_nullable
as VoiceStateAction,userId: freezed == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String?,username: freezed == username ? _self.username : username // ignore: cast_nullable_to_non_nullable
as String?,channelId: freezed == channelId ? _self.channelId : channelId // ignore: cast_nullable_to_non_nullable
as String?,muted: freezed == muted ? _self.muted : muted // ignore: cast_nullable_to_non_nullable
as bool?,deafened: freezed == deafened ? _self.deafened : deafened // ignore: cast_nullable_to_non_nullable
as bool?,screenSharing: freezed == screenSharing ? _self.screenSharing : screenSharing // ignore: cast_nullable_to_non_nullable
as bool?,
  ));
}

}


/// Adds pattern-matching-related methods to [VoiceStateUpdateData].
extension VoiceStateUpdateDataPatterns on VoiceStateUpdateData {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _VoiceStateUpdateData value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _VoiceStateUpdateData() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _VoiceStateUpdateData value)  $default,){
final _that = this;
switch (_that) {
case _VoiceStateUpdateData():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _VoiceStateUpdateData value)?  $default,){
final _that = this;
switch (_that) {
case _VoiceStateUpdateData() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( VoiceStateAction action,  String? userId,  String? username,  String? channelId,  bool? muted,  bool? deafened,  bool? screenSharing)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _VoiceStateUpdateData() when $default != null:
return $default(_that.action,_that.userId,_that.username,_that.channelId,_that.muted,_that.deafened,_that.screenSharing);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( VoiceStateAction action,  String? userId,  String? username,  String? channelId,  bool? muted,  bool? deafened,  bool? screenSharing)  $default,) {final _that = this;
switch (_that) {
case _VoiceStateUpdateData():
return $default(_that.action,_that.userId,_that.username,_that.channelId,_that.muted,_that.deafened,_that.screenSharing);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( VoiceStateAction action,  String? userId,  String? username,  String? channelId,  bool? muted,  bool? deafened,  bool? screenSharing)?  $default,) {final _that = this;
switch (_that) {
case _VoiceStateUpdateData() when $default != null:
return $default(_that.action,_that.userId,_that.username,_that.channelId,_that.muted,_that.deafened,_that.screenSharing);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _VoiceStateUpdateData implements VoiceStateUpdateData {
  const _VoiceStateUpdateData({required this.action, this.userId, this.username, this.channelId, this.muted, this.deafened, this.screenSharing});
  factory _VoiceStateUpdateData.fromJson(Map<String, dynamic> json) => _$VoiceStateUpdateDataFromJson(json);

@override final  VoiceStateAction action;
/// Absent on `room_finished`, which is about the room rather than a person.
@override final  String? userId;
@override final  String? username;
/// Null when someone left voice altogether rather than a specific channel.
@override final  String? channelId;
@override final  bool? muted;
@override final  bool? deafened;
@override final  bool? screenSharing;

/// Create a copy of VoiceStateUpdateData
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$VoiceStateUpdateDataCopyWith<_VoiceStateUpdateData> get copyWith => __$VoiceStateUpdateDataCopyWithImpl<_VoiceStateUpdateData>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$VoiceStateUpdateDataToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _VoiceStateUpdateData&&(identical(other.action, action) || other.action == action)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.username, username) || other.username == username)&&(identical(other.channelId, channelId) || other.channelId == channelId)&&(identical(other.muted, muted) || other.muted == muted)&&(identical(other.deafened, deafened) || other.deafened == deafened)&&(identical(other.screenSharing, screenSharing) || other.screenSharing == screenSharing));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,action,userId,username,channelId,muted,deafened,screenSharing);

@override
String toString() {
  return 'VoiceStateUpdateData(action: $action, userId: $userId, username: $username, channelId: $channelId, muted: $muted, deafened: $deafened, screenSharing: $screenSharing)';
}


}

/// @nodoc
abstract mixin class _$VoiceStateUpdateDataCopyWith<$Res> implements $VoiceStateUpdateDataCopyWith<$Res> {
  factory _$VoiceStateUpdateDataCopyWith(_VoiceStateUpdateData value, $Res Function(_VoiceStateUpdateData) _then) = __$VoiceStateUpdateDataCopyWithImpl;
@override @useResult
$Res call({
 VoiceStateAction action, String? userId, String? username, String? channelId, bool? muted, bool? deafened, bool? screenSharing
});




}
/// @nodoc
class __$VoiceStateUpdateDataCopyWithImpl<$Res>
    implements _$VoiceStateUpdateDataCopyWith<$Res> {
  __$VoiceStateUpdateDataCopyWithImpl(this._self, this._then);

  final _VoiceStateUpdateData _self;
  final $Res Function(_VoiceStateUpdateData) _then;

/// Create a copy of VoiceStateUpdateData
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? action = null,Object? userId = freezed,Object? username = freezed,Object? channelId = freezed,Object? muted = freezed,Object? deafened = freezed,Object? screenSharing = freezed,}) {
  return _then(_VoiceStateUpdateData(
action: null == action ? _self.action : action // ignore: cast_nullable_to_non_nullable
as VoiceStateAction,userId: freezed == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String?,username: freezed == username ? _self.username : username // ignore: cast_nullable_to_non_nullable
as String?,channelId: freezed == channelId ? _self.channelId : channelId // ignore: cast_nullable_to_non_nullable
as String?,muted: freezed == muted ? _self.muted : muted // ignore: cast_nullable_to_non_nullable
as bool?,deafened: freezed == deafened ? _self.deafened : deafened // ignore: cast_nullable_to_non_nullable
as bool?,screenSharing: freezed == screenSharing ? _self.screenSharing : screenSharing // ignore: cast_nullable_to_non_nullable
as bool?,
  ));
}


}


/// @nodoc
mixin _$DMCallActor {

 String get id; String get username;
/// Create a copy of DMCallActor
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DMCallActorCopyWith<DMCallActor> get copyWith => _$DMCallActorCopyWithImpl<DMCallActor>(this as DMCallActor, _$identity);

  /// Serializes this DMCallActor to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DMCallActor&&(identical(other.id, id) || other.id == id)&&(identical(other.username, username) || other.username == username));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,username);

@override
String toString() {
  return 'DMCallActor(id: $id, username: $username)';
}


}

/// @nodoc
abstract mixin class $DMCallActorCopyWith<$Res>  {
  factory $DMCallActorCopyWith(DMCallActor value, $Res Function(DMCallActor) _then) = _$DMCallActorCopyWithImpl;
@useResult
$Res call({
 String id, String username
});




}
/// @nodoc
class _$DMCallActorCopyWithImpl<$Res>
    implements $DMCallActorCopyWith<$Res> {
  _$DMCallActorCopyWithImpl(this._self, this._then);

  final DMCallActor _self;
  final $Res Function(DMCallActor) _then;

/// Create a copy of DMCallActor
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? username = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,username: null == username ? _self.username : username // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [DMCallActor].
extension DMCallActorPatterns on DMCallActor {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _DMCallActor value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _DMCallActor() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _DMCallActor value)  $default,){
final _that = this;
switch (_that) {
case _DMCallActor():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _DMCallActor value)?  $default,){
final _that = this;
switch (_that) {
case _DMCallActor() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String username)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _DMCallActor() when $default != null:
return $default(_that.id,_that.username);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String username)  $default,) {final _that = this;
switch (_that) {
case _DMCallActor():
return $default(_that.id,_that.username);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String username)?  $default,) {final _that = this;
switch (_that) {
case _DMCallActor() when $default != null:
return $default(_that.id,_that.username);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _DMCallActor implements DMCallActor {
  const _DMCallActor({required this.id, required this.username});
  factory _DMCallActor.fromJson(Map<String, dynamic> json) => _$DMCallActorFromJson(json);

@override final  String id;
@override final  String username;

/// Create a copy of DMCallActor
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DMCallActorCopyWith<_DMCallActor> get copyWith => __$DMCallActorCopyWithImpl<_DMCallActor>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$DMCallActorToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _DMCallActor&&(identical(other.id, id) || other.id == id)&&(identical(other.username, username) || other.username == username));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,username);

@override
String toString() {
  return 'DMCallActor(id: $id, username: $username)';
}


}

/// @nodoc
abstract mixin class _$DMCallActorCopyWith<$Res> implements $DMCallActorCopyWith<$Res> {
  factory _$DMCallActorCopyWith(_DMCallActor value, $Res Function(_DMCallActor) _then) = __$DMCallActorCopyWithImpl;
@override @useResult
$Res call({
 String id, String username
});




}
/// @nodoc
class __$DMCallActorCopyWithImpl<$Res>
    implements _$DMCallActorCopyWith<$Res> {
  __$DMCallActorCopyWithImpl(this._self, this._then);

  final _DMCallActor _self;
  final $Res Function(_DMCallActor) _then;

/// Create a copy of DMCallActor
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? username = null,}) {
  return _then(_DMCallActor(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,username: null == username ? _self.username : username // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$DMCallData {

 DMCallAction get action; String get channelId; DMCallActor get from;
/// Create a copy of DMCallData
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DMCallDataCopyWith<DMCallData> get copyWith => _$DMCallDataCopyWithImpl<DMCallData>(this as DMCallData, _$identity);

  /// Serializes this DMCallData to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DMCallData&&(identical(other.action, action) || other.action == action)&&(identical(other.channelId, channelId) || other.channelId == channelId)&&(identical(other.from, from) || other.from == from));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,action,channelId,from);

@override
String toString() {
  return 'DMCallData(action: $action, channelId: $channelId, from: $from)';
}


}

/// @nodoc
abstract mixin class $DMCallDataCopyWith<$Res>  {
  factory $DMCallDataCopyWith(DMCallData value, $Res Function(DMCallData) _then) = _$DMCallDataCopyWithImpl;
@useResult
$Res call({
 DMCallAction action, String channelId, DMCallActor from
});


$DMCallActorCopyWith<$Res> get from;

}
/// @nodoc
class _$DMCallDataCopyWithImpl<$Res>
    implements $DMCallDataCopyWith<$Res> {
  _$DMCallDataCopyWithImpl(this._self, this._then);

  final DMCallData _self;
  final $Res Function(DMCallData) _then;

/// Create a copy of DMCallData
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? action = null,Object? channelId = null,Object? from = null,}) {
  return _then(_self.copyWith(
action: null == action ? _self.action : action // ignore: cast_nullable_to_non_nullable
as DMCallAction,channelId: null == channelId ? _self.channelId : channelId // ignore: cast_nullable_to_non_nullable
as String,from: null == from ? _self.from : from // ignore: cast_nullable_to_non_nullable
as DMCallActor,
  ));
}
/// Create a copy of DMCallData
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$DMCallActorCopyWith<$Res> get from {
  
  return $DMCallActorCopyWith<$Res>(_self.from, (value) {
    return _then(_self.copyWith(from: value));
  });
}
}


/// Adds pattern-matching-related methods to [DMCallData].
extension DMCallDataPatterns on DMCallData {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _DMCallData value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _DMCallData() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _DMCallData value)  $default,){
final _that = this;
switch (_that) {
case _DMCallData():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _DMCallData value)?  $default,){
final _that = this;
switch (_that) {
case _DMCallData() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( DMCallAction action,  String channelId,  DMCallActor from)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _DMCallData() when $default != null:
return $default(_that.action,_that.channelId,_that.from);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( DMCallAction action,  String channelId,  DMCallActor from)  $default,) {final _that = this;
switch (_that) {
case _DMCallData():
return $default(_that.action,_that.channelId,_that.from);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( DMCallAction action,  String channelId,  DMCallActor from)?  $default,) {final _that = this;
switch (_that) {
case _DMCallData() when $default != null:
return $default(_that.action,_that.channelId,_that.from);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _DMCallData implements DMCallData {
  const _DMCallData({required this.action, required this.channelId, required this.from});
  factory _DMCallData.fromJson(Map<String, dynamic> json) => _$DMCallDataFromJson(json);

@override final  DMCallAction action;
@override final  String channelId;
@override final  DMCallActor from;

/// Create a copy of DMCallData
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DMCallDataCopyWith<_DMCallData> get copyWith => __$DMCallDataCopyWithImpl<_DMCallData>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$DMCallDataToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _DMCallData&&(identical(other.action, action) || other.action == action)&&(identical(other.channelId, channelId) || other.channelId == channelId)&&(identical(other.from, from) || other.from == from));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,action,channelId,from);

@override
String toString() {
  return 'DMCallData(action: $action, channelId: $channelId, from: $from)';
}


}

/// @nodoc
abstract mixin class _$DMCallDataCopyWith<$Res> implements $DMCallDataCopyWith<$Res> {
  factory _$DMCallDataCopyWith(_DMCallData value, $Res Function(_DMCallData) _then) = __$DMCallDataCopyWithImpl;
@override @useResult
$Res call({
 DMCallAction action, String channelId, DMCallActor from
});


@override $DMCallActorCopyWith<$Res> get from;

}
/// @nodoc
class __$DMCallDataCopyWithImpl<$Res>
    implements _$DMCallDataCopyWith<$Res> {
  __$DMCallDataCopyWithImpl(this._self, this._then);

  final _DMCallData _self;
  final $Res Function(_DMCallData) _then;

/// Create a copy of DMCallData
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? action = null,Object? channelId = null,Object? from = null,}) {
  return _then(_DMCallData(
action: null == action ? _self.action : action // ignore: cast_nullable_to_non_nullable
as DMCallAction,channelId: null == channelId ? _self.channelId : channelId // ignore: cast_nullable_to_non_nullable
as String,from: null == from ? _self.from : from // ignore: cast_nullable_to_non_nullable
as DMCallActor,
  ));
}

/// Create a copy of DMCallData
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$DMCallActorCopyWith<$Res> get from {
  
  return $DMCallActorCopyWith<$Res>(_self.from, (value) {
    return _then(_self.copyWith(from: value));
  });
}
}


/// @nodoc
mixin _$MessageDeleteData {

 String get id; String get channelId;
/// Create a copy of MessageDeleteData
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MessageDeleteDataCopyWith<MessageDeleteData> get copyWith => _$MessageDeleteDataCopyWithImpl<MessageDeleteData>(this as MessageDeleteData, _$identity);

  /// Serializes this MessageDeleteData to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MessageDeleteData&&(identical(other.id, id) || other.id == id)&&(identical(other.channelId, channelId) || other.channelId == channelId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,channelId);

@override
String toString() {
  return 'MessageDeleteData(id: $id, channelId: $channelId)';
}


}

/// @nodoc
abstract mixin class $MessageDeleteDataCopyWith<$Res>  {
  factory $MessageDeleteDataCopyWith(MessageDeleteData value, $Res Function(MessageDeleteData) _then) = _$MessageDeleteDataCopyWithImpl;
@useResult
$Res call({
 String id, String channelId
});




}
/// @nodoc
class _$MessageDeleteDataCopyWithImpl<$Res>
    implements $MessageDeleteDataCopyWith<$Res> {
  _$MessageDeleteDataCopyWithImpl(this._self, this._then);

  final MessageDeleteData _self;
  final $Res Function(MessageDeleteData) _then;

/// Create a copy of MessageDeleteData
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? channelId = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,channelId: null == channelId ? _self.channelId : channelId // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [MessageDeleteData].
extension MessageDeleteDataPatterns on MessageDeleteData {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MessageDeleteData value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MessageDeleteData() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MessageDeleteData value)  $default,){
final _that = this;
switch (_that) {
case _MessageDeleteData():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MessageDeleteData value)?  $default,){
final _that = this;
switch (_that) {
case _MessageDeleteData() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String channelId)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MessageDeleteData() when $default != null:
return $default(_that.id,_that.channelId);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String channelId)  $default,) {final _that = this;
switch (_that) {
case _MessageDeleteData():
return $default(_that.id,_that.channelId);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String channelId)?  $default,) {final _that = this;
switch (_that) {
case _MessageDeleteData() when $default != null:
return $default(_that.id,_that.channelId);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _MessageDeleteData implements MessageDeleteData {
  const _MessageDeleteData({required this.id, required this.channelId});
  factory _MessageDeleteData.fromJson(Map<String, dynamic> json) => _$MessageDeleteDataFromJson(json);

@override final  String id;
@override final  String channelId;

/// Create a copy of MessageDeleteData
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MessageDeleteDataCopyWith<_MessageDeleteData> get copyWith => __$MessageDeleteDataCopyWithImpl<_MessageDeleteData>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MessageDeleteDataToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _MessageDeleteData&&(identical(other.id, id) || other.id == id)&&(identical(other.channelId, channelId) || other.channelId == channelId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,channelId);

@override
String toString() {
  return 'MessageDeleteData(id: $id, channelId: $channelId)';
}


}

/// @nodoc
abstract mixin class _$MessageDeleteDataCopyWith<$Res> implements $MessageDeleteDataCopyWith<$Res> {
  factory _$MessageDeleteDataCopyWith(_MessageDeleteData value, $Res Function(_MessageDeleteData) _then) = __$MessageDeleteDataCopyWithImpl;
@override @useResult
$Res call({
 String id, String channelId
});




}
/// @nodoc
class __$MessageDeleteDataCopyWithImpl<$Res>
    implements _$MessageDeleteDataCopyWith<$Res> {
  __$MessageDeleteDataCopyWithImpl(this._self, this._then);

  final _MessageDeleteData _self;
  final $Res Function(_MessageDeleteData) _then;

/// Create a copy of MessageDeleteData
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? channelId = null,}) {
  return _then(_MessageDeleteData(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,channelId: null == channelId ? _self.channelId : channelId // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$ChannelDeleteData {

 String get id;
/// Create a copy of ChannelDeleteData
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ChannelDeleteDataCopyWith<ChannelDeleteData> get copyWith => _$ChannelDeleteDataCopyWithImpl<ChannelDeleteData>(this as ChannelDeleteData, _$identity);

  /// Serializes this ChannelDeleteData to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ChannelDeleteData&&(identical(other.id, id) || other.id == id));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id);

@override
String toString() {
  return 'ChannelDeleteData(id: $id)';
}


}

/// @nodoc
abstract mixin class $ChannelDeleteDataCopyWith<$Res>  {
  factory $ChannelDeleteDataCopyWith(ChannelDeleteData value, $Res Function(ChannelDeleteData) _then) = _$ChannelDeleteDataCopyWithImpl;
@useResult
$Res call({
 String id
});




}
/// @nodoc
class _$ChannelDeleteDataCopyWithImpl<$Res>
    implements $ChannelDeleteDataCopyWith<$Res> {
  _$ChannelDeleteDataCopyWithImpl(this._self, this._then);

  final ChannelDeleteData _self;
  final $Res Function(ChannelDeleteData) _then;

/// Create a copy of ChannelDeleteData
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [ChannelDeleteData].
extension ChannelDeleteDataPatterns on ChannelDeleteData {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ChannelDeleteData value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ChannelDeleteData() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ChannelDeleteData value)  $default,){
final _that = this;
switch (_that) {
case _ChannelDeleteData():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ChannelDeleteData value)?  $default,){
final _that = this;
switch (_that) {
case _ChannelDeleteData() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ChannelDeleteData() when $default != null:
return $default(_that.id);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id)  $default,) {final _that = this;
switch (_that) {
case _ChannelDeleteData():
return $default(_that.id);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id)?  $default,) {final _that = this;
switch (_that) {
case _ChannelDeleteData() when $default != null:
return $default(_that.id);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ChannelDeleteData implements ChannelDeleteData {
  const _ChannelDeleteData({required this.id});
  factory _ChannelDeleteData.fromJson(Map<String, dynamic> json) => _$ChannelDeleteDataFromJson(json);

@override final  String id;

/// Create a copy of ChannelDeleteData
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ChannelDeleteDataCopyWith<_ChannelDeleteData> get copyWith => __$ChannelDeleteDataCopyWithImpl<_ChannelDeleteData>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ChannelDeleteDataToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ChannelDeleteData&&(identical(other.id, id) || other.id == id));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id);

@override
String toString() {
  return 'ChannelDeleteData(id: $id)';
}


}

/// @nodoc
abstract mixin class _$ChannelDeleteDataCopyWith<$Res> implements $ChannelDeleteDataCopyWith<$Res> {
  factory _$ChannelDeleteDataCopyWith(_ChannelDeleteData value, $Res Function(_ChannelDeleteData) _then) = __$ChannelDeleteDataCopyWithImpl;
@override @useResult
$Res call({
 String id
});




}
/// @nodoc
class __$ChannelDeleteDataCopyWithImpl<$Res>
    implements _$ChannelDeleteDataCopyWith<$Res> {
  __$ChannelDeleteDataCopyWithImpl(this._self, this._then);

  final _ChannelDeleteData _self;
  final $Res Function(_ChannelDeleteData) _then;

/// Create a copy of ChannelDeleteData
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,}) {
  return _then(_ChannelDeleteData(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
