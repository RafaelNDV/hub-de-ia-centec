#!/bin/sh

set -eu

dependency_marker='node_modules/.hub-ia-package-lock.sha256'
lock_hash="$(sha256sum package-lock.json | awk '{ print $1 }')"
installed_hash=''

if [ -f "$dependency_marker" ]; then
	installed_hash="$(cat "$dependency_marker")"
fi

if [ "$installed_hash" != "$lock_hash" ] || [ ! -f node_modules/vite/bin/vite.js ]; then
	echo '[frontend] Instalando dependencias no volume Docker. Isso ocorre apenas na primeira execucao ou quando package-lock.json mudar.'
	npm ci --no-audit --no-fund
	printf '%s' "$lock_hash" > "$dependency_marker"
else
	echo '[frontend] Dependencias existentes estao atualizadas.'
fi

echo '[frontend] Iniciando Vite em http://localhost:5173'
exec node node_modules/vite/bin/vite.js dev --host 0.0.0.0
