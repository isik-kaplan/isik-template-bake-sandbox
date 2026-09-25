# Test Project

A test project generated for template validation.

Generated from [isik-template](https://github.com/isik-kaplan/isik-template).

## Before you start

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

Brings up `database`, `broker`, `backend`, `worker`, `scheduler`, `frontend`, and `server` (nginx,
the only service publishing a host port). Visit `http://testproject.test`. `.env` was
already created for you at generation time (from `.env.example`) - see that file's own header
comment before changing anything in it.

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

## Testing

```
docker compose run --rm --no-deps backend python -m pytest   # backend, 100% coverage required
cd test_project-frontend && npm install && npm run lint && npm run test
cd e2e && docker compose build && docker compose up -d && docker compose run --rm playwright npx playwright test
```

`apps/mobile` has its own unit/component suite, run the same way:
`cd test_project-frontend/apps/mobile && npm run test`. No device/emulator e2e
yet - see `.github/workflows/ci.yml`'s `mobile`/`mobile-mutation` jobs for what does run in CI.

`.github/workflows/ci.yml` runs all of the above on every push/PR.
