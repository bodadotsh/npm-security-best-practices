#!/usr/bin/env bash

set -u

readonly DEFAULT_MIN_RELEASE_AGE_DAYS=3
readonly MINUTES_PER_DAY=1440
readonly SECONDS_PER_DAY=86400
readonly DEFAULT_MIN_RELEASE_AGE_MINUTES=$((DEFAULT_MIN_RELEASE_AGE_DAYS * MINUTES_PER_DAY))
readonly DEFAULT_MIN_RELEASE_AGE_SECONDS=$((DEFAULT_MIN_RELEASE_AGE_DAYS * SECONDS_PER_DAY))

readonly Color_Off='\033[0m'
readonly Red='\033[0;31m'
readonly Yellow='\033[0;33m'
readonly Green='\033[0;32m'
readonly Dim='\033[0;2m'

print_usage() {
  cat <<EOF
Usage:
  bash default.sh

Hosted usage (replace <URL> with your raw script URL):
  curl -fsSL "<URL>" | bash

Behavior:
  - Applies npm settings: ignore-scripts=true and save-exact=true (global).
  - Tries npm min-release-age=<days> (global) and skips it if unsupported.
  - Applies pnpm setting: save-exact=true (global).
  - Tries pnpm minimumReleaseAge=<minutes> (global) and skips it if unsupported.
  - Probes Yarn capabilities:
    - If home-scoped config works, applies Berry settings: enableScripts=false and defaultSemverRangePrefix="".
    - Otherwise falls back to Yarn Classic settings: ignore-scripts=true and save-prefix="".
    - For Berry, also tries npmMinimalAgeGate=<minutes> and skips it if unsupported.
  - Checks Bun config and prints a manual bunfig.toml snippet when exact=true or minimumReleaseAge=<seconds> is missing.
  - Prompts for <days> in interactive mode (Enter defaults to ${DEFAULT_MIN_RELEASE_AGE_DAYS}).
  - Uses default ${DEFAULT_MIN_RELEASE_AGE_DAYS} days (${DEFAULT_MIN_RELEASE_AGE_MINUTES} minutes, ${DEFAULT_MIN_RELEASE_AGE_SECONDS} seconds) in non-interactive mode.
  - Skips npm, pnpm, yarn, or bun if they are not installed.
  - Exits non-zero only when no package manager could be handled.
EOF
}

info() {
  if [[ -t 1 ]]; then
    printf '%b%s%b\n' "$Dim" "$*" "$Color_Off"
  else
    printf '%s\n' "$*"
  fi
}

warn() {
  if [[ -t 2 ]]; then
    printf '%bwarn%b: %s\n' "$Yellow" "$Color_Off" "$*" >&2
  else
    printf 'warn: %s\n' "$*" >&2
  fi
}

error() {
  if [[ -t 2 ]]; then
    printf '%berror%b: %s\n' "$Red" "$Color_Off" "$*" >&2
  else
    printf 'error: %s\n' "$*" >&2
  fi
}

success() {
  if [[ -t 1 ]]; then
    printf '%b%s%b\n' "$Green" "$*" "$Color_Off"
  else
    printf '%s\n' "$*"
  fi
}

skip() {
  info "skip $*"
}

apply_setting() {
  local success_message="$1"
  local failure_message="$2"
  shift 2

  if "$@" >/dev/null 2>&1; then
    info "$success_message"
    did_apply=true
  else
    error "$failure_message"
    had_failure=true
  fi
}

probe_setting() {
  local success_message="$1"
  local skip_message="$2"
  shift 2

  if "$@" >/dev/null 2>&1; then
    info "$success_message"
    did_apply=true
    return 0
  else
    skip "$skip_message"
    return 1
  fi
}

apply_global_setting() {
  local manager="$1"
  local key="$2"
  local value="$3"

  apply_setting \
    "$manager $key=$value" \
    "failed to set $manager $key=$value" \
    "$manager" config set "$key" "$value" --global
}

probe_global_setting() {
  local manager="$1"
  local key="$2"
  local value="$3"
  local skip_message="$4"

  probe_setting \
    "$manager $key=$value" \
    "$skip_message" \
    "$manager" config set "$key" "$value" --global
}

apply_yarn_home_setting() {
  local key="$1"
  local value="$2"

  apply_setting \
    "yarn $key=$value" \
    "failed to set yarn $key=$value" \
    yarn config set -H "$key" "$value"
}

probe_yarn_home_setting() {
  local key="$1"
  local value="$2"
  local skip_message="$3"

  probe_setting \
    "yarn $key=$value" \
    "$skip_message" \
    yarn config set -H "$key" "$value"
}

apply_yarn_global_setting() {
  local key="$1"
  local value="$2"

  apply_setting \
    "yarn $key=$value" \
    "failed to set yarn $key=$value" \
    yarn config set "$key" "$value" --global
}

days_to_minutes() {
  local days="$1"

  printf '%s\n' "$((days * MINUTES_PER_DAY))"
}

days_to_seconds() {
  local days="$1"

  printf '%s\n' "$((days * SECONDS_PER_DAY))"
}

tildify() {
  if [[ $1 == "$HOME"/* ]]; then
    printf '~/%s\n' "${1#"$HOME"/}"
  else
    printf '%s\n' "$1"
  fi
}

resolve_bunfig_path() {
  local home_bunfig="${HOME}/.bunfig.toml"
  local xdg_bunfig=""

  if [ -n "${XDG_CONFIG_HOME:-}" ]; then
    xdg_bunfig="${XDG_CONFIG_HOME}/.bunfig.toml"
    if [ -f "$xdg_bunfig" ] && [ -f "$home_bunfig" ]; then
      warn "both $(tildify "$xdg_bunfig") and $(tildify "$home_bunfig") exist; using $(tildify "$xdg_bunfig")"
    fi
    printf '%s\n' "$xdg_bunfig"
    return
  fi

  printf '%s\n' "$home_bunfig"
}

bunfig_setting_matches() {
  local bunfig_path="$1"
  local key="$2"
  local expected_value="$3"

  if [ ! -f "$bunfig_path" ]; then
    return 1
  fi

  grep -Eq "^[[:space:]]*${key}[[:space:]]*=[[:space:]]*${expected_value}([[:space:]]*(#.*)?)?$" "$bunfig_path"
}

print_bun_manual_instructions() {
  local bunfig_path="$1"
  local min_release_age_seconds="$2"
  local display_path

  display_path="$(tildify "$bunfig_path")"

  needs_manual_action=true

  if [[ -t 2 ]]; then
    printf '%bmanual%b: create or update %s so Bun install config includes:\n\n' "$Yellow" "$Color_Off" "$display_path" >&2
    printf '%b[install]\nexact = true\nminimumReleaseAge = %s%b\n\n' "$Green" "$min_release_age_seconds" "$Color_Off" >&2
    printf '%s\n' 'If [install] already exists, update those keys in that section.' >&2
  else
    printf 'manual: create or update %s so Bun install config includes:\n\n' "$display_path" >&2
    printf '[install]\nexact = true\nminimumReleaseAge = %s\n\n' "$min_release_age_seconds" >&2
    printf '%s\n' 'If [install] already exists, update those keys in that section.' >&2
  fi
}

check_bun_settings() {
  local bunfig_path
  local min_release_age_seconds
  local display_path

  bunfig_path="$(resolve_bunfig_path)"
  display_path="$(tildify "$bunfig_path")"
  ensure_min_release_age_days
  min_release_age_seconds="$(days_to_seconds "$min_release_age_days")"

  if bunfig_setting_matches "$bunfig_path" "exact" "true" &&
    bunfig_setting_matches "$bunfig_path" "minimumReleaseAge" "$min_release_age_seconds"; then
    info "bun $display_path already configured"
    did_apply=true
    return
  fi

  print_bun_manual_instructions "$bunfig_path" "$min_release_age_seconds"
}

ensure_min_release_age_days() {
  min_release_age_days="${min_release_age_days:-$(get_min_release_age_days)}"
}

get_min_release_age_days() {
  local input=""

  if [ -t 0 ]; then
    printf 'Enter min-release-age in days [default: %s]: ' "$DEFAULT_MIN_RELEASE_AGE_DAYS" >&2
    read -r input
    if [ -z "$input" ]; then
      input="$DEFAULT_MIN_RELEASE_AGE_DAYS"
    fi
  else
    input="$DEFAULT_MIN_RELEASE_AGE_DAYS"
    info "non-interactive: min-release-age=$DEFAULT_MIN_RELEASE_AGE_DAYS days (${DEFAULT_MIN_RELEASE_AGE_MINUTES}m, ${DEFAULT_MIN_RELEASE_AGE_SECONDS}s for bun)" >&2
  fi

  if [[ ! "$input" =~ ^[0-9]+$ ]]; then
    warn "invalid min-release-age '$input'; using $DEFAULT_MIN_RELEASE_AGE_DAYS days (${DEFAULT_MIN_RELEASE_AGE_MINUTES}m, ${DEFAULT_MIN_RELEASE_AGE_SECONDS}s for bun)"
    input="$DEFAULT_MIN_RELEASE_AGE_DAYS"
  fi

  printf '%s\n' "$input"
}

run_yarn_classic() {
  apply_yarn_global_setting "ignore-scripts" "true"
  apply_yarn_global_setting "save-prefix" ""
}

run_npm() {
  if ! command -v npm >/dev/null 2>&1; then
    skip "npm not installed"
    return
  fi

  apply_global_setting "npm" "ignore-scripts" "true"
  apply_global_setting "npm" "save-exact" "true"
  ensure_min_release_age_days
  probe_global_setting \
    "npm" \
    "min-release-age" \
    "$min_release_age_days" \
    "npm min-release-age unsupported; unchanged"
}

run_pnpm() {
  local min_release_age_minutes

  if ! command -v pnpm >/dev/null 2>&1; then
    skip "pnpm not installed"
    return
  fi

  apply_global_setting "pnpm" "save-exact" "true"
  ensure_min_release_age_days
  min_release_age_minutes="$(days_to_minutes "$min_release_age_days")"
  probe_global_setting \
    "pnpm" \
    "minimumReleaseAge" \
    "$min_release_age_minutes" \
    "pnpm minimumReleaseAge unsupported; unchanged"
}

run_yarn() {
  local min_release_age_minutes

  if ! command -v yarn >/dev/null 2>&1; then
    skip "yarn not installed"
    return
  fi

  if probe_yarn_home_setting \
    "enableScripts" \
    "false" \
    "yarn home-scoped config unsupported; falling back to Yarn Classic"; then
    apply_yarn_home_setting "defaultSemverRangePrefix" ""
    ensure_min_release_age_days
    min_release_age_minutes="$(days_to_minutes "$min_release_age_days")"
    probe_yarn_home_setting \
      "npmMinimalAgeGate" \
      "$min_release_age_minutes" \
      "yarn npmMinimalAgeGate unsupported; unchanged"
    return
  fi

  run_yarn_classic
}

run_bun() {
  if ! command -v bun >/dev/null 2>&1; then
    skip "bun not installed"
    return
  fi

  check_bun_settings
}

case "${1:-}" in
  --help|-h)
    print_usage
    exit 0
    ;;
esac

did_apply=false
had_failure=false
needs_manual_action=false
min_release_age_days=""

run_npm
run_pnpm
run_yarn
run_bun

printf '\n'

if [[ $did_apply == true ]]; then
  if [[ $needs_manual_action == true ]]; then
    warn "manual bun update still required"
  fi
  success "done"
  exit 0
fi

if [[ $had_failure == true ]]; then
  error "nothing applied"
  exit 1
fi

if [[ $needs_manual_action == true ]]; then
  warn "manual bun update required"
  exit 0
fi

error "npm/pnpm/yarn/bun unavailable; nothing applied"
exit 2
