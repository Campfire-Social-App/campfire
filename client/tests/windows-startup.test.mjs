import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";
import vm from "node:vm";
import ts from "typescript";

const flush = () => new Promise((resolve) => setImmediate(resolve));
const deferred = () => {
  let resolve, reject;
  const promise = new Promise((yes, no) => { resolve = yes; reject = no; });
  return { promise, resolve, reject };
};

// Same transpile-and-inject approach as notifications.test.mjs. The small
// hook host lets us drive async native responses without a live Windows app.
function harness({ native = true, windows = true, invoke } = {}) {
  const slots = [];
  let cursor = 0;
  let effects = [];
  const listeners = new Map();
  const errors = [];
  const calls = [];
  const react = {
    useState(initial) {
      const index = cursor++;
      slots[index] ??= { value: initial };
      return [slots[index].value, (value) => { slots[index].value = value; }];
    },
    useRef(initial) {
      const index = cursor++;
      slots[index] ??= { current: initial };
      return slots[index];
    },
    useEffect(callback, dependencies) {
      const index = cursor++;
      const previous = slots[index];
      if (!previous || dependencies.some((value, i) => value !== previous.dependencies[i])) {
        previous?.cleanup?.();
        slots[index] = { dependencies };
        effects.push(() => { slots[index].cleanup = callback(); });
      }
    },
  };
  const imports = {
    react,
    "react/jsx-runtime": { jsx: (type, props) => ({ type, props }), jsxs: (type, props) => ({ type, props }) },
    "@tauri-apps/api/core": { isTauri: () => native, invoke: async (command, args) => {
      calls.push({ command, args });
      return invoke(command, args);
    } },
    sonner: { toast: { error: (message) => errors.push(message) } },
  };
  const { outputText } = ts.transpileModule(readFileSync(new URL("../src/components/WindowsStartupSettings.tsx", import.meta.url), "utf8"), {
    compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020, jsx: ts.JsxEmit.ReactJSX },
  });
  const exports = {};
  vm.runInNewContext(outputText, {
    exports,
    require: (name) => { assert.ok(name in imports); return imports[name]; },
    navigator: { userAgent: windows ? "Windows NT 10.0" : "Linux" },
    window: { addEventListener: (event, listener) => listeners.set(event, listener), removeEventListener: (event) => listeners.delete(event) },
  });
  function render(open = true) {
    cursor = 0;
    const tree = exports.WindowsStartupSettings({ open });
    const queued = effects;
    effects = [];
    queued.forEach((effect) => effect());
    return tree;
  }
  function findSwitch(tree) {
    if (!tree || typeof tree !== "object") return undefined;
    if (tree.props?.role === "switch") return tree;
    const children = tree.props?.children;
    return (Array.isArray(children) ? children : [children]).map(findSwitch).find(Boolean);
  }
  return { render, switch: () => findSwitch(render()), calls, errors, focus: () => listeners.get("focus")?.() };
}

test("startup settings are hidden outside Windows Tauri and never invoke native commands", () => {
  for (const options of [{ native: false }, { windows: false }]) {
    const h = harness(options);
    assert.equal(h.render(), null);
    assert.equal(h.calls.length, 0);
  }
});

test("reads registration on open and focus without ever writing", async () => {
  let enabled = true;
  const h = harness({ invoke: async () => enabled });
  h.render();
  assert.equal(h.switch().props.disabled, true);
  await flush();
  assert.equal(h.switch().props["aria-checked"], true);
  enabled = false;
  await h.focus();
  assert.equal(h.switch().props["aria-checked"], false);
  assert.deepEqual(h.calls.map((call) => call.command), ["get_startup_enabled", "get_startup_enabled"]);
});

test("toggle waits for confirmed state and blocks repeated writes", async () => {
  const write = deferred();
  const h = harness({ invoke: (command) => command === "get_startup_enabled" ? false : write.promise });
  h.render();
  await flush();
  h.switch().props.onClick();
  const busySwitch = h.switch();
  assert.equal(busySwitch.props.disabled, true);
  assert.equal(busySwitch.props["aria-checked"], false);
  busySwitch.props.onClick();
  assert.equal(h.calls.filter((call) => call.command === "set_startup_enabled").length, 1);
  assert.equal(h.calls[1].args.enabled, true);
  write.resolve(true);
  await flush();
  assert.equal(h.switch().props["aria-checked"], true);
  assert.equal(h.switch().props.disabled, false);
});

test("failed write retains confirmed state and reports an error", async () => {
  const h = harness({ invoke: async (command) => {
    if (command === "get_startup_enabled") return true;
    throw new Error("Access denied");
  } });
  h.render();
  await flush();
  h.switch().props.onClick();
  await flush();
  assert.equal(h.calls[1].args.enabled, false);
  assert.equal(h.switch().props["aria-checked"], true);
  assert.equal(h.switch().props.disabled, false);
  assert.equal(h.errors.length, 1);
});

test("disabling removes the request immediately and displays native confirmation", async () => {
  const h = harness({ invoke: async (command, args) => command === "get_startup_enabled" ? true : args.enabled });
  h.render();
  await flush();
  h.switch().props.onClick();
  await flush();
  assert.equal(h.calls[1].args.enabled, false);
  assert.equal(h.switch().props["aria-checked"], false);
  assert.equal(h.switch().props.disabled, false);
  assert.equal(h.errors.length, 0);
});

test("failed read disables the toggle and can recover on focus", async () => {
  let fail = true;
  const h = harness({ invoke: async () => {
    if (fail) throw new Error("Access denied");
    return false;
  } });
  h.render();
  await flush();
  assert.equal(h.switch().props.disabled, true);
  assert.equal(h.errors.length, 1);
  fail = false;
  await h.focus();
  assert.equal(h.switch().props.disabled, false);
});

test("reopening during an old read ignores its stale result", async () => {
  const old = deferred();
  let reads = 0;
  const h = harness({ invoke: () => ++reads === 1 ? old.promise : false });
  h.render();
  await flush();
  h.render(false);
  h.render(true);
  await flush();
  assert.equal(h.switch().props["aria-checked"], false);
  old.resolve(true);
  await flush();
  assert.equal(h.switch().props["aria-checked"], false);
  assert.equal(h.switch().props.disabled, false);
});

test("reopening during a write reads only after that write completes", async () => {
  const write = deferred();
  let enabled = false;
  const h = harness({ invoke: (command) => command === "get_startup_enabled" ? enabled : write.promise });
  h.render();
  await flush();
  h.switch().props.onClick();
  h.render(false);
  h.render(true);
  await flush();
  assert.equal(h.switch().props.disabled, true);
  assert.equal(h.calls.filter((call) => call.command === "get_startup_enabled").length, 1);
  enabled = true;
  write.resolve(true);
  await flush();
  assert.equal(h.switch().props["aria-checked"], true);
  assert.equal(h.switch().props.disabled, false);
});
