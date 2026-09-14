import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";
import vm from "node:vm";
import ts from "typescript";

function load(relative, imports, globals = {}) {
  const source = readFileSync(new URL(relative, import.meta.url), "utf8");
  const { outputText } = ts.transpileModule(source, {
    compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020 },
  });
  const exports = {};
  vm.runInNewContext(outputText, {
    exports,
    require: (name) => {
      assert.ok(name in imports, `Unexpected import: ${name}`);
      return imports[name];
    },
    ...globals,
  });
  return exports;
}

function navigation() {
  const auth = { user: { id: "me" }, status: "authenticated" };
  const settings = { serverUrl: "https://campfire.test" };
  const dms = { conversations: [{ id: "dm" }], activeDmId: "dm", selectDm(id) { this.activeDmId = id; } };
  const channels = { channels: [{ id: "channel" }], selectedChannelId: null, selectChannel(id) { this.selectedChannelId = id; } };
  const imports = Object.fromEntries(Object.entries({
    auth: ["useAuthStore", auth], settings: ["useSettingsStore", settings],
    dms: ["useDmsStore", dms], channels: ["useChannelsStore", channels],
  }).map(([path, [name, state]]) => [`@/state/${path}`, { [name]: { getState: () => state } }]));
  return { ...load("../src/lib/notificationTarget.ts", imports), auth, settings, dms, channels };
}

const flush = () => new Promise((resolve) => setImmediate(resolve));
function notifications({ native = false, permission = "granted", requestPermission, nativeFailure = false } = {}) {
  const nav = navigation();
  const sent = [];
  const warnings = [];
  let listener;
  let listeners = 0;
  let focused = 0;
  class Notification {
    static permission = permission;
    static requestPermission = requestPermission ?? (async () => "granted");
    constructor(title, options) { this.title = title; this.options = options; sent.push(this); }
    close() { this.closed = true; }
  }
  const module = load("../src/lib/notifications.ts", {
    "@tauri-apps/plugin-notification": { isPermissionGranted: async () => true, requestPermission: async () => "granted" },
    "@tauri-apps/api/core": { invoke: async (command, args) => {
      assert.equal(command, "send_chat_notification");
      assert.ok(listener, "activation must be registered before sending");
      if (nativeFailure) throw new Error("OS notification unavailable");
      sent.push(args);
    } },
    "@tauri-apps/api/event": { listen: async (event, callback) => {
      assert.equal(event, "notification-activated"); listeners++; listener = callback;
      return () => {};
    } },
    "@/lib/notificationTarget": nav,
    sonner: { toast: (message) => warnings.push(message) },
  }, { window: { Notification, focus: () => focused++, ...(native ? { __TAURI_INTERNALS__: {} } : {}) }, Notification });
  return { ...module, nav, sent, warnings, clickNative: (payload) => listener({ payload }), listeners: () => listeners, focused: () => focused };
}

test("browser clicks open the originating DM or server channel and focus the window", async () => {
  const h = notifications();
  h.notify("DM", "hello", h.nav.notificationTarget("dm", "dm"));
  h.notify("Channel", "hello", h.nav.notificationTarget("channel", "channel"));
  await flush();
  h.sent[1].onclick();
  assert.equal(h.nav.dms.activeDmId, null);
  assert.equal(h.nav.channels.selectedChannelId, "channel");
  h.sent[0].onclick();
  assert.equal(h.nav.dms.activeDmId, "dm");
  assert.equal(h.focused(), 2);
  assert.ok(h.sent.every((notification) => notification.closed));
});

test("native notifications register one listener and preserve each notification's destination", async () => {
  const h = notifications({ native: true });
  await Promise.all([h.initNotifications(), h.initNotifications()]);
  h.notify("Message", "hello", h.nav.notificationTarget("channel", "channel"));
  h.notify("Incoming call", "ring", h.nav.notificationTarget("dm", "dm"));
  await flush();
  assert.equal(h.listeners(), 1);
  h.clickNative(h.sent[0].target);
  assert.equal(h.nav.dms.activeDmId, null);
  assert.equal(h.nav.channels.selectedChannelId, "channel");
  h.clickNative(h.sent[1].target);
  assert.equal(h.nav.dms.activeDmId, "dm");
});

test("notifications queue behind permission and keep their original server/account", async () => {
  let grant;
  const h = notifications({ permission: "default", requestPermission: () => new Promise((resolve) => { grant = resolve; }) });
  h.notify("Message", "hello", h.nav.notificationTarget("channel", "channel"));
  assert.equal(h.sent.length, 0);
  h.nav.settings.serverUrl = "https://another-server.test";
  grant("granted");
  await flush();
  h.sent[0].onclick();
  assert.equal(h.nav.channels.selectedChannelId, null);
  assert.equal(h.warnings.length, 1);
});

test("deleted destinations and a different or logged-out user do not navigate", () => {
  const h = navigation();
  const target = h.notificationTarget("dm", "dm");
  h.auth.user = { id: "someone-else" };
  assert.equal(h.openNotificationTarget(target), false);
  h.auth.user = { id: "me" };
  h.auth.status = "unauthenticated";
  assert.equal(h.openNotificationTarget(target), false);
  h.auth.status = "authenticated";
  h.dms.conversations = [];
  assert.equal(h.openNotificationTarget(target), false);
  assert.equal(h.openNotificationTarget({ ...target, kind: "channel", channelId: "deleted" }), false);
});

test("denied permission and native send failures are handled without interrupting chat", async () => {
  const denied = notifications({ permission: "denied" });
  denied.notify("Message", "hello", denied.nav.notificationTarget("dm", "dm"));
  const failed = notifications({ native: true, nativeFailure: true });
  failed.notify("Message", "hello", failed.nav.notificationTarget("dm", "dm"));
  await flush();
  assert.equal(denied.sent.length, 0);
  assert.equal(failed.sent.length, 0);
});
