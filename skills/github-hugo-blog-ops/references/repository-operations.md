# Repository Operations

## Repository Facts

- Repository root: current project root (directory containing `hugo.toml`)
- Posts directory: `content/posts/`
- Archetype: `archetypes/default.md`
- Hugo config: `hugo.toml`
- Deployment workflow: `.github/workflows/hugo.yml`
- Theme submodule: `themes/github-style`
- Default publish branch: `main`

## Publish Pipeline

1. Edit or create markdown in `content/posts/`.
2. Ensure front matter has `draft = false` for posts to publish.
3. Run quality gates (`blogctl.sh doctor`, `blogctl.sh check`, `blogctl.sh seo`) before push.
4. Deploy either:
5. Direct deploy to `main` with `blogctl.sh safe-deploy --push`
6. PR-based deploy with `blogctl.sh pr-flow` then merge PR to `main`
7. GitHub Actions workflow `Deploy Hugo site to Pages` builds and deploys the site.

## Front Matter Conventions In This Repo

- Front matter uses TOML delimited by `+++`.
- Common keys:
- `title`
- `date`
- `draft`
- `summary`
- Optional keys:
- `author`
- `keywords`
- `pin`
- `lastmod`

## Maintenance Checklist

- Run `blogctl.sh bootstrap` after cloning or when submodule/tooling drift is suspected.
- Run `blogctl.sh maintain` to inspect repo status and dependencies.
- Run `blogctl.sh list draft` to identify unpublished content.
- Run `blogctl.sh schedule list` to inspect future-dated posts.
- Run `blogctl.sh update-theme` when updating `themes/github-style`.
- Run `blogctl.sh check` after config/theme/content updates.
- Run `blogctl.sh media audit` and `blogctl.sh media normalize --apply` for image hygiene.
- Run `blogctl.sh seo` before publishing important posts.
- Use `blogctl.sh safe-deploy --dry-run` before actual production pushes.
- Commit and push only intentional changes.

## Command Quick Reference

- `new`: Create draft markdown with front matter.
- `publish` / `unpublish`: Toggle post visibility state.
- `list`: Show draft/published inventory.
- `check`: Build Hugo site locally.
- `doctor`: Detect front matter/link/build quality issues.
- `preview`: Run local Hugo server for review.
- `schedule`: List future posts or publish due drafts.
- `media`: Audit/normalize/compress local media assets.
- `seo`: Validate post metadata and generated SEO artifacts.
- `safe-deploy`: Deploy with a safety tag and optional push.
- `safe-deploy rollback`: Revert commits after a tag.
- `pr-flow`: Branch/commit/push and optional PR creation.
