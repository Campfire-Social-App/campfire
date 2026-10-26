# PR: Add Windows login startup preference

## Behavior

Windows users can choose **Start Campfire with Windows** in the NSIS installer
and change it immediately in the Windows section of the existing settings
dialog. The first interactive installation defaults to enabled. Campfire opens
its normal main window when the Windows user signs in; this is login startup,
not execution before login or a background-only mode.

Existing installations without a startup entry stay disabled. Reinstallations
load the registered state, and passive/silent updates preserve it. Before an
interactive upgrade can uninstall the old version, the installer captures the
choice and restores it on successful installation. Definitive uninstall removes
the startup entry; `/UPDATE` uninstall preserves it. Cancelling before file
installation does not apply a new checkbox choice. If an interactive upgrade
has already removed the previous version and is then cancelled, that previous
uninstaller's cleanup remains in effect.

## How the preference is communicated to Windows

Both the installer and native client use this exact per-user registry value:

```text
Key:   HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Run
Name:  Campfire
Type:  REG_SZ
Data:  "C:\Users\<user>\AppData\Local\Campfire\client.exe"
```

The actual executable path is resolved at runtime by the client and from the
selected installation directory by NSIS. The entire path is quoted, including
paths with spaces. Enabling writes the value; disabling removes only this value.
No administrator permission is required. The preference belongs to the Windows
user, not to a Campfire profile or server.

The toggle reads this registration when settings open and the window regains
focus. It waits for native confirmation before changing its displayed state,
blocks concurrent changes, and reports failures. It applies independently of
profile Save/Cancel. No startup boolean is persisted in Zustand, and simply
launching the app never repairs or recreates a registration.

Windows can independently block the entry in **Settings → Apps → Startup**
(also available through Task Manager). The toggle represents Campfire's Run
registration, not a promise that Windows will execute it. The interface explains
this distinction. This implementation never edits `StartupApproved`, overrides
Windows blocks, or schedules an alternative launch mechanism.

References:
- [Microsoft: Run and RunOnce keys](https://learn.microsoft.com/en-us/windows/win32/setupapi/run-and-runonce-registry-keys)
- [Microsoft: Configure startup applications](https://support.microsoft.com/en-us/windows/experience/startup-boot/configure-startup-applications-in-windows)
- [Tauri: NSIS installer customization](https://v2.tauri.app/distribute/windows-installer/)

## Validation performed locally

- Frontend production build (`npm run build`): passed.
- Startup settings tests (`npm run test:startup`): 8 passed.
- NSIS 3.11 syntax compilation: passed with the custom template rendered for
  x64/currentUser, upstream 2.11.4 includes and Tauri utilities plugin 0.5.3.
  This used a placeholder payload, not a built Campfire executable; it validates
  installer syntax only. The unused WebView2 label warning is expected because
  this fixture skips WebView2 installation. It does not replace packaged VM tests.
- Rust/Cargo and the full NSIS build: unavailable locally because Cargo/Rust is
  not installed. The attempted Tauri build stopped at `cargo metadata` with
  `program not found`; it did not produce a packaged Campfire installer.
- Native tests were added to Windows CI. They exercise quoting, missing values,
  enable/disable, external removal and invalid registry value types in an
  isolated disposable key, never the real Run key.
- The manually dispatched Check client workflow can also build and upload an
  unsigned NSIS installer for the VM validation below.

## Required packaged validation before merge

Run on Windows 10 and Windows 11 VMs; record results and attach captures here.
These checks and screenshots have **not** been performed in this environment.

- [ ] First interactive install, checkbox initially on: complete and verify the
  quoted Run value and enabled toggle; log out/in and confirm main window opens.
- [ ] Clean first install, checkbox off: no Run value and disabled toggle.
- [ ] Toggle on/off: verify Registry, close/reopen settings and restart Campfire.
- [ ] Repeat in a directory with spaces and a Unicode Windows username.
- [ ] Upgrade with startup on and off, for interactive, `/P` and `/S` modes;
  include the updater's `/UPDATE` path and an interactive uninstall-first upgrade.
- [ ] Upgrade from an older version without this feature: remain disabled.
- [ ] Passive/silent fresh installation: do not enable startup implicitly.
- [ ] Block startup through Windows Settings: no login launch and no attempt by
  Campfire to clear the block. Remove the Run value externally: toggle refreshes
  on focus and ordinary launches do not recreate it.
- [ ] Cancel the installer before applying changes: no new Run registration.
- [ ] Deny registry mutation in a disposable VM: show error without claiming
  success; verify installer registration errors are also communicated.
- [ ] Definitive uninstall removes the value; `/UPDATE` uninstall preserves it.
- [ ] Attach screenshots of the installer checkbox and settings toggle, both
  enabled and disabled, including the Windows-block explanation.

## Maintenance

The NSIS template is based on locked Tauri CLI 2.11.4 and must be rebased when
that dependency changes. See `client/src-tauri/windows/README.md` for provenance
and the custom sections.
