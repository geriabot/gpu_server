# gpu_server

Run the language models of several robot systems on one shared GPU server, with
[Ollama](https://ollama.com), in your home directory and without `sudo`.

The robot's computer needs no GPU: the models run on the server, and the robot reaches them through
an SSH tunnel. Several systems share the server, and each has its own **instance**: an Ollama on
its own port, with its own models and settings, started and stopped on its own. Stopping one
never touches the others.

| Instance | System | Port | Models directory | What it runs |
|---|---|---|---|---|
| `attention` | [attention_system](https://github.com/geriabot/attention_system) | 11434 | `~/ollama_models` | `qwen2.5vl:32b`, 8k context, one model loaded |
| `interaction` | [interaction_system](https://github.com/geriabot/interaction_system), real sessions | 11436 | `/var/tmp/<user>_ollama_models` | `qwen3:8b`, 8k context, with the GPU to itself |
| `interaction_sim` | interaction_system, simulated experiments | 11436 | `/var/tmp/<user>_ollama_models` | `qwen3:8b` and `gemma3:12b` loaded together |

## Requirements

On the server:

- An NVIDIA GPU with its driver installed: `nvidia-smi` works. 24 GB of GPU memory for
  `qwen2.5vl:32b`.
- `git`, `curl`, `python3`, and `tar` with zstd support (`unzstd` or `tar --zstd`).
- Free disk for the models of your instance (`qwen2.5vl:32b`: 21 GB; `qwen3:8b`: 5 GB) and for
  Ollama (2 GB).

On the robot's computer: SSH access to the server.

## Quick start

Replace `<instance>` with that of your system (table above), `<user>@<server>` with your account
on the server.

**1. Install, once, on the server:**

```sh
git clone https://github.com/geriabot/gpu_server.git ~/gpu_server
bash ~/gpu_server/install.sh
```

This installs Ollama in `~/ollama`, shared by every instance, at the version in `common.sh`.

**2. Start your instance, on the server:**

```sh
bash ~/gpu_server/start.sh <instance>
```

It prints `starting on port ...` and then the state of the instance. Run it again after every
restart of the server: nothing starts by itself.

**3. Download its models, once, on the server:**

```sh
bash ~/gpu_server/pull_models.sh <instance>
```

**4. Check it, on the server:**

```sh
bash ~/gpu_server/status.sh
```

It shows the GPU and who uses it, and, for each instance, whether it runs, its models on disk,
the models loaded in the GPU, and the free disk.

**5. Reach it from the robot's computer.** Open an SSH tunnel to the port of the instance and
leave the terminal open:

```sh
ssh -N -o ServerAliveInterval=30 -o ExitOnForwardFailure=yes -L <local port>:localhost:<port> <user>@<server>
curl http://localhost:<local port>/api/tags     # in another terminal: the models of the instance
```

Each system may bring its own script for this step (it opens the tunnel and checks that the model
is the right one): see its documentation. Use a local port that no Ollama of the robot's computer
already holds.

**6. When you are done, on the server:**

```sh
bash ~/gpu_server/unload.sh <instance>     # free the GPU, keep Ollama running
bash ~/gpu_server/stop.sh <instance>       # stop Ollama; the models stay on disk
```

## The scripts

| Script | What it does |
|---|---|
| `install.sh` | Installs Ollama `OLLAMA_VERSION` (`common.sh`) in `~/ollama` and puts it in the `PATH`. Stops the running instances first: start them again afterwards |
| `start.sh <instance>` | Starts the Ollama of the instance, if not running, and waits until it answers. Refuses if its port is taken by a process it did not start, and, for an instance with `EXCLUSIVE=true`, if another instance has a model loaded |
| `pull_models.sh <instance> [model ...]` | Downloads the models of the instance (`MODELS`), or those given, into its directory. Stops when fewer than `MIN_FREE_GB` (30) GB are free there |
| `status.sh [instance]` | The GPU and its processes, the Ollama version, and every instance (or the one given) |
| `unload.sh <instance>` | Unloads its models from the GPU |
| `stop.sh <instance>` | Stops its Ollama |
| `common.sh` | Settings shared by all: `OLLAMA_DIR` (`~/ollama`), `OLLAMA_VERSION`, `STATE_DIR` (`~/.gpu_server`) |

`start.sh` records the process of each instance in `~/.gpu_server/<instance>.pid`, its log in
`~/.gpu_server/<instance>.log`, and `stop.sh` stops it by that PID.

## Adding a system

Write `instances/<name>.env` (copy one of the others) and start it with
`start.sh <name>`:

| Variable | Default | Meaning |
|---|---|---|
| `OLLAMA_PORT` | (required) | Its port, on `127.0.0.1`. One no other instance uses, unless they never run together |
| `OLLAMA_MODELS` | `~/ollama_models` | Its models directory. Instances may share one |
| `OLLAMA_CONTEXT_LENGTH` | 8192 | The default context of its models. A 32B model fits whole in a 24 GB GPU only with 8k |
| `OLLAMA_MAX_LOADED_MODELS` | 1 | Models in GPU memory at a time |
| `OLLAMA_NUM_PARALLEL` | 1 | Requests answered at once per model |
| `OLLAMA_KEEP_ALIVE` | `5m` | How long a model stays loaded after its last request, unless the request says otherwise |
| `MODELS` | (none) | What `pull_models.sh` downloads |
| `EXCLUSIVE` | `false` | `true`: `start.sh` refuses while another instance has a model loaded, for a system whose results need the GPU to itself |

Only this file sets an instance: a variable of the shell does not change it. A different setting
for the same system is another file (as `interaction_sim`). Two instances on the same port cannot
run at the same time.

## Rules of a shared server

- **Never stop Ollama by name** (`pkill -f "ollama serve"`): it would stop every instance, and
  any other Ollama of your account. Use `stop.sh <instance>`.
- **The GPU.** Look at `status.sh` before long runs. When your instance does not need its models,
  `unload.sh` or `stop.sh` it.
- **The disk.** Keep the list of models short; remove one with
  `OLLAMA_HOST=127.0.0.1:<port> ~/ollama/bin/ollama rm <model>`. Put the models of an instance
  where there is room (`OLLAMA_MODELS`). `/var/tmp` may be cleaned of files unused for a long time.
- **The version.** The results of each system were obtained with a version of Ollama; another one
  may answer differently. Change `OLLAMA_VERSION` only knowing that.
- **SSH.** Some servers block an address that opens many SSH connections in a short time: keep one
  connection (the tunnel) open instead of opening many.

## Updating

```sh
cd ~/gpu_server && git pull
```

The running instances keep running; a change of their `.env` takes effect at their next
`stop.sh` and `start.sh`. A change of `OLLAMA_VERSION`: `install.sh`.

## Problems and fixes

| Symptom | Cause | Fix |
|---|---|---|
| `nvidia-smi`: `Driver/library version mismatch` | The driver was updated and the server not restarted | Restart the server |
| `start.sh`: `No Ollama in ...` | Ollama is not installed | `install.sh` |
| `start.sh`: `port ... is taken by a process that this script did not start` | Another Ollama holds the port: another instance on the same port, one started by hand, or a service of the server | `status.sh`; stop it with its own scripts, or give the instance another port |
| `start.sh`: `needs the GPU alone` | Another instance has a model loaded | `unload.sh <other instance>`, or wait |
| `start.sh`: `it did not answer` | Ollama failed at start | Its log, `~/.gpu_server/<instance>.log` |
| A model runs partly on the CPU (`OLLAMA_HOST=127.0.0.1:<port> ~/ollama/bin/ollama ps`: not `100% GPU`) | The GPU is shared with another process (`status.sh` lists them), or `OLLAMA_CONTEXT_LENGTH` is too large for the model | Free the GPU, or a shorter context |
| `ollama list` is empty although the models were downloaded | That Ollama runs with another models directory | Start it only with `start.sh` |
| Disk taken by interrupted downloads | Partial files of a canceled pull | `stop.sh` and `start.sh`: Ollama removes them when it starts |
| Through the tunnel, `curl` times out | The tunnel died (network change, suspend) but its `ssh` still holds the local port | `ss -ltnp \| grep <local port>` gives its PID; `kill <PID>`, and open the tunnel again |

## License

Apache 2.0 ([LICENSE](LICENSE)).
