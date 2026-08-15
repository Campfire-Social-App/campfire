import { create } from "zustand";
import { persist } from "zustand/middleware";
import { createSecureStorage } from "./persist";
import { apiFetch } from "@/api/client";
import type { AuthResponse, User } from "@/lib/types";

export type AuthStatus = "idle" | "restoring" | "authenticated" | "unauthenticated";

interface AuthState {
  status: AuthStatus;
  user: User | null;
  accessToken: string | null;
  refreshToken: string | null;
  login: (username: string, password: string) => Promise<void>;
  register: (inviteCode: string, username: string, password: string) => Promise<void>;
  logout: () => void;
  restoreSession: () => Promise<void>;
  setAccessToken: (token: string) => void;
  setUser: (user: User) => void;
}

function applyAuthResponse(
  set: (partial: Partial<AuthState>) => void,
  response: AuthResponse,
): void {
  set({
    status: "authenticated",
    user: response.user,
    accessToken: response.access_token,
    refreshToken: response.refresh_token,
  });
}

export const useAuthStore = create<AuthState>()(
  persist(
    (set, get) => ({
      status: "idle",
      user: null,
      accessToken: null,
      refreshToken: null,

      login: async (username, password) => {
        const response = await apiFetch<AuthResponse>("/api/auth/login", {
          method: "POST",
          anonymous: true,
          body: { username, password },
        });
        applyAuthResponse(set, response);
      },

      register: async (inviteCode, username, password) => {
        const response = await apiFetch<AuthResponse>("/api/auth/register", {
          method: "POST",
          anonymous: true,
          body: { invite_code: inviteCode, username, password },
        });
        applyAuthResponse(set, response);
      },

      logout: () => {
        set({ status: "unauthenticated", user: null, accessToken: null, refreshToken: null });
        void apiFetch("/api/auth/logout", { method: "POST" }).catch(() => {
          // best-effort; tokens are already cleared client-side
        });
      },

      restoreSession: async () => {
        const { refreshToken } = get();
        if (!refreshToken) {
          set({ status: "unauthenticated" });
          return;
        }
        set({ status: "restoring" });
        try {
          const response = await apiFetch<{ access_token: string }>("/api/auth/refresh", {
            method: "POST",
            anonymous: true,
            body: { refresh_token: refreshToken },
          });
          set({ status: "authenticated", accessToken: response.access_token });
        } catch {
          set({ status: "unauthenticated", user: null, accessToken: null, refreshToken: null });
        }
      },

      setAccessToken: (token) => set({ accessToken: token }),
      setUser: (user) => set({ user }),
    }),
    {
      name: "campfire-auth",
      storage: createSecureStorage(),
      partialize: (state) =>
        ({ user: state.user, refreshToken: state.refreshToken }) as AuthState,
    },
  ),
);
