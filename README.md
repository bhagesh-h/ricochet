<img src="assets/logo-nobg.png" width="100">

# BioFlow — Visual Bioinformatics Pipeline Designer

<div align="center">

![Flutter](https://img.shields.io/badge/Flutter-3.5.3-02569B?logo=flutter)
![Dart](https://img.shields.io/badge/Dart-3.5.3-0175C2?logo=dart)
![License](https://img.shields.io/badge/License-MIT-green)
![Platform](https://img.shields.io/badge/Platform-macOS%20%7C%20Windows%20%7C%20Linux-lightgrey)
![Docker](https://img.shields.io/badge/Powered%20by-Docker-2496ED?logo=docker)

**Build bioinformatics pipelines visually — no code required. Powered by Docker.**

</div>


## 📋 Table of Contents

- [What is BioFlow?](#-what-is-bioflow)
- [Who is it for?](#-who-is-it-for)
- [Features](#-features)
- [Architecture](#-architecture)
- [Project Structure](#-project-structure)
- [Getting Started](#-getting-started)
- [How it Works](#-how-it-works)
- [Keyboard Shortcuts](#-keyboard-shortcuts)
- [Bioinformatics Tool Library](#-bioinformatics-tool-library)
- [Example Pipelines](#-example-pipelines)
- [Implementation Status](#-implementation-status)
- [Technology Stack](#-technology-stack)
- [macOS Docker Setup](#-macos-docker-connectivity--setup-guide)
- [Contributing](#-contributing)


## 🧬 What is BioFlow?

**BioFlow** is a desktop application that lets you build complex bioinformatics analysis pipelines by dragging and dropping Docker containers on a visual canvas — no command-line required.

Think of it as **"Figma for bioinformatics pipelines"**: connect tools like FastQC, GATK, Samtools, or any Docker image by drawing lines between nodes, configure parameters in a sidebar, and hit Execute. BioFlow handles the rest — pulling images, running containers in order, passing output files between steps, and streaming live logs.

### Why BioFlow?

| Pain Point | BioFlow Solution |
|---|---|
| Complex CLI tools | Visual drag-and-drop interface |
| "It works on my machine" | Docker containers = consistent environments |
| Conda/Python version hell | Each tool runs in its own container |
| Hard to share pipelines | Pipeline is a visual file anyone can see |
| Galaxy is slow (web-only) | Runs locally on your desktop — fast & private |
| Nextflow requires coding | No code needed — just connect nodes |


## 👥 Who is it for?

- **PhD students & postdocs** building repeatable analysis pipelines
- **Bioinformatics core facilities** standardising workflows for clients
- **Computational biologists** who want Docker benefits without DevOps 
- **Pharma/biotech scientists** running analysis without IT support
- **Bioinformatics educators** teaching pipeline concepts without CLI struggle


## ✨ Features

### ✅ Live & Working

#### 🎨 Visual Canvas
- Infinite scrollable canvas (50,000 × 50,000 virtual space)
- Smooth pan and zoom (10% – 500%) with animated controls
- Drag-and-drop node placement from sidebar
- Fit-to-view and reset zoom buttons
- Visual bezier curve connections with colour-coded gradients
- **Click any connection line to select it** (turns red) — then Delete to remove it

#### ⌨️ Keyboard Shortcuts
- `Cmd/Ctrl + Z` — Undo
- `Cmd/Ctrl + Shift + Z` / `Cmd/Ctrl + Y` — Redo
- `Delete` / `Backspace` — Delete selected node or selected connection
- `Escape` — Deselect all
- Right-click / long-press any node → context menu: **Duplicate Node**, **Delete Node**

#### 🐳 Docker Integration
- Real-time Docker Hub search (official + community images)
- Drag any Docker image from search directly onto canvas
- **Image tag picker** — type `python:3.11` to pin a specific tag; it auto-fills the Tag field
- **Live Docker health monitoring** — status banner shows if Docker is running
- Collapsible Apple Silicon notice (only shown when Docker is not running)
- Auto-start prompts when Docker Desktop is not running
- Apple Silicon (M1/M2/M3) aware — uses Rosetta 2 for x86 images
- **Docker pull progress bar** — real-time progress indicator shown below each node while pulling

#### ⚙️ Node Configuration
- Right-side parameter sidebar for each selected node
- Parameter types: text, numeric, dropdown, toggle, file path
- Dynamic add/remove custom parameters per node
- Custom Docker command override per node
- Required field validation
- **Duplicate Node** — right-click any node to create an exact copy

#### 🔗 Connection System
- Drag from output ports to input ports to connect nodes
- Bezier curve rendering with colour-coded gradient connections
- **Click any connection to highlight it red** — then press Delete or click the snackbar button to remove it
- Cycle detection — pipeline alerts if you create a loop
- Topological sorting — nodes always execute in the correct dependency order

#### 🚀 Pipeline Execution Engine
- **Pre-execution validation** — BioFlow checks for:
  - Empty canvas
  - Docker nodes with no command set
  - Disconnected nodes in a multi-node pipeline
  - Shows a clear issue list dialog with "Fix Issues" or "Run Anyway" options
- **Real Docker container execution** (not mock/simulation)
- Topological sort (Kahn's algorithm) determines execution order
- **Data flow between nodes** — output files passed automatically via volume mounts and `$INPUT_FILE` env vars
- Real-time stdout/stderr streaming to the execution console
- Per-node status indicators: pending → running → success / failed
- **Stop Pipeline button** — kill all running containers mid-execution instantly
- Pipeline halts immediately on any node failure with clear error reporting

#### 📂 Output Management
- Timestamped run directories (`~/Documents/BioFlow/Runs/run_YYYY-MM-DD_HH-MM-SS/`)
- Each node writes to its own subdirectory
- "Open Run Folder" button — opens output directory in Finder/Explorer instantly

#### 🖥️ Execution Panel
- Collapsible and resizable terminal panel at the bottom of the screen
- **Auto-scroll to bottom** — always shows the latest log line as it arrives
- Pipeline-level logs (execution order, overall status)
- Per-node logs (Docker stdout/stderr, system messages)
- Colour-coded: green for stdout, red for stderr, blue for system
- **Copy to clipboard** — one-click copy of all logs
- Clear console button

#### 📦 Export to Docker-Compose
- **One-click Export**: Generate a production-ready `.zip` containing your fully configured pipeline
- **Standard Format**: Creates a standard `docker-compose.yml` with dependencies and services mapped
- **Dynamic Configuration**: Auto-generates `pipeline_config.env` for easy parameter tweaking
- **Production Ready**: Generates a tailored `README.md` with instructions and cheat-sheets

#### 🗂️ Multi-Tab Workflows
- **Chrome-style tab bar** above the canvas — open unlimited independent pipelines simultaneously
- **Per-tab isolation** — each tab has its own nodes, connections, undo/redo stack, and execution logs
- **Session restore** — on restart, BioFlow automatically reopens all previously open pipelines from disk
- **Auto-save** — every canvas change is debounced and persisted to `~/Documents/BioFlow/Pipelines/<name>/pipeline.json` within 2 seconds. Auto-save fires only on **drag-end** (not every drag pixel) to keep performance smooth
- **Import Pipeline** — open any exported or previously saved pipeline folder via the toolbar button
- **Open Recent** — instantly re-open any pipeline that has been previously auto-saved to disk
- **Rename** — double-click or right-click any tab label to rename it


## 🏗️ Architecture

### Design Patterns

- **MVC + GetX** — Model-View-Controller with reactive state management
- **Service Layer** — Docker and Workspace concerns separated from controllers
- **Observer Pattern** — UI auto-updates via GetX `Obx` reactivity
- **Topological Sort** — Kahn's algorithm for dependency-safe execution order
- **JSON Serializable** — `@JsonSerializable` on all models via `json_annotation` + `build_runner`

### Execution Data Flow

```
User hits Execute
       ↓
ExecutionController.validatePipeline()   ← checks empty nodes, missing commands, disconnected nodes
       ↓ (if valid)
ExecutionController._doRunPipeline()
       ↓
PipelineController.getExecutionOrder()   ← Kahn's topological sort
       ↓
For each node (in order):
  PipelineController.executeNode(node, inputFiles)
       ↓
  DockerService.runContainer(image:tag, command, volumes, envVars)
       ↓
  Stream stdout/stderr → Execution Panel (auto-scrolled)
       ↓
  Capture output file path → pass to next node as $INPUT_FILE
       ↓
WorkspaceService saves output to ~/Documents/BioFlow/Runs/<timestamp>/
```


## 📁 Project Structure

```
bioflow/
├── lib/
│   ├── main.dart                                    ← App entry point & layout
│   │
│   ├── controllers/
│   │   ├── docker_controller.dart                   ← Docker health monitoring
│   │   ├── docker_search_controller.dart            ← Docker Hub image search
│   │   ├── execution_controller.dart                ← Execution, validation, stop pipeline
│   │   ├── pipeline_controller.dart                 ← Nodes, connections, undo/redo, duplicate
│   │   └── pipeline_tabs_controller.dart            ← Multi-tab + session restore + auto-save
│   │
│   ├── models/
│   │   ├── docker_image.dart                        ← Docker image data model
│   │   ├── docker_info.dart                         ← Docker system info model
│   │   ├── docker_pull_progress.dart                ← Pull progress tracking
│   │   ├── pipeline_file.dart                       ← Per-tab pipeline file model
│   │   ├── pipeline_file.g.dart                     ← Generated JSON serialization
│   │   ├── pipeline_node.dart                       ← Node & connection models
│   │   └── pipeline_node.g.dart                     ← Generated JSON serialization
│   │
│   ├── services/
│   │   ├── docker_service.dart                      ← All Docker CLI calls
│   │   ├── export_service.dart                      ← Docker-Compose ZIP export
│   │   └── workspace_service.dart                   ← Output directory & session management
│   │
│   └── views/
│       ├── pipeline_canvas.dart                     ← Infinite canvas + keyboard shortcuts + clickable connections
│       ├── tool_sidebar.dart                        ← Docker search + bioinformatics tool library
│       └── widgets/
│           ├── connection_dot.dart                  ← Port drag dot
│           ├── connection_painter.dart              ← Bezier connection drawing (hover highlight)
│           ├── docker_status_banner.dart            ← Collapsible Docker status top bar
│           ├── execution_panel.dart                 ← Terminal panel (auto-scroll, stop, clipboard)
│           ├── parameter_sidebar.dart               ← Node parameter editor
│           ├── pipeline_block_widget.dart           ← Node block (right-click menu, pull progress bar)
│           └── pipeline_tab_bar.dart                ← Chrome-style tab bar
│
├── pubspec.yaml                                     ← Dependencies
└── README.md                                        ← This file
```


## 🚀 Getting Started

### Prerequisites

- **Flutter SDK** 3.5.3 or higher
- **Docker Desktop** (must be running when you execute pipelines)
- macOS, Windows, or Linux

### Installation

```bash
# 1. Clone the repository
git clone <repository-url>
cd bioflow

# 2. Install Flutter dependencies
flutter pub get

# 3. Generate JSON serialization code
dart run build_runner build --delete-conflicting-outputs

# 4. Run the app (desktop recommended)
flutter run -d macos      # macOS
flutter run -d windows    # Windows
flutter run -d linux      # Linux
```

### Build Release

```bash
flutter build macos
flutter build windows
flutter build linux
```

> **Note (macOS):** If running locally for development, set:
> ```bash
> export HOME="/Users/your-username"
> ```
> This is required for Docker CLI access on some macOS setups.


## 🎓 How it Works

### Building a Pipeline (Step-by-step)

1. **Search for a Docker image** in the left sidebar (e.g. `fastqc`, `python`, `alpine`) — or pick from the built-in bioinformatics library
2. **Drag it onto the canvas** — a node is created. If the image isn't cached locally, a pull progress bar appears below the node
3. **Click the node** to open its parameter panel on the right
4. **Set the Docker command** (e.g. `fastqc /data/input.fastq -o /output/`)
5. **Connect nodes** by dragging from one node's output port (right dot) to another's input port (left dot)
6. **Click Execute** — BioFlow validates the pipeline first, then runs all nodes in topological order, passing output files automatically
7. **Monitor logs** in the auto-scrolling execution panel — click **Stop** at any time to kill running containers
8. *(Optional)* **Right-click any node** → Duplicate to clone it, or Delete to remove it


## ⌨️ Keyboard Shortcuts

| Shortcut | Action |
|---|---|
| `Cmd/Ctrl + Z` | Undo |
| `Cmd/Ctrl + Shift + Z` | Redo |
| `Cmd/Ctrl + Y` | Redo (alternative) |
| `Delete` / `Backspace` | Delete selected node or connection |
| `Escape` | Deselect node / connection |
| Right-click node | Context menu (Duplicate / Delete) |
| Click connection line | Select connection (turns red) |


## 🧪 Bioinformatics Tool Library

BioFlow includes 20 pre-configured bioinformatics tools organised by category. Drag any onto the canvas — the correct Docker image is pulled automatically.

| Category | Tools |
|---|---|
| **Quality Control** | FastQC, MultiQC, Fastp, Trimmomatic |
| **Alignment** | BWA, HISAT2, STAR, Bowtie2 |
| **SAM/BAM** | Samtools, Picard |
| **Variant Calling** | GATK, FreeBayes, bcftools |
| **RNA-Seq** | featureCounts, DESeq2, Salmon |
| **I/O** | Input (data source), Output (data destination) |

You can also search Docker Hub directly for any image and drag it onto the canvas.


## 🧬 Example Pipelines

### Example 1 — Hello World (alpine)
| Field | Value |
|---|---|
| Docker Image | `alpine` |
| Command | `echo "Hello from BioFlow!" > /output/hello.txt` |

### Example 2 — Python with specific tag
| Field | Value |
|---|---|
| Docker Image | `python` |
| Image Tag | `3.11-slim` |
| Command | `python -c "data=[1,2,3,4,5]; open('/output/stats.txt','w').write(f'Sum: {sum(data)}')"` |

### Example 3 — Two-Node Pipeline (data flows between nodes)

**Node 1** — Generate data:
| Field | Value |
|---|---|
| Docker Image | `alpine` |
| Command | `sh -c "echo 'ATCGATCG\nGCTAGCTA\nTTAAGGCC' > /output/sequences.txt"` |

**Node 2** — Count sequences (connects from Node 1's output):
| Field | Value |
|---|---|
| Docker Image | `alpine` |
| Command | `sh -c "wc -l < $INPUT_FILE > /output/count.txt && echo 'Lines counted!'"` |

Connect Node 1 → Node 2 on the canvas. When executed, `$INPUT_FILE` in Node 2 automatically points to Node 1's `sequences.txt`.

### Example 4 — FastQC Quality Control
| Field | Value |
|---|---|
| Docker Image | `biocontainers/fastqc` |
| Tag | `v0.11.9_cv8` |
| Command | `fastqc $INPUT_FILE -o /output/` |

Drag the FastQC node directly from the **Quality Control** section in the left sidebar — no typing needed.


## 📊 Implementation Status

### ✅ Fully Implemented

| Feature | Notes |
|---|---|
| Visual canvas with zoom/pan | Infinite canvas, smooth animations |
| Drag-and-drop nodes | From sidebar or bioinformatics library |
| Docker Hub search | Real-time, official + community images |
| Docker health monitoring | Collapsible banner, auto-detect, retry |
| Docker image pull | Per-node progress bar with percentage |
| Docker image tag picker | Type `image:tag` or edit Tag field |
| Real Docker execution | Actual containers, not simulation |
| Pre-execution validation | Checks empty canvas, missing commands, disconnected nodes |
| Stop Pipeline | Kills all running containers instantly |
| Topological sort execution | Kahn's algorithm, cycle detection |
| Data flow between nodes | Volume mounts + `$INPUT_FILE` env vars |
| Live log streaming | stdout/stderr in real time |
| Auto-scroll execution panel | Always shows latest log line |
| Copy logs to clipboard | One-click copy in panel header |
| Keyboard shortcuts | Undo, Redo, Delete, Escape |
| Click-to-delete connections | Click line → turns red → Delete key or button |
| Duplicate Node | Right-click → Duplicate (full deep copy) |
| Output directory management | Timestamped run folders |
| Parameter sidebar | 5 parameter types, custom params |
| Connection system | Bezier curves, port drag-and-drop |
| Execution panel | Collapsible, resizable, auto-scroll |
| Multi-tab pipelines | Chrome-style, per-tab isolation |
| Session restore | Reopens last open pipelines on startup |
| Auto-save (drag-end only) | Debounced, no per-pixel flood |
| Undo / Redo | Per-tab, full history |
| Export to Docker-Compose | ZIP with docker-compose.yml + env |
| Apple Silicon support | Rosetta 2 for x86 images |
| Bioinformatics library | 20 curated tools in 6 categories |


## 🛠️ Technology Stack

| Layer | Technology | Purpose |
|---|---|---|
| UI Framework | Flutter 3.5.3 | Cross-platform desktop UI |
| Language | Dart 3.5.3 | Application logic |
| State Management | GetX 4.x | Reactive state + dependency injection |
| Docker | Docker CLI via `Process` API | Container execution & image management |
| HTTP | `http` 1.2.2 | Docker Hub API calls |
| IDs | `uuid` 4.5.1 | Unique node identifiers |
| Serialization | `json_annotation` + `json_serializable` | Type-safe JSON models |
| Code Generation | `build_runner` | JSON serialization codegen |
| URLs | `url_launcher` | Open Docker download links |
| File Paths | `path` + `path_provider` | Workspace & output directory management |


## 🎨 Design System

```
Primary:    #6366F1  (Indigo)
Success:    #10B981  (Emerald Green)
Error:      #EF4444  (Red)
Warning:    #F59E0B  (Amber)
Running:    #8B5CF6  (Purple)
Background: #F7F8FA  (Slate Gray)
Canvas:     #0F172A  (Dark Navy)
```


## 🤝 Contributing

Contributions are very welcome!

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/my-feature`)
3. Commit your changes (`git commit -m 'Add my feature'`)
4. Push and open a Pull Request

**Good first issues:**
- Add a new bioinformatics tool to the library
- Add a new built-in pipeline template
- Improve the parameter sidebar for specific tools (e.g. FastQC options)
- Write documentation for a specific tool's Docker command


## 📝 License

MIT License — see [LICENSE](LICENSE) for details.


## 🔧 macOS Docker Connectivity — Setup Guide

BioFlow communicates with Docker by calling the Docker CLI directly (not through Docker's API). This section explains **exactly how the connection works** and what you need to do on your Mac to make it work.


### How BioFlow Finds and Connects to Docker

When you click **Execute**, BioFlow does the following internally:

```
1. Locate the Docker binary:
   → tries /usr/local/bin/docker   (Intel Mac)
   → tries /opt/homebrew/bin/docker (Apple Silicon / Homebrew)
   → falls back to 'docker' on PATH

2. Set connection environment:
   DOCKER_HOST   = unix://$HOME/.docker/run/docker.sock
   DOCKER_CONFIG = $HOME/.docker
   HOME          = /Users/your-username  (real home, not sandboxed)

3. Run: docker info   (to verify daemon is reachable)

4. Run containers via: docker run --rm -i ...
```


### Step-by-Step Setup (macOS)

#### Step 1 — Install Docker Desktop

Download and install Docker Desktop for your Mac architecture:

- **Apple Silicon (M1/M2/M3):** https://desktop.docker.com/mac/main/arm64/Docker.dmg
- **Intel Mac:** https://desktop.docker.com/mac/main/amd64/Docker.dmg

After installing, open **Docker Desktop** from Applications and wait for the whale icon to appear in the menu bar (fully started).


#### Step 2 — Verify Docker CLI is accessible

Open **Terminal** and run:

```bash
which docker
docker --version
# Expected: Docker version 27.x.x, build xxxxxxx
```

If `which docker` returns nothing:

```bash
sudo ln -sf /Applications/Docker.app/Contents/Resources/bin/docker /usr/local/bin/docker
docker --version
```


#### Step 3 — Confirm the Docker socket exists

```bash
ls -la ~/.docker/run/docker.sock
# Expected: srwxr-xr-x ... /Users/yourname/.docker/run/docker.sock
```

If missing, Docker Desktop isn't fully started — open it and wait.


#### Step 4 — Set the HOME environment variable

```bash
echo $HOME
# Should output: /Users/your-username  (NOT a /Library/Containers/ path)
```

If wrong, fix it:

```bash
export HOME="/Users/$(whoami)"
# To make permanent:
echo 'export HOME="/Users/$(whoami)"' >> ~/.zshrc && source ~/.zshrc
```


#### Step 5 — End-to-end Docker test

```bash
export DOCKER_HOST="unix://$HOME/.docker/run/docker.sock"
docker run --rm alpine echo "BioFlow Docker connection works!"
# Expected: BioFlow Docker connection works!
```

If this works, BioFlow pipeline execution will work too.


### Quick Troubleshooting

| Symptom | Fix |
|---|---|
| BioFlow banner shows "Docker not running" | Start Docker Desktop, wait for whale icon |
| `docker: command not found` | Run `sudo ln -sf /Applications/Docker.app/Contents/Resources/bin/docker /usr/local/bin/docker` |
| Socket file missing | Docker Desktop not fully started; restart it |
| `Cannot connect to Docker daemon` | Set `DOCKER_HOST=unix://$HOME/.docker/run/docker.sock` and retry |
| Apple Silicon: architecture error | Enable Rosetta in Docker Desktop settings |
| App works in debug but not release | Ensure `com.apple.security.app-sandbox` is `false` in Release.entitlements |


### macOS Entitlements (for developers building from source)

```xml
<!-- macos/Runner/Release.entitlements -->
<key>com.apple.security.app-sandbox</key>
<false/>                          <!-- MUST be false — sandbox blocks Process.run() -->
<key>com.apple.security.network.client</key>
<true/>                           <!-- Required for Docker Hub API calls -->
<key>com.apple.security.files.user-selected.read-write</key>
<true/>                           <!-- Required to read/write pipeline output files -->
```

> [!IMPORTANT]
> If `app-sandbox` is set to `true`, BioFlow **cannot** execute Docker commands. The app will start but all pipeline runs will silently fail.


### Apple Silicon (M1/M2/M3) Users

BioFlow automatically detects Apple Silicon and adds `--platform linux/amd64` for x86-only images. **Rosetta 2 must be installed:**

```bash
softwareupdate --install-rosetta --agree-to-license
```

In Docker Desktop → Settings → General, ensure **"Use Rosetta for x86/amd64 emulation on Apple Silicon"** is checked.


## 🙏 Acknowledgments

- Built with [Flutter](https://flutter.dev)
- Docker integration via [Docker Hub API](https://hub.docker.com)
- Icons from [Material Design](https://material.io/icons)
- Inspired by n8n's visual workflow UX
- Bioinformatics tools via [BioContainers](https://biocontainers.pro)


<div align="center">

**Made with ❤️ for the bioinformatics community**

⭐ Star this repo if it helps your research!

</div>
