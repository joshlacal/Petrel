#[cfg(not(target_arch = "wasm32"))]
#[tokio::main]
async fn main() {
    let argv: Vec<String> = std::env::args().collect();
    if let Err(err) = petrel_load::run_cli(&argv).await {
        eprintln!("PetrelLoad failed: {err}");
        let code = if err.downcast_ref::<petrel_load::ArgumentError>().is_some() {
            2
        } else {
            1
        };
        std::process::exit(code);
    }
}

#[cfg(target_arch = "wasm32")]
fn main() {}
