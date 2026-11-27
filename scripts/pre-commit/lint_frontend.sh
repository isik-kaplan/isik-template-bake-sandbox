#!/usr/bin/env bash
set -euo pipefail

# The workspace root, not apps/web, so packages/* are linted too.
cd test_project-frontend
exec npm run lint
