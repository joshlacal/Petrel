#!/usr/bin/env bash

# Compare filesystem object identity instead of path spelling. Xcode runner
# inventory may expose the selected tool through a symlink or path alias.
petrel_release_same_file_identity() {
  local left_identity right_identity
  [[ $# -eq 2 && -e $1 && -e $2 ]] || return 1
  left_identity=$(/usr/bin/stat -L -f '%d:%i' -- "$1") || return 1
  right_identity=$(/usr/bin/stat -L -f '%d:%i' -- "$2") || return 1
  [[ $left_identity == "$right_identity" ]]
}
