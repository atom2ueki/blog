---
name: github-hugo-blog-ops
description: Operate a GitHub-hosted Hugo blog repository end-to-end. Use when tasks include creating/editing drafts in content/posts, publishing/unpublishing posts, running quality gates (doctor/seo/media checks), previewing or scheduling content, deploying safely with rollback tags, opening PR-based publish flows, or maintaining theme/workflow infrastructure.
---

# GitHub Hugo Blog Ops

Use this skill to execute repeatable blog workflows safely through `scripts/blogctl.sh`.

## Quick Start

- Run commands from repo root.
- Use `skills/github-hugo-blog-ops/scripts/blogctl.sh`.
- Export `BLOG_ROOT` if running the script from outside this repo.

```bash
export BLOG_ROOT=/path/to/your/blog-repo
skills/github-hugo-blog-ops/scripts/blogctl.sh list
```

## Workflow Decision

- Draft or edit content: Use `new`, then edit markdown in `content/posts/*.md`.
- Publish content directly on `main`: Use `publish`, `check`, then `safe-deploy --push`.
- Publish via PR: Use `pr-flow` (recommended when review is required).
- Maintain infrastructure: Use `bootstrap`, `maintain`, `update-theme`, and `doctor`.
- QA/SEO/media cleanup: Use `doctor`, `seo`, and `media`.

## Create Drafts

Use `new` to generate a correctly formatted TOML front matter block.

```bash
skills/github-hugo-blog-ops/scripts/blogctl.sh new \
  --title "Install FFmpeg on macOS (2026 Update)" \
  --summary "Practical ffmpeg install and verification commands for macOS." \
  --keywords "ffmpeg,macos,video" \
  --pin
```

Then write or revise the body in the created markdown file under `content/posts/`.

## Publish Posts

Use `publish` to flip `draft` to `false` and set `lastmod`.

```bash
skills/github-hugo-blog-ops/scripts/blogctl.sh publish install-ffmpeg-on-macos
skills/github-hugo-blog-ops/scripts/blogctl.sh check
skills/github-hugo-blog-ops/scripts/blogctl.sh safe-deploy --message "Publish ffmpeg guide updates" --push
```

Use `unpublish` to move a live post back to draft mode.

## New Operational Commands

- `bootstrap`: Initialize submodules and environment sanity checks.
- `doctor`: Validate front matter, links, markdown quality, and build health.
- `preview`: Run local Hugo preview with drafts/future content support.
- `schedule list`: Show future posts via Hugo listing.
- `schedule publish-due`: Auto-publish due drafts based on `date`.
- `media audit`: Find empty image alt text and non-kebab local image names.
- `media normalize`: Rename local media filenames to kebab-case and update references.
- `media compress`: Compress large local images (threshold-based).
- `seo`: Audit title/summary lengths, canonical fields, OG cover, sitemap/robots.
- `safe-deploy`: Check + commit + tag + optional push, with rollback support.
- `pr-flow`: Create branch, commit, push, and optionally open GitHub PR.

## PR Flow Example

```bash
skills/github-hugo-blog-ops/scripts/blogctl.sh doctor
skills/github-hugo-blog-ops/scripts/blogctl.sh pr-flow \
  --branch "post/ffmpeg-2026-update" \
  --message "post: ffmpeg 2026 update" \
  --title "Update ffmpeg install guide" \
  --body "Refresh steps and verification commands."
```

Use `--dry-run` first for `safe-deploy` and `pr-flow` to preview actions safely.

## Maintenance Tasks

Use `maintain` for repository health signals:

- git working tree summary
- submodule status for `themes/github-style`
- presence of `.github/workflows/hugo.yml`
- local Hugo installation status

Use `update-theme` to fast-forward the theme submodule and prepare a commit.

```bash
skills/github-hugo-blog-ops/scripts/blogctl.sh bootstrap --update-theme
skills/github-hugo-blog-ops/scripts/blogctl.sh doctor
skills/github-hugo-blog-ops/scripts/blogctl.sh update-theme
skills/github-hugo-blog-ops/scripts/blogctl.sh check
skills/github-hugo-blog-ops/scripts/blogctl.sh safe-deploy --message "Update theme submodule" --push
```

## Guardrails

- Avoid manual front matter toggles when `blogctl.sh` can do it deterministically.
- Run `doctor` and `check` before `safe-deploy --push`.
- Keep publishing on `main` because GitHub Pages deployment is triggered by pushes to `main`.
- Prefer `pr-flow` over direct pushes when review/approval is needed.
- Keep commits scoped to blog changes; avoid unrelated edits in publish commits.
- Use `safe-deploy rollback --dry-run` before real rollback.

## Reference File

Load `references/repository-operations.md` for path conventions, deployment mechanics, and maintenance checklist.
