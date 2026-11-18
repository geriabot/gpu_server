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

# Unload the models of an instance from the GPU, leaving its Ollama running.
#   bash gpu_server/unload.sh <instance>
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
[ $# -eq 1 ] || { echo "usage: $0 <instance>" >&2; exit 2; }
load_instance "$1"
for model in $(loaded_models "$OLLAMA_PORT"); do
  curl -s -m 60 "$URL/api/generate" -d "{\"model\":\"$model\",\"keep_alive\":0}" > /dev/null &&
    echo "$INSTANCE: $model unloaded"
done
