//! Per-user Windows login registration. Never reconcile/write at app startup:
//! the installer and explicit user actions are the only writers.
#[cfg(windows)]
mod windows {
    use std::{io, path::Path};
    use winreg::{enums::{HKEY_CURRENT_USER, KEY_QUERY_VALUE, KEY_SET_VALUE}, RegKey};

    const RUN_KEY: &str = r"Software\Microsoft\Windows\CurrentVersion\Run";
    const VALUE: &str = "Campfire";

    fn registration_command(executable: &Path) -> Result<String, String> {
        if !executable.is_absolute() {
            return Err("The startup executable path must be absolute".into());
        }
        let path = executable.to_str().ok_or("The executable path is not valid Unicode")?;
        if path.contains('"') {
            return Err("The executable path contains a quote".into());
        }
        Ok(format!("\"{path}\""))
    }

    pub fn get() -> Result<bool, String> {
        get_from(&RegKey::predef(HKEY_CURRENT_USER), RUN_KEY)
    }

    fn get_from(root: &RegKey, subkey: &str) -> Result<bool, String> {
        let key = match root.open_subkey_with_flags(subkey, KEY_QUERY_VALUE) {
            Ok(key) => key,
            Err(error) if error.kind() == io::ErrorKind::NotFound => return Ok(false),
            Err(error) => return Err(error.to_string()),
        };
        match key.get_value::<String, _>(VALUE) {
            Ok(value) => Ok(!value.is_empty()),
            Err(error) if error.kind() == io::ErrorKind::NotFound => Ok(false),
            Err(error) => Err(error.to_string()),
        }
    }

    pub fn set(enabled: bool) -> Result<bool, String> {
        let root = RegKey::predef(HKEY_CURRENT_USER);
        let executable = std::env::current_exe().map_err(|e| e.to_string())?;
        set_in(&root, RUN_KEY, &executable, enabled)
    }

    fn set_in(root: &RegKey, subkey: &str, executable: &Path, enabled: bool) -> Result<bool, String> {
        if enabled {
            let command = registration_command(executable)?;
            let (key, _) = root.create_subkey_with_flags(subkey, KEY_SET_VALUE).map_err(|e| e.to_string())?;
            key.set_value(VALUE, &command).map_err(|e| e.to_string())?;
        } else {
            let key = match root.open_subkey_with_flags(subkey, KEY_SET_VALUE) {
                Ok(key) => key,
                Err(error) if error.kind() == io::ErrorKind::NotFound => return Ok(false),
                Err(error) => return Err(error.to_string()),
            };
            match key.delete_value(VALUE) {
                Ok(()) => {},
                Err(error) if error.kind() == io::ErrorKind::NotFound => {},
                Err(error) => return Err(error.to_string()),
            }
        }
        get_from(root, subkey)
    }

    #[cfg(test)]
    mod tests {
        use super::*;

        #[test]
        fn quotes_absolute_paths_with_spaces_and_unicode() {
            assert_eq!(registration_command(Path::new(r"C:\Users\João Silva\Campfire\client.exe")).unwrap(),
                "\"C:\\Users\\João Silva\\Campfire\\client.exe\"");
        }

        #[test]
        fn rejects_relative_paths_and_quotes() {
            assert!(registration_command(Path::new("client.exe")).is_err());
            assert!(registration_command(Path::new("C:\\bad\"path.exe")).is_err());
        }

        // Exercise real registry operations in a disposable key, never Run.
        #[test]
        fn registration_lifecycle_and_invalid_value_errors() {
            use winreg::enums::KEY_WRITE;
            let root = RegKey::predef(HKEY_CURRENT_USER);
            let path = format!(r"Software\Campfire\StartupTests\{}-{}", std::process::id(),
                std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).unwrap().as_nanos());
            struct Cleanup<'a>(&'a RegKey, &'a str);
            impl Drop for Cleanup<'_> {
                fn drop(&mut self) { let _ = self.0.delete_subkey_all(self.1); }
            }
            let _cleanup = Cleanup(&root, &path);
            let exe = Path::new(r"C:\Program Files\Campfire\client.exe");
            assert!(!get_from(&root, &path).unwrap());
            assert!(!set_in(&root, &path, exe, false).unwrap());
            assert!(set_in(&root, &path, exe, true).unwrap());
            let key = root.open_subkey(&path).unwrap();
            assert_eq!(key.get_value::<String, _>(VALUE).unwrap(), registration_command(exe).unwrap());
            // External removal is reflected on the next read, without repair.
            let writable = root.open_subkey_with_flags(&path, KEY_WRITE).unwrap();
            writable.delete_value(VALUE).unwrap();
            assert!(!get_from(&root, &path).unwrap());
            assert!(set_in(&root, &path, exe, true).unwrap());
            assert!(!set_in(&root, &path, exe, false).unwrap());
            assert!(!set_in(&root, &path, exe, false).unwrap());
            // Unexpected registry types are errors, not a disabled preference.
            writable.set_value(VALUE, &1u32).unwrap();
            assert!(get_from(&root, &path).is_err());
            assert!(!set_in(&root, &path, exe, false).unwrap());
        }
    }
}

#[tauri::command]
pub fn get_startup_enabled() -> Result<bool, String> {
    #[cfg(windows)]
    { windows::get() }
    #[cfg(not(windows))]
    { Err("Startup registration is only available on Windows".into()) }
}

#[tauri::command]
pub fn set_startup_enabled(enabled: bool) -> Result<bool, String> {
    #[cfg(windows)]
    { windows::set(enabled) }
    #[cfg(not(windows))]
    { let _ = enabled; Err("Startup registration is only available on Windows".into()) }
}
