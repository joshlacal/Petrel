mod cab;

pub use cab::{CAB_CLIENT_ID, CAB_REDIRECT, CabClient, CabServer};

use std::{
    env,
    ffi::OsStr,
    fmt::Write as _,
    fs::File,
    io::{self, Read, Seek, SeekFrom},
    net::{Ipv4Addr, TcpListener},
    path::{Path, PathBuf},
    process::{Child, Command, Stdio},
    time::Duration,
};

use reqwest::StatusCode;
use serde_json::Value;
use tempfile::{NamedTempFile, TempDir};
use url::Url;

use crate::{TestResult, loopback_http_client};

const SERVER_BIN_DIR: &str = "PETREL_E2E_SERVER_BIN_DIR";
const SERVER_REQUIRED: &str = "PETREL_E2E_REQUIRED";
const EXAMPLE_BIN: &str = "petrel-oauth-server-example";
const CAB_BIN: &str = "petrel-cab-server";
const STARTUP_ATTEMPTS: usize = 3;
const HEALTH_POLLS: usize = 100;
const POLL_INTERVAL: Duration = Duration::from_millis(100);
const LOG_LIMIT: u64 = 16 * 1024;

#[derive(Debug)]
pub struct ServerBins {
    directory: PathBuf,
}

impl ServerBins {
    /// E2E tests are opt-in locally and mandatory in CI. Validate the two
    /// executables before starting either server.
    ///
    /// # Panics
    ///
    /// Panics if binaries are required and the directory is absent or if a
    /// configured directory is missing either executable.
    pub fn from_env() -> Option<Self> {
        let Some(directory) = env::var_os(SERVER_BIN_DIR).filter(|path| !path.is_empty()) else {
            let message = format!("set {SERVER_BIN_DIR} to the Swift server build directory");
            assert!(
                env::var_os(SERVER_REQUIRED).as_deref() != Some(OsStr::new("1")),
                "{message} ({SERVER_REQUIRED}=1)"
            );
            eprintln!("skipped: {message}");
            return None;
        };

        let directory = PathBuf::from(directory);
        for name in [EXAMPLE_BIN, CAB_BIN] {
            let path = directory.join(executable_name(name));
            assert!(
                path.is_file(),
                "Swift server binary missing: {}",
                path.display()
            );
        }
        // Resolve relative paths before passing them to Command, which searches
        // PATH if given an executable without a path separator.
        let directory = directory
            .canonicalize()
            .expect("resolve Swift server directory");
        Some(Self { directory })
    }

    fn command(&self, name: &str) -> Command {
        Command::new(self.directory.join(executable_name(name)))
    }
}

fn executable_name(name: &str) -> String {
    format!("{name}{}", env::consts::EXE_SUFFIX)
}

#[derive(Debug)]
pub struct ExampleServer {
    server: RunningServer,
}

impl ExampleServer {
    pub async fn spawn(bins: &ServerBins, registered_clients: &[Value]) -> TestResult<Self> {
        let metadata = TempDir::new()?;
        let mut registration_args = Vec::with_capacity(registered_clients.len() * 2);

        for (index, client) in registered_clients.iter().enumerate() {
            let path = metadata.path().join(format!("client-{index}.json"));
            serde_json::to_writer(File::create(&path)?, client)?;
            registration_args.push("--register-client".into());
            registration_args.push(path.into_os_string());
        }

        let server = RunningServer::spawn(EXAMPLE_BIN, |port, _origin| {
            let mut command = bins.command(EXAMPLE_BIN);
            command.args(["--hostname", "127.0.0.1", "--port", &port.to_string()]);
            command.args(&registration_args);
            Ok(command)
        })
        .await?;
        // The executable has read the metadata by the time it begins serving.
        Ok(Self { server })
    }

    pub fn origin(&self) -> &Url {
        &self.server.origin
    }
}

#[derive(Debug)]
struct RunningServer {
    origin: Url,
    // Retain ownership so startup errors and test panics also stop the server.
    _process: ChildGuard,
}

impl RunningServer {
    async fn spawn(
        name: &str,
        command: impl Fn(u16, &Url) -> TestResult<Command>,
    ) -> TestResult<Self> {
        let client = loopback_http_client(POLL_INTERVAL)?;
        let mut failures = String::new();

        // Both servers need to know their origin before starting. Let the
        // kernel pick a port, then retry if another listener binds first.
        for attempt in 1..=STARTUP_ATTEMPTS {
            let port = TcpListener::bind((Ipv4Addr::LOCALHOST, 0))?
                .local_addr()?
                .port();
            let origin = Url::parse(&format!("http://127.0.0.1:{port}"))?;
            let health = origin.join("/health")?;
            let mut process = ChildGuard::spawn(command(port, &origin)?).map_err(|error| {
                io::Error::new(error.kind(), format!("failed to spawn {name}: {error}"))
            })?;

            match wait_for_health(&client, &health, &mut process.child).await {
                Ok(()) => {
                    return Ok(Self {
                        origin,
                        _process: process,
                    });
                }
                Err(error) => {
                    writeln!(
                        failures,
                        "Attempt {attempt} on {origin}: {error}\n{}",
                        process.log_tail(),
                    )?;
                }
            }
        }

        Err(format!("{name} failed to start:\n{failures}").into())
    }
}

async fn wait_for_health(
    client: &reqwest::Client,
    endpoint: &Url,
    child: &mut Child,
) -> TestResult<()> {
    for _ in 0..HEALTH_POLLS {
        if let Some(status) = child.try_wait()? {
            return Err(format!("exited before readiness with {status}").into());
        }
        if let Ok(response) = client.get(endpoint.clone()).send().await
            && response.status() == StatusCode::OK
            && response
                .text()
                .await
                .as_deref()
                .is_ok_and(|body| body == "OK")
        {
            if let Some(status) = child.try_wait()? {
                return Err(format!("exited during readiness with {status}").into());
            }
            return Ok(());
        }
        tokio::time::sleep(POLL_INTERVAL).await;
    }
    Err(format!("no healthy response from {endpoint}").into())
}

#[derive(Debug)]
struct ChildGuard {
    child: Child,
    log: NamedTempFile,
}

impl ChildGuard {
    fn spawn(mut command: Command) -> io::Result<Self> {
        let log = NamedTempFile::new()?;
        let child = command
            .stdin(Stdio::null())
            .stdout(log.as_file().try_clone()?)
            .stderr(log.as_file().try_clone()?)
            .spawn()?;
        Ok(Self { child, log })
    }

    fn log_tail(&self) -> String {
        match read_log_tail(self.log.path()) {
            Ok(log) => log,
            Err(error) => format!("could not read Swift server log: {error}"),
        }
    }
}

fn read_log_tail(path: &Path) -> io::Result<String> {
    let mut reader = File::open(path)?;
    let start = reader.metadata()?.len().saturating_sub(LOG_LIMIT);
    reader.seek(SeekFrom::Start(start))?;
    let mut bytes = Vec::new();
    reader.take(LOG_LIMIT).read_to_end(&mut bytes)?;
    Ok(String::from_utf8_lossy(&bytes).into_owned())
}

impl Drop for ChildGuard {
    fn drop(&mut self) {
        // kill does not reap the child. Wait even after an early exit.
        let _ = self.child.kill();
        if let Err(error) = self.child.wait() {
            eprintln!(
                "failed to reap Swift server process {}: {error}",
                self.child.id()
            );
        }
        if std::thread::panicking() {
            eprintln!("Swift server log:\n{}", self.log_tail());
        }
    }
}

#[cfg(test)]
mod tests {
    use std::net::TcpStream;

    use super::*;

    #[tokio::test]
    async fn example_starts_and_closes_listener_on_drop() {
        let Some(bins) = ServerBins::from_env() else {
            return;
        };
        let server = ExampleServer::spawn(&bins, &[])
            .await
            .expect("start example server");
        let address = (
            Ipv4Addr::LOCALHOST,
            server.origin().port().expect("assigned port"),
        );
        assert!(TcpStream::connect(address).is_ok());
        drop(server);
        assert!(
            TcpStream::connect(address).is_err(),
            "server still listening after drop"
        );
    }

    #[tokio::test]
    async fn invalid_registration_reports_early_exit() {
        let Some(bins) = ServerBins::from_env() else {
            return;
        };
        let invalid = serde_json::json!({"client_id": 42});
        let error = ExampleServer::spawn(&bins, &[invalid]).await.unwrap_err();
        let message = error.to_string();
        assert!(message.contains(EXAMPLE_BIN), "{message}");
        assert!(message.contains("exited before readiness"), "{message}");
        assert!(message.contains("Error:"), "{message}");
    }
}
