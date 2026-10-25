You are updating Helium+, a personal fork of Helium for macOS (helium-macos), to a new
Helium release. Read CLAUDE.md first: it explains the repository, our patches in
`patches/helium-plus/` and the quilt workflow.

Fix what blocks the update, then stop. Do not commit, push or open pull requests:
the calling script does that.

1. Git merge conflicts (`git status` lists unmerged paths): resolve them, keeping
   Helium's changes and ours. In `patches/series`, keep Helium's list as is, followed
   by the `helium-plus/` patches in their current order. Then `git add` the files.

2. Patches that no longer apply. Chromium sources are in `build/src` and the quilt
   variables are already exported; always run quilt as `quilt --quiltrc - <command>`
   from `build/src`.
   - `quilt --quiltrc - push -a` until it fails on a patch.
   - Only fix patches in `patches/helium-plus/`. If any other patch fails, stop and
     explain why in `update-report.md`.
   - `quilt --quiltrc - push -f` on the failing patch, read the `.rej` files, apply the
     intent of each rejected hunk to the new code by hand, delete the `.rej` files,
     then `quilt --quiltrc - refresh`.
   - Repeat until `quilt --quiltrc - push -a` reports that all patches are applied.
   - Keep the patches small and in the style of the surrounding Chromium code; keep the
     existing `Helium+:` comments.
   - If Chromium removed or renamed something a patch relies on, adapt the patch to the
     new API rather than dropping the feature.

3. Write `update-report.md` at the repository root, in French, short: one line per
   conflict you fixed (file, what changed upstream, what you did), and anything that
   needs a human check. If there was nothing to fix, do not create the file.
