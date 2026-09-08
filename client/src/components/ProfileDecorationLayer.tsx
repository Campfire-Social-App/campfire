import type { CSSProperties, ReactNode } from "react";
import { resolveAssetUrl } from "@/api/client";
import { getDecorationAssets, type DecorationCardFrameAsset, type DecorationRasterAsset } from "@/lib/profileDecorations";
import type { CustomDecorationAssets, ProfileDecorationId } from "@/lib/types";

/** Overlay-only form used by the canonical profile popout. It deliberately
 * adds no layout wrapper so the original card geometry remains untouched. */
export function ProfileDecorationOrnaments({ decoration, customAssets }: { decoration: ProfileDecorationId; customAssets?: CustomDecorationAssets }) {
  if (decoration === "none") return null;
  const assets = getDecorationAssets(decoration, customAssets);
  const frame = assets?.cardFrame;
  return <>
    <div className="profile-decoration-glow" aria-hidden="true" />
    <CardFrameOrnament frame={frame} decoration={decoration} />
    {assets?.cardTop && <DecorationAsset asset={assets.cardTop} className="profile-decoration-top-art" />}
  </>;
}

function CardFrameOrnament({ frame, decoration }: { frame?: DecorationCardFrameAsset; decoration: Exclude<ProfileDecorationId, "none"> }) {
  const ornament = (src?: string, className = "") => <div
    className={`profile-decoration-ornament ${className}`}
    data-card-frame={frame?.layout}
    style={frame && src ? {
      borderImageSource: `url("${src}")`,
      borderImageSlice: frame.slices.join(" "),
    } as CSSProperties : undefined}
    aria-hidden="true"
  >
    {!frame && <DecorationOrnament decoration={decoration} />}
  </div>;
  if (!frame?.animated) return ornament(frame?.src);
  return <>
    {ornament(frame.src, "decoration-motion-asset")}
    {ornament(frame.posterSrc, "decoration-motion-poster")}
  </>;
}

export function DecoratedAvatar({ decoration, customAssets, children }: { decoration: ProfileDecorationId; customAssets?: CustomDecorationAssets; children: ReactNode }) {
  if (decoration === "none") return children;
  const asset = getDecorationAssets(decoration, customAssets)?.avatarFrame;
  return <div className="decorated-avatar" data-profile-decoration={decoration}>
    {children}
    {asset ? (
      <DecorationAsset asset={asset} className="decorated-avatar-art" />
    ) : (
      <div className="decorated-avatar-overlay" aria-hidden="true" />
    )}
  </div>;
}

export function DecoratedIdentityPlate({ decoration, customAssets, children }: { decoration: ProfileDecorationId; customAssets?: CustomDecorationAssets; children: ReactNode }) {
  const asset = getDecorationAssets(decoration, customAssets)?.identityPlate;
  return <span className="member-identity-plate" data-profile-decoration={decoration}>
    {asset && <DecorationAsset asset={asset} className="member-identity-plate-art" />}
    <span className="member-identity-plate-content">{children}</span>
  </span>;
}

function DecorationAsset({ asset, className }: { asset: DecorationRasterAsset; className: string }) {
  const url = (src: string) => src.startsWith("/api/") ? resolveAssetUrl(src) : src;
  if (!asset.animated) return <img src={url(asset.src)} alt="" aria-hidden="true" className={className} />;
  return <>
    <img src={url(asset.src)} alt="" aria-hidden="true" className={`${className} decoration-motion-asset`} />
    <img src={url(asset.posterSrc)} alt="" aria-hidden="true" className={`${className} decoration-motion-poster`} />
  </>;
}

function DecorationOrnament({ decoration }: { decoration: Exclude<ProfileDecorationId, "none"> }) {
  if (decoration === "spectral_warden") return null;
  if (decoration === "ember_sovereign") return <svg viewBox="0 0 360 76" role="presentation"><path d="M18 61c38-7 49-33 85-27l19-20 20 19 38-25 38 25 20-19 19 20c36-6 47 20 85 27" /><path d="M157 28l23-17 23 17-8 20h-30z" /></svg>;
  return <svg viewBox="0 0 360 76" role="presentation"><path d="M8 60h42l13-18h38l18-25h35l12 15h28l12-15h35l18 25h38l13 18h42" /><path d="M38 50v-18h24M322 50v-18h-24M151 17l29 18 29-18" /></svg>;
}
