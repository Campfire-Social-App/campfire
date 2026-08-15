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
