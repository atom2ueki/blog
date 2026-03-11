#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="${BLOG_ROOT:-$(pwd)}"
POSTS_DIR="${ROOT_DIR}/content/posts"
STATIC_IMAGES_DIR="${ROOT_DIR}/static/images"


die() {
  echo "Error: $*" >&2
  exit 1
}

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

current_branch() {
  (
    cd "${ROOT_DIR}"
    git rev-parse --abbrev-ref HEAD
  )
}

usage() {
  cat <<'USAGE'
Usage:
  blogctl.sh new --title "Title" [--slug "slug"] [--summary "text"] [--author "name"] [--keywords "a,b"] [--pin]
  blogctl.sh publish <slug-or-path> [--date-now]
  blogctl.sh unpublish <slug-or-path>
  blogctl.sh list [draft|published|all]
  blogctl.sh check [--with-drafts]
  blogctl.sh deploy [--message "msg"] [--push]
  blogctl.sh bootstrap [--update-theme]
  blogctl.sh doctor [--strict] [--skip-build]
  blogctl.sh preview [--port 1313] [--bind 127.0.0.1] [--no-drafts] [--no-future]
  blogctl.sh schedule [list|publish-due] [--dry-run]
  blogctl.sh media [audit|normalize|compress] [options]
  blogctl.sh seo [--strict] [--with-drafts]
  blogctl.sh safe-deploy [--message "msg"] [--tag-prefix "release"] [--push] [--skip-check] [--dry-run]
  blogctl.sh safe-deploy rollback [--tag "tag-name"] [--push] [--dry-run]
  blogctl.sh pr-flow [--branch "name"] [--message "msg"] [--title "PR title"] [--body "PR body"] [--base main] [--no-open-pr] [--skip-check] [--dry-run]
  blogctl.sh maintain
  blogctl.sh update-theme
USAGE
}

require_repo() {
  [[ -f "${ROOT_DIR}/hugo.toml" ]] || die "hugo.toml not found under ${ROOT_DIR}. Set BLOG_ROOT correctly."
  [[ -d "${POSTS_DIR}" ]] || die "Posts directory missing: ${POSTS_DIR}"
}

iso_now() {
  date "+%Y-%m-%dT%H:%M:%S%z" | sed -E 's/([+-][0-9]{2})([0-9]{2})$/\1:\2/'
}

escape_toml_single() {
  printf '%s' "${1}" | sed "s/'/''/g"
}

slugify() {
  local input
  input="$(printf '%s' "${1}" | tr '[:upper:]' '[:lower:]')"
  input="$(printf '%s' "${input}" | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//')"
  printf '%s\n' "${input}"
}

build_keywords_line() {
  local raw="${1:-}"
  local out=""
  local item=""
  local cleaned=""
  local escaped=""

  if [[ -z "${raw}" ]]; then
    printf 'keywords = []\n'
    return
  fi

  IFS=',' read -r -a items <<< "${raw}"
  for item in "${items[@]}"; do
    cleaned="$(printf '%s' "${item}" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')"
    [[ -z "${cleaned}" ]] && continue
    escaped="$(escape_toml_single "${cleaned}")"
    if [[ -n "${out}" ]]; then
      out="${out}, "
    fi
    out="${out}'${escaped}'"
  done

  if [[ -z "${out}" ]]; then
    printf 'keywords = []\n'
  else
    printf 'keywords = [%s]\n' "${out}"
  fi
}

has_toml_frontmatter() {
  local file="${1}"
  local count=""

  [[ "$(head -n 1 "${file}")" == "+++" ]] || return 1
  count="$(grep -n '^+++$' "${file}" | head -n 2 | wc -l | tr -d '[:space:]')"
  [[ "${count}" -ge 2 ]]
}

set_frontmatter_value() {
  local file="${1}"
  local key="${2}"
  local value="${3}"
  local tmp=""

  tmp="$(mktemp "${TMPDIR:-/tmp}/blogctl.XXXXXX")"
  awk -v key="${key}" -v value="${value}" '
NR == 1 && $0 == "+++" {
  in_fm = 1
  print
  next
}
in_fm && $0 == "+++" {
  if (!replaced) {
    print key " = " value
  }
  in_fm = 0
  print
  next
}
in_fm && $0 ~ ("^[[:space:]]*" key "[[:space:]]*=") {
  print key " = " value
  replaced = 1
  next
}
{
  print
}
' "${file}" > "${tmp}"
  mv "${tmp}" "${file}"
}

resolve_post_path() {
  local input="${1}"
  local slug=""
  local candidate=""

  if [[ -f "${input}" ]]; then
    printf '%s\n' "${input}"
    return
  fi

  if [[ -f "${ROOT_DIR}/${input}" ]]; then
    printf '%s\n' "${ROOT_DIR}/${input}"
    return
  fi

  slug="${input##*/}"
  slug="${slug%.md}"
  candidate="${POSTS_DIR}/${slug}.md"
  [[ -f "${candidate}" ]] || die "Post not found: ${input}"
  printf '%s\n' "${candidate}"
}

extract_frontmatter_value() {
  local file="${1}"
  local key="${2}"

  awk -v key="${key}" '
NR == 1 && $0 == "+++" {
  in_fm = 1
  next
}
in_fm && $0 == "+++" {
  exit
}
in_fm && $0 ~ ("^[[:space:]]*" key "[[:space:]]*=") {
  sub("^[[:space:]]*" key "[[:space:]]*=[[:space:]]*", "", $0)
  print
  exit
}
' "${file}"
}

strip_quotes() {
  local value="${1}"

  value="${value%\'}"
  value="${value#\'}"
  value="${value%\"}"
  value="${value#\"}"
  printf '%s\n' "${value}"
}

is_due_datetime() {
  local raw="${1:-}"

  python3 - "${raw}" <<'PY'
import datetime as dt
import sys

raw = sys.argv[1].strip().strip("'").strip('"')
if not raw:
    raise SystemExit(1)

candidate = None
try:
    candidate = dt.datetime.fromisoformat(raw)
except Exception:
    try:
        d = dt.date.fromisoformat(raw)
        candidate = dt.datetime.combine(d, dt.time.min, tzinfo=dt.timezone.utc)
    except Exception:
        raise SystemExit(1)

if candidate.tzinfo is None:
    candidate = candidate.replace(tzinfo=dt.timezone.utc)

now_utc = dt.datetime.now(dt.timezone.utc)
raise SystemExit(0 if candidate.astimezone(dt.timezone.utc) <= now_utc else 1)
PY
}

cmd_new() {
  local title=""
  local slug=""
  local summary=""
  local author=""
  local keywords=""
  local pin="false"
  local file=""
  local ts=""
  local escaped_title=""
  local escaped_summary=""
  local escaped_author=""
  local keywords_line=""

  while [[ $# -gt 0 ]]; do
    case "${1}" in
      --title)
        title="${2:-}"
        shift 2
        ;;
      --slug)
        slug="${2:-}"
        shift 2
        ;;
      --summary)
        summary="${2:-}"
        shift 2
        ;;
      --author)
        author="${2:-}"
        shift 2
        ;;
      --keywords)
        keywords="${2:-}"
        shift 2
        ;;
      --pin)
        pin="true"
        shift
        ;;
      *)
        die "Unknown option for new: ${1}"
        ;;
    esac
  done

  [[ -n "${title}" ]] || die "--title is required"

  if [[ -z "${slug}" ]]; then
    slug="$(slugify "${title}")"
  fi
  [[ -n "${slug}" ]] || die "Failed to generate slug. Pass --slug explicitly."

  file="${POSTS_DIR}/${slug}.md"
  [[ ! -e "${file}" ]] || die "Post already exists: ${file}"

  ts="$(iso_now)"
  escaped_title="$(escape_toml_single "${title}")"
  escaped_summary="$(escape_toml_single "${summary}")"
  escaped_author="$(escape_toml_single "${author}")"
  keywords_line="$(build_keywords_line "${keywords}")"

  cat > "${file}" <<EOF
+++
title = '${escaped_title}'
date = ${ts}
draft = true
author = '${escaped_author}'
${keywords_line}summary = '${escaped_summary}'
pin = ${pin}
+++

EOF

  echo "Created draft: ${file}"
}

cmd_publish() {
  local target="${1:-}"
  local file=""
  local date_now="false"
  local ts=""

  [[ -n "${target}" ]] || die "publish requires <slug-or-path>"
  shift || true

  while [[ $# -gt 0 ]]; do
    case "${1}" in
      --date-now)
        date_now="true"
        shift
        ;;
      *)
        die "Unknown option for publish: ${1}"
        ;;
    esac
  done

  file="$(resolve_post_path "${target}")"
  has_toml_frontmatter "${file}" || die "Expected TOML front matter in ${file}"

  ts="$(iso_now)"
  set_frontmatter_value "${file}" "draft" "false"
  set_frontmatter_value "${file}" "lastmod" "${ts}"
  if [[ "${date_now}" == "true" ]]; then
    set_frontmatter_value "${file}" "date" "${ts}"
  fi

  echo "Published: ${file}"
}

cmd_unpublish() {
  local target="${1:-}"
  local file=""
  local ts=""

  [[ -n "${target}" ]] || die "unpublish requires <slug-or-path>"
  file="$(resolve_post_path "${target}")"
  has_toml_frontmatter "${file}" || die "Expected TOML front matter in ${file}"

  ts="$(iso_now)"
  set_frontmatter_value "${file}" "draft" "true"
  set_frontmatter_value "${file}" "lastmod" "${ts}"

  echo "Marked as draft: ${file}"
}

cmd_list() {
  local mode="${1:-all}"
  local file=""
  local title=""
  local draft=""
  local line=""

  case "${mode}" in
    all|draft|published)
      ;;
    *)
      die "list mode must be one of: draft, published, all"
      ;;
  esac

  shopt -s nullglob
  for file in "${POSTS_DIR}"/*.md; do
    title="$(extract_frontmatter_value "${file}" "title")"
    draft="$(extract_frontmatter_value "${file}" "draft")"
    title="$(strip_quotes "${title:-}")"
    draft="$(strip_quotes "${draft:-}")"
    [[ -n "${draft}" ]] || draft="unknown"

    if [[ "${mode}" == "draft" && "${draft}" != "true" ]]; then
      continue
    fi
    if [[ "${mode}" == "published" && "${draft}" != "false" ]]; then
      continue
    fi

    line="$(basename "${file}")"
    printf '%s\t%s\t%s\n' "${line}" "${draft}" "${title}"
  done | sort
  shopt -u nullglob
}

cmd_check() {
  local with_drafts="false"
  local -a args=()

  while [[ $# -gt 0 ]]; do
    case "${1}" in
      --with-drafts)
        with_drafts="true"
        shift
        ;;
      *)
        die "Unknown option for check: ${1}"
        ;;
    esac
  done

  command_exists hugo || die "hugo is not installed. Install Hugo first."

  args=(--gc --minify)
  if [[ "${with_drafts}" == "true" ]]; then
    args+=(--buildDrafts --buildFuture)
  fi

  (
    cd "${ROOT_DIR}"
    hugo "${args[@]}"
  )
  echo "Hugo check completed."
}

cmd_deploy() {
  local message="blog: update content"
  local push="false"

  while [[ $# -gt 0 ]]; do
    case "${1}" in
      --message)
        message="${2:-}"
        shift 2
        ;;
      --push)
        push="true"
        shift
        ;;
      *)
        die "Unknown option for deploy: ${1}"
        ;;
    esac
  done

  (
    cd "${ROOT_DIR}"
    git add -A
    if git diff --cached --quiet; then
      echo "No staged changes to commit."
      exit 0
    fi

    git commit -m "${message}"
    if [[ "${push}" == "true" ]]; then
      git push origin main
      echo "Changes pushed to origin/main."
    else
      echo "Committed locally. Push with: git push origin main"
    fi
  )
}

cmd_bootstrap() {
  local update_theme="false"

  while [[ $# -gt 0 ]]; do
    case "${1}" in
      --update-theme)
        update_theme="true"
        shift
        ;;
      *)
        die "Unknown option for bootstrap: ${1}"
        ;;
    esac
  done

  (
    cd "${ROOT_DIR}"
    if ! git submodule update --init --recursive; then
      echo "WARN: submodule init/update failed. Check git permissions and network."
    fi
    if [[ "${update_theme}" == "true" ]]; then
      if ! git submodule update --remote --merge themes/github-style; then
        echo "WARN: theme remote update failed. Check network or submodule permissions."
      fi
    fi
  )

  [[ -d "${ROOT_DIR}/themes/github-style" ]] || die "Theme submodule missing: themes/github-style"

  if command_exists hugo; then
    hugo version | head -n 1
  else
    echo "WARN: hugo is not installed."
  fi

  if [[ -f "${ROOT_DIR}/package-lock.json" ]] && ! command_exists npm; then
    echo "WARN: package-lock.json exists but npm is not installed."
  fi

  echo "Bootstrap completed."
}

cmd_doctor() {
  local strict="false"
  local skip_build="false"
  local errors=0
  local warnings=0
  local file=""
  local key=""
  local value=""
  local tmp_out=""

  while [[ $# -gt 0 ]]; do
    case "${1}" in
      --strict)
        strict="true"
        shift
        ;;
      --skip-build)
        skip_build="true"
        shift
        ;;
      *)
        die "Unknown option for doctor: ${1}"
        ;;
    esac
  done

  echo "Doctor checks:"

  [[ -f "${ROOT_DIR}/hugo.toml" ]] || {
    echo "ERROR: Missing hugo.toml"
    errors=$((errors + 1))
  }
  [[ -f "${ROOT_DIR}/.github/workflows/hugo.yml" ]] || {
    echo "ERROR: Missing .github/workflows/hugo.yml"
    errors=$((errors + 1))
  }
  [[ -d "${ROOT_DIR}/themes/github-style" ]] || {
    echo "ERROR: Missing themes/github-style"
    errors=$((errors + 1))
  }

  shopt -s nullglob
  for file in "${POSTS_DIR}"/*.md; do
    if ! has_toml_frontmatter "${file}"; then
      echo "ERROR: $(basename "${file}") has invalid or missing TOML front matter"
      errors=$((errors + 1))
      continue
    fi

    for key in title date summary draft; do
      value="$(extract_frontmatter_value "${file}" "${key}" || true)"
      value="$(strip_quotes "${value:-}")"
      if [[ -z "${value}" ]]; then
        echo "ERROR: $(basename "${file}") missing required front matter key '${key}'"
        errors=$((errors + 1))
      fi
    done

    while IFS= read -r line; do
      [[ -z "${line}" ]] && continue
      echo "WARN: ${file}:${line} empty image alt text"
      warnings=$((warnings + 1))
    done < <(rg -n '!\[\s*\]\(' "${file}" --no-heading || true)
  done
  shopt -u nullglob

  while IFS=$'\t' read -r severity location target; do
    [[ -z "${severity}" ]] && continue
    case "${severity}" in
      ERROR)
        echo "ERROR: ${location} unresolved local link: ${target}"
        errors=$((errors + 1))
        ;;
      WARN)
        echo "WARN: ${location} ${target}"
        warnings=$((warnings + 1))
        ;;
    esac
  done < <(python3 - "${POSTS_DIR}" "${ROOT_DIR}" <<'PY'
import pathlib
import re
import sys

posts_dir = pathlib.Path(sys.argv[1])
root_dir = pathlib.Path(sys.argv[2])
link_pattern = re.compile(r'!?\[[^\]]*\]\(([^)]+)\)')


def is_external(target: str) -> bool:
    lowered = target.lower()
    return lowered.startswith(("http://", "https://", "mailto:", "tel:", "#", "javascript:"))


def normalize_target(raw: str) -> str:
    token = raw.strip().split()[0] if raw.strip() else ""
    token = token.strip("<>")
    return token.split("#", 1)[0].split("?", 1)[0]

for post in sorted(posts_dir.glob("*.md")):
    try:
        lines = post.read_text(encoding="utf-8").splitlines()
    except Exception:
        continue
    for lineno, line in enumerate(lines, start=1):
        for match in link_pattern.finditer(line):
            target = normalize_target(match.group(1))
            if not target or is_external(target):
                continue
            if "{{" in target or "{<" in target:
                continue

            if target.startswith("/"):
                static_candidate = root_dir / "static" / target.lstrip("/")
                content_candidate = root_dir / "content" / target.lstrip("/")
                if static_candidate.exists() or content_candidate.exists():
                    continue
                if pathlib.PurePosixPath(target).suffix == "":
                    continue
                print(f"ERROR\t{post}:{lineno}\t{target}")
                continue

            rel_candidate = (post.parent / target).resolve()
            if rel_candidate.exists():
                continue
            if pathlib.PurePosixPath(target).suffix == "":
                continue
            print(f"ERROR\t{post}:{lineno}\t{target}")
PY
)

  if [[ "${skip_build}" == "false" ]]; then
    if command_exists hugo; then
      tmp_out="$(mktemp "${TMPDIR:-/tmp}/blogctl-doctor.XXXXXX")"
      if ! (
        cd "${ROOT_DIR}"
        hugo --gc --minify --buildDrafts --buildFuture >"${tmp_out}" 2>&1
      ); then
        echo "ERROR: hugo build failed during doctor check"
        cat "${tmp_out}"
        errors=$((errors + 1))
      fi
      rm -f "${tmp_out}"
    else
      echo "WARN: hugo command not found; skipped build check"
      warnings=$((warnings + 1))
    fi
  fi

  if command_exists markdownlint; then
    if ! markdownlint "${POSTS_DIR}"/*.md >/dev/null 2>&1; then
      echo "WARN: markdownlint reported issues"
      warnings=$((warnings + 1))
    fi
  fi

  echo "Doctor summary: ${errors} error(s), ${warnings} warning(s)"

  if (( errors > 0 )); then
    return 1
  fi
  if [[ "${strict}" == "true" ]] && (( warnings > 0 )); then
    return 1
  fi
}

cmd_preview() {
  local port="1313"
  local bind="127.0.0.1"
  local drafts="true"
  local future="true"
  local -a args=()

  while [[ $# -gt 0 ]]; do
    case "${1}" in
      --port)
        port="${2:-}"
        shift 2
        ;;
      --bind)
        bind="${2:-}"
        shift 2
        ;;
      --no-drafts)
        drafts="false"
        shift
        ;;
      --no-future)
        future="false"
        shift
        ;;
      *)
        die "Unknown option for preview: ${1}"
        ;;
    esac
  done

  command_exists hugo || die "hugo is not installed. Install Hugo first."

  args=(server --bind "${bind}" --port "${port}" --disableFastRender)
  if [[ "${drafts}" == "true" ]]; then
    args+=(--buildDrafts)
  fi
  if [[ "${future}" == "true" ]]; then
    args+=(--buildFuture)
  fi

  (
    cd "${ROOT_DIR}"
    hugo "${args[@]}"
  )
}

cmd_schedule() {
  local mode="${1:-list}"
  local dry_run="false"
  local due_file=""
  local count=0
  local ts=""
  local raw_date=""
  local draft=""

  if [[ $# -gt 0 ]]; then
    shift || true
  fi

  while [[ $# -gt 0 ]]; do
    case "${1}" in
      --dry-run)
        dry_run="true"
        shift
        ;;
      *)
        die "Unknown option for schedule: ${1}"
        ;;
    esac
  done

  case "${mode}" in
    list)
      command_exists hugo || die "hugo is not installed. Install Hugo first."
      (
        cd "${ROOT_DIR}"
        hugo list future
      )
      ;;
    publish-due)
      ts="$(iso_now)"
      shopt -s nullglob
      for due_file in "${POSTS_DIR}"/*.md; do
        draft="$(strip_quotes "$(extract_frontmatter_value "${due_file}" "draft" || true)")"
        [[ "${draft}" == "true" ]] || continue

        raw_date="$(strip_quotes "$(extract_frontmatter_value "${due_file}" "date" || true)")"
        [[ -n "${raw_date}" ]] || continue
        is_due_datetime "${raw_date}" || continue

        count=$((count + 1))
        if [[ "${dry_run}" == "true" ]]; then
          echo "Would publish due draft: ${due_file}"
          continue
        fi

        set_frontmatter_value "${due_file}" "draft" "false"
        set_frontmatter_value "${due_file}" "lastmod" "${ts}"
        echo "Published due draft: ${due_file}"
      done
      shopt -u nullglob
      if (( count == 0 )); then
        echo "No due drafts found."
      elif [[ "${dry_run}" == "true" ]]; then
        echo "Found ${count} due draft(s)."
      else
        echo "Published ${count} due draft(s)."
      fi
      ;;
    *)
      die "schedule mode must be one of: list, publish-due"
      ;;
  esac
}

cmd_media_audit() {
  local strict="false"
  local warnings=0

  while [[ $# -gt 0 ]]; do
    case "${1}" in
      --strict)
        strict="true"
        shift
        ;;
      *)
        die "Unknown option for media audit: ${1}"
        ;;
    esac
  done

  while IFS=$'\t' read -r severity location message; do
    [[ -z "${severity}" ]] && continue
    if [[ "${severity}" == "WARN" ]]; then
      echo "WARN: ${location} ${message}"
      warnings=$((warnings + 1))
    fi
  done < <(python3 - "${POSTS_DIR}" <<'PY'
import pathlib
import re
import sys

posts_dir = pathlib.Path(sys.argv[1])
image_pattern = re.compile(r'!\[([^\]]*)\]\(([^)]+)\)')


def slugify(name: str) -> str:
    name = name.lower()
    name = re.sub(r"[^a-z0-9]+", "-", name)
    return name.strip("-")

for post in sorted(posts_dir.glob("*.md")):
    try:
        lines = post.read_text(encoding="utf-8").splitlines()
    except Exception:
        continue

    for lineno, line in enumerate(lines, start=1):
        for match in image_pattern.finditer(line):
            alt = match.group(1).strip()
            target = match.group(2).strip().split()[0].strip("<>")
            if not alt:
                print(f"WARN\t{post}:{lineno}\tempty alt text")

            lowered = target.lower()
            if lowered.startswith(("http://", "https://", "data:")):
                continue

            target_path = target.split("#", 1)[0].split("?", 1)[0]
            filename = pathlib.PurePosixPath(target_path).name
            if not filename:
                continue

            stem = pathlib.Path(filename).stem
            expected = slugify(stem)
            if expected and stem != expected:
                print(f"WARN\t{post}:{lineno}\tnon-kebab image filename: {filename}")
PY
)

  echo "Media audit summary: ${warnings} warning(s)"
  if [[ "${strict}" == "true" ]] && (( warnings > 0 )); then
    return 1
  fi
}

cmd_media_normalize() {
  local dir="${STATIC_IMAGES_DIR}"
  local apply="false"
  local file=""
  local base=""
  local stem=""
  local ext=""
  local ext_lc=""
  local new_stem=""
  local new_base=""
  local new_file=""
  local old_rel=""
  local new_rel=""
  local idx=0
  local changed=0
  local map_file=""
  local md=""

  while [[ $# -gt 0 ]]; do
    case "${1}" in
      --dir)
        dir="${2:-}"
        shift 2
        ;;
      --apply)
        apply="true"
        shift
        ;;
      *)
        die "Unknown option for media normalize: ${1}"
        ;;
    esac
  done

  if [[ ! -d "${dir}" ]]; then
    echo "No media directory found at ${dir}. Skipping normalize."
    return 0
  fi

  map_file="$(mktemp "${TMPDIR:-/tmp}/blogctl-media-map.XXXXXX")"

  while IFS= read -r file; do
    base="$(basename "${file}")"
    stem="${base%.*}"
    ext="${base##*.}"
    ext_lc="$(printf '%s' "${ext}" | tr '[:upper:]' '[:lower:]')"
    new_stem="$(slugify "${stem}")"
    [[ -n "${new_stem}" ]] || new_stem="image"
    new_base="${new_stem}.${ext_lc}"

    if [[ "${base}" == "${new_base}" ]]; then
      continue
    fi

    new_file="${dir}/${new_base}"
    idx=1
    while [[ -e "${new_file}" && "${new_file}" != "${file}" ]]; do
      new_file="${dir}/${new_stem}-${idx}.${ext_lc}"
      idx=$((idx + 1))
    done

    changed=$((changed + 1))

    if [[ "${file}" == "${ROOT_DIR}/static/"* && "${new_file}" == "${ROOT_DIR}/static/"* ]]; then
      old_rel="${file#${ROOT_DIR}/static/}"
      new_rel="${new_file#${ROOT_DIR}/static/}"
      printf '%s\t%s\n' "${old_rel}" "${new_rel}" >> "${map_file}"
    fi

    if [[ "${apply}" == "true" ]]; then
      mv "${file}" "${new_file}"
      echo "Renamed: ${file} -> ${new_file}"
    else
      echo "Would rename: ${file} -> ${new_file}"
    fi
  done < <(find "${dir}" -type f \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' -o -iname '*.gif' \) | sort)

  if (( changed == 0 )); then
    rm -f "${map_file}"
    echo "No media filenames need normalization."
    return 0
  fi

  if [[ "${apply}" == "true" ]] && [[ -s "${map_file}" ]]; then
    shopt -s nullglob
    for md in "${POSTS_DIR}"/*.md; do
      while IFS=$'\t' read -r old_rel new_rel; do
        OLD_REF="/${old_rel}" NEW_REF="/${new_rel}" perl -0pi -e 's/\Q$ENV{OLD_REF}\E/$ENV{NEW_REF}/g' "${md}"
        OLD_REF="${old_rel}" NEW_REF="${new_rel}" perl -0pi -e 's/\Q$ENV{OLD_REF}\E/$ENV{NEW_REF}/g' "${md}"
      done < "${map_file}"
    done
    shopt -u nullglob
    echo "Updated markdown image references."
  fi

  rm -f "${map_file}"
  if [[ "${apply}" == "true" ]]; then
    echo "Normalized ${changed} media filename(s)."
  else
    echo "Found ${changed} media filename(s) to normalize. Re-run with --apply to execute."
  fi
}

cmd_media_compress() {
  local dir="${STATIC_IMAGES_DIR}"
  local max_bytes="800000"
  local quality="75"
  local max_dim="2400"
  local apply="false"
  local file=""
  local size_before=0
  local size_after=0
  local ext=""
  local ext_lc=""
  local matched=0

  while [[ $# -gt 0 ]]; do
    case "${1}" in
      --dir)
        dir="${2:-}"
        shift 2
        ;;
      --max-bytes)
        max_bytes="${2:-}"
        shift 2
        ;;
      --quality)
        quality="${2:-}"
        shift 2
        ;;
      --max-dim)
        max_dim="${2:-}"
        shift 2
        ;;
      --apply)
        apply="true"
        shift
        ;;
      *)
        die "Unknown option for media compress: ${1}"
        ;;
    esac
  done

  if [[ ! -d "${dir}" ]]; then
    echo "No media directory found at ${dir}. Skipping compress."
    return 0
  fi
  command_exists sips || die "sips command is required for media compress"

  while IFS= read -r file; do
    size_before="$(wc -c < "${file}" | tr -d '[:space:]')"
    if (( size_before <= max_bytes )); then
      continue
    fi

    matched=$((matched + 1))
    if [[ "${apply}" != "true" ]]; then
      echo "Would compress: ${file} (${size_before} bytes)"
      continue
    fi

    sips -Z "${max_dim}" "${file}" >/dev/null 2>&1 || true

    ext="${file##*.}"
    ext_lc="$(printf '%s' "${ext}" | tr '[:upper:]' '[:lower:]')"
    case "${ext_lc}" in
      jpg|jpeg)
        sips -s formatOptions "${quality}" "${file}" >/dev/null 2>&1 || true
        ;;
    esac

    size_after="$(wc -c < "${file}" | tr -d '[:space:]')"
    echo "Compressed: ${file} (${size_before} -> ${size_after} bytes)"
  done < <(find "${dir}" -type f \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' -o -iname '*.gif' \) | sort)

  if (( matched == 0 )); then
    echo "No files exceed max-bytes threshold (${max_bytes})."
  elif [[ "${apply}" == "true" ]]; then
    echo "Compression complete for ${matched} file(s)."
  else
    echo "Found ${matched} file(s) above threshold. Re-run with --apply to execute."
  fi
}

cmd_media() {
  local mode="${1:-audit}"
  if [[ $# -gt 0 ]]; then
    shift || true
  fi

  case "${mode}" in
    audit)
      cmd_media_audit "$@"
      ;;
    normalize)
      cmd_media_normalize "$@"
      ;;
    compress)
      cmd_media_compress "$@"
      ;;
    *)
      die "media mode must be one of: audit, normalize, compress"
      ;;
  esac
}

cmd_seo() {
  local strict="false"
  local with_drafts="false"
  local errors=0
  local warnings=0
  local file=""
  local draft=""
  local title=""
  local summary=""
  local canonical=""
  local cover=""
  local title_len=0
  local summary_len=0
  local tmp_out=""

  while [[ $# -gt 0 ]]; do
    case "${1}" in
      --strict)
        strict="true"
        shift
        ;;
      --with-drafts)
        with_drafts="true"
        shift
        ;;
      *)
        die "Unknown option for seo: ${1}"
        ;;
    esac
  done

  if command_exists hugo; then
    tmp_out="$(mktemp "${TMPDIR:-/tmp}/blogctl-seo.XXXXXX")"
    if [[ "${with_drafts}" == "true" ]]; then
      (
        cd "${ROOT_DIR}"
        hugo --gc --minify --buildDrafts --buildFuture >"${tmp_out}" 2>&1
      ) || {
        echo "ERROR: hugo build failed during seo check"
        cat "${tmp_out}"
        errors=$((errors + 1))
      }
    else
      (
        cd "${ROOT_DIR}"
        hugo --gc --minify >"${tmp_out}" 2>&1
      ) || {
        echo "ERROR: hugo build failed during seo check"
        cat "${tmp_out}"
        errors=$((errors + 1))
      }
    fi
    rm -f "${tmp_out}"
  else
    echo "WARN: hugo command not found; skipped build check"
    warnings=$((warnings + 1))
  fi

  [[ -f "${ROOT_DIR}/public/sitemap.xml" ]] || {
    echo "WARN: missing public/sitemap.xml"
    warnings=$((warnings + 1))
  }
  [[ -f "${ROOT_DIR}/public/robots.txt" ]] || {
    echo "WARN: missing public/robots.txt"
    warnings=$((warnings + 1))
  }

  shopt -s nullglob
  for file in "${POSTS_DIR}"/*.md; do
    draft="$(strip_quotes "$(extract_frontmatter_value "${file}" "draft" || true)")"
    if [[ "${with_drafts}" != "true" && "${draft}" == "true" ]]; then
      continue
    fi

    title="$(strip_quotes "$(extract_frontmatter_value "${file}" "title" || true)")"
    summary="$(strip_quotes "$(extract_frontmatter_value "${file}" "summary" || true)")"
    canonical="$(strip_quotes "$(extract_frontmatter_value "${file}" "canonicalURL" || true)")"
    if [[ -z "${canonical}" ]]; then
      canonical="$(strip_quotes "$(extract_frontmatter_value "${file}" "canonical" || true)")"
    fi
    cover="$(strip_quotes "$(extract_frontmatter_value "${file}" "cover" || true)")"

    title_len=${#title}
    summary_len=${#summary}

    if (( title_len < 30 || title_len > 70 )); then
      echo "WARN: $(basename "${file}") title length ${title_len} (recommended 30-70)"
      warnings=$((warnings + 1))
    fi

    if (( summary_len < 70 || summary_len > 180 )); then
      echo "WARN: $(basename "${file}") summary length ${summary_len} (recommended 70-180)"
      warnings=$((warnings + 1))
    fi

    if [[ -z "${canonical}" ]]; then
      echo "WARN: $(basename "${file}") missing canonicalURL/canonical"
      warnings=$((warnings + 1))
    fi

    if [[ -z "${cover}" ]]; then
      echo "WARN: $(basename "${file}") missing cover image for Open Graph"
      warnings=$((warnings + 1))
    fi
  done
  shopt -u nullglob

  echo "SEO summary: ${errors} error(s), ${warnings} warning(s)"

  if (( errors > 0 )); then
    return 1
  fi
  if [[ "${strict}" == "true" ]] && (( warnings > 0 )); then
    return 1
  fi
}

cmd_safe_deploy() {
  local mode="deploy"
  local message="blog: safe deploy"
  local tag_prefix="release"
  local push="false"
  local skip_check="false"
  local dry_run="false"
  local rollback_tag=""
  local branch=""
  local tag=""
  local commit=""
  local last_tag_file="${ROOT_DIR}/.git/blogctl-last-safe-tag"

  if [[ "${1:-}" == "rollback" ]]; then
    mode="rollback"
    shift
  fi

  while [[ $# -gt 0 ]]; do
    case "${1}" in
      --message)
        message="${2:-}"
        shift 2
        ;;
      --tag-prefix)
        tag_prefix="${2:-}"
        shift 2
        ;;
      --tag)
        rollback_tag="${2:-}"
        shift 2
        ;;
      --push)
        push="true"
        shift
        ;;
      --skip-check)
        skip_check="true"
        shift
        ;;
      --dry-run)
        dry_run="true"
        shift
        ;;
      *)
        die "Unknown option for safe-deploy: ${1}"
        ;;
    esac
  done

  if [[ "${mode}" == "rollback" ]]; then
    if [[ "${dry_run}" == "true" ]]; then
      if [[ -z "${rollback_tag}" && -f "${last_tag_file}" ]]; then
        rollback_tag="$(cat "${last_tag_file}")"
      fi
      [[ -n "${rollback_tag}" ]] || rollback_tag="<missing-last-safe-tag>"
      echo "Dry run rollback plan:"
      echo "  target tag: ${rollback_tag}"
      echo "  command path: git rev-list --no-merges ${rollback_tag}..HEAD | git revert --no-edit <commit>"
      if [[ "${push}" == "true" ]]; then
        echo "  would push rollback commits to origin/main"
      fi
      return 0
    fi

    (
      cd "${ROOT_DIR}"
      if [[ -z "${rollback_tag}" && -f "${last_tag_file}" ]]; then
        rollback_tag="$(cat "${last_tag_file}")"
      fi
      [[ -n "${rollback_tag}" ]] || die "No rollback tag provided and no last safe tag recorded"

      git rev-parse --verify "refs/tags/${rollback_tag}" >/dev/null 2>&1 || die "Tag not found: ${rollback_tag}"

      branch="$(current_branch)"
      [[ "${branch}" == "main" ]] || die "Rollback is restricted to main branch. Current branch: ${branch}"

      while IFS= read -r commit; do
        [[ -z "${commit}" ]] && continue
        git revert --no-edit "${commit}"
      done < <(git rev-list --no-merges "${rollback_tag}..HEAD")

      if [[ "${push}" == "true" ]]; then
        git push origin main
      fi
    )
    echo "Rollback completed from tag ${rollback_tag}."
    return 0
  fi

  if [[ "${dry_run}" == "true" ]]; then
    tag="${tag_prefix}-$(date +%Y%m%d-%H%M%S)"
    echo "Dry run safe-deploy plan:"
    if [[ "${skip_check}" != "true" ]]; then
      echo "  would run: blogctl.sh check"
    fi
    echo "  would stage and commit changes with message: ${message}"
    echo "  would create tag: ${tag}"
    if [[ "${push}" == "true" ]]; then
      echo "  would push main and tag to origin"
    else
      echo "  would keep commit/tag local only"
    fi
    return 0
  fi

  if [[ "${skip_check}" != "true" ]]; then
    cmd_check
  fi

  (
    cd "${ROOT_DIR}"

    git add -A
    if ! git diff --cached --quiet; then
      git commit -m "${message}"
    else
      echo "No new tracked changes to commit before tagging."
    fi

    tag="${tag_prefix}-$(date +%Y%m%d-%H%M%S)"
    git tag -a "${tag}" -m "safe deploy: ${tag}"
    printf '%s\n' "${tag}" > "${last_tag_file}"

    if [[ "${push}" == "true" ]]; then
      branch="$(current_branch)"
      [[ "${branch}" == "main" ]] || die "Push deploy is restricted to main branch. Current branch: ${branch}"
      git push origin main
      git push origin "${tag}"
      echo "Safe deploy pushed to origin/main with tag ${tag}."
    else
      echo "Safe deploy tag created locally: ${tag}"
      echo "Push with: git push origin main && git push origin ${tag}"
    fi
  )
}

cmd_pr_flow() {
  local branch="blog/update-$(date +%Y%m%d-%H%M%S)"
  local message="blog: update content"
  local title=""
  local body=""
  local base="main"
  local open_pr="true"
  local skip_check="false"
  local dry_run="false"

  while [[ $# -gt 0 ]]; do
    case "${1}" in
      --branch)
        branch="${2:-}"
        shift 2
        ;;
      --message)
        message="${2:-}"
        shift 2
        ;;
      --title)
        title="${2:-}"
        shift 2
        ;;
      --body)
        body="${2:-}"
        shift 2
        ;;
      --base)
        base="${2:-}"
        shift 2
        ;;
      --no-open-pr)
        open_pr="false"
        shift
        ;;
      --skip-check)
        skip_check="true"
        shift
        ;;
      --dry-run)
        dry_run="true"
        shift
        ;;
      *)
        die "Unknown option for pr-flow: ${1}"
        ;;
    esac
  done

  if [[ "${dry_run}" == "true" ]]; then
    echo "Dry run pr-flow plan:"
    if [[ "${skip_check}" != "true" ]]; then
      echo "  would run: blogctl.sh check --with-drafts"
    fi
    echo "  would create/switch branch: ${branch}"
    echo "  would commit with message: ${message}"
    echo "  would push: origin/${branch}"
    if [[ "${open_pr}" == "true" ]]; then
      echo "  would open PR into base branch: ${base}"
    fi
    return 0
  fi

  if [[ "${skip_check}" != "true" ]]; then
    cmd_check --with-drafts
  fi

  (
    cd "${ROOT_DIR}"

    if git rev-parse --verify "${branch}" >/dev/null 2>&1; then
      git checkout "${branch}"
    else
      git checkout -b "${branch}"
    fi

    git add -A
    if git diff --cached --quiet; then
      echo "No changes to commit for PR flow."
      exit 0
    fi

    git commit -m "${message}"
    git push -u origin "${branch}"

    if [[ "${open_pr}" == "true" ]]; then
      if command_exists gh; then
        if [[ -n "${title}" && -n "${body}" ]]; then
          gh pr create --base "${base}" --head "${branch}" --title "${title}" --body "${body}"
        elif [[ -n "${title}" ]]; then
          gh pr create --base "${base}" --head "${branch}" --title "${title}" --fill
        else
          gh pr create --base "${base}" --head "${branch}" --fill
        fi
      else
        echo "gh CLI not found. Open PR manually:"
        echo "https://github.com/atom2ueki/blog/compare/${base}...${branch}?expand=1"
      fi
    fi
  )
}

cmd_maintain() {
  echo "Blog root: ${ROOT_DIR}"
  echo
  echo "Workflow file:"
  if [[ -f "${ROOT_DIR}/.github/workflows/hugo.yml" ]]; then
    echo "  .github/workflows/hugo.yml present"
  else
    echo "  Missing .github/workflows/hugo.yml"
  fi
  echo
  echo "Git status:"
  (
    cd "${ROOT_DIR}"
    git status --short
  )
  echo
  echo "Submodule status:"
  (
    cd "${ROOT_DIR}"
    git submodule status || true
  )
  echo
  echo "Hugo:"
  if command_exists hugo; then
    hugo version | head -n 1
  else
    echo "  hugo not installed"
  fi
}

cmd_update_theme() {
  (
    cd "${ROOT_DIR}"
    git submodule update --remote --merge themes/github-style
  )
  echo "Theme submodule updated. Review diff and run deploy when ready."
}

main() {
  local cmd="${1:-help}"
  shift || true

  require_repo

  case "${cmd}" in
    new)
      cmd_new "$@"
      ;;
    publish)
      cmd_publish "$@"
      ;;
    unpublish)
      cmd_unpublish "$@"
      ;;
    list)
      cmd_list "$@"
      ;;
    check)
      cmd_check "$@"
      ;;
    deploy)
      cmd_deploy "$@"
      ;;
    bootstrap)
      cmd_bootstrap "$@"
      ;;
    doctor)
      cmd_doctor "$@"
      ;;
    preview)
      cmd_preview "$@"
      ;;
    schedule)
      cmd_schedule "$@"
      ;;
    media)
      cmd_media "$@"
      ;;
    seo)
      cmd_seo "$@"
      ;;
    safe-deploy)
      cmd_safe_deploy "$@"
      ;;
    pr-flow)
      cmd_pr_flow "$@"
      ;;
    maintain)
      cmd_maintain "$@"
      ;;
    update-theme)
      cmd_update_theme "$@"
      ;;
    help|-h|--help)
      usage
      ;;
    *)
      usage
      die "Unknown command: ${cmd}"
      ;;
  esac
}

main "$@"
