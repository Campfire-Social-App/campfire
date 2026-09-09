/** A missing peer can be reconnecting, not hanging up. Also, LiveKit emits
 * ParticipantDisconnected before changing the room state on a full restart. */
export function emptyCallGrace(shouldLeave: () => boolean, leave: () => void) {
  let timer: ReturnType<typeof setTimeout> | undefined;
  const cancel = () => {
    clearTimeout(timer);
    timer = undefined;
  };
  return {
    cancel,
    schedule() {
      cancel();
      timer = setTimeout(() => {
        timer = undefined;
        if (shouldLeave()) leave();
      }, 30_000);
    },
  };
}
