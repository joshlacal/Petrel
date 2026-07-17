#!/usr/bin/env bash

set -euo pipefail

if [[ -n ${BASH_VERSION:-} ]]; then
  _petrel_release_script=${BASH_SOURCE[0]}
elif [[ -n ${ZSH_VERSION:-} ]]; then
  eval '_petrel_release_script=${(%):-%x}'
else
  echo "activate-release-toolchain.sh requires Bash or zsh" >&2
  return 1
fi

ROOT=$(cd "$(dirname "$_petrel_release_script")/.." && pwd -P)
source "$ROOT/Scripts/release-tool-identity.sh"

_petrel_release_fail() {
  echo "$*" >&2
  return 1
}

_petrel_release_has_prerelease_marker() {
  local value lower
  value=$1
  lower=$(printf '%s' "$value" | /usr/bin/tr '[:upper:]' '[:lower:]')
  case $lower in
    *beta*|*rc*|*preview*|*seed*) return 0 ;;
    *) return 1 ;;
  esac
}

[[ -n ${RELEASE_DEVELOPER_DIR:-} ]] || {
  _petrel_release_fail "RELEASE_DEVELOPER_DIR must be exported before activation"
  return 1
}
[[ -n ${RELEASE_XCODE_VERSION:-} ]] || {
  _petrel_release_fail "RELEASE_XCODE_VERSION must be exported before activation"
  return 1
}
[[ -n ${RELEASE_XCODE_BUILD:-} ]] || {
  _petrel_release_fail "RELEASE_XCODE_BUILD must be exported before activation"
  return 1
}

_petrel_release_approved_beta=0
case ${RELEASE_TOOLCHAIN_LANE:-} in
  local-validation)
    if [[ ${RELEASE_TOOLCHAIN_SELECTION:-} == explicit-user-approved-prerelease &&
          ${RELEASE_EVIDENCE_CLASS:-} == advisory-prerelease &&
          $RELEASE_DEVELOPER_DIR == /Applications/Xcode-beta.app/Contents/Developer &&
          $RELEASE_XCODE_VERSION == 27.0 &&
          $RELEASE_XCODE_BUILD == 27A5218g &&
          ${RELEASE_SWIFT_VERSION:-} == 6.4 &&
          ${RELEASE_IOS_RUNTIME:-} == 27.0 &&
          ${RELEASE_WATCHOS_RUNTIME:-} == 27.0 &&
          ${RELEASE_TVOS_RUNTIME:-} == 27.0 &&
          ${RELEASE_VISIONOS_RUNTIME:-} == 27.0 ]]; then
      _petrel_release_approved_beta=1
    else
      _petrel_release_fail "prerelease activation requires the exact explicit-user-approved-prerelease tuple"
      return 1
    fi
    ;;
  minimum)
    if [[ ${RELEASE_TOOLCHAIN_SELECTION:-} != pinned-minimum ||
          ${RELEASE_EVIDENCE_CLASS:-} != stable-release ||
          $RELEASE_DEVELOPER_DIR != /Applications/Xcode_16.3.app/Contents/Developer ||
          $RELEASE_XCODE_VERSION != 16.3 ||
          $RELEASE_XCODE_BUILD != 16E140 ||
          ${RELEASE_IOS_RUNTIME:-} != 18.4 ||
          ${RELEASE_WATCHOS_RUNTIME:-} != 11.4 ||
          ${RELEASE_TVOS_RUNTIME:-} != 18.4 ||
          ${RELEASE_VISIONOS_RUNTIME:-} != 2.4 ]]; then
      _petrel_release_fail "release toolchain tuple is not an exact sealed lane"
      return 1
    fi
    ;;
  newest-stable)
    if [[ ${RELEASE_TOOLCHAIN_SELECTION:-} != official-runner-inventory ||
          ${RELEASE_EVIDENCE_CLASS:-} != stable-release ||
          $RELEASE_DEVELOPER_DIR != /Applications/Xcode_26.6.app/Contents/Developer ||
          $RELEASE_XCODE_VERSION != 26.6 ||
          $RELEASE_XCODE_BUILD != 17F113 ||
          ${RELEASE_IOS_RUNTIME:-} != 26.5 ||
          ${RELEASE_WATCHOS_RUNTIME:-} != 26.5 ||
          ${RELEASE_TVOS_RUNTIME:-} != 26.5 ||
          ${RELEASE_VISIONOS_RUNTIME:-} != 26.5 ]]; then
      _petrel_release_fail "release toolchain tuple is not an exact sealed lane"
      return 1
    fi
    ;;
  *)
    _petrel_release_fail "release toolchain tuple is not an exact sealed lane"
    return 1
    ;;
esac

if [[ $_petrel_release_approved_beta == 0 ]]; then
  for _petrel_release_value in \
      "$RELEASE_DEVELOPER_DIR" "$RELEASE_XCODE_VERSION" "$RELEASE_XCODE_BUILD"; do
    if _petrel_release_has_prerelease_marker "$_petrel_release_value"; then
      _petrel_release_fail "stable release activation rejects beta, RC, preview, and seed identities"
      return 1
    fi
  done
fi

RELEASE_SWIFT="$RELEASE_DEVELOPER_DIR/Toolchains/XcodeDefault.xctoolchain/usr/bin/swift"
RELEASE_XCODEBUILD="$RELEASE_DEVELOPER_DIR/usr/bin/xcodebuild"
RELEASE_XCRUN=/usr/bin/xcrun
[[ -x $RELEASE_SWIFT ]] || {
  _petrel_release_fail "selected XcodeDefault Swift is not executable: $RELEASE_SWIFT"
  return 1
}
[[ -x $RELEASE_XCODEBUILD ]] || {
  _petrel_release_fail "selected xcodebuild is not executable: $RELEASE_XCODEBUILD"
  return 1
}
[[ -x $RELEASE_XCRUN ]] || {
  _petrel_release_fail "system xcrun is not executable: $RELEASE_XCRUN"
  return 1
}

DEVELOPER_DIR=$RELEASE_DEVELOPER_DIR
RELEASE_MINT="$ROOT/.build/release-tools/mint"
MINT_PATH="$ROOT/.build/release-tools/mint-packages"
MINT_LINK_PATH="$ROOT/.build/release-tools/mint-links"
PATH="$(dirname "$RELEASE_SWIFT"):/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
export DEVELOPER_DIR RELEASE_SWIFT RELEASE_XCODEBUILD RELEASE_XCRUN
export RELEASE_MINT MINT_PATH MINT_LINK_PATH PATH

if [[ -n ${HOME:-} ]]; then
  _petrel_release_old_ifs=$IFS
  IFS=:
  for _petrel_release_component in $PATH; do
    case $_petrel_release_component in
      "$HOME/.swiftly"|"$HOME/.swiftly/"*)
        IFS=$_petrel_release_old_ifs
        _petrel_release_fail "release PATH may not contain a component below $HOME/.swiftly"
        return 1
        ;;
    esac
  done
  IFS=$_petrel_release_old_ifs
fi

_petrel_release_xcode_output=$("$RELEASE_XCODEBUILD" -version) || return 1
_petrel_release_expected_xcode_output="Xcode $RELEASE_XCODE_VERSION
Build version $RELEASE_XCODE_BUILD"
[[ $_petrel_release_xcode_output == "$_petrel_release_expected_xcode_output" ]] || {
  _petrel_release_fail "selected Xcode identity does not match the exported release tuple"
  return 1
}
if [[ $_petrel_release_approved_beta == 0 ]] && \
    _petrel_release_has_prerelease_marker "$_petrel_release_xcode_output"; then
  _petrel_release_fail "stable release activation rejects prerelease xcodebuild output"
  return 1
fi
[[ $(command -v swift) == "$RELEASE_SWIFT" ]] || {
  _petrel_release_fail "release Swift is not first on PATH"
  return 1
}
_petrel_release_xcrun_swift=$("$RELEASE_XCRUN" --find swift) || return 1
petrel_release_same_file_identity "$RELEASE_SWIFT" "$_petrel_release_xcrun_swift" || {
  _petrel_release_fail "xcrun did not resolve the selected XcodeDefault Swift"
  return 1
}

if [[ -e $RELEASE_MINT ]]; then
  [[ -x $RELEASE_MINT ]] || {
    _petrel_release_fail "existing release Mint is not executable"
    return 1
  }
  [[ $("$RELEASE_MINT" --version | /usr/bin/tr -d '\r\n') == 'Version: 0.18.0' ]] || {
    _petrel_release_fail "existing release Mint is not exactly Version: 0.18.0"
    return 1
  }
fi

if [[ $_petrel_release_approved_beta == 1 ]]; then
  [[ $(uname -m) == arm64 ]] || {
    _petrel_release_fail "approved beta validation requires arm64"
    return 1
  }
  _petrel_release_swift_output=$("$RELEASE_SWIFT" --version 2>&1) || return 1
  _petrel_release_swift_version=$(
    printf '%s\n' "$_petrel_release_swift_output" |
      /usr/bin/sed -En 's/^.*Swift version ([0-9]+\.[0-9]+).*/\1/p' |
      /usr/bin/head -1
  )
  [[ $_petrel_release_swift_version == 6.4 ]] || {
    _petrel_release_fail "approved beta validation requires Swift 6.4"
    return 1
  }
  while IFS=$'\t' read -r _petrel_release_sdk _petrel_release_expected_sdk; do
    _petrel_release_actual_sdk=$("$RELEASE_XCRUN" --sdk "$_petrel_release_sdk" --show-sdk-version) || return 1
    [[ $_petrel_release_actual_sdk == "$_petrel_release_expected_sdk" ]] || {
      _petrel_release_fail "approved beta validation requires $_petrel_release_sdk SDK $_petrel_release_expected_sdk"
      return 1
    }
  done <<'EOF'
iphoneos	27.0
watchos	27.0
appletvos	27.0
xros	27.0
EOF
  RELEASE_VALIDATION_LABEL=xcode27-beta-local-validation
  export RELEASE_VALIDATION_LABEL
else
  unset RELEASE_VALIDATION_LABEL 2>/dev/null || true
fi

unset _petrel_release_actual_sdk _petrel_release_approved_beta
unset _petrel_release_component _petrel_release_expected_sdk _petrel_release_expected_xcode_output
unset _petrel_release_old_ifs _petrel_release_script _petrel_release_sdk
unset _petrel_release_swift_output _petrel_release_swift_version _petrel_release_value
unset _petrel_release_xcode_output
unset -f _petrel_release_fail _petrel_release_has_prerelease_marker
