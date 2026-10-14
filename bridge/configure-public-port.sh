#!/bin/sh
set -u

cd "$(dirname "$0")"
exec >> /tmp/cline-port-visibility.log 2>&1

if [ ! -d node_modules/ws ]; then
  if ! npm install --no-audit --no-fund; then
    echo "Installazione dipendenze bridge non riuscita." >&2
    exit 1
  fi
fi

if ! pgrep -f '[n]ode server.js' >/dev/null; then
  nohup node server.js > /tmp/cline-bridge.log 2>&1 < /dev/null &
fi

if ! command -v gh >/dev/null 2>&1; then
  echo "GitHub CLI non disponibile; impossibile pubblicare la porta 3000." >&2
  exit 1
fi
if [ -z "${CODESPACE_NAME:-}" ]; then
  echo "CODESPACE_NAME non impostato; impossibile selezionare il Codespace per la porta 3000." >&2
  exit 1
fi

attempt=1
while [ "$attempt" -le 12 ]; do
  if gh codespace ports visibility "3000:private" --codespace "$CODESPACE_NAME" &&
    gh codespace ports visibility "3000:public" --codespace "$CODESPACE_NAME"; then
    echo "Porta 3000 pubblicata automaticamente."
    exit 0
  fi
  echo "Pubblicazione porta 3000 non riuscita (tentativo $attempt/12)." >&2
  sleep 5
  attempt=$((attempt + 1))
done

echo "Impossibile pubblicare la porta 3000; controlla autenticazione GH CLI e policy Codespaces." >&2
exit 1
