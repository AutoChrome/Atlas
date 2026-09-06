#!/usr/bin/env bash
set -euo pipefail

# First-time setup for Atlas. Interactive: asks the handful of things that
# actually need a decision (file storage, an existing Rails master key,
# whether to wire up Basecamp now), generates the secrets that don't need
# one, writes .env, then builds the app's Docker images and prepares the
# database — so the only thing left afterward is `docker compose up`.
#
# Safe to re-run: an existing .env is never overwritten without asking
# first, and choosing to keep it skips straight to the build+migrate step.
#
# Keep the .env this writes in sync with .env.example if that file gains
# new variables later.

cd "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

bold() { printf '\033[1m%s\033[0m\n' "$1"; }
info() { printf '  %s\n' "$1"; }
warn() { printf '\033[33m! %s\033[0m\n' "$1"; }

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    warn "$1 is required but wasn't found on PATH. Install it and re-run this script."
    exit 1
  fi
}

require_command docker
require_command openssl

if ! docker compose version >/dev/null 2>&1; then
  warn "The Docker Compose plugin (\`docker compose\`, not the standalone \`docker-compose\`) is required."
  exit 1
fi

bold "Atlas first-time setup"
echo

generated_new_master_key=0

# --- Reuse an existing .env, if there is one ------------------------------
if [[ -f .env ]]; then
  warn ".env already exists."
  read -rp "Keep it and skip straight to building/migrating? [Y/n]: " keep_env
  if [[ ! "$keep_env" =~ ^[Nn]$ ]]; then
    info "Keeping the existing .env."
    SKIP_CONFIG=1
  else
    info "Reconfiguring — the existing .env will be overwritten once setup finishes."
    SKIP_CONFIG=0
  fi
else
  SKIP_CONFIG=0
fi

if [[ "$SKIP_CONFIG" -eq 0 ]]; then
  # --- Site address --------------------------------------------------------
  echo
  bold "Site address"
  info "What host will this run on? Just press enter for local development."
  read -rp "SITE_ADDRESS [localhost]: " site_address
  site_address="${site_address:-localhost}"

  # --- File storage ----------------------------------------------------------
  echo
  bold "File storage"
  info "Attachments (page images, files) can be stored on local disk or in an S3 bucket."
  read -rp "Use AWS S3? [y/N]: " use_s3

  storage_service="local"
  aws_access_key_id=""
  aws_secret_access_key=""
  aws_region="eu-west-2"
  aws_s3_bucket=""

  if [[ "$use_s3" =~ ^[Yy]$ ]]; then
    storage_service="amazon"
    read -rp "AWS access key ID: " aws_access_key_id
    read -rsp "AWS secret access key: " aws_secret_access_key
    echo
    read -rp "AWS region [eu-west-2]: " aws_region_input
    aws_region="${aws_region_input:-eu-west-2}"
    read -rp "S3 bucket name: " aws_s3_bucket
  else
    info "Using local disk storage — you can switch to S3 later by editing .env (see README)."
  fi

  # --- Rails master key ------------------------------------------------------
  echo
  bold "Rails master key"
  generated_new_master_key=0
  if [[ -f config/master.key ]]; then
    info "config/master.key already exists — leaving it as is."
  else
    info "Needed to boot Rails at all. If you already have one (a teammate, a password"
    info "manager, an old .env) paste it in now — otherwise leave this blank and a new"
    info "one will be generated for you."
    read -rsp "Existing master key (blank to generate): " master_key
    echo

    if [[ -z "$master_key" ]]; then
      master_key="$(openssl rand -hex 16)"
      generated_new_master_key=1
      info "Generated a new master key."

      if [[ -f config/credentials.yml.enc ]]; then
        warn "config/credentials.yml.enc was encrypted with a different key — it'll be regenerated"
        warn "fresh (empty; this app keeps everything else in .env, not Rails credentials) once the"
        warn "Docker image is built, further down. If this repo is shared, remember to commit that."
      fi
    fi

    printf '%s' "$master_key" > config/master.key
    chmod 600 config/master.key
  fi

  # --- Active Record encryption (Webhook#secret) ------------------------------
  echo
  bold "Attachment/webhook encryption keys"
  info "Generating fresh keys for encrypted data (currently just webhook signing secrets)."
  ar_encryption_primary_key="$(openssl rand -hex 16)"
  ar_encryption_deterministic_key="$(openssl rand -hex 16)"
  ar_encryption_key_derivation_salt="$(openssl rand -hex 16)"

  # --- Basecamp integration (optional) ----------------------------------------
  echo
  bold "Basecamp integration"
  info "Lets a Basecamp project's posts create draft announcements here — entirely"
  info "optional, and can be set up later from Account menu -> Basecamp integration."
  read -rp "Set it up now? [y/N]: " setup_basecamp

  basecamp_webhook_token=""
  if [[ "$setup_basecamp" =~ ^[Yy]$ ]]; then
    basecamp_webhook_token="$(openssl rand -hex 32)"
    info "Generated a token — the exact URL to paste into Basecamp is on the integration page once Atlas is running."
  fi

  # --- Write .env --------------------------------------------------------------
  cat > .env <<ENV_FILE
RAILS_MASTER_KEY=$(cat config/master.key)
RAILS_ENV=development
RAILS_LOG_TO_STDOUT=true

DATABASE_USERNAME=postgres
DATABASE_PASSWORD=postgres

SITE_ADDRESS=${site_address}
HTTP_PORT=80
HTTPS_PORT=443

STORAGE_SERVICE=${storage_service}
AWS_ACCESS_KEY_ID=${aws_access_key_id}
AWS_SECRET_ACCESS_KEY=${aws_secret_access_key}
AWS_REGION=${aws_region}
AWS_S3_BUCKET=${aws_s3_bucket}

# Active Record Encryption (used to store webhook signing secrets so they
# can be read back later — unlike API tokens, which are only ever hashed).
AR_ENCRYPTION_PRIMARY_KEY=${ar_encryption_primary_key}
AR_ENCRYPTION_DETERMINISTIC_KEY=${ar_encryption_deterministic_key}
AR_ENCRYPTION_KEY_DERIVATION_SALT=${ar_encryption_key_derivation_salt}

# Basecamp webhook integration (see /admin/integrations/basecamp). Basecamp
# doesn't sign its webhook payloads, so this token — embedded in the URL
# you give Basecamp — is what stands in for verification.
BASECAMP_WEBHOOK_TOKEN=${basecamp_webhook_token}
ENV_FILE

  echo
  info ".env written."
fi

# --- Build and migrate --------------------------------------------------------
echo
bold "Building Docker images"
docker compose build

# A new master key means the checked-in config/credentials.yml.enc (if any)
# is now permanently undecryptable — Rails itself only knows how to create
# a fresh one interactively (bin/rails credentials:edit, via $EDITOR), so
# this does it directly with ActiveSupport's own encrypted-config class
# instead. Needs the image built above: this app's gems, not anything on
# your host, are what provide ActiveSupport.
if [[ "$generated_new_master_key" -eq 1 ]]; then
  echo
  bold "Regenerating config/credentials.yml.enc for the new master key"
  rm -f config/credentials.yml.enc
  docker compose run --rm web bin/rails runner '
    config = ActiveSupport::EncryptedConfiguration.new(
      config_path: Rails.root.join("config/credentials.yml.enc"),
      key_path: Rails.root.join("config/master.key"),
      env_key: "RAILS_MASTER_KEY",
      raise_if_missing_key: true
    )
    config.write("# Nothing needed here today — Atlas configures everything through .env instead\n# (see README). This file exists only so Rails always has one to decrypt.\n")
    puts "Wrote a fresh config/credentials.yml.enc encrypted with the new master key."
  '
fi

echo
bold "Preparing the database"
docker compose run --rm web bin/rails db:prepare

echo
bold "Done."
info "Start Atlas with:"
echo
echo "    docker compose up"
echo
