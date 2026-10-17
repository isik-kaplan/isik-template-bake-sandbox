#!/usr/bin/env bash
# Drafts the privacy policy and terms of service with app-privacy-policy-generator, filled from this project's
# answers, into the files the legal pages read. Optional, and only when run: its code is AGPL-3.0, so it is fetched
# into a temporary directory and run there, never copied into this repository. What it writes is a starting point
# for a lawyer, not a finished document.
#
#   bash scripts/generate-legal.sh [--force]
#
# Answers can be overridden through the environment:
#   LEGAL_OWNER       who the documents name as responsible (default: Test Author)
#   LEGAL_OWNER_TYPE  Individual or Company (default: Individual)
#   LEGAL_CONTACT     the contact address they give (default: test@example.test)
#   LEGAL_POLICY      gdpr, simple or no-tracking (default: gdpr)
#   LEGAL_SERVICES    third-party services to name, comma-separated, as the generator spells them
#                     (default: Sentry,Expo)
set -euo pipefail

cd "$(dirname "$0")/.."

# Pinned, so the page this drives is the one it was written against. Moving it is a reviewed change.
GENERATOR_REPOSITORY=https://github.com/nisrulz/app-privacy-policy-generator
GENERATOR_COMMIT=2848bb8493efddd44a62aa8d80a387e8dfc8df6d
HOSTED=https://app-privacy-policy-generator.nisrulz.com/
OUT=test_project-frontend/apps/web/src/legal/en
FILES=(privacy-policy terms-of-service)

manual() {
  cat >&2 <<MANUAL

Generate them by hand instead: open $HOSTED, answer its wizard with
  app name: Test Project    contact: ${LEGAL_CONTACT:-test@example.test}
  platforms: Web, Android, iOS
and export each document as Markdown into:
  $OUT/privacy-policy.md
  $OUT/terms-of-service.md
MANUAL
  exit 1
}

if [ "${1:-}" != "--force" ]; then
  for name in "${FILES[@]}"; do
    if [ -s "$OUT/$name.md" ]; then
      echo "$OUT/$name.md already exists; rerun with --force to replace it." >&2
      exit 1
    fi
  done
fi

command -v docker >/dev/null || { echo "docker is needed to run the generator." >&2; manual; }
command -v curl >/dev/null || { echo "curl is needed to fetch the generator." >&2; manual; }

workdir="$(mktemp -d)"
trap 'rm -rf "$workdir" 2>/dev/null || true' EXIT

echo "Fetching $GENERATOR_REPOSITORY at $GENERATOR_COMMIT..."
curl -fsSL "https://codeload.github.com/nisrulz/app-privacy-policy-generator/tar.gz/$GENERATOR_COMMIT" \
  | tar -xz -C "$workdir" --strip-components=1 || manual

image="${COMPOSE_PROJECT_NAME:-test-project}-legal-generator"
echo "Building the browser image (the e2e suite's own)..."
docker build -q -t "$image" e2e/playwright >/dev/null || manual

# Built by python3 rather than spliced into a string, so a quote in a name cannot break the JSON.
answers=$(
  LEGAL_OWNER="${LEGAL_OWNER:-Test Author}" \
  LEGAL_OWNER_TYPE="${LEGAL_OWNER_TYPE:-Individual}" \
  LEGAL_CONTACT="${LEGAL_CONTACT:-test@example.test}" \
  LEGAL_POLICY="${LEGAL_POLICY:-gdpr}" \
  LEGAL_SERVICES="${LEGAL_SERVICES:-Sentry,Expo}" \
  python3 -c '
import json, os
print(json.dumps({
    "appName": "Test Project",
    "owner": os.environ["LEGAL_OWNER"],
    "ownerType": os.environ["LEGAL_OWNER_TYPE"],
    "contact": os.environ["LEGAL_CONTACT"],
    "policy": os.environ["LEGAL_POLICY"],
    "platforms": ["Web", "Android", "iOS"],
    "services": [name.strip() for name in os.environ["LEGAL_SERVICES"].split(",") if name.strip()],
}))'
)

echo "Generating..."
docker run --rm \
  -v "$workdir/public:/generator:ro" \
  -v "$PWD/scripts/generate-legal.mjs:/e2e/generate-legal.mjs:ro" \
  -e LEGAL_ANSWERS="$answers" \
  "$image" node generate-legal.mjs > "$workdir/documents.json" || manual

mkdir -p "$OUT"
python3 - "$workdir/documents.json" "$OUT" <<'PY'
import json, pathlib, sys
documents, out = json.loads(pathlib.Path(sys.argv[1]).read_text()), pathlib.Path(sys.argv[2])
for slug, markdown in documents.items():
    (out / f"{slug}.md").write_text(markdown)
    print(f"wrote {out / f'{slug}.md'}")
PY

python3 scripts/pre-commit/legal_version.py || true

cat <<DONE

Drafted by app-privacy-policy-generator ($GENERATOR_REPOSITORY). Read both documents, fill in anything the
generator left as a placeholder, and have them reviewed by someone qualified before launch: a generated policy
describes a generic app, not this one. The privacy policy page adds this site's cookie disclosure on its own.
DONE
