# NSIS template maintenance

`installer.nsi` is based on the upstream template from Tauri CLI **2.11.4**,
the version in `client/package-lock.json`:
https://github.com/tauri-apps/tauri/blob/tauri-cli-v2.11.4/crates/tauri-bundler/src/bundle/windows/nsis/installer.nsi

Upstream Tauri code is copyright Tauri Programme within The Commons
Conservancy and licensed under Apache-2.0 OR MIT.

When upgrading the CLI, compare/rebase this template against the new upstream
version, including changes to bundled plugins and template variables.

Campfire customizations:

- Capture `HKCU\Software\Microsoft\Windows\CurrentVersion\Run\Campfire`
  in `.onInit`, before a previous uninstaller can remove it.
- Default to enabled only for a new interactive installation. An existing
  uninstall entry or saved install directory identifies a previous installation.
- Add `PageStartup` and `PageLeaveStartup` before file installation.
- Apply registration in `.onInstSuccess`, using the same quoted executable
  command as `src/startup.rs`. Passive, silent and `/UPDATE` installations keep
  the captured choice, including when no registration exists.
- Retain upstream uninstall cleanup: remove the product's Run value only when
  not uninstalling with `/UPDATE`. Interactive upgrades that uninstall first
  restore the captured choice after installation succeeds.

The scope is explicitly `currentUser`. There are no StartupApproved writes,
scheduled tasks, services, or automatic app-start reconciliation.

For a validation installer, run the **Check client** workflow manually with
`build_installer` enabled. It runs the frontend build, native checks and startup
tests, then uploads an unsigned installer with updater signing artifacts disabled.
This override is limited to validation and does not change release configuration.
