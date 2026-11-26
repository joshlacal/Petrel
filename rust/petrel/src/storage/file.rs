use std::env;
use std::fmt;
use std::fs::File;
use std::io::{self, ErrorKind, Read as _, Write as _};
use std::path::{Path, PathBuf};
use std::sync::Arc;

use aes_gcm::aead::{Aead, KeyInit, Payload};
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
/// Magic header distinguishing v2 AAD-bound entries from v1 Swift-compatible entries.
const V2_MAGIC: &[u8; 8] = b"PTLSECv2";

/// An encrypted, file-backed secret store for native targets.
///
/// New entries are written in the v2 AES-256-GCM envelope that binds
/// `namespace + "\0" + key` as AAD, while v1 entries (matching Swift's
/// `FileEncryptedStore`, including `.petrel-key-check`) remain readable
/// transparently. Unix operations use a held directory descriptor and require
/// the owner to be the current user, with group and other access disabled.
/// Windows inherits ACLs from the chosen private directory and rejects reparse
/// points. Keep the directory private on Windows, where file data is flushed
/// before an atomic rename but directory metadata cannot be explicitly flushed.
///
/// Container compatibility applies to raw secret bytes with supported
/// names. A namespace cannot contain a period. The typed session records
/// written by [`super::SessionStore`] have a separate Rust JSON format.
///
/// Async [`SecretStore`] methods offload blocking filesystem I/O onto
/// `tokio::task::spawn_blocking` under the `native` feature, and onto a
/// helper thread without it. Rust instances serialize
/// mutations with an advisory lock. Coordinate independently running Swift
/// and Rust writers externally when using a directory from both runtimes.
pub struct FileSecretStore {
    inner: Arc<FileSecretStoreInner>,
}

struct FileSecretStoreInner {
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
    ///
    /// On Unix no component of `directory` may be a symbolic link, so that
    /// the store cannot be redirected. Pass a canonical path: system
    /// locations such as macOS's `/var` and `/tmp` are links.
    pub fn open(directory: impl AsRef<Path>, key: &[u8; 32]) -> Result<Self, StoreError> {
        let inner = Arc::new(FileSecretStoreInner {
            directory: Directory::open(directory.as_ref()).map_err(io_error)?,
            key: Zeroizing::new(*key),
        });
        // Windows requires a regular file for locking. Reject an existing
        // different key before creating that file, then recheck under the lock.
        #[cfg(windows)]
        inner.validate_contents()?;
        {
            let _lock = inner.directory.lock().map_err(io_error)?;
            if !inner.validate_contents()? {
                inner.establish_key_check()?;
            }
            inner.clear_interrupted_files()?;
        }
        Ok(Self { inner })
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
}

async fn run_blocking<F, T>(operation: F) -> Result<T, StoreError>
where
    F: FnOnce() -> Result<T, StoreError> + Send + 'static,
    T: Send + 'static,
{
    #[cfg(all(not(target_arch = "wasm32"), feature = "native"))]
    {
        tokio::task::spawn_blocking(operation)
            .await
            .map_err(|_| StoreError::Unavailable("file store task cancelled".into()))?
    }
    // Without Tokio, a helper thread keeps file I/O off the polling executor.
    #[cfg(not(all(not(target_arch = "wasm32"), feature = "native")))]
    {
        crate::auth::background::on_thread(operation)
            .await
            .ok_or_else(|| StoreError::Unavailable("file store thread unavailable".into()))?
    }
}

impl FileSecretStoreInner {
    /// Checks that `key` is this directory's key. Returns whether the
    /// directory already records one.
    ///
    /// With a key marker present the marker alone decides. A damaged entry
    /// is then reported as [`StoreError::Corrupt`] when it is read, and does
    /// not make every other entry unreadable. Without a marker (a directory
    /// written before markers existed) any entry the key cannot open means
    /// the key is wrong.
    fn validate_contents(&self) -> Result<bool, StoreError> {
        let marker = self.read_encrypted(KEY_CHECK_FILENAME)?;
        if let Some(ref marker) = marker {
            self.verify_key_check(marker)?;
        }
        for name in self.directory.names().map_err(io_error)? {
            // Reading checks each entry's owner and mode, so a file someone
            // else could have written still refuses the whole directory.
            if let Some(ns_key) = namespaced_key(&name)
                && let Some(ciphertext) = self.read_encrypted(&name)?
                && marker.is_none()
            {
                let (ns, key) = ns_key.split_once('.').ok_or_else(corrupt_file)?;
                self.decrypt_entry(ns, key, &ciphertext)
                    .map_err(|_| StoreError::KeyMismatch)?;
            }
        }
        Ok(marker.is_some())
    }

    fn verify_key_check(&self, combined: &[u8]) -> Result<(), StoreError> {
        let plaintext = self
            .decrypt_v1(combined)
            .map_err(|_| StoreError::KeyMismatch)?;
        if plaintext.as_slice() != KEY_CHECK_PLAINTEXT {
            return Err(StoreError::KeyMismatch);
        }
        Ok(())
    }

    fn establish_key_check(&self) -> Result<(), StoreError> {
        let combined = self.encrypt_v1(KEY_CHECK_PLAINTEXT)?;
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

    fn encrypt_v1(&self, plaintext: &[u8]) -> Result<Vec<u8>, StoreError> {
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

    fn encrypt_v2(
        &self,
        namespace: &str,
        key: &str,
        plaintext: &[u8],
    ) -> Result<Vec<u8>, StoreError> {
        let mut nonce = [0; 12];
        getrandom::getrandom(&mut nonce)
            .map_err(|_| StoreError::Unavailable("randomness".into()))?;
        let aad = entry_aad(namespace, key);
        let ciphertext = self
            .cipher()?
            .encrypt(
                &Nonce::from(nonce),
                Payload {
                    msg: plaintext,
                    aad: &aad,
                },
            )
            .map_err(|_| StoreError::Other("file encryption failed".into()))?;
        let mut envelope = Vec::with_capacity(V2_MAGIC.len() + nonce.len() + ciphertext.len());
        envelope.extend_from_slice(V2_MAGIC);
        envelope.extend_from_slice(&nonce);
        envelope.extend_from_slice(&ciphertext);
        Ok(envelope)
    }

    fn decrypt_v1(&self, combined: &[u8]) -> Result<Zeroizing<Vec<u8>>, StoreError> {
        let (nonce, encrypted) = combined
            .split_first_chunk::<12>()
            .ok_or_else(corrupt_file)?;
        self.cipher()?
            .decrypt(&Nonce::from(*nonce), encrypted)
            .map(Zeroizing::new)
            .map_err(|_| corrupt_file())
    }

    fn decrypt_entry(
        &self,
        namespace: &str,
        key: &str,
        combined: &[u8],
    ) -> Result<Zeroizing<Vec<u8>>, StoreError> {
        if let Some(rest) = combined.strip_prefix(V2_MAGIC) {
            let (nonce, encrypted) = rest.split_first_chunk::<12>().ok_or_else(corrupt_file)?;
            let aad = entry_aad(namespace, key);
            self.cipher()?
                .decrypt(
                    &Nonce::from(*nonce),
                    Payload {
                        msg: encrypted,
                        aad: &aad,
                    },
                )
                .map(Zeroizing::new)
                .map_err(|_| corrupt_file())
        } else {
            self.decrypt_v1(combined)
        }
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

    fn replace(
        &self,
        name: &str,
        namespace: &str,
        key: &str,
        plaintext: &[u8],
    ) -> Result<(), StoreError> {
        let _existing = self.directory.read_file(name).map_err(io_error)?;
        let combined = self.encrypt_v2(namespace, key, plaintext)?;
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
        let name = encoded_entry_name(namespace, key);
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
            validate_namespace(namespace)?;
            validate_key(key)?;
            let inner = Arc::clone(&self.inner);
            let namespace = namespace.to_owned();
            let key = key.to_owned();
            run_blocking(move || {
                inner.with_entry(&namespace, &key, |name| {
                    inner
                        .read_encrypted(name)?
                        .map(|ciphertext| {
                            inner
                                .decrypt_entry(&namespace, &key, &ciphertext)
                                .map(|value| value.to_vec())
                        })
                        .transpose()
                })
            })
            .await
        })
    }

    fn put<'a>(
        &'a self,
        namespace: &'a str,
        key: &'a str,
        value: &'a [u8],
    ) -> BoxFuture<'a, Result<(), StoreError>> {
        Box::pin(async move {
            validate_namespace(namespace)?;
            validate_key(key)?;
            let inner = Arc::clone(&self.inner);
            let namespace = namespace.to_owned();
            let key = key.to_owned();
            let value = Zeroizing::new(value.to_vec());
            run_blocking(move || {
                inner.with_entry(&namespace, &key, |name| {
                    inner.replace(name, &namespace, &key, &value)
                })
            })
            .await
        })
    }

    fn delete<'a>(
        &'a self,
        namespace: &'a str,
        key: &'a str,
    ) -> BoxFuture<'a, Result<(), StoreError>> {
        Box::pin(async move {
            validate_namespace(namespace)?;
            validate_key(key)?;
            let inner = Arc::clone(&self.inner);
            let namespace = namespace.to_owned();
            let key = key.to_owned();
            run_blocking(move || inner.with_entry(&namespace, &key, |name| inner.remove_file(name)))
                .await
        })
    }

    fn take<'a>(
        &'a self,
        namespace: &'a str,
        key: &'a str,
    ) -> BoxFuture<'a, Result<Option<Vec<u8>>, StoreError>> {
        Box::pin(async move {
            validate_namespace(namespace)?;
            validate_key(key)?;
            let inner = Arc::clone(&self.inner);
            let namespace = namespace.to_owned();
            let key = key.to_owned();
            run_blocking(move || {
                inner.with_entry(&namespace, &key, |name| {
                    let Some(file) = inner.directory.read_file(name).map_err(io_error)? else {
                        return Ok(None);
                    };
                    let claimed = unique_name("claim")?;
                    inner.directory.rename(name, &claimed).map_err(io_error)?;
                    inner.directory.sync().map_err(io_error)?;
                    let result = read_encrypted_file(file)
                        .map_err(io_error)
                        .and_then(|ciphertext| inner.decrypt_entry(&namespace, &key, &ciphertext));
                    let cleanup = inner.remove_file(&claimed);
                    let plaintext = result?;
                    cleanup?;
                    Ok(Some(plaintext.to_vec()))
                })
            })
            .await
        })
    }

    fn delete_namespace<'a>(&'a self, namespace: &'a str) -> BoxFuture<'a, Result<(), StoreError>> {
        Box::pin(async move {
            validate_namespace(namespace)?;
            let inner = Arc::clone(&self.inner);
            let namespace = namespace.to_owned();
            run_blocking(move || {
                let _lock = inner.directory.lock().map_err(io_error)?;
                let mut first_error = None;
                for name in inner.directory.names().map_err(io_error)? {
                    if namespaced_key(&name).is_some_and(|key| {
                        key.split_once('.').is_some_and(|(ns, _)| ns == namespace)
                    }) && let Err(error) = inner.remove_file(&name)
                    {
                        first_error.get_or_insert(error);
                    }
                }
                first_error.map_or(Ok(()), Err)
            })
            .await
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
            validate_namespace(namespace)?;
            validate_key(key)?;
            let inner = Arc::clone(&self.inner);
            let namespace = namespace.to_owned();
            let key = key.to_owned();
            let expected = expected.map(|bytes| Zeroizing::new(bytes.to_vec()));
            let new = new.map(|bytes| Zeroizing::new(bytes.to_vec()));
            run_blocking(move || {
                inner.with_entry(&namespace, &key, |name| {
                    let existing = inner
                        .read_encrypted(name)?
                        .map(|ciphertext| inner.decrypt_entry(&namespace, &key, &ciphertext))
                        .transpose()?;
                    if existing.as_ref().map(|value| value.as_slice())
                        != expected.as_ref().map(|value| value.as_slice())
                    {
                        return Ok(false);
                    }
                    match new {
                        Some(value) => inner.replace(name, &namespace, &key, &value)?,
                        None => inner.remove_file(name)?,
                    }
                    Ok(true)
                })
            })
            .await
        })
    }
}

fn encoded_entry_name(namespace: &str, key: &str) -> String {
    URL_SAFE_NO_PAD.encode(format!("{namespace}.{key}"))
}

fn entry_aad(namespace: &str, key: &str) -> Vec<u8> {
    let mut aad = Vec::with_capacity(namespace.len() + 1 + key.len());
    aad.extend_from_slice(namespace.as_bytes());
    aad.push(0);
    aad.extend_from_slice(key.as_bytes());
    aad
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

        let staged = store
            .inner
            .encrypt_v2("test", "key", b"replacement")
            .unwrap();
        let failed = store.inner.publish(&staged, |_| {
            Err::<(), _>(ErrorKind::PermissionDenied.into())
        });
        assert!(matches!(failed, Err(StoreError::Unavailable(_))));
        assert_eq!(
            store.get("test", "key").await.unwrap().as_deref(),
            Some(b"committed".as_slice())
        );
        assert!(
            store
                .inner
                .directory
                .names()
                .unwrap()
                .iter()
                .all(|name| !name.starts_with(".petrel-temp."))
        );
    }
}
