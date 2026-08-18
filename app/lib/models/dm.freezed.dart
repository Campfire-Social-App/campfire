// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'dm.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$DMConversation {

 String get id; User get recipient; DateTime? get lastMessageAt; int get unreadCount;
/// Create a copy of DMConversation
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DMConversationCopyWith<DMConversation> get copyWith => _$DMConversationCopyWithImpl<DMConversation>(this as DMConversation, _$identity);

  /// Serializes this DMConversation to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DMConversation&&(identical(other.id, id) || other.id == id)&&(identical(other.recipient, recipient) || other.recipient == recipient)&&(identical(other.lastMessageAt, lastMessageAt) || other.lastMessageAt == lastMessageAt)&&(identical(other.unreadCount, unreadCount) || other.unreadCount == unreadCount));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,recipient,lastMessageAt,unreadCount);

@override
String toString() {
  return 'DMConversation(id: $id, recipient: $recipient, lastMessageAt: $lastMessageAt, unreadCount: $unreadCount)';
}


}

/// @nodoc
abstract mixin class $DMConversationCopyWith<$Res>  {
  factory $DMConversationCopyWith(DMConversation value, $Res Function(DMConversation) _then) = _$DMConversationCopyWithImpl;
@useResult
$Res call({
 String id, User recipient, DateTime? lastMessageAt, int unreadCount
});


$UserCopyWith<$Res> get recipient;

}
/// @nodoc
class _$DMConversationCopyWithImpl<$Res>
    implements $DMConversationCopyWith<$Res> {
  _$DMConversationCopyWithImpl(this._self, this._then);

  final DMConversation _self;
  final $Res Function(DMConversation) _then;

/// Create a copy of DMConversation
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? recipient = null,Object? lastMessageAt = freezed,Object? unreadCount = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,recipient: null == recipient ? _self.recipient : recipient // ignore: cast_nullable_to_non_nullable
as User,lastMessageAt: freezed == lastMessageAt ? _self.lastMessageAt : lastMessageAt // ignore: cast_nullable_to_non_nullable
as DateTime?,unreadCount: null == unreadCount ? _self.unreadCount : unreadCount // ignore: cast_nullable_to_non_nullable
as int,
  ));
}
/// Create a copy of DMConversation
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$UserCopyWith<$Res> get recipient {
  
  return $UserCopyWith<$Res>(_self.recipient, (value) {
    return _then(_self.copyWith(recipient: value));
  });
}
}


/// Adds pattern-matching-related methods to [DMConversation].
extension DMConversationPatterns on DMConversation {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _DMConversation value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _DMConversation() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _DMConversation value)  $default,){
final _that = this;
switch (_that) {
case _DMConversation():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _DMConversation value)?  $default,){
final _that = this;
switch (_that) {
case _DMConversation() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  User recipient,  DateTime? lastMessageAt,  int unreadCount)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _DMConversation() when $default != null:
return $default(_that.id,_that.recipient,_that.lastMessageAt,_that.unreadCount);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  User recipient,  DateTime? lastMessageAt,  int unreadCount)  $default,) {final _that = this;
switch (_that) {
case _DMConversation():
return $default(_that.id,_that.recipient,_that.lastMessageAt,_that.unreadCount);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  User recipient,  DateTime? lastMessageAt,  int unreadCount)?  $default,) {final _that = this;
switch (_that) {
case _DMConversation() when $default != null:
return $default(_that.id,_that.recipient,_that.lastMessageAt,_that.unreadCount);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _DMConversation implements DMConversation {
  const _DMConversation({required this.id, required this.recipient, required this.lastMessageAt, this.unreadCount = 0});
  factory _DMConversation.fromJson(Map<String, dynamic> json) => _$DMConversationFromJson(json);

@override final  String id;
@override final  User recipient;
@override final  DateTime? lastMessageAt;
@override@JsonKey() final  int unreadCount;

/// Create a copy of DMConversation
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DMConversationCopyWith<_DMConversation> get copyWith => __$DMConversationCopyWithImpl<_DMConversation>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$DMConversationToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _DMConversation&&(identical(other.id, id) || other.id == id)&&(identical(other.recipient, recipient) || other.recipient == recipient)&&(identical(other.lastMessageAt, lastMessageAt) || other.lastMessageAt == lastMessageAt)&&(identical(other.unreadCount, unreadCount) || other.unreadCount == unreadCount));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,recipient,lastMessageAt,unreadCount);

@override
String toString() {
  return 'DMConversation(id: $id, recipient: $recipient, lastMessageAt: $lastMessageAt, unreadCount: $unreadCount)';
}


}

/// @nodoc
abstract mixin class _$DMConversationCopyWith<$Res> implements $DMConversationCopyWith<$Res> {
  factory _$DMConversationCopyWith(_DMConversation value, $Res Function(_DMConversation) _then) = __$DMConversationCopyWithImpl;
@override @useResult
$Res call({
 String id, User recipient, DateTime? lastMessageAt, int unreadCount
});


@override $UserCopyWith<$Res> get recipient;

}
/// @nodoc
class __$DMConversationCopyWithImpl<$Res>
    implements _$DMConversationCopyWith<$Res> {
  __$DMConversationCopyWithImpl(this._self, this._then);

  final _DMConversation _self;
  final $Res Function(_DMConversation) _then;

/// Create a copy of DMConversation
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? recipient = null,Object? lastMessageAt = freezed,Object? unreadCount = null,}) {
  return _then(_DMConversation(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,recipient: null == recipient ? _self.recipient : recipient // ignore: cast_nullable_to_non_nullable
as User,lastMessageAt: freezed == lastMessageAt ? _self.lastMessageAt : lastMessageAt // ignore: cast_nullable_to_non_nullable
as DateTime?,unreadCount: null == unreadCount ? _self.unreadCount : unreadCount // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

/// Create a copy of DMConversation
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$UserCopyWith<$Res> get recipient {
  
  return $UserCopyWith<$Res>(_self.recipient, (value) {
    return _then(_self.copyWith(recipient: value));
  });
}
}

// dart format on
