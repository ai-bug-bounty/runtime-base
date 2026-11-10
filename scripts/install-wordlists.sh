#!/usr/bin/env bash
# Wordlists: Kali's `wordlists` package (rockyou, dirb, john) plus a *curated*
# set of SecLists files.
#
# Kali's `seclists` package is 1.8 GB, and almost none of it is for the web:
# the User-Agents tree alone is over 300 MB, the CMS lists 105 MB, `dutch` 42 MB,
# Passwords 624 MB, Miscellaneous 248 MB. These are the files that actually get
# used — directory and file discovery, API endpoints, parameter names, a DNS
# list, a common-password list and a few fuzzing payloads — about 7 MB in total.
# A task that wants the rest can still `apt install seclists`, or fetch a single
# list from the SecLists repository.
#
# The layout is SecLists' own (/usr/share/seclists/...), so the paths tools
# document (`-w /usr/share/seclists/Discovery/Web-Content/raft-medium-directories.txt`)
# are the ones that work.
set -euo pipefail

SECLISTS_ROOT=/usr/share/seclists
# Pinned to a release tag: a file renamed upstream would otherwise break the
# build at a random moment. Bump this deliberately (`curl -s
# https://api.github.com/repos/danielmiessler/SecLists/tags | head`).
SECLISTS_TAG=2026.2
SECLISTS_RAW="https://raw.githubusercontent.com/danielmiessler/SecLists/${SECLISTS_TAG}"

files=(
  # directory / file discovery
  "Discovery/Web-Content/common.txt"
  "Discovery/Web-Content/raft-small-directories.txt"
  "Discovery/Web-Content/raft-small-files.txt"
  "Discovery/Web-Content/raft-medium-directories.txt"
  "Discovery/Web-Content/raft-medium-files.txt"
  "Discovery/Web-Content/LinuxFileList.txt"
  # parameters, endpoints, hints
  "Discovery/Web-Content/burp-parameter-names.txt"
  "Discovery/Web-Content/quickhits.txt"
  "Discovery/Web-Content/api/api-endpoints.txt"
  "Discovery/Web-Content/api/objects.txt"
  # DNS
  "Discovery/DNS/subdomains-top1million-5000.txt"
  # credentials
  "Passwords/Common-Credentials/100k-most-used-passwords-NCSC.txt"
  "Usernames/top-usernames-shortlist.txt"
  # fuzzing payloads
  "Fuzzing/command-injection-commix.txt"
  "Fuzzing/LFI/LFI-Jhaddix.txt"
)

mkdir -p /opt/payloads /usr/share/wordlists "${SECLISTS_ROOT}"

echo "==> ${#files[@]} SecLists files from ${SECLISTS_TAG} (the full collection is 1.8 GB)"
for path in "${files[@]}"; do
  target="${SECLISTS_ROOT}/${path}"
  mkdir -p "$(dirname "${target}")"
  curl -fsSL --retry 3 --create-dirs -o "${target}.part" "${SECLISTS_RAW}/${path}"
  mv "${target}.part" "${target}"
done
du -sh "${SECLISTS_ROOT}"

# Tools that predate SecLists look under /usr/share/wordlists.
ln -sfn "${SECLISTS_ROOT}" /usr/share/wordlists/seclists
echo "==> rockyou (Kali ships it gzipped; tools read .gz)"
ls /usr/share/wordlists/rockyou.txt* 2>/dev/null || echo "note: no rockyou in /usr/share/wordlists"

echo "==> PayloadsAllTheThings"
if [ ! -d /opt/payloads/PayloadsAllTheThings/.git ]; then
  git clone --depth 1 \
    https://github.com/swisskyrepo/PayloadsAllTheThings.git \
    /opt/payloads/PayloadsAllTheThings
fi
rm -rf /opt/payloads/PayloadsAllTheThings/.git
du -sh /opt/payloads/PayloadsAllTheThings
