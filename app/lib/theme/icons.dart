import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Every icon the React client draws, named by the job it does rather than by
/// its glyph. Both clients pull from Lucide, so this is a straight rename — but
/// going through one table means a future icon swap happens in one place, and
/// `campfire_icons_test.dart` can assert nothing in the set went missing.
abstract final class CampfireIcons {
  // Identity and navigation
  static const IconData brand = LucideIcons.flame;
  static const IconData textChannel = LucideIcons.hash;
  static const IconData voiceChannel = LucideIcons.volume2;
  static const IconData mention = LucideIcons.atSign;
  static const IconData search = LucideIcons.search;
  static const IconData settings = LucideIcons.settings;
  static const IconData signIn = LucideIcons.logIn;
  static const IconData invite = LucideIcons.userPlus;
  static const IconData connection = LucideIcons.wifi;

  // Composer and message actions
  static const IconData send = LucideIcons.send;
  static const IconData attach = LucideIcons.paperclip;
  static const IconData reply = LucideIcons.reply;
  static const IconData quoted = LucideIcons.cornerUpLeft;
  static const IconData edit = LucideIcons.pencil;
  static const IconData delete = LucideIcons.trash2;
  static const IconData copy = LucideIcons.copy;
  static const IconData download = LucideIcons.download;
  static const IconData more = LucideIcons.moreHorizontal;
  static const IconData add = LucideIcons.plus;
  static const IconData remove = LucideIcons.minus;
  static const IconData close = LucideIcons.x;
  static const IconData confirm = LucideIcons.check;

  // File kinds, for the attachment cards
  static const IconData file = LucideIcons.file;
  static const IconData fileText = LucideIcons.fileText;
  static const IconData fileAudio = LucideIcons.fileAudio;
  static const IconData fileVideo = LucideIcons.fileVideo;
  static const IconData fileArchive = LucideIcons.fileArchive;

  // Voice and calls
  static const IconData micOn = LucideIcons.mic;
  static const IconData micOff = LucideIcons.micOff;
  static const IconData deafenOff = LucideIcons.headphones;
  static const IconData cameraOn = LucideIcons.video;
  static const IconData cameraOff = LucideIcons.videoOff;
  static const IconData screenShareOn = LucideIcons.screenShare;
  static const IconData screenShareOff = LucideIcons.screenShareOff;
  static const IconData callAnswer = LucideIcons.phone;
  static const IconData callEnd = LucideIcons.phoneOff;
  static const IconData screen = LucideIcons.monitor;
  static const IconData screenPlaying = LucideIcons.monitorPlay;
  static const IconData window = LucideIcons.appWindow;

  // Media player
  static const IconData play = LucideIcons.play;
  static const IconData pause = LucideIcons.pause;
  static const IconData stop = LucideIcons.square;
  static const IconData loop = LucideIcons.repeat;
  static const IconData volumeLow = LucideIcons.volume1;
  static const IconData volumeHigh = LucideIcons.volume2;
  static const IconData volumeMuted = LucideIcons.volumeX;
  static const IconData enterFullscreen = LucideIcons.maximize;
  static const IconData exitFullscreen = LucideIcons.minimize;
  static const IconData expand = LucideIcons.maximize2;
  static const IconData pictureInPicture = LucideIcons.pictureInPicture2;

  // Status and feedback
  static const IconData spinner = LucideIcons.loader2;
  static const IconData retry = LucideIcons.refreshCw;
  static const IconData info = LucideIcons.info;
  static const IconData success = LucideIcons.circleCheck;
  static const IconData warning = LucideIcons.triangleAlert;
  static const IconData error = LucideIcons.octagonX;

  // Disclosure
  static const IconData chevronDown = LucideIcons.chevronDown;
  static const IconData chevronLeft = LucideIcons.chevronLeft;
  static const IconData chevronRight = LucideIcons.chevronRight;

  /// Used by the test that guards against a Lucide upgrade silently dropping
  /// one of these code points.
  static const List<IconData> all = [
    brand, textChannel, voiceChannel, mention, search, settings, signIn, invite,
    connection, send, attach, reply, quoted, edit, delete, copy, download, more,
    add, remove, close, confirm, file, fileText, fileAudio, fileVideo,
    fileArchive, micOn, micOff, deafenOff, cameraOn, cameraOff, screenShareOn,
    screenShareOff, callAnswer, callEnd, screen, screenPlaying, window, play,
    pause, stop, loop, volumeLow, volumeHigh, volumeMuted, enterFullscreen,
    exitFullscreen, expand, pictureInPicture, spinner, retry, info, success,
    warning, error, chevronDown, chevronLeft, chevronRight,
  ];
}
