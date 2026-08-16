import { useState } from "react";
import { MoreHorizontal, Pencil, Plus, Trash2 } from "lucide-react";
import {
  ContextMenu,
  ContextMenuContent,
  ContextMenuItem,
  ContextMenuSeparator,
  ContextMenuTrigger,
} from "@/components/ui/context-menu";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import { CreateChannelDialog } from "@/components/CreateChannelDialog";
import { EditChannelDialog } from "@/components/EditChannelDialog";
import { DeleteChannelDialog } from "@/components/DeleteChannelDialog";
import { useAuthStore } from "@/state/auth";
import type { Channel } from "@/lib/types";

interface ChannelMenuProps {
  channel: Channel;
  children: React.ReactNode;
}

/** Wraps a channel row with its admin actions: right-click anywhere on the row,
 * or left-click the "…" button that appears on hover. Non-admins get the bare
 * row back — there's nothing on this menu they're allowed to do. */
export function ChannelMenu({ channel, children }: ChannelMenuProps) {
  const isAdmin = useAuthStore((s) => s.user?.is_admin ?? false);
  const [createOpen, setCreateOpen] = useState(false);
  const [editOpen, setEditOpen] = useState(false);
  const [deleteOpen, setDeleteOpen] = useState(false);

  if (!isAdmin) return <>{children}</>;

  // Both menus show the same actions; only the primitives differ.
  const items = (
    Item: typeof ContextMenuItem | typeof DropdownMenuItem,
    Separator: typeof ContextMenuSeparator | typeof DropdownMenuSeparator,
  ) => (
    <>
      <Item onSelect={() => setCreateOpen(true)}>
        <Plus className="size-4" /> Create channel
      </Item>
      <Item onSelect={() => setEditOpen(true)}>
        <Pencil className="size-4" /> Edit channel
      </Item>
      <Separator />
      <Item variant="destructive" onSelect={() => setDeleteOpen(true)}>
        <Trash2 className="size-4" /> Delete channel
      </Item>
    </>
  );

  return (
    <>
      <ContextMenu>
        <ContextMenuTrigger asChild>
          <div className="group/channel relative">
            {children}
            <DropdownMenu>
              <DropdownMenuTrigger asChild>
                <button
                  aria-label={`Channel options for ${channel.name}`}
                  className="absolute top-1/2 right-1 -translate-y-1/2 rounded-md p-0.5 text-muted-foreground opacity-0 hover:text-foreground focus-visible:opacity-100 group-hover/channel:opacity-100 data-open:opacity-100"
                >
                  <MoreHorizontal className="size-4" />
                </button>
              </DropdownMenuTrigger>
              <DropdownMenuContent align="end" className="w-56">
                {items(DropdownMenuItem, DropdownMenuSeparator)}
              </DropdownMenuContent>
            </DropdownMenu>
          </div>
        </ContextMenuTrigger>
        <ContextMenuContent>{items(ContextMenuItem, ContextMenuSeparator)}</ContextMenuContent>
      </ContextMenu>

      <CreateChannelDialog open={createOpen} onOpenChange={setCreateOpen} />
      <EditChannelDialog channel={channel} open={editOpen} onOpenChange={setEditOpen} />
      <DeleteChannelDialog channel={channel} open={deleteOpen} onOpenChange={setDeleteOpen} />
    </>
  );
}
