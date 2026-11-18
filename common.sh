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

# Sourced by the other scripts. The settings of the program (install.sh), and those of an instance
# (instances/<instance>.env).
GPU_SERVER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OLLAMA_DIR="${OLLAMA_DIR:-$HOME/ollama}"          # the Ollama program, shared by every instance
OLLAMA_VERSION="${OLLAMA_VERSION:-0.40.2}"        # the version install.sh installs
STATE_DIR="${STATE_DIR:-$HOME/.gpu_server}"       # the PID and log of every instance
OLLAMA="$OLLAMA_DIR/bin/ollama"

instances() { for f in "$GPU_SERVER_DIR"/instances/*.env; do basename "$f" .env; done; }

# load_instance NAME: the settings of instances/NAME.env, with their defaults
load_instance() {
  INSTANCE=$1
  local env="$GPU_SERVER_DIR/instances/$INSTANCE.env"
  [ -f "$env" ] || { echo "No instance '$INSTANCE' (instances: $(instances | tr '\n' ' '))" >&2; exit 2; }
  # Only the file sets an instance (not the environment, where an OLLAMA_MODELS of the shell
  # would move every instance); another setting is another instance file
  unset OLLAMA_PORT OLLAMA_MODELS OLLAMA_CONTEXT_LENGTH OLLAMA_MAX_LOADED_MODELS OLLAMA_NUM_PARALLEL \
    OLLAMA_KEEP_ALIVE MODELS EXCLUSIVE
  # shellcheck disable=SC1090
  source "$env"
  : "${OLLAMA_PORT:?instances/$INSTANCE.env must set OLLAMA_PORT}"
  OLLAMA_MODELS="${OLLAMA_MODELS:-$HOME/ollama_models}"
  OLLAMA_CONTEXT_LENGTH="${OLLAMA_CONTEXT_LENGTH:-8192}"
  OLLAMA_MAX_LOADED_MODELS="${OLLAMA_MAX_LOADED_MODELS:-1}"
  OLLAMA_NUM_PARALLEL="${OLLAMA_NUM_PARALLEL:-1}"
  OLLAMA_KEEP_ALIVE="${OLLAMA_KEEP_ALIVE:-5m}"
  MODELS="${MODELS:-}"
  EXCLUSIVE="${EXCLUSIVE:-false}"
  PID_FILE="$STATE_DIR/$INSTANCE.pid"
  LOG_FILE="$STATE_DIR/$INSTANCE.log"
  URL="http://127.0.0.1:$OLLAMA_PORT"
}

# Whether the Ollama of the loaded instance (the process of its PID file) is running
running() { [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; }

# The models loaded now by the Ollama of an instance (empty if it does not answer)
loaded_models() {
  curl -s -m 3 "http://127.0.0.1:$1/api/ps" 2>/dev/null |
    python3 -c "import json,sys; print(' '.join(m['name'] for m in json.load(sys.stdin).get('models', [])))" 2>/dev/null
}
