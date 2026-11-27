#!/bin/bash
# The e2e backend without Docker, for the iOS flows: GitHub's Apple-silicon runners can't run containers.
# Serves the API on 127.0.0.1:80 (the caller points api. and auth.testproject.test there in /etc/hosts),
# Mailpit on 8025 and the texts on 8026, with the e2e stack's settings. macOS with Homebrew and uv; sudo for port 80.
set -euo pipefail
cd "$(dirname "$0")/../.."
state="$PWD/e2e/maestro/.native"
mkdir -p "$state/sms"
[ -f .env ] || cp .env.example .env
value() { sed -n "s/^TEST_PROJECT__$1=//p" .env; }
# As the backend reads it: unset, the answer given at generation.
cache="$(value CACHE__BACKEND)"
cache="${cache:-redis}"

brew install postgresql@18 mailpit $([ "$cache" = redis ] && echo redis) rabbitmq gettext

pg="$(brew --prefix postgresql@18)/bin"
# TCP only: a socket under the checkout would pass the 103 characters macOS allows its path.
"$pg/initdb" -D "$state/pg" -U postgres --auth=trust >/dev/null
"$pg/pg_ctl" -D "$state/pg" -l "$state/postgres.log" -o "-h 127.0.0.1 -k ''" -w start
"$pg/psql" -h 127.0.0.1 -U postgres -v ON_ERROR_STOP=1 \
  -c "CREATE ROLE \"$(value DB__USER)\" LOGIN SUPERUSER PASSWORD '$(value DB__PASSWORD)'" \
  -c "CREATE DATABASE \"$(value DB__NAME)\" OWNER \"$(value DB__USER)\""
if [ "$cache" = redis ]; then
  redis-server --bind 127.0.0.1 --requirepass "$(value CACHE__PASSWORD)" --daemonize yes --logfile "$state/redis.log"
fi

# The stack's own broker settings, which RabbitMQ 4 needs for Celery.
# In the background and polled: await_startup gives up at once on a node that hasn't registered yet.
RABBITMQ_CONFIG_FILE="$PWD/broker/broker.conf" rabbitmq-server >"$state/rabbitmq.log" 2>&1 &
for _ in $(seq 60); do
  rabbitmq-diagnostics -q ping >/dev/null 2>&1 && break
  sleep 2
done
rabbitmq-diagnostics -q ping >/dev/null || { cat "$state/rabbitmq.log" >&2; exit 1; }
# The node answers ping before its app has booted, and add_user needs the app.
rabbitmqctl await_startup --timeout 120
rabbitmqctl add_user "$(value BROKER__USER)" "$(value BROKER__PASSWORD)"
rabbitmqctl set_permissions -p / "$(value BROKER__USER)" ".*" ".*" ".*"

mailpit --smtp 127.0.0.1:1025 --listen 127.0.0.1:8025 >"$state/mailpit.log" 2>&1 &
python3 -m http.server 8026 --bind 127.0.0.1 --directory "$state/sms" >"$state/sms.log" 2>&1 &

# Where the stack's containers find each of these, here on this machine; the rest is e2e/.env's.
export TEST_PROJECT__DB__HOST=127.0.0.1
export TEST_PROJECT__CACHE__HOST=127.0.0.1
export TEST_PROJECT__BROKER__HOST=127.0.0.1
export TEST_PROJECT__EMAIL__BACKEND=smtp
export TEST_PROJECT__EMAIL__SMTP__HOST=127.0.0.1
export TEST_PROJECT__EMAIL__SMTP__PORT=1025
export TEST_PROJECT__EMAIL__SMTP__USE_TLS=false
export TEST_PROJECT__SMS__BACKEND=file
export TEST_PROJECT__SMS__FILE_PATH="$state/sms/messages.jsonl"
export TEST_PROJECT__RATE_LIMITS__ENABLED=false

cd test_project
uv sync --frozen
uv run python manage.py compilemessages -i .venv -i mutants
uv run python manage.py migrate
uv run python manage.py createcachetable
uv run python manage.py setup
# Threads, not forks: a forked worker on macOS can die or hang in the system's networking. From .venv, not
# uv run, which holds uv's cache lock while it runs and leaves the job's cache save waiting on it.
PYTHONUNBUFFERED=1 .venv/bin/celery -A test_project worker --pool threads --loglevel INFO >"$state/worker.log" 2>&1 &
# Port 80 is root's; -E keeps the settings above.
sudo -E PYTHONUNBUFFERED=1 .venv/bin/python manage.py runserver 127.0.0.1:80 --noreload >"$state/backend.log" 2>&1 &
for _ in $(seq 60); do
  curl -sf -H "Host: localhost" http://127.0.0.1/health/ >/dev/null && exit 0
  sleep 2
done
cat "$state/backend.log" >&2
exit 1
