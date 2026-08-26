// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'command.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$SlashCommand {

 String get name; String get description;/// Argument hint shown next to the name, e.g. `<url ou busca>`.
 String get usage;/// The bot enforces this; the client only uses it to explain the
/// requirement before spending a round trip.
 bool get requiresVoice;
/// Create a copy of SlashCommand
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SlashCommandCopyWith<SlashCommand> get copyWith => _$SlashCommandCopyWithImpl<SlashCommand>(this as SlashCommand, _$identity);

  /// Serializes this SlashCommand to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SlashCommand&&(identical(other.name, name) || other.name == name)&&(identical(other.description, description) || other.description == description)&&(identical(other.usage, usage) || other.usage == usage)&&(identical(other.requiresVoice, requiresVoice) || other.requiresVoice == requiresVoice));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,name,description,usage,requiresVoice);

@override
String toString() {
  return 'SlashCommand(name: $name, description: $description, usage: $usage, requiresVoice: $requiresVoice)';
}


}

/// @nodoc
abstract mixin class $SlashCommandCopyWith<$Res>  {
  factory $SlashCommandCopyWith(SlashCommand value, $Res Function(SlashCommand) _then) = _$SlashCommandCopyWithImpl;
@useResult
$Res call({
 String name, String description, String usage, bool requiresVoice
});




}
/// @nodoc
class _$SlashCommandCopyWithImpl<$Res>
    implements $SlashCommandCopyWith<$Res> {
  _$SlashCommandCopyWithImpl(this._self, this._then);

  final SlashCommand _self;
  final $Res Function(SlashCommand) _then;

/// Create a copy of SlashCommand
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? name = null,Object? description = null,Object? usage = null,Object? requiresVoice = null,}) {
  return _then(_self.copyWith(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,usage: null == usage ? _self.usage : usage // ignore: cast_nullable_to_non_nullable
as String,requiresVoice: null == requiresVoice ? _self.requiresVoice : requiresVoice // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [SlashCommand].
extension SlashCommandPatterns on SlashCommand {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SlashCommand value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SlashCommand() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SlashCommand value)  $default,){
final _that = this;
switch (_that) {
case _SlashCommand():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SlashCommand value)?  $default,){
final _that = this;
switch (_that) {
case _SlashCommand() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String name,  String description,  String usage,  bool requiresVoice)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SlashCommand() when $default != null:
return $default(_that.name,_that.description,_that.usage,_that.requiresVoice);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String name,  String description,  String usage,  bool requiresVoice)  $default,) {final _that = this;
switch (_that) {
case _SlashCommand():
return $default(_that.name,_that.description,_that.usage,_that.requiresVoice);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String name,  String description,  String usage,  bool requiresVoice)?  $default,) {final _that = this;
switch (_that) {
case _SlashCommand() when $default != null:
return $default(_that.name,_that.description,_that.usage,_that.requiresVoice);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _SlashCommand implements SlashCommand {
  const _SlashCommand({required this.name, required this.description, this.usage = '', this.requiresVoice = false});
  factory _SlashCommand.fromJson(Map<String, dynamic> json) => _$SlashCommandFromJson(json);

@override final  String name;
@override final  String description;
/// Argument hint shown next to the name, e.g. `<url ou busca>`.
@override@JsonKey() final  String usage;
/// The bot enforces this; the client only uses it to explain the
/// requirement before spending a round trip.
@override@JsonKey() final  bool requiresVoice;

/// Create a copy of SlashCommand
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SlashCommandCopyWith<_SlashCommand> get copyWith => __$SlashCommandCopyWithImpl<_SlashCommand>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SlashCommandToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SlashCommand&&(identical(other.name, name) || other.name == name)&&(identical(other.description, description) || other.description == description)&&(identical(other.usage, usage) || other.usage == usage)&&(identical(other.requiresVoice, requiresVoice) || other.requiresVoice == requiresVoice));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,name,description,usage,requiresVoice);

@override
String toString() {
  return 'SlashCommand(name: $name, description: $description, usage: $usage, requiresVoice: $requiresVoice)';
}


}

/// @nodoc
abstract mixin class _$SlashCommandCopyWith<$Res> implements $SlashCommandCopyWith<$Res> {
  factory _$SlashCommandCopyWith(_SlashCommand value, $Res Function(_SlashCommand) _then) = __$SlashCommandCopyWithImpl;
@override @useResult
$Res call({
 String name, String description, String usage, bool requiresVoice
});




}
/// @nodoc
class __$SlashCommandCopyWithImpl<$Res>
    implements _$SlashCommandCopyWith<$Res> {
  __$SlashCommandCopyWithImpl(this._self, this._then);

  final _SlashCommand _self;
  final $Res Function(_SlashCommand) _then;

/// Create a copy of SlashCommand
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? name = null,Object? description = null,Object? usage = null,Object? requiresVoice = null,}) {
  return _then(_SlashCommand(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,usage: null == usage ? _self.usage : usage // ignore: cast_nullable_to_non_nullable
as String,requiresVoice: null == requiresVoice ? _self.requiresVoice : requiresVoice // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
