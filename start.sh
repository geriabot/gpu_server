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

# Start the Ollama of an instance (only if it is not running), with the settings of
# instances/<instance>.env, and wait until it answers. Safe to run again (also from cron:
# @reboot bash <path>/gpu_server/start.sh <instance>).
#   bash gpu_server/start.sh <instance>
# It refuses if the port is taken by a process it did not start, and, for an instance with
# EXCLUSIVE=true, if the Ollama of another instance has a model loaded (it would share the GPU).
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
[ $# -eq 1 ] || { echo "usage: $0 <instance> (instances: $(instances | tr '\n' ' '))" >&2; exit 2; }
load_instance "$1"
if [ "$EXCLUSIVE" = true ]; then
  for other in $(instances); do
    [ "$other" = "$INSTANCE" ] && continue
    port=$(OLLAMA_PORT='' bash -c "source '$GPU_SERVER_DIR/instances/$other.env'; echo \$OLLAMA_PORT")
    [ "$port" = "$OLLAMA_PORT" ] && continue
    busy=$(loaded_models "$port")
    if [ -n "$busy" ]; then
      echo "$INSTANCE needs the GPU alone, and instance $other (port $port) has loaded: $busy"
      echo "Unload it (bash $(dirname "$0")/unload.sh $other) or wait"; exit 1
    fi
  done
fi
mkdir -p "$STATE_DIR"
if running; then
  echo "$INSTANCE: already running (PID $(cat "$PID_FILE"), $URL)"
else
  if curl -s -m 2 "$URL" > /dev/null; then
    echo "$INSTANCE: port $OLLAMA_PORT is taken by a process that this script did not start: not started"
    exit 1
  fi
  [ -x "$OLLAMA" ] || { echo "No Ollama in $OLLAMA_DIR: bash $(dirname "$0")/install.sh"; exit 1; }
  mkdir -p "$OLLAMA_MODELS"
  echo "$INSTANCE: starting on port $OLLAMA_PORT (models in $OLLAMA_MODELS)"
  OLLAMA_HOST="127.0.0.1:$OLLAMA_PORT" OLLAMA_MODELS="$OLLAMA_MODELS" \
    OLLAMA_CONTEXT_LENGTH="$OLLAMA_CONTEXT_LENGTH" OLLAMA_MAX_LOADED_MODELS="$OLLAMA_MAX_LOADED_MODELS" \
    OLLAMA_NUM_PARALLEL="$OLLAMA_NUM_PARALLEL" OLLAMA_KEEP_ALIVE="$OLLAMA_KEEP_ALIVE" \
    setsid nohup "$OLLAMA" serve > "$LOG_FILE" 2>&1 < /dev/null &
  echo $! > "$PID_FILE"
  for _ in $(seq 60); do curl -s -m 2 "$URL" > /dev/null && break; sleep 1; done
  curl -s -m 2 "$URL" > /dev/null || { echo "$INSTANCE: it did not answer (log: $LOG_FILE)"; exit 1; }
fi
bash "$(dirname "${BASH_SOURCE[0]}")/status.sh" "$INSTANCE"
