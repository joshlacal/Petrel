use std::net::Ipv4Addr;

use axum::{
    Router,
    extract::Path,
    http::{StatusCode, header},
    response::IntoResponse,
    routing::get,
};
use serde_json::json;
use tokio::{net::TcpListener, task::JoinHandle};
use url::Url;

use crate::{DEMO_HANDLE, TestResult};

/// One-account loopback PLC directory that serves a synthetic DID document.
#[derive(Debug)]
pub struct FakePlc {
    origin: Url,
    task: JoinHandle<std::io::Result<()>>,
}

impl FakePlc {
    pub async fn start(did: &str, pds_origin: &Url) -> TestResult<Self> {
        let listener = TcpListener::bind((Ipv4Addr::LOCALHOST, 0)).await?;
        let origin = Url::parse(&format!("http://{}", listener.local_addr()?))?;
        let document = json!({
            "@context": ["https://www.w3.org/ns/did/v1"],
            "id": did,
            "alsoKnownAs": [format!("at://{DEMO_HANDLE}")],
            "service": [{
                "id": "#atproto_pds",
                "type": "AtprotoPersonalDataServer",
                "serviceEndpoint": pds_origin.as_str().trim_end_matches('/'),
            }],
        })
        .to_string();

        let did = did.to_owned();
        let app = Router::new().route(
            "/{did}",
            get(move |Path(requested): Path<String>| async move {
                if requested == did {
                    (
                        [(header::CONTENT_TYPE, "application/did+ld+json")],
                        document,
                    )
                        .into_response()
                } else {
                    StatusCode::NOT_FOUND.into_response()
                }
            }),
        );
        let task = tokio::spawn(async move { axum::serve(listener, app).await });
        Ok(Self { origin, task })
    }

    pub fn origin(&self) -> &Url {
        &self.origin
    }
}

impl Drop for FakePlc {
    fn drop(&mut self) {
        self.task.abort();
    }
}

#[cfg(test)]
mod tests {
    use std::time::Duration;

    use super::*;
    use crate::{DEMO_DID, loopback_http_client};

    #[tokio::test]
    async fn directory_serves_only_the_synthetic_identity() {
        let pds = Url::parse("http://127.0.0.1:53201").unwrap();
        let directory = FakePlc::start(DEMO_DID, &pds).await.unwrap();
        let client = loopback_http_client(Duration::from_secs(2)).unwrap();

        let mut document_url = directory.origin().clone();
        document_url.path_segments_mut().unwrap().push(DEMO_DID);
        let response = client.get(document_url).send().await.unwrap();
        assert_eq!(response.status(), StatusCode::OK);
        assert_eq!(
            response.headers()[header::CONTENT_TYPE],
            "application/did+ld+json"
        );
        let document: serde_json::Value =
            serde_json::from_slice(&response.bytes().await.unwrap()).unwrap();
        assert_eq!(document["id"], DEMO_DID);
        assert_eq!(document["alsoKnownAs"], json!(["at://demo.test"]));
        assert_eq!(document["service"][0]["id"], "#atproto_pds");
        assert_eq!(document["service"][0]["type"], "AtprotoPersonalDataServer");
        assert_eq!(
            document["service"][0]["serviceEndpoint"],
            "http://127.0.0.1:53201"
        );

        let response = client
            .get(directory.origin().join("/did:plc:another-account").unwrap())
            .send()
            .await
            .unwrap();
        assert_eq!(response.status(), StatusCode::NOT_FOUND);
    }
}
