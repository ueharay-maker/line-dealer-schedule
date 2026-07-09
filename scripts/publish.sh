#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

REPO="ueharay-maker/line-dealer-schedule"
MESSAGE="${1:-Update LINE dealer schedule}"

if [[ ! -f deploy/index.html ]]; then
  echo "deploy/index.html not found" >&2
  exit 1
fi

REVISION="$(date +%Y-%m-%d-%H%M)"
perl -0pi -e "s/<meta name=\"deploy-revision\" content=\"[^\"]*\" \\/>/<meta name=\"deploy-revision\" content=\"$REVISION\" \/>/" deploy/index.html

cp deploy/index.html docs/index.html
touch docs/.nojekyll

git add deploy/index.html docs/index.html docs/.nojekyll

if git diff --staged --quiet; then
  echo "No changes to publish."
  exit 0
fi

git commit -m "$MESSAGE"

pull_latest() {
  if git diff --quiet && git diff --staged --quiet; then
    git pull --rebase origin main
    return $?
  fi
  return 1
}

push_with_gh() {
  if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
    git push origin main
    return $?
  fi
  return 1
}

push_with_token() {
  local token="${GITHUB_TOKEN:-${GH_TOKEN:-}}"
  if [[ -n "$token" ]]; then
    git push "https://x-access-token:${token}@github.com/${REPO}.git" main
    return $?
  fi
  return 1
}

if pull_latest; then
  echo "Synced with origin/main."
else
  echo "Skipped pull because the working tree is not clean after commit."
fi

if push_with_gh || push_with_token; then
  echo "Published to https://ueharay-maker.github.io/line-dealer-schedule/"
  echo "GitHub Pages rebuild usually finishes within 1-3 minutes."
  exit 0
fi

echo ""
echo "Commit created locally, but push failed."
echo "Run once: gh auth login"
echo "Or set GITHUB_TOKEN, then run this script again."
echo ""
echo "Manual fallback:"
echo "  https://github.com/${REPO}/upload/main/docs"
exit 1
