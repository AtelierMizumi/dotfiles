#!/usr/bin/env bash
# Stage quickshell (and the packages its tools need) without installing anything: download the packages pacman would
# fetch from the mirror it is configured with, verify every signature against the system keyring, and unpack them into
# $RICE_STAGE/root (default ~/.cache/rice-staging/root). scripts/dev/nested-shell.sh runs quickshell from there.
# No sudo, nothing outside the staging directory is written. Re-running only fetches what is missing.
set -euo pipefail

STAGE=${RICE_STAGE:-${XDG_CACHE_HOME:-$HOME/.cache}/rice-staging}
PACKAGES=(quickshell ttf-material-symbols-variable)

mkdir -p -- "$STAGE/pkgs" "$STAGE/root"
cd -- "$STAGE/pkgs"

mapfile -t urls < <(pacman -Sp --needed "${PACKAGES[@]}")
((${#urls[@]} > 0)) || {
  echo "stage-quickshell.sh: pacman lists nothing to fetch (are the packages already installed?)" >&2
  exit 0
}

for url in "${urls[@]}"; do
  file=${url##*/}
  [[ -s "$file" ]] || curl -sfL -o "$file" -- "$url"
  [[ -s "$file.sig" ]] || curl -sfL -o "$file.sig" -- "$url.sig"
  if ! gpg --homedir /etc/pacman.d/gnupg --verify "$file.sig" "$file" 2>/dev/null; then
    echo "stage-quickshell.sh: bad signature on $file, not unpacking it" >&2
    exit 2
  fi
  # --force-local: package file names contain a colon (the epoch), which tar would take for a remote host.
  tar --force-local -xf "$file" -C "$STAGE/root" --exclude='.PKGINFO' --exclude='.BUILDINFO' --exclude='.MTREE' \
    --exclude='.INSTALL'
  echo "staged $file"
done
echo "quickshell: $STAGE/root/usr/bin/quickshell"
