import { acceptDmCall, endDmCall, startDmCall } from "@/api/endpoints";
import { joinVoiceChannel, leaveVoiceChannel } from "@/livekit/voice";
import { useCallsStore } from "@/state/calls";
import { useVoiceStore } from "@/state/voice";

/** The actions behind a 1:1 call. Two independent things happen on every one of
 * them: the ring is signalled over the gateway (so the other client lights up),
 * and we join or leave the LiveKit room the DM channel stands for. */

export async function startCall(channelId: string, options: { video?: boolean } = {}): Promise<void> {
  const calls = useCallsStore.getState();
  // Ring first: a 409 (they're already calling us) must not leave us sitting in
  // a room we then have to back out of.
  await startDmCall(channelId);
  calls.setOutgoing(channelId);

  try {
    await joinVoiceChannel(channelId, { camera: options.video });
  } catch (err) {
    calls.clearOutgoing(channelId);
    void endDmCall(channelId).catch(() => {});
    throw err;
  }
}

export async function acceptCall(
  channelId: string,
  options: { video?: boolean } = {},
): Promise<void> {
  useCallsStore.getState().clearIncoming(channelId);
  await acceptDmCall(channelId);
  await joinVoiceChannel(channelId, { camera: options.video });
}

export async function declineCall(channelId: string): Promise<void> {
  useCallsStore.getState().clearIncoming(channelId);
  await endDmCall(channelId);
}

/** Leaves the call and stops any ring still going — the one exit for "hang up",
 * whether the call was answered or never got past ringing. */
export async function hangUp(channelId: string): Promise<void> {
  useCallsStore.getState().clearOutgoing(channelId);
  if (useVoiceStore.getState().connectedChannelId === channelId) {
    await leaveVoiceChannel();
  }
  // Harmless once the call was answered — the server has no ring left to end.
  await endDmCall(channelId).catch(() => {});
}
