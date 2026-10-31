# Test Project

A test project generated for template validation.

Generated from [isik-template](https://github.com/isik-kaplan/isik-template).

## Before you start

**[SETUP.md](SETUP.md)** is the checklist of everything to do after generating this project - `.env`, the first
superuser, DNS and TLS, social login providers, the legal documents and more. What follows explains how it works.

**[docs/development.md](docs/development.md)** is for writing code here: the backend conventions,
logging, the starter kit, testing and mutation testing, and the conventions the build enforces.

This app is **not servable at plain `localhost`** - cross-subdomain session/CSRF cookies (shared
across `api.`, `admin.`, `auth.testproject.test`) need a real registrable domain. Add to
`/etc/hosts`:

```
127.0.0.1 api.testproject.test admin.testproject.test auth.testproject.test
```

or point real DNS at these subdomains if deploying to the real domain instead.

## Running it

```
docker compose build
docker compose up -d
```
Split rather than `up -d --build` in one shot: `worker`/`scheduler` share `backend`'s image tag
with no `build:` of their own, and starting them before that build finishes tagging the image can
race compose into trying to pull it instead of using what was just built.

Brings up `database`, `broker`, `storage`, `backend`, `worker`, `scheduler`, `frontend`, and `server` (nginx,
the only service publishing a host port). Visit `http://testproject.test`.
`.env` was already created for you at generation time by `scripts/setup.sh` (cookiecutter's own
last step) - see `.env.example`'s own header comment before changing anything in it. Rerun
`bash scripts/setup.sh` by hand later to redo that choice - e.g. to move this same checkout from
local development to a real deployment, which generates strong secrets and prompts for real
domain/SMTP/OAuth/Sentry config instead of leaving `.env.example`'s dev defaults in place.

## Background jobs

Tasks are Celery tasks over RabbitMQ (`broker`), run by `worker`; `scheduler` runs Celery beat
with `django_celery_beat`'s database schedule, edited in the admin. Every task takes
`base=OnCommitTask`, so it is dispatched once the transaction that asked for it commits, and its
history rows name whoever caused it.

## Object storage

Uploads (`FileField`/`ImageField`, anything through `default_storage`) go to S3 via django-storages.
That is the `storage` service, a one-node [Garage](https://garagehq.deuxfleurs.fr/), in development
and in production alike. Its data lives on the `storage_data` volume - back that volume up.
The app never creates a bucket - `s3:CreateBucket` is a provisioning permission the web process should
not hold - so `storage/entrypoint.sh` makes sure of the key and the bucket on every start. Only the test
suite makes buckets of its own, so `TEST_PROJECT__STORAGE__KEY_CAN_CREATE_BUCKETS` is on in
`.env.example` and off in a deployment. Inspect the bucket by hand on the loopback port Garage publishes:

```
aws --endpoint-url=http://localhost:3900 s3 ls s3://test-project/
```

The backend tests write to a real Garage too, never a mock - each pytest worker gets a bucket of
its own (`<bucket>-test-<worker>`), the way it gets a database of its own.

Nothing is public: no URL reaches a stored file without a view deciding who may have it first. The
view answers with `apps.common.files.serve_file()`, and nginx sends the file itself, fetched from the
bucket over a presigned URL that lives a minute and never reaches the client:

```python
def download(request, pk):
    report = get_object_or_404(Report, pk=pk, owner=request.user)
    return serve_file(report.file.name, as_attachment=True)
```

So a large download never ties up a uwsgi worker, and ranges work. nginx sends every stored file with
`X-Content-Type-Options: nosniff` and a sandboxing `Content-Security-Policy`, so an uploaded HTML or
SVG file cannot run as a page on the API's origin.

## Rate limits

Three layers, all counting against the same client, and all switched off together by
`TEST_PROJECT__RATE_LIMITS__ENABLED=false` (the e2e stack does):

- **nginx** refuses a flood before it reaches anything: `TEST_PROJECT__RATE_LIMITS__REQUESTS_PER_SECOND` per
  client (20 unless set), ten seconds' worth at once. The API's refusal is JSON in the throttles' own
  shape, with the CORS headers that let the page read it; a page's is a page. Static files are never
  counted.
- **allauth** limits signing in, signing up, password resets and the like, with its own defaults
  (`ACCOUNT_RATE_LIMITS`).
- **The API** (DRF) limits everyone signed out per address (`TEST_PROJECT__RATE_LIMITS__ANONYMOUS`,
  `120/minute`) and everyone signed in per account (`TEST_PROJECT__RATE_LIMITS__USER`, `600/minute`). A view
  that has to be stricter names a rate in `REST_FRAMEWORK["DEFAULT_THROTTLE_RATES"]` and says
  `throttle_scope = "<that name>"`, as entering a device's code does (`device_codes`). A refusal is a
  429 with `Retry-After` and `"code": "throttled"`.

**Who the client is** is worked out once, by nginx, and passed to the backend as `X-Client-Ip`
(`apps/common/client_ip.py`), which every limit and the request log read: the address
`TEST_PROJECT__TRUSTED_PROXY_COUNT` entries from the right of `X-Forwarded-For`. A page the frontend renders
fetches from the API as well, from the frontend's own address - so the frontend names the visitor it
renders for (`lib/visitor.ts`), and nginx believes it only alongside `TEST_PROJECT__FRONTEND_KEY`, a secret
the two share. nginx refuses to start without one. The frontend's own fetches are not counted by
nginx again, since the page load that made them already was. IPv6 addresses are counted per `/64`,
which one subscriber is handed whole.

**The counts** live in the default cache, which every process and container shares -
Redis, the `cache` service. Nothing in it outlives a restart that matters: counts start
again. A cache of each process's own would let a caller make the limit's worth of requests to every
uwsgi process in turn. The backend tests run on a cache of each process's own instead, which they clear
between tests; `apps/common/tests/test_cache.py` checks the configured one is shared.

**In the frontend**, a refused form says how long to wait. A page whose render the API refused goes to
`/too-many-requests`, which offers it again (`lib/tooManyRequests.ts`), rather than rendering what it
was refused as empty.

## TLS

This project serves plain HTTP (`:80`) only - it expects a TLS-terminating load balancer or
reverse proxy in front of it in any real deployment (a platform's own (Fly.io/Render/Railway/an
AWS ALB/Cloudflare), or your own nginx/Caddy on the same host), which forwards to this stack's
`server` container and sets `X-Forwarded-Proto` the way
`test_project-server/template.nginx.conf`'s own comments describe - get that
wrong and `settings.py`'s `SECURE_PROXY_SSL_HEADER` trusts whatever the client sent instead,
which lets anyone choose the scheme of an emailed password-reset link. It must pass the browser's
`Host` through unchanged: nginx answers only this project's names and sets `X-Forwarded-Host` from
`Host` itself, so a balancer that rewrites it gets every request dropped. Regenerate with
`tls_termination: self` instead if you'd rather this project terminate its own TLS via certbot,
with no separate proxy to run.

That load balancer has to append to `X-Forwarded-For` rather than replace it, and
`TEST_PROJECT__TRUSTED_PROXY_COUNT` has to count it: nginx takes the client to be the address that
many entries from the right (see "Rate limits"). Unset, it is `2` (the load balancer plus nginx), which `scripts/setup.sh`'s
deployment mode writes for you, adding one per further proxy. `.env.example` sets `1` for local
development, where the browser reaches nginx directly - left at `1` behind a load balancer, every
visitor shares its address and one rate-limit bucket.

nginx publishes on `127.0.0.1` only, which suits a load balancer on the same host. One on another host
(an AWS ALB, say) reaches it once `TEST_PROJECT__HTTP_BIND` is set to this host's private address. Firewall
that port to the load balancer alone: a request that reaches nginx directly skips it, so the proxy count
above trusts an `X-Forwarded-For` entry the client wrote, and nginx passes on the client's own
`X-Forwarded-Proto`, letting it choose the scheme of emailed links and OAuth redirects.

### Local HTTPS

Some browser APIs exist only in a secure context - WebAuthn/passkeys, service workers, parts of the
clipboard API - so on this stack's plain `http://testproject.test` they are simply undefined.
For local development only:

```
bash scripts/dev-tls.sh
docker compose up -d --force-recreate server frontend
```

It mints a certificate for `testproject.test` and its `api.`/`admin.`/`auth.` subdomains into
`test_project-server/dev-tls/` (gitignored) - with [mkcert](https://github.com/FiloSottile/mkcert)
if it's installed, so the browser trusts it outright, or self-signed otherwise, which needs a
click-through and still leaves WebAuthn off in Chromium (it refuses any certificate error). It also
adds `docker-compose.dev-tls.yml` to `COMPOSE_FILE` in `.env`, which publishes `:443` (override with
`TEST_PROJECT__HTTPS_PORT`) and hands the frontend the CA for its server-side
fetches. Plain HTTP keeps working beside it; `https://testproject.test` is the secure one.
Rerunning it is safe - it keeps a still-valid certificate. Never run it on a real deployment: that
gets its TLS from the proxy in front of it.

The mobile app (`test_project-frontend/apps/mobile`) isn't part of the compose
stack - it talks to the same backend over plain HTTP, pointed at by two env vars Expo embeds at
build time:

```
cd test_project-frontend/apps/mobile
EXPO_PUBLIC_API_ORIGIN=http://api.testproject.test EXPO_PUBLIC_AUTH_ORIGIN=http://auth.testproject.test npm run start
```

The iOS Simulator shares this machine's own `/etc/hosts`, so the domain above works as-is. A
physical device or the Android emulator doesn't - point at this machine's LAN IP instead (or
`10.0.2.2` for the Android emulator specifically).

The native Google/Apple sign-in buttons show when `EXPO_PUBLIC_SOCIAL_LOGIN_PROVIDERS` (inlined at
build time, like the two origins above) names `google` or `apple` - set it to the backend's own
`TEST_PROJECT__SOCIAL_LOGIN__PROVIDERS`. They (`apps/mobile/lib/nativeSignIn.ts`)
need a custom dev client, not Expo Go - `npx expo run:ios` / `npx expo run:android` (or an EAS development build) after adding
your own real credentials: a Google OAuth iOS client ID (its reversed form as `iosUrlScheme` in
`app.config.ts`'s `@react-native-google-signin/google-signin` plugin entry) and, for Apple, a
provisioning profile with the Sign in with Apple capability enabled. Until those exist, the
buttons render but the native pickers will fail to open.

Push needs a development build too. The app asks to notify once signed in, registers the phone's own APNs or
FCM token with the backend (not an Expo push token) and forgets it at logout; a tapped push opens the
Notifications screen. iOS needs the Push Notifications capability on its provisioning profile; Android needs
Firebase's `google-services.json`, named by `GOOGLE_SERVICES_FILE` at build time. A development build's APNs
token is the sandbox's, so it registers as such.


## Translations

Every string is authored in English; `languages` also named tr, so `post_gen_project.py` already scaffolded real, empty catalogs for
it at generation time (its own
printout named the exact files) - fill in the backend `locale/<lang>/LC_MESSAGES/django.po` and the
frontend `locales/<lang>/*.json` files before shipping that language. A signed-in user's language
preference (`User.language`, editable from the profile page) picks between whatever `LANGUAGES`
ends up configured with; a visitor with no preference gets their browser's own language instead.

## Sensitive actions and locking sign-in down

Acts that change who can get into an account (adding, removing or promoting an email, setting a first
password, connecting or disconnecting a provider, ending another session) ask the person to prove it
is them again first: the API answers with `X-Reauthentication-Required: 1`, and the frontend sends
them to `/auth/prove` and back. A proof is spent by the one act it was asked for. Somebody with a
password types it; somebody who signed up through an OpenID Connect provider signs in there again
(it has to report a fresh `auth_time`); anybody without a password can also set one from an emailed
link. `apps/users/tests/test_reauthentication_gate.py` fails until every routed write is classified
as gated or not an act.

For an incident, **Site settings** in the admin holds a "who may sign in" ladder (everyone, staff,
superusers only). Raising it signs out everybody it excludes straight away and refuses them on both
the password and the social sign-in; only a superuser can choose the top rung.

## Signing in to other apps with this one

`apps/oauth_provider` makes this project an OAuth 2.0 / OpenID Connect provider through
django-oauth-toolkit, served at `auth.<domain>/o/` and switched by `OAUTH_PROVIDER__MODE` (off,
approval or auto - see SETUP.md). Its tables exist whatever the mode, and while it is off every one
of its routes answers 404. Two flows are offered: the authorization code flow with PKCE, for a website
or an app that can open a browser and be sent back, and the device code flow (RFC 8628), for a command
line that can only show a code. DOT's dynamic client registration, introspection and its own unstyled
pages are not routed. DOT's consent screen redirects to `/auth/oauth/authorize`, the frontend's page,
which posts the answer straight back. A signed-out person goes through the ordinary sign-in first, and
`next` lets sign-in return to that one authorize endpoint and nowhere else off-site.

A device posts its client id to `auth.<domain>/o/device-authorization/`, shows the person the code and
the link it is handed (the frontend's `/device`), and polls `/o/token/`. Whoever enters the code there
decides for their own account, and the device's next poll gets one token: the code is spent by it,
and is the client's that asked for it alone (`apps/oauth_provider/device_codes.py` - DOT would mint a
token for an authorized code every time it was presented, to any client). A device application is
registered as public, with no redirect URIs: it keeps no secret and is sent back nowhere.

Anybody signed in registers an app at `/applications` - DOT's own `Application`, swapped for
`apps.oauth_provider.models.Application`, which carries its review state and the scopes it asks for.
In approval mode it waits for a superuser (`/staff/applications`) before it signs anybody in; in auto
mode it is approved for what it asks the moment it is registered. A superuser can withdraw one, its
owner can switch it off, and either takes every token it holds down with it. The profile's Apps tab
lists the apps a person let in, with a way to shut each one out (revoking its refresh tokens too).
Those moves are `apps/oauth_provider/services.py`'s alone: triggers refuse an approval, or an approved
scope, written from anywhere else - DOT's admin, a shell, a stray `update()` - and check constraints
keep DOT's own columns from skipping the consent question or naming a grant this project does not
serve. DOT's application admin is kept for looking things up and deleting, and changes nothing.

Beyond signing somebody in, an app can ask to act for them on the API. Its scopes are this project's
permissions (`apps/users/permissions.py`, the `where:action:what` names), and only the delegatable
ones: a superuser approves which an app may ask for, each person chooses on the consent page, and a
token can only ever use what both its person holds and they let it have - a superuser's token holds no
more than it was let have either. The API takes a token only on the actions a viewset names in
`token_actions`, so a new endpoint is closed to apps until somebody decides otherwise.

## Personal access tokens

The profile's Tokens tab makes a token for somebody's own scripts - `Authorization: Bearer pat_...`
calls the API as them, with no app and no browser involved. It acts the same way an app's token does:
only on `token_actions`, only with the scopes it was given (the delegatable permissions its owner
holds), and never with more than its owner holds when it is used. It lasts 7, 30, 90 or 365 days, or
until it is deleted. Making one asks the person to prove it is them, the token is shown once, and only
its SHA-256 is stored (`apps/users/personal_access_tokens.py`); a token of somebody deactivated or
shut out by the sign-in ladder is refused.

## Notifications

Built on isik's notifications app; every one of its tables is this project's own, in
`apps/notifications/models/`. A kind is declared in `apps/notifications/kinds.py`, and nothing raises a
kind that isn't there (`REQUIRE_DECLARED_KINDS`). Most are written by the database: `@notifies(...)` on a
model compiles to a trigger that inserts the notice in the same transaction as the change, so a raw
`UPDATE` notifies too. Fan-out then turns each notice into deliveries - the inbox (the profile's
Notifications tab), email (`templates/notifications/<kind>/`, in the recipient's language), webhooks
and push to phones, once it has credentials.

- **The owner's own:** a personal access token made or revoked, an application approved or withdrawn.
- **Signed out by the sign-in ladder:** one notice per person shut out, by inbox and email.
- **Account changes:** allauth mails these itself; `account_changed` copies them into the inbox, which
  somebody may turn off on the Notifications tab. Security notices can't be turned off.
- **allauth's mail is recorded, not queued:** a reset link has to go out now, so the account adapter
  sends it as before and `record_email` writes it to the ledger afterwards, keyed by its task so its
  retries are attempts at one delivery. Nothing of the message is kept. A mail allauth adds later has
  no kind in `RECORDED_MAIL` and goes out unrecorded; a test fails until it gets one.
- **Staff can decide one person's notification for them:** `force_subscription(user, kind, enabled=...,
  source=STAFF, reason=...)` locks it on or off; the person sees it locked, and why, and is told by the
  mandatory `notification_settings_forced`. `release_subscription(...)` gives them their own choice back.

**Push to phones** goes straight to APNs and FCM over HTTP/2, with no SDK or middleman: set
`TEST_PROJECT__PUSH__*` (`.env.example`) and push is on for every kind sent on it. Each of a
person's phones is a `Device`, which the app registers at `/v0/notifications/devices/` with the phone's own
token at every start and forgets at logout; a token Apple or Google says is dead turns its device off. A
push says the kind's label and message; one about a token or an application says its label alone
(`PRIVATE_PUSH`), so what somebody named them stays off lock screens. Every push sets the app's badge to the
unread inbox count.

Each kind declares its `label`, `description` and `message` in `kinds.py`, rendered in the request's
language: `/v0/notifications/kinds/` lists every kind with what the caller gets of it and whether they may
change it, and every inbox item carries its sentence, so a client needs no text of its own for either.

Fan-out, the reaper (retries due, stranded deliveries) and pruning run from `scheduler`'s beat
(`merge_beat_schedule(app)` in `celery.py`).

**Webhooks** (each user's own, sent only that user's notices): `/v0/notifications/endpoints/`.
Registering or editing one asks somebody to prove it is them, and its secret is shown once. Each delivery
is signed in `X-test-project-Signature` - the slug, not the display
name, since receivers verify by it - and carries an `Idempotency-Key`. An endpoint resolving to a private,
loopback or link-local address, this deployment's own services included, is refused when it's sent to.

## Features and settings

Built on isik's features app, its tables this project's own in `apps/features/models/`. Everything is
declared in `apps/features/declarations.py`:

- **Features** a person is granted - by staff, or as a trial that ends (`grant(user, LONG_LIVED_TOKENS,
  source="trial", expires_at=...)`). Grants are a ledger: revoked, never edited or deleted.
- **Settings** a person chooses within them, each a column on `UserOverrides`, so adding one is a
  migration. `token_lifetime_days` bounds every new personal access token (at most 90 days without
  `long_lived_tokens`); `two_factor_required` keeps the last second factor from being removed, and changing
  it asks for a fresh proof; `max_endpoints`, which staff set and
  the person only reads, is 0 without `webhooks`.
- **Staff force a setting** with `force_setting(user, name, value, source=STAFF, reason=...)`; the
  person's own value is kept for `release_setting(...)`. Who forced what, when and why is
  `UserOverrides`' history.

`/v0/settings/` lists each setting with its value and why it is that value, and takes a change under the
version it read (If-Match); `/v0/features/` lists what a person has. The profile's Settings tab is one
component reading both. A grant ending changes things with no write, so a sweep says so: beat runs it
every minute. Deleting a person erases their grants and settings, with
their history, in the same transaction.

## Permissions

`apps/users/permissions.py` declares every permission there is, as `where:action:what` - written into
`auth_permission` on every migrate, and the only thing `has_perm` answers about
(`apps.users.backends.permissions.PermissionsBackend`, which also expands what each one `requires`). A
superuser holds them all; anybody else holds what was granted. Granting follows one rule
(`apps/users/granting.py`): you may hand on only what you hold yourself, and only staff holding
`users:grant:rights` grant anything at all. `/staff/people` lists everybody's account for staff and
holders of `users:manage:user`, who may also deactivate somebody or change what they may do.

## Legal pages and cookies

`/legal/<slug>` renders each document `apps/web/src/legal/documents.json` names from
`apps/web/src/legal/<language>/<slug>.md`, falling back to English, and says a document has not been added yet while
its file is missing. The footer links every document; signup (password or social, web and mobile) says continuing
means agreeing to them, and the account adapter records `User.terms_version` and `terms_accepted_at`. The template
ships no legal text - [SETUP.md](SETUP.md) covers writing or generating it.

There is no cookie banner because nothing needs one: the session and CSRF cookies are strictly necessary, and the
theme, kept in local storage, is a choice the visitor made. Both kinds need disclosing, not consent, so the footer
carries a one-line disclosure and the privacy policy page renders a cookies section from
`apps/web/src/legal/storage.json`. `e2e/playwright/tests/legal/storage-disclosure.spec.ts` signs up, signs in and walks
the app, then fails on any cookie or storage key that list leaves out.

Adding analytics, advertising, embedded third-party content or anything else not strictly necessary means consent
first, under GDPR and the ePrivacy rules, before anything is set:

- Add a consent banner (shadcn's dialog or drawer, in `components/base/`, will do) with accept and reject offered
  equally, and keep the choice in a cookie or local storage key of its own, itself listed in `storage.json`.
- Expose the choice through one provider in `app/layout.tsx`, beside `SiteFooter`, and load every non-essential
  script only from a component that renders once consent is given (`next/script` inside it), never from the page
  head.
- Let people change their mind: a "cookie settings" link in `SiteFooter` that reopens the banner, and removal of
  whatever the refused category had already set.
- List each new item in `storage.json` with its purpose. The e2e spec above keeps failing until you do, which is the
  point - and update the privacy policy to name the service and what it receives.

No consent hook ships with the template: with nothing to gate, it would be code no test can give a reason to exist.
