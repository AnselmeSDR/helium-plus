#!/bin/bash -eu
# Helium+: merges the latest Helium release into an update/<version> branch,
# reapplies our patches (Claude Code fixes conflicts), opens a pull request and
# starts the arm64 build. Runs in GitHub Actions (helium-plus-update.yml).

cd "$(dirname "$0")/../.."
root="$PWD"
report="$root/update-report.md"

# Every other week, unless started by hand.
if [ "${GITHUB_EVENT_NAME:-}" = schedule ] && [ $((10#$(date -u +%V) % 2)) -ne 0 ]; then
  echo "odd week, nothing to do"
  exit 0
fi

git config user.name "github-actions[bot]"
git config user.email "41898282+github-actions[bot]@users.noreply.github.com"
git remote add upstream https://github.com/imputnet/helium-macos.git 2>/dev/null || true
git fetch --quiet --tags upstream main

if git merge-base --is-ancestor upstream/main HEAD; then
  echo "already up to date with Helium"
  exit 0
fi

version=$(git describe --tags --abbrev=0 upstream/main)
branch="update/$version"
if git ls-remote --exit-code --heads origin "$branch" >/dev/null; then
  echo "$branch already exists"
  exit 0
fi
git switch -c "$branch"

run_claude() {
  npm install --global --silent @anthropic-ai/claude-code
  claude -p "$(cat "$root/.github/helium-plus/resolve-conflicts.md")" \
    --dangerously-skip-permissions --max-turns 200
}

if ! git merge --no-edit upstream/main; then
  run_claude
  if [ -n "$(git diff --name-only --diff-filter=U)" ]; then
    echo "merge conflicts left after Claude" >&2
    exit 1
  fi
  git commit --no-edit
fi
git submodule update --init --recursive

# Chromium sources, then every patch with quilt, as in a local `he setup`.
brew install quilt coreutils zstd
pip3 install requests --break-system-packages --quiet
source ./devutils/shared.sh
fetch_sources true
rm -rf "$_download_cache"
python3 "$_main_repo/utils/prune_binaries.py" --keep-build-dependencies \
  "$_src_dir" "$_main_repo/pruning.list"
./devutils/update_patches.sh merge

export QUILT_PATCHES="$root/patches" QUILT_SERIES=series.merged
export QUILT_PATCH_OPTS="--unified --reject-format=unified"
export QUILT_DIFF_ARGS="-p ab --no-timestamps --no-index"
export QUILT_REFRESH_ARGS="-p ab --no-timestamps --no-index"
if ! (cd "$_src_dir" && quilt --quiltrc - push -a -q); then
  run_claude
fi
if (cd "$_src_dir" && quilt --quiltrc - next >/dev/null 2>&1); then
  echo "some patches still do not apply" >&2
  exit 1
fi

./devutils/update_patches.sh unmerge
git add patches
if ! git diff --cached --quiet; then
  git commit -m "fix: refresh Helium+ patches for Helium $version"
fi
git push origin "$branch"

{
  echo "Mise à jour vers Helium $version, build arm64 en cours."
  echo
  echo "@AnselmeSDR : je te préviens ici quand l'app est prête à tester."
  if [ -f "$report" ]; then
    echo
    cat "$report"
  fi
} > pr-body.md
pr_url=$(gh pr create --base main --head "$branch" \
  --title "$branch: mise à jour vers Helium $version" --body-file pr-body.md)
gh workflow run helium-plus-build.yml --ref "$branch" -f pr="$pr_url"
