// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'message.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$MessageReplyPreview {

 String get id; User get author; String get content; bool get hasAttachments;
/// Create a copy of MessageReplyPreview
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MessageReplyPreviewCopyWith<MessageReplyPreview> get copyWith => _$MessageReplyPreviewCopyWithImpl<MessageReplyPreview>(this as MessageReplyPreview, _$identity);

  /// Serializes this MessageReplyPreview to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MessageReplyPreview&&(identical(other.id, id) || other.id == id)&&(identical(other.author, author) || other.author == author)&&(identical(other.content, content) || other.content == content)&&(identical(other.hasAttachments, hasAttachments) || other.hasAttachments == hasAttachments));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,author,content,hasAttachments);

@override
String toString() {
  return 'MessageReplyPreview(id: $id, author: $author, content: $content, hasAttachments: $hasAttachments)';
}


}

/// @nodoc
abstract mixin class $MessageReplyPreviewCopyWith<$Res>  {
  factory $MessageReplyPreviewCopyWith(MessageReplyPreview value, $Res Function(MessageReplyPreview) _then) = _$MessageReplyPreviewCopyWithImpl;
@useResult
$Res call({
 String id, User author, String content, bool hasAttachments
});


$UserCopyWith<$Res> get author;

}
/// @nodoc
class _$MessageReplyPreviewCopyWithImpl<$Res>
    implements $MessageReplyPreviewCopyWith<$Res> {
  _$MessageReplyPreviewCopyWithImpl(this._self, this._then);

  final MessageReplyPreview _self;
  final $Res Function(MessageReplyPreview) _then;

/// Create a copy of MessageReplyPreview
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? author = null,Object? content = null,Object? hasAttachments = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,author: null == author ? _self.author : author // ignore: cast_nullable_to_non_nullable
as User,content: null == content ? _self.content : content // ignore: cast_nullable_to_non_nullable
as String,hasAttachments: null == hasAttachments ? _self.hasAttachments : hasAttachments // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}
/// Create a copy of MessageReplyPreview
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$UserCopyWith<$Res> get author {
  
  return $UserCopyWith<$Res>(_self.author, (value) {
    return _then(_self.copyWith(author: value));
  });
}
}


/// Adds pattern-matching-related methods to [MessageReplyPreview].
extension MessageReplyPreviewPatterns on MessageReplyPreview {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MessageReplyPreview value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MessageReplyPreview() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MessageReplyPreview value)  $default,){
final _that = this;
switch (_that) {
case _MessageReplyPreview():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MessageReplyPreview value)?  $default,){
final _that = this;
switch (_that) {
case _MessageReplyPreview() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  User author,  String content,  bool hasAttachments)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MessageReplyPreview() when $default != null:
return $default(_that.id,_that.author,_that.content,_that.hasAttachments);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  User author,  String content,  bool hasAttachments)  $default,) {final _that = this;
switch (_that) {
case _MessageReplyPreview():
return $default(_that.id,_that.author,_that.content,_that.hasAttachments);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  User author,  String content,  bool hasAttachments)?  $default,) {final _that = this;
switch (_that) {
case _MessageReplyPreview() when $default != null:
return $default(_that.id,_that.author,_that.content,_that.hasAttachments);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _MessageReplyPreview implements MessageReplyPreview {
  const _MessageReplyPreview({required this.id, required this.author, required this.content, required this.hasAttachments});
  factory _MessageReplyPreview.fromJson(Map<String, dynamic> json) => _$MessageReplyPreviewFromJson(json);

@override final  String id;
@override final  User author;
@override final  String content;
@override final  bool hasAttachments;

/// Create a copy of MessageReplyPreview
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MessageReplyPreviewCopyWith<_MessageReplyPreview> get copyWith => __$MessageReplyPreviewCopyWithImpl<_MessageReplyPreview>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MessageReplyPreviewToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _MessageReplyPreview&&(identical(other.id, id) || other.id == id)&&(identical(other.author, author) || other.author == author)&&(identical(other.content, content) || other.content == content)&&(identical(other.hasAttachments, hasAttachments) || other.hasAttachments == hasAttachments));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,author,content,hasAttachments);

@override
String toString() {
  return 'MessageReplyPreview(id: $id, author: $author, content: $content, hasAttachments: $hasAttachments)';
}


}

/// @nodoc
abstract mixin class _$MessageReplyPreviewCopyWith<$Res> implements $MessageReplyPreviewCopyWith<$Res> {
  factory _$MessageReplyPreviewCopyWith(_MessageReplyPreview value, $Res Function(_MessageReplyPreview) _then) = __$MessageReplyPreviewCopyWithImpl;
@override @useResult
$Res call({
 String id, User author, String content, bool hasAttachments
});


@override $UserCopyWith<$Res> get author;

}
/// @nodoc
class __$MessageReplyPreviewCopyWithImpl<$Res>
    implements _$MessageReplyPreviewCopyWith<$Res> {
  __$MessageReplyPreviewCopyWithImpl(this._self, this._then);

  final _MessageReplyPreview _self;
  final $Res Function(_MessageReplyPreview) _then;

/// Create a copy of MessageReplyPreview
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? author = null,Object? content = null,Object? hasAttachments = null,}) {
  return _then(_MessageReplyPreview(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,author: null == author ? _self.author : author // ignore: cast_nullable_to_non_nullable
as User,content: null == content ? _self.content : content // ignore: cast_nullable_to_non_nullable
as String,hasAttachments: null == hasAttachments ? _self.hasAttachments : hasAttachments // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

/// Create a copy of MessageReplyPreview
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$UserCopyWith<$Res> get author {
  
  return $UserCopyWith<$Res>(_self.author, (value) {
    return _then(_self.copyWith(author: value));
  });
}
}


/// @nodoc
mixin _$MessageReaction {

 ReactionType get type; int get count; bool get reactedByMe;
/// Create a copy of MessageReaction
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MessageReactionCopyWith<MessageReaction> get copyWith => _$MessageReactionCopyWithImpl<MessageReaction>(this as MessageReaction, _$identity);

  /// Serializes this MessageReaction to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MessageReaction&&(identical(other.type, type) || other.type == type)&&(identical(other.count, count) || other.count == count)&&(identical(other.reactedByMe, reactedByMe) || other.reactedByMe == reactedByMe));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,type,count,reactedByMe);

@override
String toString() {
  return 'MessageReaction(type: $type, count: $count, reactedByMe: $reactedByMe)';
}


}

/// @nodoc
abstract mixin class $MessageReactionCopyWith<$Res>  {
  factory $MessageReactionCopyWith(MessageReaction value, $Res Function(MessageReaction) _then) = _$MessageReactionCopyWithImpl;
@useResult
$Res call({
 ReactionType type, int count, bool reactedByMe
});




}
/// @nodoc
class _$MessageReactionCopyWithImpl<$Res>
    implements $MessageReactionCopyWith<$Res> {
  _$MessageReactionCopyWithImpl(this._self, this._then);

  final MessageReaction _self;
  final $Res Function(MessageReaction) _then;

/// Create a copy of MessageReaction
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? type = null,Object? count = null,Object? reactedByMe = null,}) {
  return _then(_self.copyWith(
type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as ReactionType,count: null == count ? _self.count : count // ignore: cast_nullable_to_non_nullable
as int,reactedByMe: null == reactedByMe ? _self.reactedByMe : reactedByMe // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [MessageReaction].
extension MessageReactionPatterns on MessageReaction {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MessageReaction value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MessageReaction() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MessageReaction value)  $default,){
final _that = this;
switch (_that) {
case _MessageReaction():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MessageReaction value)?  $default,){
final _that = this;
switch (_that) {
case _MessageReaction() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( ReactionType type,  int count,  bool reactedByMe)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MessageReaction() when $default != null:
return $default(_that.type,_that.count,_that.reactedByMe);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( ReactionType type,  int count,  bool reactedByMe)  $default,) {final _that = this;
switch (_that) {
case _MessageReaction():
return $default(_that.type,_that.count,_that.reactedByMe);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( ReactionType type,  int count,  bool reactedByMe)?  $default,) {final _that = this;
switch (_that) {
case _MessageReaction() when $default != null:
return $default(_that.type,_that.count,_that.reactedByMe);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _MessageReaction implements MessageReaction {
  const _MessageReaction({required this.type, required this.count, required this.reactedByMe});
  factory _MessageReaction.fromJson(Map<String, dynamic> json) => _$MessageReactionFromJson(json);

@override final  ReactionType type;
@override final  int count;
@override final  bool reactedByMe;

/// Create a copy of MessageReaction
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MessageReactionCopyWith<_MessageReaction> get copyWith => __$MessageReactionCopyWithImpl<_MessageReaction>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MessageReactionToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _MessageReaction&&(identical(other.type, type) || other.type == type)&&(identical(other.count, count) || other.count == count)&&(identical(other.reactedByMe, reactedByMe) || other.reactedByMe == reactedByMe));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,type,count,reactedByMe);

@override
String toString() {
  return 'MessageReaction(type: $type, count: $count, reactedByMe: $reactedByMe)';
}


}

/// @nodoc
abstract mixin class _$MessageReactionCopyWith<$Res> implements $MessageReactionCopyWith<$Res> {
  factory _$MessageReactionCopyWith(_MessageReaction value, $Res Function(_MessageReaction) _then) = __$MessageReactionCopyWithImpl;
@override @useResult
$Res call({
 ReactionType type, int count, bool reactedByMe
});




}
/// @nodoc
class __$MessageReactionCopyWithImpl<$Res>
    implements _$MessageReactionCopyWith<$Res> {
  __$MessageReactionCopyWithImpl(this._self, this._then);

  final _MessageReaction _self;
  final $Res Function(_MessageReaction) _then;

/// Create a copy of MessageReaction
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? type = null,Object? count = null,Object? reactedByMe = null,}) {
  return _then(_MessageReaction(
type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as ReactionType,count: null == count ? _self.count : count // ignore: cast_nullable_to_non_nullable
as int,reactedByMe: null == reactedByMe ? _self.reactedByMe : reactedByMe // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}


/// @nodoc
mixin _$Message {

 String get id; String get channelId; User get author; String get content; DateTime get createdAt; DateTime? get editedAt; List<Attachment> get attachments; MessageReplyPreview? get replyTo;/// Absent from servers older than the reactions migration, and from any
/// message this client cached before it — an empty list, not a failure to
/// parse (the React client defaults it the same way).
 List<MessageReaction> get reactions;/// Local only: an optimistic row standing in for a message the server has
/// not acknowledged yet. The web client has no equivalent — it waits for the
/// POST — but on a phone the network is slow often enough that the text has
/// to appear the moment it is sent.
@JsonKey(includeFromJson: false, includeToJson: false) bool get pending;/// Local only: the POST came back an error, so the row offers to send it
/// again or throw it away instead of quietly losing what was typed.
@JsonKey(includeFromJson: false, includeToJson: false) bool get sendFailed;
/// Create a copy of Message
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MessageCopyWith<Message> get copyWith => _$MessageCopyWithImpl<Message>(this as Message, _$identity);

  /// Serializes this Message to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Message&&(identical(other.id, id) || other.id == id)&&(identical(other.channelId, channelId) || other.channelId == channelId)&&(identical(other.author, author) || other.author == author)&&(identical(other.content, content) || other.content == content)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.editedAt, editedAt) || other.editedAt == editedAt)&&const DeepCollectionEquality().equals(other.attachments, attachments)&&(identical(other.replyTo, replyTo) || other.replyTo == replyTo)&&const DeepCollectionEquality().equals(other.reactions, reactions)&&(identical(other.pending, pending) || other.pending == pending)&&(identical(other.sendFailed, sendFailed) || other.sendFailed == sendFailed));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,channelId,author,content,createdAt,editedAt,const DeepCollectionEquality().hash(attachments),replyTo,const DeepCollectionEquality().hash(reactions),pending,sendFailed);

@override
String toString() {
  return 'Message(id: $id, channelId: $channelId, author: $author, content: $content, createdAt: $createdAt, editedAt: $editedAt, attachments: $attachments, replyTo: $replyTo, reactions: $reactions, pending: $pending, sendFailed: $sendFailed)';
}


}

/// @nodoc
abstract mixin class $MessageCopyWith<$Res>  {
  factory $MessageCopyWith(Message value, $Res Function(Message) _then) = _$MessageCopyWithImpl;
@useResult
$Res call({
 String id, String channelId, User author, String content, DateTime createdAt, DateTime? editedAt, List<Attachment> attachments, MessageReplyPreview? replyTo, List<MessageReaction> reactions,@JsonKey(includeFromJson: false, includeToJson: false) bool pending,@JsonKey(includeFromJson: false, includeToJson: false) bool sendFailed
});


$UserCopyWith<$Res> get author;$MessageReplyPreviewCopyWith<$Res>? get replyTo;

}
/// @nodoc
class _$MessageCopyWithImpl<$Res>
    implements $MessageCopyWith<$Res> {
  _$MessageCopyWithImpl(this._self, this._then);

  final Message _self;
  final $Res Function(Message) _then;

/// Create a copy of Message
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? channelId = null,Object? author = null,Object? content = null,Object? createdAt = null,Object? editedAt = freezed,Object? attachments = null,Object? replyTo = freezed,Object? reactions = null,Object? pending = null,Object? sendFailed = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,channelId: null == channelId ? _self.channelId : channelId // ignore: cast_nullable_to_non_nullable
as String,author: null == author ? _self.author : author // ignore: cast_nullable_to_non_nullable
as User,content: null == content ? _self.content : content // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,editedAt: freezed == editedAt ? _self.editedAt : editedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,attachments: null == attachments ? _self.attachments : attachments // ignore: cast_nullable_to_non_nullable
as List<Attachment>,replyTo: freezed == replyTo ? _self.replyTo : replyTo // ignore: cast_nullable_to_non_nullable
as MessageReplyPreview?,reactions: null == reactions ? _self.reactions : reactions // ignore: cast_nullable_to_non_nullable
as List<MessageReaction>,pending: null == pending ? _self.pending : pending // ignore: cast_nullable_to_non_nullable
as bool,sendFailed: null == sendFailed ? _self.sendFailed : sendFailed // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}
/// Create a copy of Message
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$UserCopyWith<$Res> get author {
  
  return $UserCopyWith<$Res>(_self.author, (value) {
    return _then(_self.copyWith(author: value));
  });
}/// Create a copy of Message
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$MessageReplyPreviewCopyWith<$Res>? get replyTo {
    if (_self.replyTo == null) {
    return null;
  }

  return $MessageReplyPreviewCopyWith<$Res>(_self.replyTo!, (value) {
    return _then(_self.copyWith(replyTo: value));
  });
}
}


/// Adds pattern-matching-related methods to [Message].
extension MessagePatterns on Message {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Message value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Message() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Message value)  $default,){
final _that = this;
switch (_that) {
case _Message():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Message value)?  $default,){
final _that = this;
switch (_that) {
case _Message() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String channelId,  User author,  String content,  DateTime createdAt,  DateTime? editedAt,  List<Attachment> attachments,  MessageReplyPreview? replyTo,  List<MessageReaction> reactions, @JsonKey(includeFromJson: false, includeToJson: false)  bool pending, @JsonKey(includeFromJson: false, includeToJson: false)  bool sendFailed)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Message() when $default != null:
return $default(_that.id,_that.channelId,_that.author,_that.content,_that.createdAt,_that.editedAt,_that.attachments,_that.replyTo,_that.reactions,_that.pending,_that.sendFailed);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String channelId,  User author,  String content,  DateTime createdAt,  DateTime? editedAt,  List<Attachment> attachments,  MessageReplyPreview? replyTo,  List<MessageReaction> reactions, @JsonKey(includeFromJson: false, includeToJson: false)  bool pending, @JsonKey(includeFromJson: false, includeToJson: false)  bool sendFailed)  $default,) {final _that = this;
switch (_that) {
case _Message():
return $default(_that.id,_that.channelId,_that.author,_that.content,_that.createdAt,_that.editedAt,_that.attachments,_that.replyTo,_that.reactions,_that.pending,_that.sendFailed);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String channelId,  User author,  String content,  DateTime createdAt,  DateTime? editedAt,  List<Attachment> attachments,  MessageReplyPreview? replyTo,  List<MessageReaction> reactions, @JsonKey(includeFromJson: false, includeToJson: false)  bool pending, @JsonKey(includeFromJson: false, includeToJson: false)  bool sendFailed)?  $default,) {final _that = this;
switch (_that) {
case _Message() when $default != null:
return $default(_that.id,_that.channelId,_that.author,_that.content,_that.createdAt,_that.editedAt,_that.attachments,_that.replyTo,_that.reactions,_that.pending,_that.sendFailed);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Message implements Message {
  const _Message({required this.id, required this.channelId, required this.author, required this.content, required this.createdAt, required this.editedAt, final  List<Attachment> attachments = const <Attachment>[], this.replyTo, final  List<MessageReaction> reactions = const <MessageReaction>[], @JsonKey(includeFromJson: false, includeToJson: false) this.pending = false, @JsonKey(includeFromJson: false, includeToJson: false) this.sendFailed = false}): _attachments = attachments,_reactions = reactions;
  factory _Message.fromJson(Map<String, dynamic> json) => _$MessageFromJson(json);

@override final  String id;
@override final  String channelId;
@override final  User author;
@override final  String content;
@override final  DateTime createdAt;
@override final  DateTime? editedAt;
 final  List<Attachment> _attachments;
@override@JsonKey() List<Attachment> get attachments {
  if (_attachments is EqualUnmodifiableListView) return _attachments;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_attachments);
}

@override final  MessageReplyPreview? replyTo;
/// Absent from servers older than the reactions migration, and from any
/// message this client cached before it — an empty list, not a failure to
/// parse (the React client defaults it the same way).
 final  List<MessageReaction> _reactions;
/// Absent from servers older than the reactions migration, and from any
/// message this client cached before it — an empty list, not a failure to
/// parse (the React client defaults it the same way).
@override@JsonKey() List<MessageReaction> get reactions {
  if (_reactions is EqualUnmodifiableListView) return _reactions;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_reactions);
}

/// Local only: an optimistic row standing in for a message the server has
/// not acknowledged yet. The web client has no equivalent — it waits for the
/// POST — but on a phone the network is slow often enough that the text has
/// to appear the moment it is sent.
@override@JsonKey(includeFromJson: false, includeToJson: false) final  bool pending;
/// Local only: the POST came back an error, so the row offers to send it
/// again or throw it away instead of quietly losing what was typed.
@override@JsonKey(includeFromJson: false, includeToJson: false) final  bool sendFailed;

/// Create a copy of Message
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MessageCopyWith<_Message> get copyWith => __$MessageCopyWithImpl<_Message>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MessageToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Message&&(identical(other.id, id) || other.id == id)&&(identical(other.channelId, channelId) || other.channelId == channelId)&&(identical(other.author, author) || other.author == author)&&(identical(other.content, content) || other.content == content)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.editedAt, editedAt) || other.editedAt == editedAt)&&const DeepCollectionEquality().equals(other._attachments, _attachments)&&(identical(other.replyTo, replyTo) || other.replyTo == replyTo)&&const DeepCollectionEquality().equals(other._reactions, _reactions)&&(identical(other.pending, pending) || other.pending == pending)&&(identical(other.sendFailed, sendFailed) || other.sendFailed == sendFailed));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,channelId,author,content,createdAt,editedAt,const DeepCollectionEquality().hash(_attachments),replyTo,const DeepCollectionEquality().hash(_reactions),pending,sendFailed);

@override
String toString() {
  return 'Message(id: $id, channelId: $channelId, author: $author, content: $content, createdAt: $createdAt, editedAt: $editedAt, attachments: $attachments, replyTo: $replyTo, reactions: $reactions, pending: $pending, sendFailed: $sendFailed)';
}


}

/// @nodoc
abstract mixin class _$MessageCopyWith<$Res> implements $MessageCopyWith<$Res> {
  factory _$MessageCopyWith(_Message value, $Res Function(_Message) _then) = __$MessageCopyWithImpl;
@override @useResult
$Res call({
 String id, String channelId, User author, String content, DateTime createdAt, DateTime? editedAt, List<Attachment> attachments, MessageReplyPreview? replyTo, List<MessageReaction> reactions,@JsonKey(includeFromJson: false, includeToJson: false) bool pending,@JsonKey(includeFromJson: false, includeToJson: false) bool sendFailed
});


@override $UserCopyWith<$Res> get author;@override $MessageReplyPreviewCopyWith<$Res>? get replyTo;

}
/// @nodoc
class __$MessageCopyWithImpl<$Res>
    implements _$MessageCopyWith<$Res> {
  __$MessageCopyWithImpl(this._self, this._then);

  final _Message _self;
  final $Res Function(_Message) _then;

/// Create a copy of Message
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? channelId = null,Object? author = null,Object? content = null,Object? createdAt = null,Object? editedAt = freezed,Object? attachments = null,Object? replyTo = freezed,Object? reactions = null,Object? pending = null,Object? sendFailed = null,}) {
  return _then(_Message(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,channelId: null == channelId ? _self.channelId : channelId // ignore: cast_nullable_to_non_nullable
as String,author: null == author ? _self.author : author // ignore: cast_nullable_to_non_nullable
as User,content: null == content ? _self.content : content // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,editedAt: freezed == editedAt ? _self.editedAt : editedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,attachments: null == attachments ? _self._attachments : attachments // ignore: cast_nullable_to_non_nullable
as List<Attachment>,replyTo: freezed == replyTo ? _self.replyTo : replyTo // ignore: cast_nullable_to_non_nullable
as MessageReplyPreview?,reactions: null == reactions ? _self._reactions : reactions // ignore: cast_nullable_to_non_nullable
as List<MessageReaction>,pending: null == pending ? _self.pending : pending // ignore: cast_nullable_to_non_nullable
as bool,sendFailed: null == sendFailed ? _self.sendFailed : sendFailed // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

/// Create a copy of Message
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$UserCopyWith<$Res> get author {
  
  return $UserCopyWith<$Res>(_self.author, (value) {
    return _then(_self.copyWith(author: value));
  });
}/// Create a copy of Message
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$MessageReplyPreviewCopyWith<$Res>? get replyTo {
    if (_self.replyTo == null) {
    return null;
  }

  return $MessageReplyPreviewCopyWith<$Res>(_self.replyTo!, (value) {
    return _then(_self.copyWith(replyTo: value));
  });
}
}


/// @nodoc
mixin _$MessagePage {

 List<Message> get messages; bool get hasMore;
/// Create a copy of MessagePage
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MessagePageCopyWith<MessagePage> get copyWith => _$MessagePageCopyWithImpl<MessagePage>(this as MessagePage, _$identity);

  /// Serializes this MessagePage to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MessagePage&&const DeepCollectionEquality().equals(other.messages, messages)&&(identical(other.hasMore, hasMore) || other.hasMore == hasMore));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(messages),hasMore);

@override
String toString() {
  return 'MessagePage(messages: $messages, hasMore: $hasMore)';
}


}

/// @nodoc
abstract mixin class $MessagePageCopyWith<$Res>  {
  factory $MessagePageCopyWith(MessagePage value, $Res Function(MessagePage) _then) = _$MessagePageCopyWithImpl;
@useResult
$Res call({
 List<Message> messages, bool hasMore
});




}
/// @nodoc
class _$MessagePageCopyWithImpl<$Res>
    implements $MessagePageCopyWith<$Res> {
  _$MessagePageCopyWithImpl(this._self, this._then);

  final MessagePage _self;
  final $Res Function(MessagePage) _then;

/// Create a copy of MessagePage
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? messages = null,Object? hasMore = null,}) {
  return _then(_self.copyWith(
messages: null == messages ? _self.messages : messages // ignore: cast_nullable_to_non_nullable
as List<Message>,hasMore: null == hasMore ? _self.hasMore : hasMore // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [MessagePage].
extension MessagePagePatterns on MessagePage {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MessagePage value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MessagePage() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MessagePage value)  $default,){
final _that = this;
switch (_that) {
case _MessagePage():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MessagePage value)?  $default,){
final _that = this;
switch (_that) {
case _MessagePage() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<Message> messages,  bool hasMore)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MessagePage() when $default != null:
return $default(_that.messages,_that.hasMore);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<Message> messages,  bool hasMore)  $default,) {final _that = this;
switch (_that) {
case _MessagePage():
return $default(_that.messages,_that.hasMore);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<Message> messages,  bool hasMore)?  $default,) {final _that = this;
switch (_that) {
case _MessagePage() when $default != null:
return $default(_that.messages,_that.hasMore);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _MessagePage implements MessagePage {
  const _MessagePage({required final  List<Message> messages, required this.hasMore}): _messages = messages;
  factory _MessagePage.fromJson(Map<String, dynamic> json) => _$MessagePageFromJson(json);

 final  List<Message> _messages;
@override List<Message> get messages {
  if (_messages is EqualUnmodifiableListView) return _messages;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_messages);
}

@override final  bool hasMore;

/// Create a copy of MessagePage
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MessagePageCopyWith<_MessagePage> get copyWith => __$MessagePageCopyWithImpl<_MessagePage>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MessagePageToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _MessagePage&&const DeepCollectionEquality().equals(other._messages, _messages)&&(identical(other.hasMore, hasMore) || other.hasMore == hasMore));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_messages),hasMore);

@override
String toString() {
  return 'MessagePage(messages: $messages, hasMore: $hasMore)';
}


}

/// @nodoc
abstract mixin class _$MessagePageCopyWith<$Res> implements $MessagePageCopyWith<$Res> {
  factory _$MessagePageCopyWith(_MessagePage value, $Res Function(_MessagePage) _then) = __$MessagePageCopyWithImpl;
@override @useResult
$Res call({
 List<Message> messages, bool hasMore
});




}
/// @nodoc
class __$MessagePageCopyWithImpl<$Res>
    implements _$MessagePageCopyWith<$Res> {
  __$MessagePageCopyWithImpl(this._self, this._then);

  final _MessagePage _self;
  final $Res Function(_MessagePage) _then;

/// Create a copy of MessagePage
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? messages = null,Object? hasMore = null,}) {
  return _then(_MessagePage(
messages: null == messages ? _self._messages : messages // ignore: cast_nullable_to_non_nullable
as List<Message>,hasMore: null == hasMore ? _self.hasMore : hasMore // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
