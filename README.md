<p align="center">
  <img src="assets/ricochet_logo.svg" alt="Ricochet Logo" width="300"/>
</p>

# Ricochet

**A visual, Docker-powered bioinformatics pipeline builder for your desktop.**

Ricochet lets you build complex bioinformatics analysis pipelines by dragging and dropping Docker containers onto a visual canvas: no YAML, no Bash scripts, no server required. Connect tools like FastQC, STAR, BWA, GATK, and Samtools like building blocks, configure them through a clean GUI, and hit **Execute**. Ricochet handles the rest.

> **"If you can use Figma, you can use Ricochet. If you can run Docker, you can run Ricochet."**

## Features

### Home Screen & Template Gallery

When you launch Ricochet you are greeted by a **Home Screen** — not a blank canvas. It provides:

- **Recent Pipelines** sidebar: lists every saved pipeline with its folder path; click to open instantly.
- **New Blank Pipeline** button to start from scratch.
- **Template Gallery** with category filter chips (All, Quick Start, Preprocessing, Genomics, Transcriptomics) and animated, gradient-accented template cards.
- **Keyboard Shortcuts** and **About** dialogs accessible from the top bar.
- **Animated transition** (220 ms fade) between the Home Screen and the Editor.

### Curated Pipeline Templates

Pick a curated template to pre-populate the canvas with nodes, connections, and sensible defaults — no setup required.

| Template | Category | Docker Images | Est. Time | Difficulty |
|----------|----------|--------------|-----------|------------|
| **Quality Check** | Quick Start | `staphb/fastqc` | ~3 min | Beginner |
| **Trim & QC** | Preprocessing | `staphb/trimmomatic`, `staphb/fastqc` | ~8 min | Beginner |
| **DNA Alignment** | Genomics | `staphb/bwa`, `staphb/samtools` | ~20 min | Intermediate |
| **RNA-seq Quantification** | Transcriptomics | `staphb/star`, `staphb/subread` | ~25 min | Intermediate |
| **Variant Calling** | Genomics | `staphb/bwa`, `staphb/samtools`, `broadinstitute/gatk` | ~45 min | Advanced |

After a template is loaded the canvas **auto-fits** to show all nodes immediately — no manual zoom required.

### Visual Pipeline Canvas

- **Infinite canvas** with smooth pan and zoom
- **Drag-and-drop** nodes from the sidebar or add them directly on the canvas
- **Bezier curve connections** between node ports to represent data flow
- **Cycle detection**: connections that create loops are highlighted and blocked at execution time
- **Canvas reset** button to clear the workspace and start fresh
- **Fit-to-Canvas**: after loading a template the view automatically frames all nodes

### Multi-Tab Pipeline Editor (Chrome-style)

- Work on multiple pipelines simultaneously in separate tabs
- Each tab is **independently named, saved, and restored** across sessions
- **Auto-save**: changes are debounced and written to disk (as `pipeline.json`) 2 seconds after each edit
- **Unsaved-changes indicator** (`•`) shown on each tab: prompts before closing
- **Tab renaming**: double-click to rename; folder on disk is renamed accordingly
- **Session restore**: last open pipelines are automatically reloaded on app launch
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
| **Input Data** | *(none)* | Multi-file picker node: mounts selected files into downstream containers |
| **Output Results** | *(none)* | Receives the final processed data at the end of a pipeline |

### Docker Hub Integration

- **Live search** the Docker Hub registry directly from the sidebar: no browser required
- Search results show stars, pulls, and whether the image is official
- Click any result to drop a fully configured node onto the canvas
- **Smart default tag**: Ricochet automatically fetches the most recent stable tag for each image from Docker Hub (e.g. `0.23.4` instead of `latest`)
- Tag list is sorted by recency using a deterministic algorithm that ranks version-like tags (e.g. `v1.2.3`) above others
- Tag results are **cached with LRU eviction and TTL** plus **Stale-While-Revalidate** — stale data is returned immediately while a background refresh runs
- In-flight requests are **deduplicated** so rapid searches do not cause repeated network hits

### Node Configuration Panel

Each node exposes fully editable parameters:

- **Text, numeric, dropdown, and file-picker** parameter fields
- **Resizable sidebar**: drag the left edge to resize between 280 px and 700 px wide
- Parameters for Docker nodes: **Docker Image**, **Image Tag**, **Command**, **Volume Mounts**, **Environment Variables**, **Port Mappings**
- **Output File Name** and **Output Directory** overrides per node
- **Aggregator node toggle**: marks the node as an HTTP-server aggregator (see below)
- Pre-filled default commands for well-known images (FastQC, Trimmomatic, BWA, STAR, GATK, MultiQC, Samtools, HISAT2, Bowtie2, Kallisto, Salmon, Cutadapt, Fastp, Python, R/Bioconductor)
- **Retry** button on failed image downloads

### Automatic Docker Image Management

- When a Docker node is dropped onto the canvas, Ricochet immediately checks if the image exists locally
- If not found, it **automatically pulls the image** in the background with a **live layer-by-layer progress bar**
- Pulling and extraction progress is tracked per-layer and displayed inside the node card
- Images already cached locally are recognized instantly (`Image ready`)
- Image pulls can be **cancelled** at any time

### Multi-File Input & Environment Variables

The **Input Data** node supports selecting **multiple files at once**. Downstream containers receive:

- `$INPUT_FILE` — first file (backward-compatible alias)
- `$INPUT_FILE_1`, `$INPUT_FILE_2`, … — each file individually numbered
- `$INPUT_DIR` — the container path when an upstream output directory is mounted

Ricochet also validates each selected file: FASTQ, BAM, SAM, VCF files that are smaller than 500 bytes trigger a warning indicating a likely failed download.

### Custom Variable Expressions in Commands

Inside any node's **Command** field you can reference upstream nodes using dot notation:

```
# Reference the output file of an upstream node named "FastQC"
FastQC.out              → /inputs/<filename>

# Reference the input files passed to an upstream node named "Trimmomatic"  
Trimmomatic.in          → /inputs/upstream_.../
Trimmomatic.in_1        → first input file
Trimmomatic.in_2        → second input file
```

These expressions are resolved automatically at runtime before the container starts — no manual path wiring needed.

### Pipeline Execution Engine

- **Topological sort** (Kahn's algorithm) determines the correct execution order for all connected nodes
- **Data flow**: output from each node is automatically mounted as `/inputs/<filename>` in the next container; `$INPUT_FILE` environment variable is injected for convenience
- Outputs are written to `/outputs/` inside each container, mapped to a **timestamped workspace folder** on the host
- **Heartbeat logging**: every 10 seconds Ricochet logs the elapsed time of long-running containers so you know they are still alive
- **Pre-execution validation**: checks for empty canvas, missing commands, empty Docker image fields, and disconnected nodes before running
- **Container execution timeout**: containers are automatically killed after **120 minutes** with a descriptive error log
- Pipeline stops immediately on the first failed node with detailed error output
- **Stop button**: gracefully kills all running containers mid-execution
- **Run Anyway** option to override validation warnings when needed

### Smart Output Deduplication (Content-Addressed Results)

Ricochet uses **MD5 directory hashing** to avoid redundant computation:

1. After a node finishes, its output directory is hashed recursively (sorted file paths + contents).
2. If the hash matches a **previous run** for the same node in the same pipeline, the existing result folder is reused — no duplicate disk writes.
3. If the results differ, a new timestamped folder is created: `<NodeName>_<ss_mm_hh_DD_MM_YYYY>/`.

This gives you content-addressed, reproducible pipeline outputs with zero manual cleanup.

### Aggregator Nodes

Mark any node as an **aggregator** in the parameter panel to:

- Automatically append `python3 -m http.server 8080 --directory /output` to its container command
- Expose **port 8080** in both live execution and the Docker Compose export
- View results in the browser at `http://localhost:8080` without copying files manually

### Execution Console (Terminal Panel)

- Slide-up terminal panel accessible from the status bar at the bottom
- **Per-tab logs**: each pipeline tab has its own isolated execution log
- Structured log messages: `[STDOUT]`, `[STDERR]`, `[SYSTEM]`, `[ERROR]`
- Logs show input/output file paths, files produced (with sizes), and elapsed time per node
- **Resizable**: drag to expand or compact the panel (clamped between 100px and 600px)
- Clear logs button to reset the console for a fresh run

### System Resource Monitor

The editor status bar shows live system stats, updated every **4 seconds**:

| Metric | macOS | Windows | Linux |
|--------|-------|---------|-------|
| **CPU** | `top -l 1` | PowerShell `Win32_Processor` | `/proc/stat` (zero-spawn) |
| **GPU** | — | `nvidia-smi` (if available) | `nvidia-smi` (if available) |
| **Disk** | `df -h` | PowerShell `Get-PSDrive` | `df -h` |

- NVIDIA GPU polling gracefully **disables itself** if `nvidia-smi` is not found, with no error noise.
- Linux CPU usage is computed from raw `/proc/stat` tick deltas — **no subprocess spawned per poll**.

### Undo / Redo

- Full **undo/redo history per tab**: each tab maintains its own independent state stack
- History is preserved when switching between tabs
- Undo/redo operates on canvas nodes and connections

### Docker Compose Export

Export your entire pipeline as a **production-ready Docker Compose project**:

- Generates a `.zip` archive containing:
  - `docker-compose.yml`: all services with correct `depends_on: service_completed_successfully` ordering
  - `pipeline_config.env`: all node parameters as overridable environment variables
  - `README.md`: auto-generated documentation with run instructions, lifecycle cheat-sheet, and common fixes
  - `raw_data/` and `results/` placeholder directories
- Service names are auto-slugified from node titles with collision avoidance
- **Platform-aware**: on Apple Silicon, `platform: linux/amd64` is injected automatically; on ARM64 Linux, `platform: linux/arm64` is used instead
- Supports **aggregator nodes** that also start a local HTTP server (`python3 -m http.server 8080`) for viewing results in the browser
- The exported `.env` file embeds a **Base64-encoded `RICOCHET_STATE` blob** that allows the full pipeline to be re-imported into Ricochet — true round-trip portability

### Pipeline Import (Round-Trip)

You can import a pipeline from:

| Source | Method |
|--------|--------|
| **Folder** | Any directory containing a `pipeline*.json` file |
| **Zip export** | `.zip` archive produced by "Export Docker" — decodes the embedded `RICOCHET_STATE` |
| **Env file** | `.env` file containing a `# RICOCHET_STATE:` line |
| **JSON file** | Raw `pipeline.json` file |

Duplicate-tab detection prevents opening the same pipeline folder twice.

### Docker Status Banner

- Persistent banner shown at the top of the UI when Docker is not running or not installed
- **Per-OS** install and launch instructions (macOS, Windows, Linux)
- **Apple Silicon notice**: informs users running on macOS ARM that x86-only images will use emulation
- Execute button is automatically **disabled** when Docker is not available; tooltip explains why
- **Retry** button to re-check Docker status without restarting the app

### Custom Window Title Bar and Window Controls

- **Frameless Window**: Hides the default operating system title bar and Flutter branding to deliver a unified desktop experience.
- **Responsive Controls**: Fully customized Minimize, Maximize/Restore, and Close buttons with responsive hover effects. The close button transitions to standard Windows-native red on hover.
- **Universal Dragging**: Integrated `DragToMoveArea` regions across the Home top bar and the Editor Multi-Tab header, allowing the entire window to be moved by grabbing any header area.
- **macOS Layout Compliance**: Automatically scales the left-side margin to `80px` on macOS to gracefully clear the native Apple traffic light controls, while hiding redundant custom buttons.

### Minimalist Custom App Icon

- **Premium Styling**: Updated the taskbar and application executable icons with a minimalist, high-contrast, bold purple capital letter 'R' centered on a flat solid white background.
- **Windows Integration**: Packaged natively as a high-DPI `256x256` Device Independent Bitmap (DIB) `.ico` file to ensure crisp rendering at all desktop scale levels.

### Automated GitHub Build and Release Pipeline

- **Continuous Compilation**: Configured a complete GitHub Actions workflow ([build_binaries.yml](.github/workflows/build_binaries.yml)) that compiles the application in parallel across Windows, macOS, and Linux runners on branch push.
- **Self-contained packaging**:
  - **Windows**: Single `.exe` self-extractor compiled with `csc.exe` that bundles all DLLs and assets.
  - **macOS**: `.dmg` disk image created with `hdiutil`.
  - **Linux**: Self-extracting bash script with embedded `.tar.gz` payload — runs from any temp directory with no install step.
- **Release Automation**: Downstream actions automatically create pre-releases tagged as `v1.0.0-build.<run_number>` and publish compiled target zip files directly to the Releases page for instant direct downloads.

### Workspace & Persistence

- Each pipeline is saved as a `pipeline.json` file inside its own named folder in the Ricochet workspace
- Node outputs use **OS temp staging directories** during execution; results are only written to the workspace **after successful completion and deduplication**
- Node output folders are named `<NodeTitle>_<ss_mm_hh_DD_MM_YYYY>/` for easy identification
- Input file path is passed to downstream containers via volume mounts at `/inputs/<filename>`
- **Open Recent**: toolbar button shows a dialog listing all saved pipelines with their folder paths
- Import any pipeline folder from anywhere on disk via the **Import** button

### Duplicate Nodes

Right-click or menu option to **duplicate** any node: creates a deep copy with a new UUID offset by 30 px. Docker image pull is automatically triggered for the duplicate if it is a Docker node.

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

### Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| `⌘/Ctrl + Z` | Undo |
| `⌘/Ctrl + Shift + Z` / `⌘/Ctrl + Y` | Redo |
| `Delete` / `Backspace` | Remove selected node |
| `Scroll wheel` | Zoom in / out |
| `Drag on canvas` | Pan view |
| `Escape` | Deselect all |

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     Ricochet Desktop App                    │
│                      (Flutter / Dart)                       │
│                      (Frameless Window)                     │
├───────────────┬─────────────────┬───────────────────────────┤
│  HomeScreen   │   PipelineCanvas│     ExecutionPanel        │
│  (Templates + │  (Nodes +       │  (Logs, Stop, Resize)     │
│   Recent)     │   Connections)  │                           │
│               ├─────────────────┤                           │
│               │   ToolSidebar   │                           │
│               │  (Docker Hub    │                           │
│               │   + Built-ins)  │                           │
├───────────────┴─────────────────┴───────────────────────────┤
│                      Controller Layer                       │
│  PipelineController │ ExecutionController │ DockerController│
│  PipelineTabsCtrl   │ DockerSearchController               │
│  HomeController     │ SystemStatsController                │
├─────────────────────────────────────────────────────────────┤
│                       Service Layer                         │
│  DockerService (CLI) │ WorkspaceService │ ComposeExportSvc  │
│  DirectoryHashingService │ ProcessRunner (abstraction)      │
└─────────────────────────────────────────────────────────────┘
                              ↓
           ┌────────────────────────────────┐
           │      Docker Engine (Local)     │
           │  Container 1 │ Container 2 │...  │
           └────────────────────────────────┘
                              ↓
           ┌────────────────────────────────────────────┐
           │  Workspace directory (OS Documents folder) │
           │  Pipelines/                                │
           │  ├── My_RNA_Seq_Pipeline/                  │
           │  │   ├── pipeline_<timestamp>.json         │
           │  │   ├── FastQC_<timestamp>/output.txt     │
           │  │   └── Trimmomatic_<timestamp>/...       │
           │  └── Variant_Calling/                      │
           │      └── pipeline_<timestamp>.json         │
           │  exports/                                  │
           │  └── MyPipeline_export_<timestamp>.zip     │
           └────────────────────────────────────────────┘
```

### Tech Stack

| Layer | Technology |
|-------|-----------| 
| UI Framework | Flutter 3.x / Dart 3.x / window_manager |
| State Management | GetX 4.x |
| Docker Integration | Docker CLI via Dart `Process` API |
| HTTP (Docker Hub) | `http` |
| Serialization | `json_serializable` / `json_annotation` |
| File Picking | `file_picker` |
| Path Handling | `path`, `path_provider` |
| Archive (Export) | `archive` (ZIP) |
| Hashing (Dedup) | `crypto` (MD5) |
| Typography | `google_fonts` |
| Execution Algorithm | Kahn's Topological Sort |
| Process Abstraction | `ProcessRunner` interface (injectable for testing) |

## Getting Started

### Prerequisites

See [`requirements.txt`](requirements.txt) for the full breakdown. The short version:

| Platform | Flutter SDK | Docker |
|----------|------------|--------|
| **macOS** | >= 3.22 | Docker Desktop >= 4.x ([download](https://docs.docker.com/desktop/install/mac-install/)) |
| **Windows 10/11** | >= 3.22 | Docker Desktop >= 4.x + WSL2 backend ([download](https://docs.docker.com/desktop/install/windows-install/)) |
| **Linux** | >= 3.22 | Docker Engine **or** Docker Desktop for Linux ([docs](https://docs.docker.com/desktop/install/linux-install/)) |

### Platform-Specific Docker Setup

#### macOS

```bash
# Install Docker Desktop (ARM or Intel build is selected automatically)
open https://docs.docker.com/desktop/install/mac-install/

# Apple Silicon users: enable Rosetta emulation in Docker Desktop
# Settings -> General -> "Use Rosetta for x86/amd64 emulation"
```

#### Windows 10 / 11

```powershell
# 1. Enable WSL2 (run as Administrator)
wsl --install

# 2. Download and install Docker Desktop, choosing the WSL2 backend
# https://desktop.docker.com/win/main/amd64/Docker%20Desktop%20Installer.exe

# 3. After install, Docker Desktop starts automatically
docker run hello-world   # verify it works
```

#### Linux (Ubuntu / Debian)

```bash
# Option A: Docker Engine (lighter, CLI only)
sudo apt-get update
sudo apt-get install -y docker.io

# Add yourself to the docker group (avoids needing sudo for every command)
sudo usermod -aG docker $USER
newgrp docker              # apply without logging out

# Enable the daemon to start on boot
sudo systemctl enable --now docker

# Option B: Docker Desktop for Linux (GUI + tray icon)
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

1. **Open Ricochet**: the Home Screen appears with recent pipelines and the template gallery
2. **Pick a template** (e.g. "Quality Check") or click **New Blank Pipeline**
3. **Search Docker Hub** in the sidebar search bar, or drag a built-in block (FastQC, BWA, etc.) onto the canvas
4. **Configure each node**: click a node to open its parameter panel; set the command, image tag, volumes, etc.
5. **Connect nodes**: drag from an output port on one node to an input port on another to establish data flow
6. **Add an Input node** and select your FASTQ/FASTA/BAM file(s): files are mounted into the first tool container at `/inputs/<filename>` (available as `$INPUT_FILE` / `$INPUT_FILE_1`, `$INPUT_FILE_2`, …)
7. **Execute**: click the green **Execute** button; the terminal panel slides up showing live logs
8. **View results**: output files are written to the workspace folder shown in the terminal log; identical results from previous runs are reused automatically
9. **Export**: click **Export Docker** to download a ready-to-run `docker-compose.yml` project that can be re-imported into Ricochet

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
│   ├── My_RNA_Seq_Pipeline/
│   │   ├── pipeline_<timestamp>.json     ← auto-saved pipeline definition
│   │   ├── FastQC_<timestamp>/           ← node output (new if results changed)
│   │   │   └── output.txt
│   │   └── Trimmomatic_<timestamp>/
│   └── Variant_Calling/
│       └── pipeline_<timestamp>.json
└── exports/
    └── MyPipeline_export_2025-06-01T12-00-00.zip
```

> **Note**: Node outputs use the OS temp directory as a **staging area** during execution. Results are only moved to the `Pipelines/<name>/` folder after successful completion and MD5 deduplication — so you never see partial or failed run artifacts in your workspace.

## Platform Notes & Known Limitations

### All Platforms

- Ricochet only supports **Directed Acyclic Graphs (DAGs)**: circular connections are blocked at execution time
- Nodes must be **connected** in a multi-node pipeline: disconnected nodes are flagged before execution
- Input files must exist on disk and be readable: Ricochet warns if biological sequence files appear suspiciously small (likely a failed download)
- Containers are hard-killed after **120 minutes** to prevent zombie processes from runaway bioinformatics jobs

### macOS

- **Apple Silicon (M1/M2/M3):** Docker Desktop must have Rosetta 2 emulation enabled for x86/amd64 images. Ricochet automatically injects `--platform linux/amd64` when pulling or running images. An info notice appears in the toolbar when Apple Silicon is detected.
- **Sandboxed app:** Ricochet sets `DOCKER_HOST` and `DOCKER_CONFIG` explicitly to the real home directory so the Docker daemon can be reached from inside the macOS sandbox.

### Windows

- Docker **must** use the **WSL2 backend** (not Hyper-V). The WSL2 backend is required for reliable volume mounts and process management.
- Windows host paths in volume mounts are automatically translated to the WSL-compatible format (e.g. `C:\Users\me\data.fastq` -> `/c/Users/me/data.fastq`): you do not need to do this manually.
- The Docker executable is searched at `C:\Program Files\Docker\Docker\resources\bin\docker.exe` before falling back to `docker.exe` on `PATH`.
- Open output directory uses `explorer.exe` to open the workspace folder.

### Linux

- **Docker group membership is required.** If you installed Docker Engine (not Desktop), run `sudo usermod -aG docker $USER` and log out/in. Without this, the app cannot communicate with the Docker daemon.
- **Socket auto-detection:** Ricochet checks for the Docker Desktop user-scoped socket (`~/.docker/run/docker.sock`) first, then falls back to the system socket (`/var/run/docker.sock`). If neither exists, it relies on the `docker` binary's own context discovery.
- **ARM64 Linux** (Raspberry Pi 4/5, AWS Graviton, etc.): Ricochet automatically requests `--platform linux/arm64` so native arm64 images are preferred, avoiding emulation.
- **x86_64 Linux** (most desktops/servers): no platform flag needed: native amd64 containers run without emulation.
- Linux CPU monitoring reads `/proc/stat` directly — **zero subprocess overhead** per polling cycle.
- Open output directory uses `xdg-open` to open the workspace folder in the default file manager.
- GTK 3 development libraries are required to build the app: see [`requirements.txt`](requirements.txt).

## License

See [LICENSE](LICENSE) for details.
