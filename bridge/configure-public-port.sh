#!/bin/sh
set -u

cd "$(dirname "$0")"
exec >> /tmp/cline-port-visibility.log 2>&1

if [ ! -d node_modules/ws ]; then
  if ! npm install --no-audit --no-fund; then
    echo "ERRORE: installazione dipendenze bridge non riuscita; bridge non avviato." >&2
    exit 1
  fi
fi

if ! command -v cline >/dev/null 2>&1; then
  if ! command -v npm >/dev/null 2>&1; then
    echo "ERRORE: npm non disponibile; impossibile installare Cline CLI." >&2
    exit 1
  fi
  if ! npm install --global --no-audit --no-fund cline; then
    echo "ERRORE: installazione Cline CLI non riuscita; bridge non avviato." >&2
    exit 1
  fi
fi
if ! command -v cline >/dev/null 2>&1; then
  echo "ERRORE: Cline CLI non trovato nel PATH dopo l'installazione." >&2
  exit 1
fi

if ! pgrep -f '[n]ode .*server\.js' >/dev/null; then
  if ! command -v setsid >/dev/null 2>&1; then
    echo "ERRORE: setsid non disponibile; bridge non avviato." >&2
    exit 1
  fi
  setsid -f node server.js > /tmp/cline-bridge.log 2>&1 < /dev/null
fi

if ! command -v curl >/dev/null 2>&1; then
  echo "ERRORE: curl non disponibile; impossibile verificare il bridge." >&2
  exit 1
fi

attempt=1
while [ "$attempt" -le 15 ]; do
  if curl -fsS --max-time 2 http://127.0.0.1:3000/ 2>/dev/null |
    grep -Fxq "Cline Agent Mobile Bridge Server"; then
    echo "Bridge server pronto sulla porta 3000."
    break
  fi
  if [ "$attempt" -eq 15 ]; then
    echo "ERRORE: bridge non risponde sulla porta 3000; ultimi log:" >&2
    tail -n 20 /tmp/cline-bridge.log >&2 || true
    exit 1
  fi
  sleep 2
  attempt=$((attempt + 1))
done

if ! command -v gh >/dev/null 2>&1; then
  echo "ERRORE: GitHub CLI non disponibile; bridge avviato ma porta 3000 non pubblicata." >&2
  exit 1
fi
if [ -z "${CODESPACE_NAME:-}" ]; then
  echo "ERRORE: CODESPACE_NAME non impostato; bridge avviato ma porta 3000 non pubblicata." >&2
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

echo "ERRORE: impossibile pubblicare la porta 3000; bridge lasciato attivo per la diagnosi." >&2
exit 1
