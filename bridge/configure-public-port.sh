#!/bin/sh
set -u

cd "$(dirname "$0")"
exec >> /tmp/cline-port-visibility.log 2>&1

if [ ! -d node_modules/ws ]; then
  if ! npm install --no-audit --no-fund; then
    echo "ERRORE: installazione dipendenze bridge non riuscita; bridge non avviato." >&2
    exit 0
  fi
fi

if ! pgrep -f '^node server\.js$' >/dev/null; then
  nohup node server.js > /tmp/cline-bridge.log 2>&1 < /dev/null &
fi

if ! command -v gh >/dev/null 2>&1; then
  echo "ERRORE: GitHub CLI non disponibile; bridge avviato ma porta 3000 non pubblicata." >&2
  exit 0
fi
if [ -z "${CODESPACE_NAME:-}" ]; then
  echo "ERRORE: CODESPACE_NAME non impostato; bridge avviato ma porta 3000 non pubblicata." >&2
  exit 0
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

echo "ERRORE: impossibile pubblicare la porta 3000; bridge lasciato attivo per la diagnosi." >&2
exit 0
