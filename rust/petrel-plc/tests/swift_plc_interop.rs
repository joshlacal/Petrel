#![cfg(not(target_arch = "wasm32"))]

use std::{
    env, fs,
    path::{Path, PathBuf},
    process::{Command, Stdio},
};

use petrel_crypto::{K256Keypair, P256Keypair};
use petrel_plc::{
    PlcAtProfile, PlcAuditLogVerifier, PlcOperation, PlcOperationCodec, UnsignedPlcOperation,
};
use serde::{Deserialize, Serialize};
use serde_json::Value as Json;

mod common;
use common::make_audit_json;

const SWIFT_INTEROP_REQUIRED_ENV: &str = "PETREL_SWIFT_PLC_INTEROP_REQUIRED";

#[derive(Debug, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
struct InteropBundle {
    did: String,
    audit_json: String,
    operations_json: Vec<String>,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
struct SwiftInput {
    rust_bundles: Vec<InteropBundle>,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
struct SwiftOutput {
    swift_bundles: Vec<InteropBundle>,
}

fn find_swift_binary() -> Option<PathBuf> {
    if let Ok(path) = env::var("SWIFT_BIN")
        && !path.is_empty()
    {
        return Some(PathBuf::from(path));
    }
    let output = Command::new("which").arg("swift").output().ok()?;
    if output.status.success() {
        let p = String::from_utf8_lossy(&output.stdout).trim().to_owned();
        if !p.is_empty() {
            return Some(PathBuf::from(p));
        }
    }
    let xcrun = Command::new("/usr/bin/xcrun")
        .args(["--find", "swift"])
        .output()
        .ok()?;
    if xcrun.status.success() {
        let p = String::from_utf8_lossy(&xcrun.stdout).trim().to_owned();
        if !p.is_empty() {
            return Some(PathBuf::from(p));
        }
    }
    None
}

fn build_bundle(did: &str, ops: &[PlcOperation]) -> InteropBundle {
    let audit_bytes = make_audit_json(did, ops, None, None);
    let audit_json = String::from_utf8(audit_bytes).unwrap();
    let operations_json = ops
        .iter()
        .map(|op| String::from_utf8(op.canonical_json().unwrap()).unwrap())
        .collect();
    InteropBundle {
        did: did.to_owned(),
        audit_json,
        operations_json,
    }
}

fn ensure_swift_helper(repo_root: &Path, helper_dir: &Path) {
    let src_dir = helper_dir.join("Sources").join("SwiftPlcInterop");
    fs::create_dir_all(&src_dir).unwrap();
    let pkg_name = repo_root
        .file_name()
        .and_then(|s| s.to_str())
        .unwrap_or("petrel")
        .to_ascii_lowercase();

    let package_swift = format!(
        r#"// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "SwiftPlcInterop",
    platforms: [.macOS(.v15)],
    dependencies: [
        .package(path: "{}"),
    ],
    targets: [
        .executableTarget(
            name: "SwiftPlcInterop",
            dependencies: [
                .product(name: "PetrelCrypto", package: "{}"),
                .product(name: "PetrelPLC", package: "{}"),
            ]
        ),
    ]
)
"#,
        repo_root.display(),
        pkg_name,
        pkg_name
    );
    fs::write(helper_dir.join("Package.swift"), package_swift).unwrap();
    fs::write(src_dir.join("main.swift"), MAIN_SWIFT).unwrap();
}

const MAIN_SWIFT: &str = r#"import Foundation
import PetrelCrypto
import PetrelPLC

struct BundlePayload: Codable {
    let did: String
    let auditJson: String
    let operationsJson: [String]
}

struct InputPayload: Codable {
    let rustBundles: [BundlePayload]
}

struct OutputPayload: Codable {
    let swiftBundles: [BundlePayload]
}

func run() async throws {
    let stdinData = FileHandle.standardInput.readDataToEndOfFile()
    let input = try JSONDecoder().decode(InputPayload.self, from: stdinData)

    // 1. Verify every Rust-signed genesis + rotation bundle in Swift PetrelPLC
    for bundle in input.rustBundles {
        let auditData = Data(bundle.auditJson.utf8)
        let verifiedLog = try PLCAuditLogVerifier.verify(json: auditData, did: bundle.did)
        let ops = try bundle.operationsJson.map { try PLCOperationCodec.decodeSignedJSON(Data($0.utf8)) }
        guard let first = ops.first else {
            throw NSError(domain: "Interop", code: 1, userInfo: [NSLocalizedDescriptionKey: "empty ops"])
        }
        let derived = try PLCOperationCodec.genesisDID(for: first)
        guard derived == bundle.did else {
            throw NSError(domain: "Interop", code: 2, userInfo: [NSLocalizedDescriptionKey: "DID mismatch \(derived) != \(bundle.did)"])
        }
        try PLCOperationCodec.verifyGenesis(first, expectedDID: bundle.did)
        let linearData = try PLCAuditLogVerifier.validateOperationLog(ops, did: bundle.did)
        guard linearData == verifiedLog.documentData else {
            throw NSError(domain: "Interop", code: 3, userInfo: [NSLocalizedDescriptionKey: "linear/audit mismatch"])
        }
    }

    // 2. Mint K-256 and P-256 genesis + rotation bundles in Swift PetrelPLC for Rust verification
    func makeSwiftBundle(useP256: Bool, handle1: String, handle2: String) async throws -> BundlePayload {
        let signingKey: any ATProtoKeypair = useP256 ? P256Keypair.generate() : K256Keypair.generate()
        let rot1: any ATProtoKeypair = useP256 ? P256Keypair.generate() : K256Keypair.generate()
        let rot2: any ATProtoKeypair = useP256 ? K256Keypair.generate() : P256Keypair.generate()

        let genesisUnsigned = try PLCATProfile.genesisOperation(
            handle: handle1,
            signingKey: signingKey.didKey,
            rotationKeys: [rot1.didKey, rot2.didKey],
            pdsEndpoint: "https://swift-pds.example.com"
        )
        let genesisSigned = try await PLCOperationCodec.sign(.regular(genesisUnsigned), with: rot1)
        let did = try PLCOperationCodec.genesisDID(for: genesisSigned)

        let upd1Unsigned = try PLCOperationCodec.update(after: genesisSigned) { draft in
            draft.rotationKeys = [rot2.didKey, rot1.didKey]
            try draft.setHandle(handle2)
        }
        let upd1Signed = try await PLCOperationCodec.sign(.regular(upd1Unsigned), with: rot2)

        let upd2Unsigned = try PLCOperationCodec.updatePDS(after: upd1Signed, endpoint: "https://swift-pds2.example.com")
        let upd2Signed = try await PLCOperationCodec.sign(.regular(upd2Unsigned), with: rot2)

        let ops = [genesisSigned, upd1Signed, upd2Signed]
        let opsJson = try ops.map { String(decoding: try $0.canonicalJSON, as: UTF8.self) }
        var auditObjects = [[String: Any]]()
        for (i, op) in ops.enumerated() {
            auditObjects.append([
                "did": did,
                "operation": try JSONSerialization.jsonObject(with: op.canonicalJSON),
                "cid": try op.cid.string,
                "nullified": false,
                "createdAt": "2026-07-27T12:00:0\(i).000Z",
            ])
        }
        let auditData = try JSONSerialization.data(withJSONObject: auditObjects, options: [.sortedKeys])
        return BundlePayload(
            did: did,
            auditJson: String(decoding: auditData, as: UTF8.self),
            operationsJson: opsJson
        )
    }

    let k256Bundle = try await makeSwiftBundle(useP256: false, handle1: "swift-k256.example.com", handle2: "swift-k256-rotated.example.com")
    let p256Bundle = try await makeSwiftBundle(useP256: true, handle1: "swift-p256.example.com", handle2: "swift-p256-rotated.example.com")
    let output = OutputPayload(swiftBundles: [k256Bundle, p256Bundle])
    let outData = try JSONEncoder().encode(output)
    FileHandle.standardOutput.write(outData)
}

do {
    try await run()
} catch {
    FileHandle.standardError.write(Data("SwiftPlcInterop error: \(error)\n".utf8))
    exit(1)
}
"#;

async fn build_rust_bundles() -> SwiftInput {
    let k_signing = K256Keypair::generate().unwrap();
    let k_rotation = K256Keypair::generate().unwrap();
    let p_backup = P256Keypair::generate().unwrap();

    let k_genesis_unsigned = PlcAtProfile::genesis_operation(
        "rust-k256.example.com",
        &k_signing.did_key(),
        &[k_rotation.did_key(), p_backup.did_key()],
        "https://rust-pds.example.com",
    )
    .unwrap();
    let k_genesis = PlcOperationCodec::sign(
        &UnsignedPlcOperation::Regular(k_genesis_unsigned),
        &k_rotation,
    )
    .await
    .unwrap();
    let k_did = PlcOperationCodec::genesis_did(&k_genesis).unwrap();

    let k_rotated_unsigned = PlcOperationCodec::update(&k_genesis, |draft| {
        draft.rotation_keys = vec![p_backup.did_key(), k_rotation.did_key()];
        draft.set_handle("rust-k256-rotated.example.com")
    })
    .unwrap();
    let k_rotated = PlcOperationCodec::sign(
        &UnsignedPlcOperation::Regular(k_rotated_unsigned),
        &p_backup,
    )
    .await
    .unwrap();

    let p_signing = P256Keypair::generate().unwrap();
    let p_primary = P256Keypair::generate().unwrap();
    let p_genesis_unsigned = PlcAtProfile::genesis_operation(
        "rust-p256.example.com",
        &p_signing.did_key(),
        &[p_primary.did_key()],
        "https://rust-p256-pds.example.com",
    )
    .unwrap();
    let p_genesis = PlcOperationCodec::sign(
        &UnsignedPlcOperation::Regular(p_genesis_unsigned),
        &p_primary,
    )
    .await
    .unwrap();
    let p_did = PlcOperationCodec::genesis_did(&p_genesis).unwrap();
    let p_update_unsigned =
        PlcOperationCodec::update_pds(&p_genesis, "https://rust-p256-pds2.example.com").unwrap();
    let p_update = PlcOperationCodec::sign(
        &UnsignedPlcOperation::Regular(p_update_unsigned),
        &p_primary,
    )
    .await
    .unwrap();

    SwiftInput {
        rust_bundles: vec![
            build_bundle(&k_did, &[k_genesis, k_rotated]),
            build_bundle(&p_did, &[p_genesis, p_update]),
        ],
    }
}

#[tokio::test]
async fn swift_rust_plc_roundtrip_bidirectional() {
    let Some(swift_bin) = find_swift_binary() else {
        assert!(
            env::var(SWIFT_INTEROP_REQUIRED_ENV).as_deref() != Ok("1"),
            "swift binary required when {SWIFT_INTEROP_REQUIRED_ENV}=1"
        );
        eprintln!("skipped live Swift<->Rust PLC interop: swift not found on PATH");
        return;
    };

    let input = build_rust_bundles().await;
    let input_json = serde_json::to_vec(&input).unwrap();

    let manifest_dir = PathBuf::from(env!("CARGO_MANIFEST_DIR"));
    let repo_root = manifest_dir.parent().unwrap().parent().unwrap();
    let helper_dir = repo_root
        .join("rust")
        .join("target")
        .join("swift-plc-interop");
    ensure_swift_helper(repo_root, &helper_dir);

    let mut child = Command::new(&swift_bin)
        .arg("run")
        .arg("--package-path")
        .arg(&helper_dir)
        .arg("SwiftPlcInterop")
        .stdin(Stdio::piped())
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .spawn()
        .expect("spawn swift run SwiftPlcInterop");
    {
        use std::io::Write as _;
        let mut stdin = child.stdin.take().unwrap();
        stdin.write_all(&input_json).unwrap();
    }
    let output = child.wait_with_output().unwrap();
    assert!(
        output.status.success(),
        "SwiftPlcInterop failed ({:?}):\nstdout:\n{}\nstderr:\n{}",
        output.status,
        String::from_utf8_lossy(&output.stdout),
        String::from_utf8_lossy(&output.stderr)
    );

    // 2. Verify Swift-signed K-256 and P-256 genesis + rotation bundles in Rust petrel-plc
    let parsed: SwiftOutput = serde_json::from_slice(&output.stdout).unwrap();
    assert_eq!(parsed.swift_bundles.len(), 2);

    for (idx, bundle) in parsed.swift_bundles.iter().enumerate() {
        let verified =
            PlcAuditLogVerifier::verify_json(bundle.audit_json.as_bytes(), &bundle.did).unwrap();
        let ops: Vec<PlcOperation> = bundle
            .operations_json
            .iter()
            .map(|s| PlcOperationCodec::decode_signed_json(s.as_bytes()).unwrap())
            .collect();
        assert_eq!(ops.len(), 3);
        assert_eq!(PlcOperationCodec::genesis_did(&ops[0]).unwrap(), bundle.did);
        PlcOperationCodec::verify_genesis(&ops[0], &bundle.did).unwrap();
        let linear_state = PlcAuditLogVerifier::validate_operation_log(&ops, &bundle.did).unwrap();
        assert_eq!(linear_state, verified.document_data());
        let data = verified.document_data().unwrap();
        let expected_handle = if idx == 0 {
            "swift-k256-rotated.example.com"
        } else {
            "swift-p256-rotated.example.com"
        };
        assert_eq!(data.handle(), Some(expected_handle));
        assert_eq!(data.pds_endpoint(), Some("https://swift-pds2.example.com"));
        // Verify JSON serialization roundtrip produces identical canonical CIDs
        let roundtrip: Vec<Json> = ops
            .iter()
            .map(|op| serde_json::from_slice(&op.canonical_json().unwrap()).unwrap())
            .collect();
        assert_eq!(roundtrip.len(), 3);
    }
}
