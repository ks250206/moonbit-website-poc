#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
moon build engine --target wasm --release
moon build frontend --target js --release
mkdir -p dist
cp public/* dist/
cp _build/wasm/release/build/engine/engine.wasm dist/engine.wasm
cp _build/js/release/build/frontend/frontend.js dist/app.js
touch dist/.nojekyll
printf '\nStatic app ready in dist/\n'
