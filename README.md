<p align="center">
  <img src="assets/logo-nobg.png" alt="Ricochet Logo" width="180"/>
</p>

# Ricochet

**A visual, Docker-powered bioinformatics pipeline builder for your desktop.**

Ricochet lets you build complex bioinformatics analysis pipelines by dragging and dropping Docker containers onto a visual canvas — no YAML, no Bash scripts, no server required. Connect tools like FastQC, STAR, BWA, GATK, and Samtools like building blocks, configure them through a clean GUI, and hit **Execute**. Ricochet handles the rest.

> **"If you can use Figma, you can use Ricochet. If you can run Docker, you can run Ricochet."**



## Features

### Visual Pipeline Canvas

- **Infinite canvas** with smooth pan and zoom
- **Drag-and-drop** nodes from the sidebar or add them directly on the canvas
- **Bezier curve connections** between node ports to represent data flow
- **Cycle detection** — connections that create loops are highlighted and blocked at execution time
- **Canvas reset** button to clear the workspace and start fresh

### Multi-Tab Pipeline Editor (Chrome-style)

- Work on multiple pipelines simultaneously in separate tabs
- Each tab is **independently named, saved, and restored** across sessions
- **Auto-save** — changes are debounced and written to disk (as `pipeline.json`) 2 seconds after each edit
- **Unsaved-changes indicator** (`•`) shown on each tab — prompts before closing
- **Tab renaming** — double-click to rename; folder on disk is renamed accordingly
- **Session restore** — last open pipelines are automatically reloaded on app launch
- Open and **Import** an existing pipeline folder from disk via the toolbar

### Built-in Bioinformatics Tool Blocks

Drag pre-configured nodes from the sidebar with tool-specific defaults:

| Block | Docker Image | Purpose |
|-------|-------------|---------|
| **FastQC** | `staphb/fastqc` | Quality control for sequencing data |
| **Trimmomatic** | `staphb/trimmomatic` | Trim and filter sequencing reads |
| **BWA Aligner** | `staphb/bwa` | Sequence alignment against reference (mem, aln, bwasw) |
| **STAR Aligner** | `staphb/star` | Spliced alignment to reference genome |
| **Samtools** | `staphb/samtools` | Process SAM/BAM alignments (view, sort, index, flagstat, stats) |
| **Input Data** | *(none)* | File picker node — mounts selected file into downstream containers |
| **Output Results** | *(none)* | Receives the final processed data at the end of a pipeline |

### Docker Hub Integration

- **Live search** the Docker Hub registry directly from the sidebar — no browser required
- Search results show stars, pulls, and whether the image is official
- Click any result to drop a fully configured node onto the canvas
- **Smart default tag** — Ricochet automatically fetches the most recent stable tag for each image from Docker Hub (e.g. `0.23.4` instead of `latest`)
- Tag list is sorted by recency using a deterministic algorithm that ranks version-like tags (e.g. `v1.2.3`) above others
- Tag results are **cached with LRU eviction and TTL** to avoid redundant API calls
- In-flight requests are **deduplicated** so rapid searches don't cause repeated network hits

### Node Configuration Panel

Each node exposes fully editable parameters:

- **Text, numeric, dropdown, and file-picker** parameter fields
- Parameters for Docker nodes: **Docker Image**, **Image Tag**, **Command**, **Volume Mounts**, **Environment Variables**, **Port Mappings**
- Pre-filled default commands for well-known images (FastQC, Trimmomatic, BWA, STAR, GATK, MultiQC, Samtools, HISAT2, Bowtie2, Kallisto, Salmon, Cutadapt, Fastp, Python, R/Bioconductor)
- **Retry** button on failed image downloads

### Automatic Docker Image Management

- When a Docker node is dropped onto the canvas, Ricochet immediately checks if the image exists locally
- If not found, it **automatically pulls the image** in the background with a **live layer-by-layer progress bar**
- Pulling and extraction progress is tracked per-layer and displayed inside the node card
- Images already cached locally are recognised instantly (`Image ready`)
- Image pulls can be **cancelled** at any time

### Pipeline Execution Engine

- **Topological sort** (Kahn's algorithm) determines the correct execution order for all connected nodes
- **Data flow** — output from each node is automatically mounted as `/inputs/<filename>` in the next container; `$INPUT_FILE` environment variable is injected for convenience
- Outputs are written to `/outputs/` inside each container, mapped to a **timestamped workspace folder** on the host
- **Heartbeat logging** — every 10 seconds Ricochet logs the elapsed time of long-running containers so you know they're still alive
- **Pre-execution validation** — checks for empty canvas, missing commands, empty Docker image fields, and disconnected nodes before running
- Pipeline stops immediately on the first failed node with detailed error output
- **Stop button** — gracefully kills all running containers mid-execution
- **Run Anyway** option to override validation warnings when needed

### Execution Console (Terminal Panel)

- Slide-up terminal panel accessible from the status bar at the bottom
- **Per-tab logs** — each pipeline tab has its own isolated execution log
- Structured log messages: `[STDOUT]`, `[STDERR]`, `[SYSTEM]`, `[ERROR]`
- Logs show input/output file paths, files produced (with sizes), and elapsed time per node
- **Resizable** — drag to expand or compact the panel (clamped between 100px – 600px)
- Clear logs button to reset the console for a fresh run

### Undo / Redo

- Full **undo/redo history per tab** — each tab maintains its own independent state stack
- History is preserved when switching between tabs
- Undo/redo operates on canvas nodes and connections

### Docker Compose Export

Export your entire pipeline as a **production-ready Docker Compose project**:

- Generates a `.zip` archive containing:
  - `docker-compose.yml` — all services with correct `depends_on: service_completed_successfully` ordering
  - `pipeline_config.env` — all node parameters as overridable environment variables
  - `README.md` — auto-generated documentation with run instructions, lifecycle cheat-sheet, and common fixes
  - `raw_data/` and `results/` placeholder directories
- Service names are auto-slugified from node titles with collision avoidance
- **Platform-aware** — on Apple Silicon, `platform: linux/amd64` is injected automatically; on ARM64 Linux, `platform: linux/arm64` is used instead
- Supports **aggregator nodes** that also start a local HTTP server (`python3 -m http.server 8080`) for viewing results in the browser

### Docker Status Banner

- Persistent banner shown at the top of the UI when Docker is not running or not installed
- **Per-OS** install and launch instructions (macOS, Windows, Linux — see below)
- **Apple Silicon notice** — informs users running on macOS ARM that x86-only images will use emulation
- Execute button is automatically **disabled** when Docker is not available; tooltip explains why
- **Retry** button to re-check Docker status without restarting the app

### Workspace & Persistence

- Each pipeline is saved as a `pipeline.json` file inside its own named folder in the Ricochet workspace
- Each pipeline run gets a **fresh timestamped run directory** — no stale outputs from prior runs
- Node output folders are named `<nodeTitle>_<nodeId>/` for easy identification
- Input file path is passed to downstream containers via volume mounts at `/inputs/<filename>`
- **Open Recent** — toolbar button shows a dialog listing all saved pipelines with their folder paths
- Import any pipeline folder from anywhere on disk via the **Import** button

### Duplicate Nodes

Right-click or menu option to **duplicate** any node — creates a deep copy with a new UUID offset by 30 px. Docker image pull is automatically triggered for the duplicate if it is a Docker node.

### Node Status Indicators

| Status | Meaning |
|--------|---------|
| `idle` | Not yet run |
| `checking` | Verifying if image is cached |
| `downloading` | Pulling image from Docker Hub |
| `ready` | Image cached, ready to execute |
| `running` | Container currently executing |
| `success` | Completed successfully |
| `failed` | Execution failed |
| `error` | Image pull or setup error |



## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     Ricochet Desktop App                     │
│                      (Flutter / Dart)                       │
├───────────────┬─────────────────┬───────────────────────────┤
│  PipelineCanvas│   ToolSidebar  │     ExecutionPanel        │
│  (Nodes +      │  (Docker Hub   │  (Logs, Stop, Resize)     │
│   Connections) │   + Built-ins) │                           │
├───────────────┴─────────────────┴───────────────────────────┤
│                      Controller Layer                       │
│  PipelineController │ ExecutionController │ DockerController│
│  PipelineTabsCtrl   │ DockerSearchController                │
├─────────────────────────────────────────────────────────────┤
│                       Service Layer                         │
│  DockerService (CLI) │ WorkspaceService │ ComposeExportSvc  │
└─────────────────────────────────────────────────────────────┘
                              ↓
           ┌────────────────────────────────┐
           │      Docker Engine (Local)     │
           │  Container 1 │ Container 2 │…  │
           └────────────────────────────────┘
                              ↓
           ┌────────────────────────────────────────────┐
           │  Workspace directory (OS Documents folder) │
           │  run_2025-06-01T10-30-15/                  │
           │  ├── FastQC_<id>/output.txt                │
           │  └── Trimmomatic_<id>/…                    │
           └────────────────────────────────────────────┘
```

### Tech Stack

| Layer | Technology |
|-------|-----------|
| UI Framework | Flutter 3.x / Dart 3.x |
| State Management | GetX 4.x |
| Docker Integration | Docker CLI via Dart `Process` API |
| HTTP (Docker Hub) | `http`, `dio` |
| Serialization | `json_serializable` / `json_annotation` |
| File Picking | `file_picker` |
| Path Handling | `path`, `path_provider` |
| Archive (Export) | `archive` (ZIP) |
| Execution Algorithm | Kahn's Topological Sort |



## Getting Started

### Prerequisites

See [`requirements.txt`](requirements.txt) for the full breakdown. The short version:

| Platform | Flutter SDK | Docker |
|----------|------------|--------|
| **macOS** | ≥ 3.22 | Docker Desktop ≥ 4.x ([download](https://docs.docker.com/desktop/install/mac-install/)) |
| **Windows 10/11** | ≥ 3.22 | Docker Desktop ≥ 4.x + WSL2 backend ([download](https://docs.docker.com/desktop/install/windows-install/)) |
| **Linux** | ≥ 3.22 | Docker Engine **or** Docker Desktop for Linux ([docs](https://docs.docker.com/desktop/install/linux-install/)) |

### Platform-Specific Docker Setup

#### macOS

```bash
# Install Docker Desktop (ARM or Intel build is selected automatically)
open https://docs.docker.com/desktop/install/mac-install/

# Apple Silicon users: enable Rosetta emulation in Docker Desktop
# → Settings → General → "Use Rosetta for x86/amd64 emulation"
```

#### Windows 10 / 11

```powershell
# 1. Enable WSL2 (run as Administrator)
wsl --install

# 2. Download and install Docker Desktop, choosing the WSL2 backend
# → https://desktop.docker.com/win/main/amd64/Docker%20Desktop%20Installer.exe

# 3. After install, Docker Desktop starts automatically
docker run hello-world   # verify it works
```

#### Linux (Ubuntu / Debian)

```bash
# Option A — Docker Engine (lighter, CLI only)
sudo apt-get update
sudo apt-get install -y docker.io

# Add yourself to the docker group (avoids needing sudo for every command)
sudo usermod -aG docker $USER
newgrp docker              # apply without logging out

# Enable the daemon to start on boot
sudo systemctl enable --now docker

# Option B — Docker Desktop for Linux (GUI + tray icon)
# Follow the official guide: https://docs.docker.com/desktop/install/linux-install/

# Verify
docker run hello-world
```

#### Linux (Fedora / RHEL / CentOS)

```bash
sudo dnf install -y docker-ce docker-ce-cli containerd.io
sudo usermod -aG docker $USER
sudo systemctl enable --now docker
```

#### Linux (Arch)

```bash
sudo pacman -S docker
sudo usermod -aG docker $USER
sudo systemctl enable --now docker
```

### Build & Run Ricochet

```bash
# 1. Install Flutter SDK (https://docs.flutter.dev/get-started/install)

# 2. Clone and install dependencies
git clone <repo-url>
cd ricochet
flutter pub get

# 3. Run (pick your target platform)
flutter run -d macos      # macOS
flutter run -d windows    # Windows
flutter run -d linux      # Linux (GTK)

# 4. Production build
flutter build macos       # .app bundle
flutter build windows     # MSIX installer
flutter build linux       # ELF binary
```



## Usage Walkthrough

1. **Open Ricochet** — a blank canvas tab is created automatically
2. **Search Docker Hub** in the sidebar search bar, or drag a built-in block (FastQC, BWA, etc.) onto the canvas
3. **Configure each node** — click a node to open its parameter panel; set the command, image tag, volumes, etc.
4. **Connect nodes** — drag from an output port on one node to an input port on another to establish data flow
5. **Add an Input node** and select your FASTQ/FASTA/BAM file — this mounts the file into the first tool container at `/inputs/<filename>` (available inside the container as `$INPUT_FILE`)
6. **Execute** — click the green **Execute** button; the terminal panel slides up showing live logs
7. **View results** — output files are written to the workspace folder shown in the terminal log
8. **Export** — click **Export Docker** to download a ready-to-run `docker-compose.yml` project



## Workspace Location

Ricochet stores all pipelines and run outputs in the platform Documents folder:

| Platform | Path |
|----------|------|
| **macOS** | `~/Documents/Ricochet/` |
| **Windows** | `C:\Users\<user>\Documents\Ricochet\` |
| **Linux** | `~/Documents/Ricochet/` (or `$XDG_DOCUMENTS_DIR/Ricochet/`) |

Structure inside the workspace:

```
Ricochet/
├── Pipelines/
│   ├── My RNA-Seq Pipeline/
│   │   └── pipeline.json
│   └── Variant Calling/
│       └── pipeline.json
├── Runs/
│   ├── run_2025-06-01T10-30-15/
│   │   ├── FastQC_<id>/output.txt
│   │   └── Trimmomatic_<id>/trimmed.fastq.gz
│   └── run_2025-06-01T11-45-02/
└── exports/
    └── Ricochet-export_2025-06-01T12-00-00.zip
```



## ⚠️ Platform Notes & Known Limitations

### All Platforms

- Ricochet only supports **Directed Acyclic Graphs (DAGs)** — circular connections are blocked at execution time
- Nodes must be **connected** in a multi-node pipeline — disconnected nodes are flagged before execution
- Input files must exist on disk and be readable — Ricochet warns if biological sequence files appear suspiciously small (likely a failed download)

### macOS

- **Apple Silicon (M1/M2/M3):** Docker Desktop must have Rosetta 2 emulation enabled for x86/amd64 images. Ricochet automatically injects `--platform linux/amd64` when pulling or running images. An info notice appears in the toolbar when Apple Silicon is detected.
- **Sandboxed app:** Ricochet sets `DOCKER_HOST` and `DOCKER_CONFIG` explicitly to the real home directory so the Docker daemon can be reached from inside the macOS sandbox.

### Windows

- Docker **must** use the **WSL2 backend** (not Hyper-V). The WSL2 backend is required for reliable volume mounts and process management.
- Windows host paths in volume mounts are automatically translated to the WSL-compatible format (e.g. `C:\Users\me\data.fastq` → `/c/Users/me/data.fastq`) — you do not need to do this manually.
- The Docker executable is searched at `C:\Program Files\Docker\Docker\resources\bin\docker.exe` before falling back to `docker.exe` on `PATH`.
- Open output directory uses `explorer.exe` to open the workspace folder.

### Linux

- **Docker group membership is required.** If you installed Docker Engine (not Desktop), run `sudo usermod -aG docker $USER` and log out/in. Without this, the app cannot communicate with the Docker daemon.
- **Socket auto-detection:** Ricochet checks for the Docker Desktop user-scoped socket (`~/.docker/run/docker.sock`) first, then falls back to the system socket (`/var/run/docker.sock`). If neither exists, it relies on the `docker` binary's own context discovery.
- **ARM64 Linux** (Raspberry Pi 4/5, AWS Graviton, etc.): Ricochet automatically requests `--platform linux/arm64` so native arm64 images are preferred, avoiding emulation.
- **x86_64 Linux** (most desktops/servers): no platform flag needed — native amd64 containers run without emulation.
- Open output directory uses `xdg-open` to open the workspace folder in the default file manager.
- GTK 3 development libraries are required to build the app — see [`requirements.txt`](requirements.txt).



## License

See [LICENSE](LICENSE) for details.
