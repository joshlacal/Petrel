use std::{env, fs::File};

use base64::{
    Engine as _,
    engine::general_purpose::{STANDARD, URL_SAFE_NO_PAD},
};
use p256::{
    SecretKey,
    elliptic_curve::{rand_core::OsRng, sec1::ToEncodedPoint},
    pkcs8::{EncodePrivateKey, LineEnding},
};
use serde_json::{Value, json};
use tempfile::TempDir;
use url::Url;

use super::{CAB_BIN, RunningServer, ServerBins};
use crate::{DEMO_SCOPE, TestResult};

pub const CAB_CLIENT_ID: &str = "https://client.example/oauth-client-metadata.json";
pub const CAB_REDIRECT: &str = "https://client.example/callback";
const KID: &str = "petrel-rust-interop";

/// An isolated confidential client with a fresh key for Swift CAB assertions.
#[derive(Debug)]
pub struct CabClient {
    assertion_key: SecretKey,
}

impl CabClient {
    pub fn generate() -> Self {
        Self {
            assertion_key: SecretKey::random(&mut OsRng),
        }
    }

    /// Metadata to register with the Swift authorization server before it starts.
    pub fn metadata(&self) -> Value {
        let point = self.assertion_key.public_key().to_encoded_point(false);
        let coordinates = point.as_bytes();
        let jwk = json!({
            "kty": "EC",
            "crv": "P-256",
            "kid": KID,
            "alg": "ES256",
            "use": "sig",
            "x": URL_SAFE_NO_PAD.encode(&coordinates[1..33]),
            "y": URL_SAFE_NO_PAD.encode(&coordinates[33..65]),
        });
        json!({
            "client_id": CAB_CLIENT_ID,
            "client_name": "Petrel Rust interoperability client",
            "application_type": "web",
            "grant_types": ["authorization_code", "refresh_token"],
            "response_types": ["code"],
            "redirect_uris": [CAB_REDIRECT],
            "scope": DEMO_SCOPE,
            "token_endpoint_auth_method": "private_key_jwt",
            "token_endpoint_auth_signing_alg": "ES256",
            "dpop_bound_access_tokens": true,
            "jwks": {"keys": [jwk]},
        })
    }

    pub async fn spawn(
        &self,
        bins: &ServerBins,
        issuer: &Url,
        require_nonce: bool,
        denied_jkts: &[&str],
    ) -> TestResult<CabServer> {
        let directory = TempDir::new()?;
        let config_path = directory.path().join("cab.json");
        let pem = self.assertion_key.to_pkcs8_pem(LineEnding::LF)?;
        let pem_base64 = STANDARD.encode(pem.as_bytes());

        let server = RunningServer::spawn(CAB_BIN, |port, origin| {
            // The audience allowlist is only configurable through a file.
            // This limits assertions to the Swift issuer for this test run.
            let config = json!({
                "client_id": CAB_CLIENT_ID,
                "public_url": origin.origin().ascii_serialization(),
                "host": "127.0.0.1",
                "port": port,
                "keys": [{"kid": KID, "pem_base64": pem_base64}],
                "active_kid": KID,
                "aud_allowlist": [issuer.origin().ascii_serialization()],
                "require_nonce": require_nonce,
                "nonce_secret_base64": STANDARD.encode([0xA5; 32]),
                "denied_jkts": denied_jkts,
            });
            serde_json::to_writer(File::create(&config_path)?, &config)?;

            let mut command = bins.command(CAB_BIN);
            command.args(["serve", "--log-level", "error", "--config"]);
            command.arg(&config_path);
            // Do not let a developer's ambient CAB configuration change this fixture.
            for (key, _) in env::vars_os() {
                if key.to_str().is_some_and(|name| name.starts_with("CAB_")) {
                    command.env_remove(key);
                }
            }
            Ok(command)
        })
        .await?;

        Ok(CabServer { server })
    }
}

#[derive(Debug)]
pub struct CabServer {
    server: RunningServer,
}

impl CabServer {
    pub fn origin(&self) -> &Url {
        &self.server.origin
    }
}

#[cfg(test)]
mod tests {
    use std::time::Duration;

    use super::*;
    use crate::{loopback_http_client, swift::ExampleServer};

    #[tokio::test]
    async fn cab_serves_the_assertion_key_registered_with_the_issuer() {
        let Some(bins) = ServerBins::from_env() else {
            return;
        };
        let client = CabClient::generate();
        let metadata = client.metadata();
        let issuer = ExampleServer::spawn(&bins, std::slice::from_ref(&metadata))
            .await
            .expect("register client with Swift issuer");
        let cab = client
            .spawn(&bins, issuer.origin(), true, &[])
            .await
            .expect("start Swift CAB server");

        let jwks_url = cab.origin().join("/.well-known/jwks.json").unwrap();
        let response = loopback_http_client(Duration::from_secs(2))
            .unwrap()
            .get(jwks_url)
            .send()
            .await
            .unwrap()
            .error_for_status()
            .unwrap();
        let jwks: Value = serde_json::from_slice(&response.bytes().await.unwrap()).unwrap();
        for key in ["kid", "kty", "crv", "x", "y"] {
            assert_eq!(
                jwks["keys"][0][key], metadata["jwks"]["keys"][0][key],
                "{key}"
            );
        }
    }
}
