# Context is the workspace root: packages/* must build first, and npm doesn't order `--workspaces` runs.

FROM node:22-alpine AS deps
WORKDIR /repo
COPY package.json package-lock.json ./
COPY apps/web/package.json apps/web/package.json
COPY packages/api/package.json packages/api/package.json
COPY packages/auth-api/package.json packages/auth-api/package.json
# package-lock.json is generated at bake time: its workspace entries name this project's packages.
RUN npm ci

# Where the suites run, locally and in CI. From `deps`, not `builder`: vitest never reads `.next`.
FROM deps AS tester
WORKDIR /repo
COPY . .
RUN npm run build:packages
# Not apps/mobile, which has a toolchain of its own.
CMD ["npm", "run", "test", "--workspace=web", \
     "--workspace=@test-project/api", "--workspace=@test-project/auth-api"]

FROM node:22-alpine AS builder
WORKDIR /repo
COPY --from=deps /repo/node_modules ./node_modules
COPY . .
# The one build-time value: next build inlines NEXT_PUBLIC_* into the client bundle. Empty disables it.
ARG NEXT_PUBLIC_SENTRY_DSN=
ENV NEXT_PUBLIC_SENTRY_DSN=$NEXT_PUBLIC_SENTRY_DSN
RUN npm run build --workspace=@test-project/api --workspace=@test-project/auth-api
RUN npm run build --workspace=web

FROM node:22-alpine AS runner
WORKDIR /repo
ENV NODE_ENV=production
# 80, like the backend's uwsgi, so a portless request reaches either container directly.
ENV PORT=80
ENV HOSTNAME=0.0.0.0
COPY --from=builder /repo/apps/web/.next/standalone ./
COPY --from=builder /repo/apps/web/.next/static ./apps/web/.next/static
COPY --from=builder /repo/apps/web/public ./apps/web/public
EXPOSE 80
CMD ["node", "apps/web/server.js"]
