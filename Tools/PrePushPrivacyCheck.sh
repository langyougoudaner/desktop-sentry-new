#!/bin/bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

failed=0

report_paths() {
    local heading="$1"
    local paths="$2"
    [[ -z "$paths" ]] && return
    echo "PRIVACY CHECK FAILED: $heading" >&2
    printf '%s\n' "$paths" >&2
    failed=1
}

tracked_paths="$(git ls-files)"
forbidden_paths="$(printf '%s\n' "$tracked_paths" | grep -E '(^|/)(build|DerivedData|backups|credentials|private)/|^docs/product/approved/evidence/|\.(app|app\.backup|dmg|zip|xcarchive|mov|log|pem|key|p12|mobileprovision)$|(^|/)(data|deadlines|task-calendar-v5)(\.[^/]*)?\.json$' || true)"
report_paths "forbidden generated, runtime, backup, credential, or evidence paths are tracked" "$forbidden_paths"

# The checker contains these detection expressions, so exclude only this file
# from content matching. Its path and size remain covered by the other checks.
secret_pattern="-----BEGIN (RSA |OPENSSH |EC |DSA )?PRIVATE KEY-----|github_pat_[A-Za-z0-9_]{20,}|gh[opurs]_[A-Za-z0-9]{20,}|AKIA[0-9A-Z]{16}|ASIA[0-9A-Z]{16}|xox[baprs]-[A-Za-z0-9-]{10,}|sk-[A-Za-z0-9]{20,}|AIza[0-9A-Za-z_-]{30,}"
secret_files="$(git grep -I -l -E "$secret_pattern" -- . ':(exclude)Tools/PrePushPrivacyCheck.sh' 2>/dev/null || true)"
report_paths "credential-like content found (values intentionally hidden)" "$secret_files"

machine_path_pattern="/Users/[^/[:space:]]+|/var/folders/|/private/var/"
machine_path_files="$(git grep -I -l -E "$machine_path_pattern" -- . ':(exclude)Tools/PrePushPrivacyCheck.sh' 2>/dev/null || true)"
report_paths "machine-local absolute paths found" "$machine_path_files"

outgoing_revisions=("$@")
if (( ${#outgoing_revisions[@]} == 0 )); then
    while IFS= read -r revision; do
        [[ -n "$revision" ]] && outgoing_revisions+=("$revision")
    done < <(git rev-list HEAD --not --remotes 2>/dev/null || true)
fi

local_identity_commits=""
for revision in "${outgoing_revisions[@]}"; do
    identity="$(git show -s --format='%ae%n%ce' "$revision" 2>/dev/null || true)"
    if printf '%s\n' "$identity" | grep -Eiq '@[^[:space:]]+\.local$'; then
        local_identity_commits+="${revision}"$'\n'
    fi
done
report_paths "machine-local Git author or committer identity found" \
    "${local_identity_commits%$'\n'}"

large_files=""
while IFS= read -r path; do
    [[ -f "$path" ]] || continue
    bytes="$(stat -f '%z' "$path")"
    if (( bytes > 10 * 1024 * 1024 )); then
        large_files+="${path} (${bytes} bytes)"$'\n'
    fi
done <<< "$tracked_paths"
report_paths "tracked files larger than 10 MiB require explicit review" "${large_files%$'\n'}"

if (( failed != 0 )); then
    exit 1
fi

echo "privacy-check=passed"
echo "tracked-files=$(printf '%s\n' "$tracked_paths" | sed '/^$/d' | wc -l | tr -d ' ')"
