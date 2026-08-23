import { useEffect, useMemo, useState } from "react";
import { format } from "date-fns";
import { Ban, Copy, ExternalLink, Gavel, Hash, Link2, Loader2, MessageSquare, MicOff, Shield, UserMinus, Volume2 } from "lucide-react";
import { banUser, getUserModerationOverview, kickUserFromVoice, muteVoiceParticipant, timeoutUser } from "@/api/endpoints";
import { AttachmentList } from "@/components/AttachmentList";
import { UserAvatar } from "@/components/UserAvatar";
import { Button } from "@/components/ui/button";
import { Dialog, DialogContent, DialogHeader, DialogTitle } from "@/components/ui/dialog";
import { Tooltip, TooltipContent, TooltipTrigger } from "@/components/ui/tooltip";
import { ApiError, type ModerationMessage, type User, type UserModerationOverview } from "@/lib/types";
import { cn } from "@/lib/utils";
import { useChannelsStore } from "@/state/channels";
import { useDmsStore } from "@/state/dms";
import { useAuthStore } from "@/state/auth";
import { useUsersStore } from "@/state/users";
import { useVoiceStore } from "@/state/voice";
import { toast } from "sonner";

type Tab = "overview" | "messages" | "media" | "links";
type ConfirmAction = "kick" | "ban" | "timeout";
const URL_PATTERN = /https?:\/\/[^\s<>()]+/gi;

export function UserModerationDialog({
  user,
  open,
  onOpenChange,
}: {
  user: User | null;
  open: boolean;
  onOpenChange: (open: boolean) => void;
}) {
  const [data, setData] = useState<UserModerationOverview | null>(null);
  const [loading, setLoading] = useState(false);
  const [tab, setTab] = useState<Tab>("overview");
  const [action, setAction] = useState<"mute" | null>(null);
  const [confirmAction, setConfirmAction] = useState<ConfirmAction | null>(null);
  const [moderationBusy, setModerationBusy] = useState(false);
  const ownUserId = useAuthStore((state) => state.user?.id);
  const channels = useChannelsStore((state) => state.channels);
  const voiceState = useVoiceStore((state) => state.states.find((item) => item.user_id === user?.id));

  useEffect(() => {
    if (!open || !user) return;
    setLoading(true);
    setData(null);
    setTab("overview");
    void getUserModerationOverview(user.id)
      .then(setData)
      .catch((error) => {
        toast.error(error instanceof ApiError ? error.message : "Couldn't load moderation details.");
        onOpenChange(false);
      })
      .finally(() => setLoading(false));
  }, [open, user, onOpenChange]);

  const messages = data?.messages ?? [];
  const mediaMessages = useMemo(
    () => messages.filter((message) => message.attachments.length > 0),
    [messages],
  );
  const links = useMemo(
    () =>
      messages.flatMap((message) =>
        Array.from(message.content.matchAll(URL_PATTERN), (match) => ({
          url: match[0].replace(/[.,!?;:]$/, ""),
          message,
        })),
      ),
    [messages],
  );

  if (!user) return null;

  const startDm = async () => {
    try {
      await useDmsStore.getState().openWithUser(user.id);
      onOpenChange(false);
    } catch (error) {
      toast.error(error instanceof ApiError ? error.message : "Failed to open the conversation.");
    }
  };

  const mute = async () => {
    setAction("mute");
    try {
      await muteVoiceParticipant(user.id);
      useVoiceStore.getState().setParticipantMuted(user.id, true);
      toast.success(`${user.username}'s microphone was muted.`);
    } catch (error) {
      toast.error(error instanceof ApiError ? error.message : "Couldn't mute the participant.");
    } finally {
      setAction(null);
    }
  };

  const copyId = async () => {
    try {
      await navigator.clipboard.writeText(user.id);
      toast.success("User ID copied.");
    } catch {
      toast.error("Couldn't copy the user ID.");
    }
  };

  const runConfirmedAction = async () => {
    if (!confirmAction) return;
    setModerationBusy(true);
    try {
      if (confirmAction === "kick") {
        await kickUserFromVoice(user.id);
        toast.success(`${user.username} was disconnected from voice.`);
      } else if (confirmAction === "ban") {
        const updated = await banUser(user.id);
        useUsersStore.getState().upsertUser(updated);
        toast.success(`${user.username} was banned.`);
        onOpenChange(false);
      } else {
        const updated = await timeoutUser(user.id);
        useUsersStore.getState().upsertUser(updated);
        setData((current) => current ? { ...current, user: updated } : current);
        toast.success(`${user.username} is in timeout for one hour.`);
      }
      setConfirmAction(null);
    } catch (error) {
      toast.error(error instanceof ApiError ? error.message : "Moderation action failed.");
    } finally {
      setModerationBusy(false);
    }
  };

  const tabs: Array<{ id: Tab; label: string; count?: number }> = [
    { id: "overview", label: "Overview" },
    { id: "messages", label: "Messages", count: messages.length },
    { id: "media", label: "Media", count: mediaMessages.reduce((sum, item) => sum + item.attachments.length, 0) },
    { id: "links", label: "Links", count: links.length },
  ];

  const target = data?.user ?? user;
  const cannotModerate = target.is_admin || target.id === ownUserId;
  const isTimedOut = target.timed_out_until
    ? new Date(target.timed_out_until).getTime() > Date.now()
    : false;
  const confirmation = confirmAction
    ? {
        kick: {
          title: "Expulsar da chamada?",
          description: `${target.username} será desconectado do canal de voz atual.`,
          label: "Expulsar",
        },
        ban: {
          title: "Banir usuário?",
          description: `${target.username} perderá o acesso à plataforma e será desconectado imediatamente.`,
          label: "Banir",
        },
        timeout: {
          title: "Aplicar castigo?",
          description: `${target.username} ficará uma hora sem enviar mensagens ou participar de chamadas.`,
          label: "Aplicar castigo",
        },
      }[confirmAction]
    : null;

  return (
    <>
      <Dialog open={open} onOpenChange={onOpenChange}>
        <DialogContent className="flex h-[min(82vh,760px)] flex-col gap-0 overflow-hidden border-glass-border bg-popover/95 p-0 shadow-2xl backdrop-blur-xl sm:max-w-4xl">
        <DialogHeader className="border-b border-border bg-white/2 px-6 py-5">
          <DialogTitle className="flex items-center gap-3">
            <UserAvatar username={user.username} size="lg" className="size-12 *:text-lg" />
            <span>
              <span className="block font-heading text-lg">{user.username}</span>
              <span className="mt-0.5 flex items-center gap-1 text-xs font-normal text-muted-foreground">
                <Shield className="size-3" /> {user.is_admin ? "Administrator" : "Member"}
              </span>
            </span>
          </DialogTitle>
        </DialogHeader>

        <div className="grid shrink-0 grid-cols-5 gap-2 border-b border-border bg-black/10 px-5 py-4">
          <Tooltip>
            <TooltipTrigger asChild>
              <Button
                size="icon"
                variant="outline"
                aria-label="Mandar mensagem direta"
                className="h-11 w-full border-border bg-muted/20 text-muted-foreground hover:bg-muted/60 hover:text-foreground"
                onClick={() => void startDm()}
              >
                <MessageSquare className="size-5" />
              </Button>
            </TooltipTrigger>
            <TooltipContent>Mandar mensagem direta</TooltipContent>
          </Tooltip>
          <Tooltip>
            <TooltipTrigger asChild>
              <Button
                size="icon"
                variant="outline"
                aria-label="Expulsar"
                className="h-11 w-full border-border bg-muted/20 text-muted-foreground hover:bg-muted/60 hover:text-foreground"
                disabled={!voiceState || cannotModerate}
                onClick={() => setConfirmAction("kick")}
              >
                <UserMinus className="size-5" />
              </Button>
            </TooltipTrigger>
            <TooltipContent>Expulsar</TooltipContent>
          </Tooltip>
          <Tooltip>
            <TooltipTrigger asChild>
              <Button
                size="icon"
                variant="outline"
                aria-label="Banir"
                className="h-11 w-full border-border bg-muted/20 text-muted-foreground hover:bg-muted/60 hover:text-foreground"
                disabled={cannotModerate || !!target.is_banned}
                onClick={() => setConfirmAction("ban")}
              >
                <Ban className="size-5" />
              </Button>
            </TooltipTrigger>
            <TooltipContent>Banir</TooltipContent>
          </Tooltip>
          <Tooltip>
            <TooltipTrigger asChild>
              <Button
                size="icon"
                variant="outline"
                aria-label="Castigo"
                className="h-11 w-full border-border bg-muted/20 text-muted-foreground hover:bg-muted/60 hover:text-foreground"
                disabled={cannotModerate || isTimedOut}
                onClick={() => setConfirmAction("timeout")}
              >
                <Gavel className="size-5" />
              </Button>
            </TooltipTrigger>
            <TooltipContent>Castigo</TooltipContent>
          </Tooltip>
          <Tooltip>
            <TooltipTrigger asChild>
              <Button
                size="icon"
                variant="outline"
                aria-label="Copiar ID"
                className="h-11 w-full border-border bg-muted/20 text-muted-foreground hover:bg-muted/60 hover:text-foreground"
                onClick={() => void copyId()}
              >
                <Copy className="size-5" />
              </Button>
            </TooltipTrigger>
            <TooltipContent>Copiar ID</TooltipContent>
          </Tooltip>
        </div>

        <div className="flex min-h-0 flex-1">
          <aside className="w-44 shrink-0 border-r border-border bg-black/10 p-3">
            <p className="mb-2 px-2 text-[10px] font-semibold tracking-wider text-muted-foreground uppercase">
              Moderator view
            </p>
            <nav className="space-y-1">
              {tabs.map((item) => (
                <button
                  key={item.id}
                  type="button"
                  onClick={() => setTab(item.id)}
                  className={cn(
                    "flex w-full items-center justify-between rounded-lg px-2.5 py-2 text-left text-sm text-muted-foreground transition-colors hover:bg-white/5 hover:text-foreground",
                    tab === item.id && "bg-primary/12 font-medium text-foreground ring-1 ring-primary/20",
                  )}
                >
                  <span>{item.label}</span>
                  {item.count !== undefined && (
                    <span className="rounded-full bg-white/6 px-1.5 py-0.5 text-[10px]">
                      {item.count}
                    </span>
                  )}
                </button>
              ))}
            </nav>
          </aside>

          <div className="min-w-0 flex-1 overflow-y-auto p-5">
          {loading ? (
            <div className="flex h-full items-center justify-center"><Loader2 className="size-6 animate-spin text-muted-foreground" /></div>
          ) : tab === "overview" ? (
            <div className="grid gap-4 lg:grid-cols-2">
              <section className="rounded-xl border border-glass-border bg-glass p-4">
                <h3 className="font-heading text-sm font-semibold">Account</h3>
                <dl className="mt-3 space-y-2 text-sm">
                  <Info label="Role" value={user.is_admin ? "Administrator" : "Member"} />
                  <Info label="Joined" value={format(new Date(user.created_at), "PPp")} />
                  <Info label="Public messages" value={String(messages.length)} />
                  <Info
                    label="Status"
                    value={target.is_banned ? "Banned" : isTimedOut ? "In timeout" : "Active"}
                  />
                </dl>
              </section>

              <section className="rounded-xl border border-glass-border bg-glass p-4">
                <h3 className="font-heading text-sm font-semibold">Voice moderation</h3>
                {voiceState ? (
                  <div className="mt-3 space-y-3">
                    <p className="flex items-center gap-2 text-sm text-muted-foreground">
                      <Volume2 className="size-4" /> In {channels.find((item) => item.id === voiceState.channel_id)?.name ?? "voice"}
                    </p>
                    <Button
                      variant="destructive"
                      className="w-full"
                      disabled={voiceState.muted || action !== null}
                      onClick={() => void mute()}
                    >
                      {action === "mute" ? <Loader2 className="size-4 animate-spin" /> : <MicOff className="size-4" />}
                      {voiceState.muted ? "Microphone already muted" : "Mute microphone"}
                    </Button>
                    <p className="rounded-lg border border-dashed border-border px-3 py-2 text-xs leading-relaxed text-muted-foreground">
                      To move this participant, drag their name from the voice list and drop it on another voice channel.
                    </p>
                  </div>
                ) : (
                  <p className="mt-3 text-sm text-muted-foreground">This user is not in a voice channel.</p>
                )}
              </section>
            </div>
          ) : tab === "messages" ? (
            <MessageHistory messages={messages} onOpenChange={onOpenChange} />
          ) : tab === "media" ? (
            <div className="space-y-4">
              {mediaMessages.map((message) => (
                <section key={message.id} className="rounded-xl border border-glass-border bg-glass p-4">
                  <MessageMeta message={message} onOpenChange={onOpenChange} />
                  <AttachmentList attachments={message.attachments} />
                </section>
              ))}
              {mediaMessages.length === 0 && <Empty label="No media or files from this user." />}
            </div>
          ) : (
            <div className="space-y-2">
              {links.map(({ url, message }, index) => (
                <a key={`${message.id}:${index}`} href={url} target="_blank" rel="noreferrer" className="flex items-center gap-3 rounded-lg border border-glass-border bg-glass p-3 hover:border-ember-tint-border">
                  <Link2 className="size-4 shrink-0 text-primary" />
                  <span className="min-w-0 flex-1 truncate text-sm">{url}</span>
                  <span className="text-xs text-muted-foreground">#{message.channel_name}</span>
                  <ExternalLink className="size-3.5 text-muted-foreground" />
                </a>
              ))}
              {links.length === 0 && <Empty label="No links from this user." />}
            </div>
          )}
          </div>
        </div>
        </DialogContent>
      </Dialog>

      <Dialog
        open={confirmation !== null}
        onOpenChange={(nextOpen) => {
          if (!nextOpen && !moderationBusy) setConfirmAction(null);
        }}
      >
        <DialogContent className="border-glass-border bg-popover/95 shadow-2xl backdrop-blur-xl sm:max-w-md">
          <DialogHeader>
            <DialogTitle>{confirmation?.title}</DialogTitle>
          </DialogHeader>
          <p className="text-sm leading-relaxed text-muted-foreground">
            {confirmation?.description}
          </p>
          <div className="mt-2 flex justify-end gap-2">
            <Button
              variant="outline"
              disabled={moderationBusy}
              onClick={() => setConfirmAction(null)}
            >
              Cancelar
            </Button>
            <Button
              variant={confirmAction === "ban" ? "destructive" : "default"}
              disabled={moderationBusy}
              onClick={() => void runConfirmedAction()}
            >
              {moderationBusy && <Loader2 className="size-4 animate-spin" />}
              {confirmation?.label}
            </Button>
          </div>
        </DialogContent>
      </Dialog>
    </>
  );
}

function Info({ label, value, mono }: { label: string; value: string; mono?: boolean }) {
  return <div className="flex gap-3"><dt className="w-28 shrink-0 text-muted-foreground">{label}</dt><dd className={cn("min-w-0 truncate", mono && "font-mono text-xs")}>{value}</dd></div>;
}

function MessageMeta({ message, onOpenChange }: { message: ModerationMessage; onOpenChange: (open: boolean) => void }) {
  return (
    <div className="mb-2 flex items-center gap-2 text-xs text-muted-foreground">
      <button type="button" onClick={() => { useChannelsStore.getState().selectChannel(message.channel_id); onOpenChange(false); }} className="flex items-center gap-1 font-medium text-primary hover:underline">
        <Hash className="size-3" /> {message.channel_name}
      </button>
      <span>·</span><time>{format(new Date(message.created_at), "PPp")}</time>
    </div>
  );
}

function MessageHistory({ messages, onOpenChange }: { messages: ModerationMessage[]; onOpenChange: (open: boolean) => void }) {
  if (messages.length === 0) return <Empty label="No public messages from this user." />;
  return <div className="space-y-3">{messages.map((message) => <section key={message.id} className="rounded-xl border border-glass-border bg-glass p-4"><MessageMeta message={message} onOpenChange={onOpenChange} />{message.content && <p className="text-sm wrap-break-word whitespace-pre-wrap">{message.content}</p>}{message.attachments.length > 0 && <AttachmentList attachments={message.attachments} />}</section>)}</div>;
}

function Empty({ label }: { label: string }) {
  return <div className="flex min-h-40 items-center justify-center text-sm text-muted-foreground">{label}</div>;
}
