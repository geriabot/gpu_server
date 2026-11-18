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

# The GPU, and the Ollama of every instance (or of the one given): running or not, its models on
# disk and those loaded. It asks each Ollama through its port.
#   bash gpu_server/status.sh [instance]
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
json() { python3 -c "import json,sys; d=json.load(sys.stdin); $1" 2>/dev/null; }
echo "== GPU"
nvidia-smi --query-gpu=name,memory.used,memory.total --format=csv,noheader 2>&1 | head -2
nvidia-smi --query-compute-apps=pid,used_memory --format=csv,noheader 2>/dev/null |
  while IFS=, read -r pid mem; do echo "  PID $pid ($(ps -o user= -p "$pid" 2>/dev/null)),$mem"; done
[ -x "$OLLAMA" ] && echo "== Ollama installed: $("$OLLAMA" --version 2>/dev/null | grep -o '[0-9][0-9.]*$') (in $OLLAMA_DIR)"
for name in ${1:-$(instances)}; do
  ( load_instance "$name"
    echo "== $INSTANCE ($URL, models in $OLLAMA_MODELS)"
    if tags=$(curl -s -m 3 "$URL/api/tags"); then
      if running; then echo "  running, PID $(cat "$PID_FILE")"
      else echo "  an Ollama answers on its port, not started as this instance (another instance on the same port?)"; fi
      echo "$tags" | json "[print(f\"  on disk: {m['name']} ({m['size']/1e9:.1f} GB)\") for m in d['models']]"
      for m in $(loaded_models "$OLLAMA_PORT"); do echo "  loaded: $m"; done
    else
      echo "  not running (bash $(dirname "$0")/start.sh $INSTANCE; log: $LOG_FILE)"
    fi
    [ -d "$OLLAMA_MODELS" ] && echo "  disk: $(df -h "$OLLAMA_MODELS" | tail -1 | awk '{print $4 " free of " $2}'), models $(du -sh "$OLLAMA_MODELS" 2>/dev/null | cut -f1)" )
done
