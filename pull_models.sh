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

# Download the models of an instance (MODELS of its .env, or those given) into its directory,
# stopping before the disk gets too full. Its Ollama must be running (start.sh).
#   bash gpu_server/pull_models.sh <instance> [model ...]
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
[ $# -ge 1 ] || { echo "usage: $0 <instance> [model ...]" >&2; exit 2; }
load_instance "$1"; shift
export OLLAMA_HOST="127.0.0.1:$OLLAMA_PORT"
curl -s -m 5 "$URL" > /dev/null || { echo "$INSTANCE is not running: bash $(dirname "$0")/start.sh $INSTANCE"; exit 1; }
MIN_FREE_GB=${MIN_FREE_GB:-30}
for model in ${@:-$MODELS}; do
  free_gb=$(df -BG --output=avail "$OLLAMA_MODELS" | tail -1 | tr -dc 0-9)
  if [ "$free_gb" -lt "$MIN_FREE_GB" ]; then
    echo "Only ${free_gb} GB free in $OLLAMA_MODELS: stopping before $model (MIN_FREE_GB=$MIN_FREE_GB)"; break
  fi
  echo "== $model ($free_gb GB free)"
  "$OLLAMA" pull "$model"
done
"$OLLAMA" list
