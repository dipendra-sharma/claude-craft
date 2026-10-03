#!/bin/bash
set -euo pipefail
three_version=0.186.1
case_dir=$(cd "$(dirname "$0")" && pwd)
vendor="$case_dir/vendor"
if [ ! -f "$vendor/three/package.json" ]; then
  mkdir -p "$vendor"
  tarball=$(npm pack "three@$three_version" --pack-destination "$vendor" --silent)
  mkdir -p "$vendor/three"
  tar -xzf "$vendor/$tarball" -C "$vendor/three" --strip-components 1
fi
mkdir -p node_modules/three
cp "$vendor/three/package.json" node_modules/three/
cp -R "$vendor/three/build" node_modules/three/
cat > package.json <<JSON
{
  "name": "asteroid-dodge",
  "private": true,
  "type": "module",
  "scripts": {
    "test": "node --test"
  },
  "dependencies": {
    "three": "$three_version"
  }
}
JSON
printf 'node_modules/\n' > .gitignore
git init -q
git add -A
git -c user.name=fixture -c user.email=fixture@example.invalid commit -qm "Empty game project with three.js installed"
