# Atlas

Internal documentation platform: Rails 8 + Postgres + Caddy,
running in Docker. Content is organised into **Areas** (collections of
documentation, nestable) containing **Pages** (rich-text content with
images, video, and file attachments). Areas and individual Pages can be
made public so they're readable without an account; everything else
requires signing in. Every create/update/delete is recorded in an audit
log.

## Stack

- **Rails 8.1**, Ruby 3.3
- **PostgreSQL 16**, **Redis**, **OpenSearch**, Caddy 2 (reverse proxy, automatic HTTPS) — all in Docker Compose
- **Sidekiq** for background jobs (account-setup emails, search indexing)
- **Searchkick** (on OpenSearch) for search — titles, descriptions, and full page content
- **Hotwire** (Turbo + Stimulus) via importmap — no JS build step
- **Dart Sass** for a custom, componentised SCSS design system (light/dark mode, responsive)
- **Action Text** (Trix) for WYSIWYG editing — supports pasted/dragged images, inline attachments, and file uploads
- **Active Storage** for attachments — local disk by default, S3-ready
- Auth: Rails 8's built-in `has_secure_password` sessions (no Devise) — admin-created accounts, "remember me", email-based setup/reset
- **Pundit** for authorization, **Audited** for full change history, **FriendlyId** for slugs
- Self-hosted **Font Awesome Free** + our own SVG icon set — see `app/helpers/icon_helper.rb`
- **rails_performance** (`/admin/performance`) for request/DB/view timing, **Sidekiq::Web** (`/admin/sidekiq`) for job monitoring — both admin-only
- **letter_opener_web** (`/letter_opener`, dev only) instead of actually sending mail
- Full JSON CRUD API (bearer-token authenticated, scopable to specific Areas) under `/api/v1` — see `/api_tokens/docs` once running

## Getting started

```bash
./scripts/setup.sh
```

Interactive first-time setup: asks the things that actually need a decision
(local disk or S3 storage, an existing Rails master key if you have one,
whether to wire up the optional Basecamp integration now), generates
whatever secrets it can generate for you, writes `.env`, then builds the
Docker images and prepares the database. Safe to re-run later — an existing
`.env` is never overwritten without asking first.

Prefer doing it by hand? Skip the script and:

```bash
cp .env.example .env
```

Fill in `RAILS_MASTER_KEY` in `.env` with the contents of `config/master.key`
(generated locally, not committed — ask whoever generated it, or delete it
and let `scripts/setup.sh` generate a new one, or run
`bin/rails credentials:edit` inside the web container yourself).

```bash
docker compose up -d
```

Caddy serves the app on **http://localhost** (redirects to **https://localhost**
using a locally-trusted cert Caddy generates itself — your browser may warn
about it once, that's expected in development). First boot runs pending
migrations automatically (see `bin/dev-entrypoint`).

Seed some starter content, and build the search index:

```bash
docker compose run --rm web bin/rails db:seed
docker compose run --rm web bin/rails searchkick:reindex:all
```

The reindex step is only needed once (or after restoring a DB dump) —
ongoing changes index themselves automatically as they're saved. Search
degrades gracefully (empty results, no error) if OpenSearch is unreachable
or an index hasn't been built yet.

Seeding creates an admin account — `admin@example.com` / `password123` —
and a public "Getting Started" area with one page. **Change that password.**

### Everyday commands

```bash
docker compose logs -f web            # tail app logs
docker compose run --rm web bin/rails console
docker compose run --rm web bin/rails generate migration ...
docker compose run --rm web bin/rails db:migrate
docker compose run --rm web bin/rubocop
docker compose down                   # stop everything (add -v to also wipe volumes)
```

Gems are installed into the `bundle_cache` volume, not baked into the image,
so after editing the Gemfile run:

```bash
docker compose run --rm web bundle install
docker compose restart web
```

SCSS changes recompile automatically (`bin/rails dartsass:watch_poll` via
`Procfile.dev`, polling rather than relying on filesystem events — those
don't reliably cross Docker Desktop's bind mount on Windows).

## Roles & visibility

Three account roles: **admin** (manages users, areas, pages, and can read the
audit log), **member** (can create/edit areas and pages), **guest**
(read-only — can see everything an admin can, but can't change anything).

Independently, any Area or Page can be flagged **public**, which makes it
(and, for pages, anything under a public area) visible to visitors with no
account at all — including the areas index and site root, which anonymous
visitors can browse (scoped to public content only; the "Public" badge itself
only shows to signed-in users, since everything an anonymous visitor sees
*is* public and the badge would be redundant/misleading there).

Admins create accounts from **Admin → Manage users** — no self-signup, and
no typing a password on their behalf: the new user gets an email with a link
to set their own (open `/letter_opener` in development to see it).

## Project layout

```
app/assets/stylesheets/
  abstracts/   variables & mixins (spacing scale, type scale, breakpoints) — no CSS output
  themes/      colour tokens as CSS custom properties, light + dark
  base/        reset, fonts, base typography
  vendor/      trix.css, vendored verbatim (see components/_editor.scss for why)
  layout/      app shell, sidebar, topbar
  components/  buttons, cards, forms, badges, modal, dropdown, nav tree, search, editor, docs, pagination…
  utilities/   small single-purpose helper classes
  application.scss   the manifest — start here to see what's loaded

app/assets/images/icons/   our own SVG icon set, inlined by IconHelper#icon
app/assets/fontawesome/    self-hosted Font Awesome Free (not a CDN — see IconHelper#fa_icon, .icon-fa)

app/javascript/controllers/   Stimulus controllers (theme toggle, sidebar, typeahead search, dropdown, flash, modal, icon picker, clipboard/share)

app/models/area.rb, app/models/page.rb   the core content model (Area has_many :children, self-referential; Page belongs_to :area, has_rich_text :content, has_many_attached :attachments). Both `searchkick` and both can carry a Font Awesome `icon` name (see app/models/concerns/iconable.rb)

app/models/concerns/autocorrectable.rb   rudimentary common-typo autocorrect, applied on save

app/policies/          Pundit authorization rules
app/controllers/api/   JSON API (separate from the session-based web controllers — bearer token auth, optionally scoped to specific Areas via ApiToken#areas)
```

Adding a new theme: duplicate `themes/_light.scss` under a new
`:root[data-theme="yourtheme"]` block with your own colour tokens, add it to
`application.scss`, and extend the option list in `theme_controller.js` /
the account menu.

## File storage (S3)

Local disk works out of the box. To use S3 instead, set in `.env`:

```
STORAGE_SERVICE=amazon
AWS_ACCESS_KEY_ID=...
AWS_SECRET_ACCESS_KEY=...
AWS_REGION=eu-west-2
AWS_S3_BUCKET=your-bucket
```

and restart the `web` container. See `config/storage.yml`.

## API

Every user can generate bearer tokens for themselves under **Account menu →
API tokens**, either with access to all Areas or scoped to specific ones
(set at creation — revoke and reissue to change it). The token is shown once
at creation time — store it somewhere safe, it's kept hashed server-side and
can't be recovered afterwards.

Full endpoint-by-endpoint documentation with cURL examples lives at
`/api_tokens/docs` in the running app. Quick start:

```bash
curl -H "Authorization: Bearer <token>" https://your-host/api/v1/areas
curl -H "Authorization: Bearer <token>" https://your-host/api/v1/pages?area_id=1
curl -X POST -H "Authorization: Bearer <token>" \
     -d "area_id=1" -d "title=New page" -d "content=<p>Hello</p>" \
     https://your-host/api/v1/pages
```

Full CRUD is available for Areas and Pages (not Users — manage those from
the admin UI). Responses are paginated (`pagination.page` / `.pages` /
`.count`). The API enforces the same roles as the web UI (a `guest` token
can read but not write) plus, for scoped tokens, the area grant — touching
an area outside a token's scope returns `403`.

## Announcements & webhooks

Admins and members can post announcements (title + rich-text body) from the
**Announcements** link in the sidebar. An announcement starts as a draft;
publishing it delivers the content to every active webhook configured at
**Account menu → Webhooks** (admin-only).

Each webhook has a description, a target URL, and an auto-generated signing
secret. Publishing (or re-publishing) POSTs a JSON payload — the announcement
as clean HTML plus an `X-Atlas-Signature: sha256=...` HMAC header — to every
active webhook's URL, independently and in the background (Sidekiq). Atlas
doesn't validate what the receiving endpoint does with it; it only records
the HTTP status/response for the delivery log shown on each announcement's
page and summarized on the webhooks index.

Full payload shape, headers, and signature-verification code samples live at
`/admin/webhooks/docs` in the running app.

### Basecamp → Announcements

A Basecamp project can be configured to post its new message-board posts into Atlas as draft
announcements, via an inbound webhook (`Integrations::BasecampController`) rather than the
outbound one above. Setup, the webhook URL to paste into Basecamp, and what ends up in the draft
are all documented at **Account menu → Basecamp integration** (admin-only) — it needs
`BASECAMP_WEBHOOK_TOKEN` set in the environment first, since Basecamp doesn't sign its webhook
payloads and that token is what stands in for verification instead.

## Production deployment (CI/CD)

Pushing to `main` — including a merge — runs the full CI suite (`.github/workflows/ci.yml`:
security scans, lint, tests, system tests) and, only if every one of those passes, a `deploy` job
builds the production image, runs database migrations, and restarts the app with the new code.
Asset compilation isn't a separate step: it happens as part of the image build itself (see the
`Dockerfile`, which runs `assets:precompile` while building), so a broken asset build fails the
build step directly rather than a later one. A pull request only ever runs the checks — `deploy`
is gated to `push` events on `main` specifically, and won't run at all if any earlier job failed.

Deploying like this — rather than to a cloud host — means the workflow has to run *on* your actual
production server, since that's what has to end up with new containers running. That's what a
**self-hosted runner** is: instead of GitHub spinning up a throwaway VM, your own server registers
itself with GitHub and picks up jobs targeted at it — here, that's every `deploy` job, via
`runs-on: [self-hosted, production]`.

### One-time server setup

Needed once, before the first deploy can succeed:

1. **Install Docker + the Compose plugin** on the server, if it isn't already there — see
   [Docker's install docs](https://docs.docker.com/engine/install/). Confirm with `docker compose version`.
2. **Register the runner.** In this repo on GitHub: **Settings → Actions → Runners → New
   self-hosted runner**, choose the server's OS/architecture, and follow the commands GitHub shows
   you (download, extract, then `./config.sh --url ... --token ...`). When `config.sh` asks for
   labels, add `production` (the workflow targets `self-hosted` *and* `production` together, so a
   runner registered without that label won't pick up the `deploy` job).
3. **Run it as a service**, not a foreground terminal session, so it survives reboots and keeps
   listening after you disconnect:
   ```bash
   sudo ./svc.sh install
   sudo ./svc.sh start
   ```
4. **Give the runner's user Docker access** — add it to the `docker` group (`sudo usermod -aG
   docker <runner-user>`) so the deploy steps can actually run `docker compose` without `sudo`.
5. **Create `.env` on the server**, in the same directory the runner checks this repo out into
   (typically `_work/<repo>/<repo>` under wherever you installed the runner). Copy
   `.env.example`, fill in real production values, and set `RAILS_ENV=production`. This file is
   gitignored and the checkout step is deliberately configured not to clean it, so it persists
   across every deploy — the pipeline never generates or overwrites it. `docker-compose.prod.yml`
   fails loudly and immediately (before touching anything) if `DATABASE_PASSWORD`,
   `OPENSEARCH_ADMIN_PASSWORD`, or `SITE_ADDRESS` are missing from it.

From here, every push to `main` that passes CI deploys itself — no further manual steps.

### What's actually different from the dev setup

`docker-compose.prod.yml` is a separate, standalone file (not an override layered on the dev
`docker-compose.yml`) — `web`/`worker` build from the real `Dockerfile` instead of
`Dockerfile.dev`, with no source bind-mount (a deploy rebuilds the image with the new code baked
in, it doesn't live-mount it the way local dev does), and `db`/`redis`/`opensearch` don't publish
any ports to the host — only the app containers on the same Docker network can reach them.

## Notes / things to know

- The theme-detection inline script (in both layouts, sets `data-theme`
  before first paint) relies on Content-Security-Policy being left at its
  Rails default (disabled). If you turn on
  `config.content_security_policy`, that script needs a nonce.
- `bin/dev-entrypoint` runs `db:prepare` (creates + migrates) on every `web`
  container start, so a fresh `docker compose up` always has an up-to-date
  schema.
- The `Dockerfile` in the repo root (not `Dockerfile.dev`) is Rails' default
  Kamal-style production build, used by `docker-compose.prod.yml` — see
  "Production deployment" above. It's unrelated to Kamal itself; nothing
  here uses `bin/kamal`.
- Webhook URLs are admin-only configuration, validated only for a well-formed
  `http(s)://` scheme+host — there's no private-IP/metadata-endpoint
  blocklist. That's an accepted trust boundary (same model as configuring a
  Slack/Stripe/GitHub webhook), not an oversight, since admins are already
  trusted with arbitrary outbound integrations elsewhere in the app.
