#!/bin/bash
# Copyright 2026 Rodrigo Pérez-Rodríguez
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Install Ollama OLLAMA_VERSION (common.sh) in OLLAMA_DIR, in the user's home, without sudo, put it
# in the PATH, and link the command gpu-server in ~/.local/bin. Every instance uses this program:
# the running ones are stopped first (by their PIDs) and must be started again. Another version may
# answer differently: the experiments of each system name the version they were run with.
#   bash gpu_server/install.sh
set -e
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
echo "== GPU"
if ! nvidia-smi --query-gpu=name,memory.total,driver_version --format=csv,noheader; then
  echo "nvidia-smi fails. With 'Driver/library version mismatch', the server must be restarted."
  exit 1
fi
echo "== Ollama $OLLAMA_VERSION"
mkdir -p "$OLLAMA_DIR"
url=$(curl -s "https://api.github.com/repos/ollama/ollama/releases/tags/v$OLLAMA_VERSION" | grep browser_download_url \
      | grep -E 'ollama-linux-amd64\.(tar\.zst|tgz)"' | head -1 | cut -d'"' -f4)
[ -n "$url" ] || { echo "Cannot find the Linux release v$OLLAMA_VERSION of Ollama on GitHub"; exit 1; }
echo "Downloading $url"
tmp="$OLLAMA_DIR/ollama-download"
curl -L "$url" -o "$tmp"
size=$(stat -c %s "$tmp")
[ "$size" -gt 1000000 ] || { echo "The download is $size bytes: not the program"; rm -f "$tmp"; exit 1; }
for name in $(instances); do bash "$GPU_SERVER_DIR/stop.sh" "$name"; done
rm -rf "$OLLAMA_DIR/lib/ollama"                     # the old libraries
case "$url" in
  *.tar.zst) if command -v unzstd > /dev/null; then tar --use-compress-program=unzstd -xf "$tmp" -C "$OLLAMA_DIR";
             else tar --zstd -xf "$tmp" -C "$OLLAMA_DIR"; fi ;;
  *) tar xzf "$tmp" -C "$OLLAMA_DIR" ;;
esac
rm -f "$tmp"
"$OLLAMA" --version || true
grep -q "$OLLAMA_DIR/bin" "$HOME/.bashrc" || echo "export PATH=$OLLAMA_DIR/bin:\$PATH" >> "$HOME/.bashrc"
# The command gpu-server, in ~/.local/bin (in the PATH of Ubuntu once the folder exists)
mkdir -p "$HOME/.local/bin"
if [ -e "$HOME/.local/bin/gpu-server" ] && [ "$(readlink -f "$HOME/.local/bin/gpu-server")" != "$GPU_SERVER_DIR/gpu-server" ]; then
  mv "$HOME/.local/bin/gpu-server" "$HOME/.local/bin/gpu-server.old" && echo "Your earlier gpu-server kept as ~/.local/bin/gpu-server.old"
fi
ln -sfn "$GPU_SERVER_DIR/gpu-server" "$HOME/.local/bin/gpu-server"
echo "== Done. Next: bash $(dirname "$0")/start.sh <instance>, then bash $(dirname "$0")/pull_models.sh <instance>"
