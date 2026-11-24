use std::env;
use std::fmt;
use std::fs::File;
use std::io::{self, ErrorKind, Read as _, Write as _};
use std::path::{Path, PathBuf};

use aes_gcm::aead::{Aead, KeyInit};
use aes_gcm::{Aes256Gcm, Nonce};
use base64::Engine as _;
use base64::engine::general_purpose::{STANDARD, URL_SAFE_NO_PAD};
use zeroize::Zeroizing;

use crate::rt::BoxFuture;

use super::{SecretStore, StoreError, validate_key, validate_namespace};

#[cfg(unix)]
mod unix;
#[cfg(windows)]
mod windows;
#[cfg(unix)]
use unix::Directory;
#[cfg(windows)]
use windows::Directory;

const KEY_CHECK_FILENAME: &str = ".petrel-key-check";
const KEY_CHECK_PLAINTEXT: &[u8] = b"petrel.encrypted-files.key-check.v1";

/// An encrypted, file-backed secret store for native targets.
///
/// The container matches the Swift AES-256-GCM file format. Unix operations
/// use a held directory descriptor and require the owner to be the current
/// user, with group and other access disabled. Windows inherits ACLs from
/// the chosen private directory and rejects reparse points. Keep the
/// directory private on Windows, where file data is flushed before an
/// atomic rename but directory metadata cannot be explicitly flushed.
///
/// Operations use blocking filesystem I/O. Rust instances serialize
/// mutations with an advisory lock. Coordinate independently running Swift
/// and Rust writers externally when using a directory from both runtimes.
pub struct FileSecretStore {
    directory: Directory,
    key: Zeroizing<[u8; 32]>,
}

impl fmt::Debug for FileSecretStore {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.debug_struct("FileSecretStore").finish_non_exhaustive()
    }
}

impl FileSecretStore {
    /// Opens or creates a directory with an embedder-supplied AES-256 key.
    pub fn open(directory: impl AsRef<Path>, key: &[u8; 32]) -> Result<Self, StoreError> {
        let store = Self {
            directory: Directory::open(directory.as_ref()).map_err(io_error)?,
            key: Zeroizing::new(*key),
        };
        // Windows requires a regular file for locking. Reject an existing
        // different key before creating that file, then recheck under the lock.
        #[cfg(windows)]
        store.validate_contents()?;
        {
            let _lock = store.directory.lock().map_err(io_error)?;
            if !store.validate_contents()? {
                store.establish_key_check()?;
            }
            store.clear_interrupted_files()?;
        }
        Ok(store)
    }

    /// Opens the directory configured by `PETREL_SECRETS_DIR` or
    /// `~/.petrel-secrets` using a Base64-encoded `PETREL_MASTER_KEY`.
    pub fn from_env() -> Result<Self, StoreError> {
        let key = Zeroizing::new(
            env::var("PETREL_MASTER_KEY")
                .map_err(|_| StoreError::Other("missing file store master key".into()))?,
        );
        let bytes = Zeroizing::new(
            STANDARD
                .decode(key.as_bytes())
                .map_err(|_| StoreError::Other("invalid file store master key".into()))?,
        );
        let key = <&[u8; 32]>::try_from(bytes.as_slice())
            .map_err(|_| StoreError::Other("file store master key must be 32 bytes".into()))?;
        let directory = match env::var_os("PETREL_SECRETS_DIR").filter(|path| !path.is_empty()) {
            Some(path) => PathBuf::from(path),
            None => env::home_dir()
                .ok_or_else(|| StoreError::Other("missing file store home directory".into()))?
                .join(".petrel-secrets"),
        };
        Self::open(directory, key)
    }

    fn validate_contents(&self) -> Result<bool, StoreError> {
        let marker = self.read_encrypted(KEY_CHECK_FILENAME)?;
        if let Some(ref marker) = marker {
            self.verify_key_check(marker)?;
        }
        for name in self.directory.names().map_err(io_error)? {
            if namespaced_key(&name).is_some()
                && let Some(ciphertext) = self.read_encrypted(&name)?
            {
                self.decrypt(&ciphertext).map_err(|error| {
                    if marker.is_some() {
                        error
                    } else {
                        StoreError::KeyMismatch
                    }
                })?;
            }
        }
        Ok(marker.is_some())
    }

    fn verify_key_check(&self, combined: &[u8]) -> Result<(), StoreError> {
        let plaintext = self
            .decrypt(combined)
            .map_err(|_| StoreError::KeyMismatch)?;
        if plaintext.as_slice() != KEY_CHECK_PLAINTEXT {
            return Err(StoreError::KeyMismatch);
        }
        Ok(())
    }

    fn establish_key_check(&self) -> Result<(), StoreError> {
        let combined = self.encrypt(KEY_CHECK_PLAINTEXT)?;
        let linked = self.publish(&combined, |staged| {
            match self.directory.link(staged, KEY_CHECK_FILENAME) {
                Ok(()) => Ok(true),
                Err(error) if error.kind() == ErrorKind::AlreadyExists => Ok(false),
                Err(error) => Err(error),
            }
        })?;
        // A Swift writer can publish the marker without taking the Rust lock.
        if !linked {
            let marker = self
                .read_encrypted(KEY_CHECK_FILENAME)?
                .ok_or_else(|| StoreError::Unavailable("key check disappeared".into()))?;
            self.verify_key_check(&marker)?;
        }
        Ok(())
    }

    fn clear_interrupted_files(&self) -> Result<(), StoreError> {
        for name in self.directory.names().map_err(io_error)? {
            let id = name
                .strip_prefix(".petrel-temp.")
                .or_else(|| name.strip_prefix(".petrel-claim."));
            if id.is_some_and(|id| id.len() == 32 && id.bytes().all(|c| c.is_ascii_hexdigit())) {
                self.remove_file(&name)?;
            }
        }
        Ok(())
    }

    fn read_encrypted(&self, name: &str) -> Result<Option<Vec<u8>>, StoreError> {
        self.directory
            .read_file(name)
            .map_err(io_error)?
            .map(read_encrypted_file)
            .transpose()
            .map_err(io_error)
    }

    fn encrypt(&self, plaintext: &[u8]) -> Result<Vec<u8>, StoreError> {
        let mut nonce = [0; 12];
        getrandom::getrandom(&mut nonce)
            .map_err(|_| StoreError::Unavailable("randomness".into()))?;
        let mut combined = nonce.to_vec();
        combined.extend(
            self.cipher()?
                .encrypt(&Nonce::from(nonce), plaintext)
                .map_err(|_| StoreError::Other("file encryption failed".into()))?,
        );
        Ok(combined)
    }

    fn decrypt(&self, combined: &[u8]) -> Result<Zeroizing<Vec<u8>>, StoreError> {
        let (nonce, encrypted) = combined
            .split_first_chunk::<12>()
            .ok_or_else(corrupt_file)?;
        self.cipher()?
            .decrypt(&Nonce::from(*nonce), encrypted)
            .map(Zeroizing::new)
            .map_err(|_| corrupt_file())
    }

    fn cipher(&self) -> Result<Aes256Gcm, StoreError> {
        Aes256Gcm::new_from_slice(self.key.as_ref())
            .map_err(|_| StoreError::Other("invalid master key size".into()))
    }

    fn publish<T>(
        &self,
        bytes: &[u8],
        publish: impl FnOnce(&str) -> io::Result<T>,
    ) -> Result<T, StoreError> {
        let name = unique_name("temp")?;
        let mut file = self.directory.create_file(&name).map_err(io_error)?;
        let result = (|| {
            file.write_all(bytes)?;
            file.sync_all()?;
            drop(file);
            publish(&name)
        })();
        let cleanup = self.directory.remove(&name);
        let result = result.map_err(io_error)?;
        cleanup.map_err(io_error)?;
        self.directory.sync().map_err(io_error)?;
        Ok(result)
    }

    fn replace(&self, name: &str, plaintext: &[u8]) -> Result<(), StoreError> {
        let _existing = self.directory.read_file(name).map_err(io_error)?;
        let combined = self.encrypt(plaintext)?;
        self.publish(&combined, |source| self.directory.rename(source, name))
    }

    fn remove_file(&self, name: &str) -> Result<(), StoreError> {
        if self.directory.read_file(name).map_err(io_error)?.is_some()
            && self.directory.remove(name).map_err(io_error)?
        {
            self.directory.sync().map_err(io_error)?;
        }
        Ok(())
    }

    fn with_entry<T>(
        &self,
        namespace: &str,
        key: &str,
        operation: impl FnOnce(&str) -> Result<T, StoreError>,
    ) -> Result<T, StoreError> {
        validate_namespace(namespace)?;
        validate_key(key)?;
        let name = URL_SAFE_NO_PAD.encode(format!("{namespace}.{key}"));
        let _lock = self.directory.lock().map_err(io_error)?;
        operation(&name)
    }
}

impl SecretStore for FileSecretStore {
    fn get<'a>(
        &'a self,
        namespace: &'a str,
        key: &'a str,
    ) -> BoxFuture<'a, Result<Option<Vec<u8>>, StoreError>> {
        Box::pin(async move {
            self.with_entry(namespace, key, |name| {
                self.read_encrypted(name)?
                    .map(|ciphertext| self.decrypt(&ciphertext).map(|value| value.to_vec()))
                    .transpose()
            })
        })
    }

    fn put<'a>(
        &'a self,
        namespace: &'a str,
        key: &'a str,
        value: &'a [u8],
    ) -> BoxFuture<'a, Result<(), StoreError>> {
        Box::pin(async move { self.with_entry(namespace, key, |name| self.replace(name, value)) })
    }

    fn delete<'a>(
        &'a self,
        namespace: &'a str,
        key: &'a str,
    ) -> BoxFuture<'a, Result<(), StoreError>> {
        Box::pin(async move { self.with_entry(namespace, key, |name| self.remove_file(name)) })
    }

    fn take<'a>(
        &'a self,
        namespace: &'a str,
        key: &'a str,
    ) -> BoxFuture<'a, Result<Option<Vec<u8>>, StoreError>> {
        Box::pin(async move {
            self.with_entry(namespace, key, |name| {
                let Some(file) = self.directory.read_file(name).map_err(io_error)? else {
                    return Ok(None);
                };
                let claimed = unique_name("claim")?;
                self.directory.rename(name, &claimed).map_err(io_error)?;
                self.directory.sync().map_err(io_error)?;
                let result = read_encrypted_file(file)
                    .map_err(io_error)
                    .and_then(|ciphertext| self.decrypt(&ciphertext));
                let cleanup = self.remove_file(&claimed);
                let plaintext = result?;
                cleanup?;
                Ok(Some(plaintext.to_vec()))
            })
        })
    }

    fn delete_namespace<'a>(&'a self, namespace: &'a str) -> BoxFuture<'a, Result<(), StoreError>> {
        Box::pin(async move {
            validate_namespace(namespace)?;
            let _lock = self.directory.lock().map_err(io_error)?;
            let mut first_error = None;
            for name in self.directory.names().map_err(io_error)? {
                if namespaced_key(&name)
                    .is_some_and(|key| key.split_once('.').is_some_and(|(ns, _)| ns == namespace))
                    && let Err(error) = self.remove_file(&name)
                {
                    first_error.get_or_insert(error);
                }
            }
            first_error.map_or(Ok(()), Err)
        })
    }

    fn compare_and_swap<'a>(
        &'a self,
        namespace: &'a str,
        key: &'a str,
        expected: Option<&'a [u8]>,
        new: Option<&'a [u8]>,
    ) -> BoxFuture<'a, Result<bool, StoreError>> {
        Box::pin(async move {
            self.with_entry(namespace, key, |name| {
                let existing = self
                    .read_encrypted(name)?
                    .map(|ciphertext| self.decrypt(&ciphertext))
                    .transpose()?;
                if existing.as_ref().map(|value| value.as_slice()) != expected {
                    return Ok(false);
                }
                match new {
                    Some(value) => self.replace(name, value)?,
                    None => self.remove_file(name)?,
                }
                Ok(true)
            })
        })
    }
}

fn read_encrypted_file(mut file: File) -> io::Result<Vec<u8>> {
    let mut bytes = Vec::new();
    file.read_to_end(&mut bytes)?;
    Ok(bytes)
}

fn namespaced_key(filename: &str) -> Option<String> {
    let decoded = URL_SAFE_NO_PAD.decode(filename).ok()?;
    let key = String::from_utf8(decoded).ok()?;
    key.split_once('.')?;
    Some(key)
}

fn unique_name(purpose: &str) -> Result<String, StoreError> {
    let mut random = [0; 16];
    getrandom::getrandom(&mut random).map_err(|_| StoreError::Unavailable("randomness".into()))?;
    Ok(format!(
        ".petrel-{purpose}.{:032x}",
        u128::from_le_bytes(random)
    ))
}

fn optional<T>(result: io::Result<T>) -> io::Result<Option<T>> {
    match result {
        Ok(value) => Ok(Some(value)),
        Err(error) if error.kind() == ErrorKind::NotFound => Ok(None),
        Err(error) => Err(error),
    }
}

// Consumes the underlying error at the Result boundary and reports only its
// kind, since the underlying error can contain paths or backend data.
#[allow(clippy::needless_pass_by_value)]
fn io_error(error: io::Error) -> StoreError {
    StoreError::Unavailable(error.kind().to_string())
}

fn corrupt_file() -> StoreError {
    StoreError::Corrupt("ciphertext failed to authenticate".into())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn interrupted_publication_preserves_the_prior_value() {
        let root = tempfile::tempdir().unwrap();
        let path = root.path().canonicalize().unwrap().join("store");
        let store = FileSecretStore::open(&path, &[23; 32]).unwrap();
        store.put("test", "key", b"committed").await.unwrap();

        let staged = store.encrypt(b"replacement").unwrap();
        let failed = store.publish(&staged, |_| {
            Err::<(), _>(ErrorKind::PermissionDenied.into())
        });
        assert!(matches!(failed, Err(StoreError::Unavailable(_))));
        assert_eq!(
            store.get("test", "key").await.unwrap().as_deref(),
            Some(b"committed".as_slice())
        );
        assert!(
            store
                .directory
                .names()
                .unwrap()
                .iter()
                .all(|name| !name.starts_with(".petrel-temp."))
        );
    }
}
