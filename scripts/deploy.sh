#!/usr/bin/env bash
set -euo pipefail

# Zero-downtime blue/green deploy for the production stack
# (docker-compose.prod.yml). Run this ON THE PRODUCTION HOST, from the repo
# checkout — e.g. over SSH, or from a systemd/cron job that calls it.
#
# The gist: build the new image, migrate, then start a SECOND `web`
# container alongside the one already running (Compose scales the service
# to 2, `--no-recreate` leaves the original untouched). Once the new
# container's own health check passes, Caddy is pointed AT THAT SPECIFIC
# CONTAINER (by its own Docker-assigned name, not the shared "web" DNS
# alias both containers answer to while they're briefly both up — using
# the specific name means Caddy never has a chance to round-robin an
# unverified container into rotation) and reloaded. `caddy reload` swaps
# to new config without ever dropping its listening socket, so there's no
# gap where a request has nowhere to land — unlike `service nginx
# restart`, which briefly does. Only once Caddy is confirmed serving the
# new container does the old one get removed.
#
# Requires: the deploy user can run `docker`/`docker compose` (e.g. is in
# the `docker` group). No sudo, and nothing to add to /etc/sudoers —
# reloading Caddy happens via `docker compose exec caddy caddy reload`,
# which doesn't need it.

cd "$(dirname "$0")/.."

readonly COMPOSE_FILE="docker-compose.prod.yml"
readonly SERVICE="web"
readonly APP_PORT=3000
readonly HEALTH_TIMEOUT_SECONDS=60

compose() {
  docker compose -f "$COMPOSE_FILE" "$@"
}

pull_latest_code() {
  echo "==> Pulling latest code"
  git pull
}

# Rails' own health check (config/routes.rb: get "up" => "rails/health#show"),
# checked from INSIDE the new container against its own localhost — this
# works regardless of what's published to the host (nothing is, in this
# compose file; only Caddy publishes 80/443) and doesn't depend on Caddy's
# own config being anywhere near correct yet.
wait_for_healthy() {
  local container_id=$1
  local waited=0

  echo "==> Waiting for the new container to report healthy"
  until docker exec "$container_id" curl -fsS "http://localhost:${APP_PORT}/up" > /dev/null 2>&1; do
    waited=$((waited + 3))
    if [[ $waited -ge $HEALTH_TIMEOUT_SECONDS ]]; then
      echo "New container never became healthy after ${HEALTH_TIMEOUT_SECONDS}s — aborting. Old container is untouched, nothing was cut over."
      docker logs --tail 50 "$container_id" || true
      exit 1
    fi
    sleep 3
  done
  echo "New container is healthy."
}

# Points Caddy's reverse_proxy at $1 and reloads — gracefully, no dropped
# connections. Rewrites the running container's OWN copy of
# upstream.caddy (imported from Caddyfile — see caddy/Caddyfile), not the
# one checked into git, which stays the steady-state default for a fresh
# `docker compose up` to start from.
set_caddy_upstream() {
  local target=$1
  echo "==> Pointing Caddy at $target"
  printf 'reverse_proxy %s\n' "$target" | compose exec -T caddy sh -c "cat > /etc/caddy/upstream.caddy"
  compose exec -T caddy caddy reload --config /etc/caddy/Caddyfile
}

update_server() {
  pull_latest_code

  echo "==> Building new image"
  compose build "$SERVICE"

  # Asset precompilation already happened at image-build time (see
  # Dockerfile), so there's no separate assets:precompile step here, unlike
  # a setup where the image doesn't bake them in.
  echo "==> Running migrations against the new image"
  compose run --rm "$SERVICE" ./bin/rails db:migrate

  old_container_id=$(compose ps -q "$SERVICE")
  if [[ -z "$old_container_id" ]]; then
    echo "No running $SERVICE container found — nothing to blue/green against. Run 'docker compose -f $COMPOSE_FILE up -d' for a first deploy instead."
    exit 1
  fi

  echo "==> Starting new $SERVICE container alongside the old one"
  compose up -d --no-deps --scale "${SERVICE}=2" --no-recreate "$SERVICE"

  # Diffed against the known old id, rather than assumed from `docker ps`
  # list ordering — unambiguous regardless of how Docker happens to sort it.
  new_container_id=$(compose ps -q "$SERVICE" | grep -v "^${old_container_id}$" || true)
  if [[ -z "$new_container_id" ]] || [[ $(wc -l <<< "$new_container_id") -ne 1 ]]; then
    echo "Couldn't identify exactly one new container (got: '${new_container_id}') — aborting."
    exit 1
  fi

  wait_for_healthy "$new_container_id"

  new_container_name=$(docker inspect -f '{{ .Name }}' "$new_container_id" | sed 's#^/##')
  set_caddy_upstream "${new_container_name}:${APP_PORT}"

  echo "==> Removing old container"
  docker rm -f "$old_container_id"

  echo "==> Scaling back down to a single $SERVICE container"
  compose up -d --no-deps --scale "${SERVICE}=1" "$SERVICE"

  echo "==> Reverting Caddy to the default upstream"
  set_caddy_upstream "${SERVICE}:${APP_PORT}"

  echo "==> Restarting sidekiq with the new image"
  compose up -d --build worker

  echo "==> Clearing build cache"
  docker system prune -f

  echo "Deployment complete!"
}

update_server
