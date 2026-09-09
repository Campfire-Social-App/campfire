import type { CustomDecorationAsset, CustomDecorationAssets, ProfileDecorationId } from "@/lib/types";

export type DecorationAssetFormat = "png" | "webp" | "gif";

export type DecorationRasterAsset =
  | {
      src: string;
      format: DecorationAssetFormat;
      sourceSize: readonly [number, number];
      animated?: false;
    }
  | {
      src: string;
      posterSrc: string;
      format: "gif" | "webp";
      sourceSize: readonly [number, number];
      animated: true;
    };

export type DecorationCardFrameAsset = DecorationRasterAsset & {
  layout: "flush" | "legacy-outset";
  slices: readonly [top: number, right: number, bottom: number, left: number];
};

export interface ProfileDecorationAssets {
  cardFrame?: DecorationCardFrameAsset;
  cardTop?: DecorationRasterAsset;
  avatarFrame?: DecorationRasterAsset;
  identityPlate?: DecorationRasterAsset;
}

export interface ProfileDecorationDefinition {
  id: ProfileDecorationId;
  name: string;
  description: string;
  rarity: "standard" | "rare" | "legendary";
  colors: readonly [string, string, string];
  assets?: ProfileDecorationAssets;
}

export const PROFILE_DECORATIONS: readonly ProfileDecorationDefinition[] = [
  { id: "none", name: "None", description: "Use the clean Campfire profile shell.", rarity: "standard", colors: ["#27272A", "#52525B", "#A1A1AA"] },
  { id: "custom", name: "Custom", description: "Use assets uploaded by you.", rarity: "standard", colors: ["#18181B", "#F97316", "#FDE68A"] },
  {
    id: "spectral_warden",
    name: "Spectral Warden",
    description: "Ancient cyan energy and watchful spectral masks.",
    rarity: "legendary",
    colors: ["#071A22", "#22D3EE", "#A5F3FC"],
    assets: {
      cardFrame: {
        src: "/decorations/spectral-warden-frame-animated.gif",
        posterSrc: "/decorations/spectral-warden-frame-v2.webp",
        format: "gif",
        sourceSize: [512, 768],
        slices: [150, 55, 70, 55],
        layout: "legacy-outset",
        animated: true,
      },
      avatarFrame: {
        src: "/decorations/spectral-warden-avatar.webp",
        format: "webp",
        sourceSize: [512, 512],
      },
      identityPlate: {
        src: "/decorations/spectral-warden-identity-plate.gif?v=5",
        posterSrc: "/decorations/spectral-warden-identity-plate.webp?v=5",
        format: "gif",
        sourceSize: [456, 80],
        animated: true,
      },
    },
  },
  {
    id: "ember_sovereign",
    name: "Ember Sovereign",
    description: "Forged metal, rising sparks and a crown of flame.",
    rarity: "legendary",
    colors: ["#270D04", "#FF6A00", "#FDE68A"],
    assets: {
      cardFrame: {
        src: "/decorations/ember-sovereign-frame-animated.gif",
        posterSrc: "/decorations/ember-sovereign-frame-poster.webp",
        format: "gif",
        sourceSize: [512, 768],
        slices: [150, 55, 70, 55],
        layout: "legacy-outset",
        animated: true,
      },
      avatarFrame: {
        src: "/decorations/ember-sovereign-avatar.webp",
        format: "webp",
        sourceSize: [512, 512],
      },
      identityPlate: {
        src: "/decorations/ember-sovereign-identity-plate.gif?v=2",
        posterSrc: "/decorations/ember-sovereign-identity-plate.webp?v=2",
        format: "gif",
        sourceSize: [456, 80],
        animated: true,
      },
    },
  },
  {
    id: "neon_revenant",
    name: "Neon Revenant",
    description: "A fractured circuit aura from beyond the grid.",
    rarity: "rare",
    colors: ["#120621", "#A855F7", "#22D3EE"],
    assets: {
      cardFrame: {
        src: "/decorations/neon-revenant-frame-animated.gif",
        posterSrc: "/decorations/neon-revenant-frame-poster.webp",
        format: "gif",
        sourceSize: [512, 768],
        slices: [150, 55, 70, 55],
        layout: "legacy-outset",
        animated: true,
      },
      avatarFrame: {
        src: "/decorations/neon-revenant-avatar.webp",
        format: "webp",
        sourceSize: [512, 512],
      },
      identityPlate: {
        src: "/decorations/neon-revenant-identity-plate.gif?v=2",
        posterSrc: "/decorations/neon-revenant-identity-plate.webp?v=2",
        format: "gif",
        sourceSize: [456, 80],
        animated: true,
      },
    },
  },
] as const;

export const getProfileDecoration = (id: ProfileDecorationId) =>
  PROFILE_DECORATIONS.find((decoration) => decoration.id === id) ?? PROFILE_DECORATIONS[0];

const rasterAsset = (asset: CustomDecorationAsset): DecorationRasterAsset => asset.animated && asset.poster_src
  ? {
      src: asset.src,
      posterSrc: asset.poster_src,
      format: "gif",
      sourceSize: asset.source_size,
      animated: true,
    }
  : {
      src: asset.src,
      format: asset.format,
      sourceSize: asset.source_size,
    };

export function getDecorationAssets(
  id: ProfileDecorationId,
  customAssets?: CustomDecorationAssets,
): ProfileDecorationAssets | undefined {
  if (id !== "custom") return getProfileDecoration(id).assets;
  const cardFrame = customAssets?.["card-frame"];
  return {
    cardFrame: cardFrame ? {
      ...rasterAsset(cardFrame),
      layout: "flush",
      slices: [160, 32, 64, 32],
    } : undefined,
    cardTop: customAssets?.["card-top"] ? rasterAsset(customAssets["card-top"]) : undefined,
    avatarFrame: customAssets?.["avatar-frame"] ? rasterAsset(customAssets["avatar-frame"]) : undefined,
    identityPlate: customAssets?.["identity-plate"] ? rasterAsset(customAssets["identity-plate"]) : undefined,
  };
}
