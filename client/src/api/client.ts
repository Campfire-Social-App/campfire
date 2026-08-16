import { useSettingsStore } from "@/state/settings";
import { useAuthStore } from "@/state/auth";
import { ApiError, type AccessTokenResponse } from "@/lib/types";

function getServerUrl(): string {
  const url = useSettingsStore.getState().serverUrl;
  if (!url) throw new ApiError(0, "No server configured");
  return url;
}

let refreshPromise: Promise<string> | null = null;

/** Calls /api/auth/refresh directly — never goes through apiFetch, to avoid recursion. */
async function refreshAccessToken(): Promise<string> {
  const refreshToken = useAuthStore.getState().refreshToken;
  if (!refreshToken) throw new ApiError(401, "No session to refresh");

  const res = await fetch(`${getServerUrl()}/api/auth/refresh`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ refresh_token: refreshToken }),
  });

  if (!res.ok) {
    useAuthStore.getState().logout();
    throw new ApiError(res.status, "Session expired");
  }

  const body = (await res.json()) as AccessTokenResponse;
  useAuthStore.getState().setAccessToken(body.access_token);
  return body.access_token;
}

export interface ApiFetchOptions extends Omit<RequestInit, "body"> {
  body?: unknown;
  /** Skip Bearer injection (login/register/refresh don't have a session yet). */
  anonymous?: boolean;
}

export async function apiFetch<T>(path: string, options: ApiFetchOptions = {}): Promise<T> {
  const { body, anonymous, headers, ...rest } = options;

  const doRequest = async (token: string | null): Promise<Response> => {
    const finalHeaders = new Headers(headers);
    if (body !== undefined) finalHeaders.set("Content-Type", "application/json");
    if (token) finalHeaders.set("Authorization", `Bearer ${token}`);

    return fetch(`${getServerUrl()}${path}`, {
      ...rest,
      headers: finalHeaders,
      body: body !== undefined ? JSON.stringify(body) : undefined,
    });
  };

  let token = anonymous ? null : useAuthStore.getState().accessToken;
  let res = await doRequest(token);

  if (res.status === 401 && !anonymous && useAuthStore.getState().refreshToken) {
    refreshPromise ??= refreshAccessToken().finally(() => {
      refreshPromise = null;
    });
    try {
      token = await refreshPromise;
      res = await doRequest(token);
    } catch {
      // refreshAccessToken already logged the session out.
    }
  }

  if (!res.ok) {
    let detail = res.statusText;
    try {
      const errBody = (await res.json()) as { detail?: string };
      if (errBody.detail) detail = errBody.detail;
    } catch {
      // response had no JSON body
    }
    throw new ApiError(res.status, detail);
  }

  if (res.status === 204) return undefined as T;
  return (await res.json()) as T;
}

/** XHR rather than fetch: it's the only one that reports upload progress, which
 * a 25MB video very much needs. */
export async function apiUpload<T>(
  path: string,
  file: File,
  onProgress?: (fraction: number) => void,
): Promise<T> {
  const token = useAuthStore.getState().accessToken;
  const formData = new FormData();
  formData.append("file", file);

  return new Promise<T>((resolve, reject) => {
    const request = new XMLHttpRequest();
    request.open("POST", `${getServerUrl()}${path}`);
    if (token) request.setRequestHeader("Authorization", `Bearer ${token}`);

    request.upload.onprogress = (event) => {
      if (event.lengthComputable) onProgress?.(event.loaded / event.total);
    };

    request.onload = () => {
      if (request.status >= 200 && request.status < 300) {
        resolve(JSON.parse(request.responseText) as T);
        return;
      }
      let detail = request.statusText;
      try {
        const body = JSON.parse(request.responseText) as { detail?: string };
        if (body.detail) detail = body.detail;
      } catch {
        // response had no JSON body
      }
      reject(new ApiError(request.status, detail));
    };
    request.onerror = () => reject(new ApiError(0, "Upload failed"));
    request.onabort = () => reject(new ApiError(0, "Upload cancelled"));

    request.send(formData);
  });
}

export function resolveAssetUrl(path: string): string {
  if (/^https?:\/\//i.test(path)) return path;
  return `${getServerUrl()}${path}`;
}
