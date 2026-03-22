# BioFlow

**A visual, Docker-powered bioinformatics pipeline builder for your desktop.**

BioFlow lets you build complex bioinformatics analysis pipelines by dragging and dropping Docker containers onto a visual canvas — no YAML, no Bash scripts, no server required. Connect tools like FastQC, STAR, BWA, GATK, and Samtools like building blocks, configure them through a clean GUI, and hit **Execute**. BioFlow handles the rest.

> **"If you can use Figma, you can use BioFlow. If you can run Docker, you can run BioFlow."**

---

## ✨ Features

### 🎨 Visual Pipeline Canvas

- **Infinite canvas** with smooth pan and zoom
- **Drag-and-drop** nodes from the sidebar or add them directly on the canvas
- **Bezier curve connections** between node ports to represent data flow
- **Cycle detection** — connections that create loops are highlighted and blocked at execution time
- **Canvas reset** button to clear the workspace and start fresh

### 📑 Multi-Tab Pipeline Editor (Chrome-style)

- Work on multiple pipelines simultaneously in separate tabs
- Each tab is **independently named, saved, and restored** across sessions
- **Auto-save** — changes are debounced and written to disk (as `pipeline.json`) 2 seconds after each edit
- **Unsaved-changes indicator** (`•`) shown on each tab — prompts before closing
- **Tab renaming** — double-click to rename; folder on disk is renamed accordingly
- **Session restore** — last open pipelines are automatically reloaded on app launch
- Open and **Import** an existing pipeline folder from disk via the toolbar

### 🧰 Built-in Bioinformatics Tool Blocks

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

### 🐳 Docker Hub Integration

- **Live search** the Docker Hub registry directly from the sidebar — no browser required
- Search results show stars, pulls, and whether the image is official
- Click any result to drop a fully configured node onto the canvas
- **Smart default tag** — BioFlow automatically fetches the most recent stable tag for each image from Docker Hub (e.g. `0.23.4` instead of `latest`)
- Tag list is sorted by recency using a deterministic algorithm that ranks version-like tags (e.g. `v1.2.3`) above others
- Tag results are **cached with LRU eviction and TTL** to avoid redundant API calls
- In-flight requests are **deduplicated** so rapid searches don't cause repeated network hits

### ⚙️ Node Configuration Panel

Each node exposes fully editable parameters:

- **Text, numeric, dropdown, and file-picker** parameter fields
- Parameters for Docker nodes: **Docker Image**, **Image Tag**, **Command**, **Volume Mounts**, **Environment Variables**, **Port Mappings**
- Pre-filled default commands for well-known images (FastQC, Trimmomatic, BWA, STAR, GATK, MultiQC, Samtools, HISAT2, Bowtie2, Kallisto, Salmon, Cutadapt, Fastp, Python, R/Bioconductor)
- **Retry** button on failed image downloads

### 📥 Automatic Docker Image Management

- When a Docker node is dropped onto the canvas, BioFlow immediately checks if the image exists locally
- If not found, it **automatically pulls the image** in the background with a **live layer-by-layer progress bar**
- Pulling and extraction progress is tracked per-layer and displayed inside the node card
- Images already cached locally are recognised instantly (`Image ready`)
- Image pulls can be **cancelled** at any time

### ▶️ Pipeline Execution Engine

- **Topological sort** (Kahn's algorithm) determines the correct execution order for all connected nodes
- **Data flow** — output from each node is automatically mounted as `/inputs/<filename>` in the next container; `$INPUT_FILE` environment variable is injected for convenience
- Outputs are written to `/outputs/` inside each container, mapped to a **timestamped workspace folder** on the host
- **Heartbeat logging** — every 10 seconds BioFlow logs the elapsed time of long-running containers so you know they're still alive
- **Pre-execution validation** — checks for empty canvas, missing commands, empty Docker image fields, and disconnected nodes before running
- Pipeline stops immediately on the first failed node with detailed error output
- **Stop button** — gracefully kills all running containers mid-execution
- **Run Anyway** option to override validation warnings when needed

### 🖥️ Execution Console (Terminal Panel)

- Slide-up terminal panel accessible from the status bar at the bottom
- **Per-tab logs** — each pipeline tab has its own isolated execution log
- Structured log messages: `[STDOUT]`, `[STDERR]`, `[SYSTEM]`, `[ERROR]`
- Logs show input/output file paths, files produced (with sizes), and elapsed time per node
- **Resizable** — drag to expand or compact the panel (clamped between 100px – 600px)
- Clear logs button to reset the console for a fresh run

### ↩️ Undo / Redo

- Full **undo/redo history per tab** — each tab maintains its own independent state stack
- History is preserved when switching between tabs
- Undo/redo operates on canvas nodes and connections

### 📤 Docker Compose Export

Export your entire pipeline as a **production-ready Docker Compose project**:

- Generates a `.zip` archive containing:
  - `docker-compose.yml` — all services with correct `depends_on: service_completed_successfully` ordering
  - `pipeline_config.env` — all node parameters as overridable environment variables
  - `README.md` — auto-generated documentation with run instructions, lifecycle cheat-sheet, and common fixes
  - `raw_data/` and `results/` placeholder directories
- Service names are auto-slugified from node titles with collision avoidance
- **Apple Silicon support** — `platform:` flag is injected automatically if BioFlow detects an ARM Mac
- Supports **aggregator nodes** that also start a local HTTP server (`python3 -m http.server 8080`) for viewing results in the browser

### 🔔 Docker Status Banner

- Persistent banner shown at the top of the UI when Docker is not running or not installed
- Shows platform-appropriate install/launch instructions (macOS vs Windows)
- **Apple Silicon notice** — informs users when running on ARM Mac and provides guidance on emulation
- Execute button is automatically **disabled** when Docker is not available; tooltip explains why

### 💾 Workspace & Persistence

- Each pipeline is saved as a `pipeline.json` file inside its own named folder in the BioFlow workspace (`~/Documents/bioflow_workspace/`)
- Each pipeline run gets a **fresh timestamped run directory** — no stale outputs from prior runs
- Node output folders are named `<nodeId>_<nodeTitle>/` for easy identification
- Input file path is passed to downstream containers via volume mounts at `/inputs/<filename>`
- **Open Recent** — toolbar button shows a dialog listing all saved pipelines with their folder paths
- Import any pipeline folder from anywhere on disk via the **Import** button

### 📋 Duplicate Nodes

- Right-click or menu option to **duplicate** any node — creates a deep copy with a new UUID, offset 30px
- Docker image pull is automatically triggered for the duplicate if it's a Docker node

### 🧹 Node Status Indicators

Each node on the canvas displays its current state:

| Status | Meaning |
|--------|---------|
| `idle` | Not yet run |
| `checking` | Verifying if image is cached |
| `downloading` | Pulling image from Docker Hub |
| `ready` | Image cached, ready to execute |
| `running` | Container currently executing |
| `success` | Completed successfully (green) |
| `failed` | Execution failed (red) |
| `error` | Image pull or setup error |

---

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     BioFlow Desktop App                     │
│                      (Flutter / Dart)                       │
├───────────────┬─────────────────┬───────────────────────────┤
│  PipelineCanvas│   ToolSidebar  │     ExecutionPanel         │
│  (Nodes +      │  (Docker Hub   │  (Logs, Stop, Resize)      │
│   Connections) │   + Built-ins) │                            │
├───────────────┴─────────────────┴───────────────────────────┤
│                      Controller Layer                        │
│  PipelineController │ ExecutionController │ DockerController │
│  PipelineTabsCtrl   │ DockerSearchController                 │
├──────────────────────────────────────────────────────────────┤
│                       Service Layer                          │
│  DockerService (CLI) │ WorkspaceService │ ComposeExportSvc   │
└──────────────────────────────────────────────────────────────┘
                              ↓
           ┌────────────────────────────────┐
           │      Docker Engine (Local)     │
           │  Container 1 │ Container 2 │…  │
           └────────────────────────────────┘
                              ↓
           ┌────────────────────────────────┐
           │  ~/Documents/bioflow_workspace/ │
           │  run_2025-06-01T10-30-15/      │
           │  ├── node1_fastqc/output.txt   │
           │  └── node2_trimmomatic/…       │
           └────────────────────────────────┘
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

---

## 🚀 Getting Started

### Prerequisites

- **Flutter SDK** `^3.8.0` (Dart `^3.8.0`)
- **Docker Desktop** (running) — [Download here](https://www.docker.com/products/docker-desktop)

### Run Locally

```bash
flutter pub get
flutter run -d macos      # macOS
flutter run -d windows    # Windows
flutter run -d linux      # Linux
```

### Build for Production

```bash
flutter build macos       # macOS app bundle
flutter build windows     # Windows MSIX
```

---

## 📖 Usage Walkthrough

1. **Open BioFlow** — a blank canvas tab is created automatically
2. **Search Docker Hub** in the sidebar search bar or drag a built-in block (FastQC, BWA, etc.) onto the canvas
3. **Configure each node** — click a node to open its parameter panel. Set the command, image tag, volumes, etc.
4. **Connect nodes** — drag from an output port on one node to an input port on another to establish data flow
5. **Add an Input node** and select your FASTQ/FASTA/BAM file — this mounts the file into the first tool container
6. **Execute** — click the green **Execute** button. The terminal panel slides up showing live logs
7. **View results** — output files are written to `~/Documents/bioflow_workspace/<run_timestamp>/`
8. **Export** — click **Export Docker** to download a ready-to-run `docker-compose.yml` project

---

## ⚠️ Known Limitations & Tips

- BioFlow only supports **Directed Acyclic Graphs (DAGs)** — circular connections are blocked
- On **Apple Silicon Macs**, many bioinformatics images are `linux/amd64` only. BioFlow injects `--platform linux/amd64` automatically, but Rosetta 2 or Docker Desktop's emulation must be enabled
- On **Windows**, Docker must use the **WSL2 backend**. Windows host paths are automatically translated to WSL-compatible paths (e.g. `C:\path` → `/c/path`) for volume mounts
- Input files must exist on disk before executing — BioFlow validates file presence and warns if biological sequence files appear suspiciously small (likely a failed download)
- Nodes must be **connected** in a multi-node pipeline — disconnected nodes are flagged before execution

---

## 📄 License

See [LICENSE](LICENSE) for details.
