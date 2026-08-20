const VOICE_SOUND_VOLUME = 0.5;

function playSound(url: string): void {
  const audio = new Audio(url);
  audio.volume = VOICE_SOUND_VOLUME;
  // Autoplay can be blocked before the user has interacted with the page — ignore.
  void audio.play().catch(() => {});
}

export function playJoinSound(): void {
  playSound("/sounds/join.mp3");
}

export function playLeaveSound(): void {
  playSound("/sounds/leave.mp3");
}

export function playMicrophoneMuteSound(): void {
  playSound("/sounds/mic_mute.mp3");
}

export function playMicrophoneUnmuteSound(): void {
  playSound("/sounds/mic_unmute.mp3");
}

export function playDeafenSound(): void {
  playSound("/sounds/deafen.mp3");
}

export function playUndeafenSound(): void {
  playSound("/sounds/undeafen.mp3");
}
