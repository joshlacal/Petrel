//! Native test harness for the Petrel Rust client and Swift test servers.
//!
//! Build `petrel-oauth-server-example` and `petrel-cab-server` from the Swift
//! `Server` package. Set `PETREL_E2E_SERVER_BIN_DIR` to the directory with both
//! executables and run `cargo test -p petrel-e2e` from `rust/`. Set
//! `PETREL_E2E_REQUIRED=1` to fail when the binaries are unavailable.

#![cfg(not(target_arch = "wasm32"))]

mod browser;
mod plc;
mod swift;

pub use browser::headless_approve;
pub use plc::FakePlc;
pub use swift::{CAB_CLIENT_ID, CAB_REDIRECT, CabClient, CabServer, ExampleServer, ServerBins};

use std::time::Duration;

use reqwest::{Client, redirect::Policy};

pub const DEMO_DID: &str = "did:plc:petrelexampledemoaccount";
pub const DEMO_HANDLE: &str = "demo.test";
pub const DEMO_SCOPE: &str = "atproto transition:generic";
const DEMO_PASSWORD: &str = "petrel-demo";

pub type TestResult<T> = Result<T, Box<dyn std::error::Error + Send + Sync>>;

fn loopback_http_client(timeout: Duration) -> Result<Client, reqwest::Error> {
    Client::builder()
        .no_proxy()
        .redirect(Policy::none())
        .timeout(timeout)
        .build()
}
