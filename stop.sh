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

# Stop the Ollama of an instance started by start.sh (frees the GPU; the models stay on disk). By
# its PID, never by name: the Ollama of another instance, or of another user, is not touched.
#   bash gpu_server/stop.sh <instance>
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
[ $# -eq 1 ] || { echo "usage: $0 <instance> (instances: $(instances | tr '\n' ' '))" >&2; exit 2; }
load_instance "$1"
if running; then
  pid=$(cat "$PID_FILE"); kill "$pid"
  for _ in $(seq 15); do kill -0 "$pid" 2>/dev/null || break; sleep 1; done
  if kill -0 "$pid" 2>/dev/null; then echo "$INSTANCE: did not stop (PID $pid)"; exit 1; fi
  echo "$INSTANCE: stopped (PID $pid)"
else
  echo "$INSTANCE: was not running"
fi
rm -f "$PID_FILE"
