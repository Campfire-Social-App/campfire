export const THEMES = [
  { id: "ember", name: "Campfire Ember", colors: ["#070A12", "#0C101A", "#FF6A00"] },
  { id: "oled", name: "Campfire OLED", colors: ["#000000", "#070707", "#FF6500"] },
  { id: "frost", name: "Campfire Frost", colors: ["#080D16", "#101B2B", "#38BDF8"] },
  { id: "neon", name: "Campfire Neon", colors: ["#080810", "#171126", "#A855F7"] },
  { id: "forest", name: "Campfire Forest", colors: ["#08110D", "#102019", "#22C55E"] },
  { id: "crimson", name: "Campfire Crimson", colors: ["#100809", "#211012", "#EF4444"] },
] as const;

export type ThemeId = (typeof THEMES)[number]["id"];
