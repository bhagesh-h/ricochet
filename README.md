# BioFlow — Visual Bioinformatics Pipeline Designer

<div align="center">

![Flutter](https://img.shields.io/badge/Flutter-3.5.3-02569B?logo=flutter)
![Dart](https://img.shields.io/badge/Dart-3.5.3-0175C2?logo=dart)
![License](https://img.shields.io/badge/License-MIT-green)
![Platform](https://img.shields.io/badge/Platform-macOS%20%7C%20Windows%20%7C%20Linux-lightgrey)
![Docker](https://img.shields.io/badge/Powered%20by-Docker-2496ED?logo=docker)

**Build bioinformatics pipelines visually — no code required. Powered by Docker.**

</div>

---

## 📋 Table of Contents

- [What is BioFlow?](#-what-is-bioflow)
- [Who is it for?](#-who-is-it-for)
- [Features](#-features)
- [Architecture](#-architecture)
- [Project Structure](#-project-structure)
- [Getting Started](#-getting-started)
- [How it Works](#-how-it-works)
- [Example Pipelines](#-example-pipelines)
- [Implementation Status](#-implementation-status)
- [Roadmap](#-roadmap)
- [Technology Stack](#-technology-stack)
- [macOS Docker Setup](#-macos-docker-connectivity--setup-guide)
- [Contributing](#-contributing)

---

## 🧬 What is BioFlow?

**BioFlow** is a desktop application that lets you build complex bioinformatics analysis pipelines by dragging and dropping Docker containers on a visual canvas — no command-line required.

Think of it as **"Figma for bioinformatics pipelines"**: connect tools like FastQC, GATK, Samtools, or any Docker image by drawing lines between nodes, configure parameters in a sidebar, and hit Execute. BioFlow handles the rest — pulling images, running containers in order, passing output files between steps, and streaming live logs.

### Why BioFlow?

| Pain Point | BioFlow Solution |
|-----------|-----------------|
| Complex CLI tools | Visual drag-and-drop interface |
| "It works on my machine" | Docker containers = consistent environments |
| Conda/Python version hell | Each tool runs in its own container |
| Hard to share pipelines | Pipeline is a visual file anyone can see |
| Galaxy is slow (web-only) | Runs locally on your desktop — fast & private |
| Nextflow requires coding | No code needed — just connect nodes |

---

## 👥 Who is it for?

- **PhD students & postdocs** building repeatable analysis pipelines
- **Bioinformatics core facilities** standardising workflows for clients
- **Computational biologists** who want Docker benefits without DevOps 
- **Pharma/biotech scientists** running analysis without IT support
- **Bioinformatics educators** teaching pipeline concepts without CLI struggle

---

## ✨ Features

### ✅ Live & Working

#### 🎨 Visual Canvas
- Infinite scrollable canvas (50,000 × 50,000 virtual space)
- Smooth pan and zoom (10% – 500%) with animated controls
- Drag-and-drop node placement from sidebar
- Fit-to-view and reset zoom buttons
- Visual bezier curve connections between nodes

#### 🐳 Docker Integration
- Real-time Docker Hub search (official + community images)
- Drag any Docker image from search directly onto canvas
- **Live Docker health monitoring** — status banner shows if Docker is running
- Auto-start prompts when Docker Desktop is not running
- Apple Silicon (M1/M2/M3) aware — uses Rosetta 2 for x86 images
- Image pull with real-time progress streaming

#### ⚙️ Node Configuration
- Right-side parameter sidebar for each selected node
- Parameter types: text, numeric, dropdown, toggle, file path
- Dynamic add/remove custom parameters per node
- Custom Docker command override per node
- Required field validation

#### 🔗 Connection System
- Drag from output ports to input ports to connect nodes
- Bezier curve rendering with colour-coded connections
- Cycle detection — pipeline alerts if you create a loop
- Topological sorting — nodes always execute in the correct dependency order

#### 🚀 Pipeline Execution Engine
- **Real Docker container execution** (not mock/simulation)
- Topological sort (Kahn's algorithm) determines execution order
- **Data flow between nodes** — output files from Node A are automatically passed as input to Node B via Docker volume mounts and `$INPUT_FILE` environment variables
- Real-time stdout/stderr streaming to the execution console
- Per-node status indicators: pending → running → success / failed
- Pipeline halts immediately on any node failure with clear error reporting
- Stop button to kill running containers mid-execution

#### 📂 Output Management
- Timestamped run directories (`~/Documents/bioflow_workspace/run_YYYY-MM-DD_HH-MM-SS/`)
- Each node writes to its own subdirectory
- "Open Run Folder" button — opens output directory in Finder/Explorer instantly

#### 🖥️ Execution Panel
- Collapsible terminal panel at the bottom of the screen
- Pipeline-level logs (execution order, overall status)
- Per-node logs (Docker stdout/stderr, system messages)
- Colour-coded: green for stdout, red for stderr, blue for system
- Clear console and copy-to-clipboard support

---

## 🏗️ Architecture

### Design Patterns

- **MVC + GetX** — Model-View-Controller with reactive state management
- **Service Layer** — Docker and Workspace concerns separated from controllers
- **Observer Pattern** — UI auto-updates via GetX `Obx` reactivity
- **Topological Sort** — Kahn's algorithm for dependency-safe execution order

### Execution Data Flow

```
User hits Execute
       ↓
ExecutionController.runPipeline()
       ↓
PipelineController.getExecutionOrder()   ← Kahn's topological sort
       ↓
For each node (in order):
  PipelineController.executeNode(node, inputFiles)
       ↓
  DockerService.runContainer(image, command, volumes, envVars)
       ↓
  Stream stdout/stderr → Execution Panel logs
       ↓
  Capture output file path → pass to next node as $INPUT_FILE
       ↓
WorkspaceService saves output to timestamped run directory
```

---

## 📁 Project Structure

```
bioflow/
├── lib/
│   ├── main.dart                                    ← App entry point & layout
│   │
│   ├── controllers/
│   │   ├── docker_controller.dart                   ← Docker health monitoring
│   │   ├── docker_search_controller.dart            ← Docker Hub image search
│   │   ├── execution_controller.dart                ← Pipeline execution logic
│   │   └── pipeline_controller.dart                 ← Nodes & connections state
│   │
│   ├── models/
│   │   ├── docker_image.dart                        ← Docker image data model
│   │   ├── docker_info.dart                         ← Docker system info model
│   │   ├── docker_pull_progress.dart                ← Pull progress tracking
│   │   └── pipeline_node.dart                       ← Node & connection models
│   │
│   ├── services/
│   │   ├── docker_service.dart                      ← All Docker CLI calls
│   │   └── workspace_service.dart                   ← Output directory management
│   │
│   └── views/
│       ├── pipeline_canvas.dart                     ← Main infinite canvas
│       ├── tool_sidebar.dart                        ← Docker image browser
│       └── widgets/
│           ├── connection_dot.dart                  ← Port drag dot
│           ├── connection_painter.dart              ← Bezier connection drawing
│           ├── docker_status_banner.dart            ← Docker status top bar
│           ├── execution_panel.dart                 ← Terminal log panel
│           ├── parameter_sidebar.dart               ← Node parameter editor
│           └── pipeline_block_widget.dart           ← Node block on canvas
│
├── PROJECT_OVERVIEW.md                              ← Architecture & market context
├── pubspec.yaml                                     ← Dependencies
└── README.md                                        ← This file
```

---

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

# 3. Run the app (desktop recommended)
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

---

## 🎓 How it Works

### Building a Pipeline (Step-by-step)

1. **Search for a Docker image** in the left sidebar (e.g. `fastqc`, `python`, `alpine`)
2. **Drag it onto the canvas** — a node is created
3. **Click the node** to open its parameter panel on the right
4. **Set the Docker command** (e.g. `fastqc /data/input.fastq -o /output/`)
5. **Connect nodes** by dragging from one node's output port to another's input port
6. **Click Execute** — BioFlow runs all nodes in topological order, passing output files automatically

### Data Flow Between Nodes

When Node A produces an output file, BioFlow automatically:
- Mounts Node A's output directory into Node B's container as a volume
- Sets the `$INPUT_FILE` environment variable pointing to that file
- Node B's command can use `$INPUT_FILE` to read the upstream result

```bash
# Node A command (produces output)
python -c "open('/output/result.txt','w').write('hello')"

# Node B command (consumes upstream output automatically)
cat $INPUT_FILE > /output/final.txt
```

---

## � Example Pipelines

These are ready-to-use node configurations to try immediately after installing BioFlow.

### Example 1 — Hello World (alpine)
| Field | Value |
|-------|-------|
| Docker Image | `alpine` |
| Command | `echo "Hello from BioFlow!" > /output/hello.txt` |

### Example 2 — Python Data Processing
| Field | Value |
|-------|-------|
| Docker Image | `python:3.11-slim` |
| Command | `python -c "data=[1,2,3,4,5]; open('/output/stats.txt','w').write(f'Sum: {sum(data)}, Mean: {sum(data)/len(data)}')"` |

### Example 3 — Two-Node Pipeline (data flows between nodes)

**Node 1** — Generate data:
| Field | Value |
|-------|-------|
| Docker Image | `alpine` |
| Command | `sh -c "echo 'ATCGATCG\nGCTAGCTA\nTTAAGGCC' > /output/sequences.txt"` |

**Node 2** — Count sequences (connects from Node 1's output):
| Field | Value |
|-------|-------|
| Docker Image | `alpine` |
| Command | `sh -c "wc -l < $INPUT_FILE > /output/count.txt && echo 'Lines counted!'"` |

Connect Node 1 → Node 2 on the canvas. When executed, `$INPUT_FILE` in Node 2 automatically points to Node 1's `sequences.txt`.

### Example 4 — FastQC Quality Control
| Field | Value |
|-------|-------|
| Docker Image | `biocontainers/fastqc:v0.11.9_cv8` |
| Command | `fastqc $INPUT_FILE -o /output/` |

Requires an input FASTQ file from an upstream node.

---

## �📊 Implementation Status

### ✅ Fully Implemented

| Feature | Notes |
|---------|-------|
| Visual canvas with zoom/pan | Infinite canvas, smooth animations |
| Drag-and-drop nodes | From sidebar to canvas |
| Docker Hub search | Real-time, official + community images |
| Docker health monitoring | Status banner, auto-detect, retry |
| Docker image pull | With real-time progress streaming |
| Real Docker execution | Actual containers, not simulation |
| Topological sort execution | Kahn's algorithm, cycle detection |
| Data flow between nodes | Volume mounts + `$INPUT_FILE` env vars |
| Live log streaming | stdout/stderr in real time |
| Pipeline stop | Kill running container mid-run |
| Output directory management | Timestamped run folders |
| Parameter sidebar | 5 parameter types, custom params |
| Connection system | Bezier curves, port drag-and-drop |
| Execution panel | Collapsible, per-node + pipeline logs |
| Apple Silicon support | Rosetta 2 for x86 images |

### 🚧 Planned

| Feature | Priority |
|---------|----------|
| Save / Load pipelines (JSON) | High |
| Undo / Redo | High |
| Pipeline templates library | High |
| Cloud execution | Medium |
| Pipeline marketplace | Medium |
| Team collaboration | Low |
| Enterprise SSO | Low |

---

## 🗺️ Roadmap

### Phase 1 — Local Polish (Now)
- [ ] Save/load pipelines as JSON
- [ ] Undo/redo (command pattern)
- [ ] Keyboard shortcuts (Delete, Ctrl+Z, Ctrl+A)
- [ ] Multi-select and bulk move nodes

### Phase 2 — Community (Month 1–2)
- [ ] Starter pipeline templates (FastQC, BWA, DESeq2)
- [ ] "Export pipeline" to shareable format
- [ ] GitHub open source launch

### Phase 3 — Cloud & Monetisation (Month 3)
- [ ] Cloud execution backend (AWS Lambda + SQS)
- [ ] User authentication (Firebase)
- [ ] Pipeline marketplace (70/30 revenue split)
- [ ] BioFlow Pro pricing ($29/month)
- [ ] Team plans ($199/month)

### Phase 4 — Enterprise (Year 2)
- [ ] SSO / SAML authentication
- [ ] On-premise deployment
- [ ] White-label edition
- [ ] Priority support SLA

---

## 🛠️ Technology Stack

| Layer | Technology | Purpose |
|-------|-----------|---------|
| UI Framework | Flutter 3.5.3 | Cross-platform desktop UI |
| Language | Dart 3.5.3 | Application logic |
| State Management | GetX 4.x | Reactive state + DI |
| Docker | Docker CLI via `Process` API | Container execution |
| HTTP | `http` 1.2.2 | Docker Hub API calls |
| IDs | `uuid` 4.5.1 | Unique node identifiers |
| URLs | `url_launcher` | Open Docker download links |
| File Paths | `path` + `path_provider` | Output directory management |

---

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

---

## 🤝 Contributing

Contributions are very welcome!

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/my-feature`)
3. Commit your changes (`git commit -m 'Add my feature'`)
4. Push and open a Pull Request

**Good first issues:**
- Add a new built-in pipeline template
- Implement save/load as JSON
- Add keyboard shortcut (Delete to remove selected node)
- Write documentation for a specific bioinformatics tool's Docker command

---

## 📝 License

MIT License — see [LICENSE](LICENSE) for details.

---

## 🔧 macOS Docker Connectivity — Setup Guide

BioFlow communicates with Docker by calling the Docker CLI directly (not through Docker's API). This section explains **exactly how the connection works** and what you need to do on your Mac to make it work.

---

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

---

### Step-by-Step Setup (macOS)

#### Step 1 — Install Docker Desktop

Download and install Docker Desktop for your Mac architecture:

- **Apple Silicon (M1/M2/M3):** https://desktop.docker.com/mac/main/arm64/Docker.dmg
- **Intel Mac:** https://desktop.docker.com/mac/main/amd64/Docker.dmg

After installing, open **Docker Desktop** from Applications and wait for the whale icon to appear in the menu bar (fully started).

---

#### Step 2 — Verify Docker CLI is accessible

Open **Terminal** and run:

```bash
# Check which docker binary exists
which docker

# Verify it works
docker --version

# Expected output:
# Docker version 27.x.x, build xxxxxxx
```

If `which docker` returns nothing, Docker Desktop didn't set up the symlink. Fix it:

```bash
# For Apple Silicon (Homebrew path)
sudo ln -sf /Applications/Docker.app/Contents/Resources/bin/docker /usr/local/bin/docker

# Verify
docker --version
```

---

#### Step 3 — Confirm the Docker socket exists

BioFlow connects to Docker via a Unix socket file. Verify it exists:

```bash
ls -la ~/.docker/run/docker.sock

# Expected output (something like):
# srwxr-xr-x  1 yourname  staff  0 Feb 27 10:00 /Users/yourname/.docker/run/docker.sock
```

If the file **does not exist**, Docker Desktop is not fully started. Open Docker Desktop and wait for it to say "Docker Desktop is running".

---

#### Step 4 — Set the HOME environment variable

BioFlow needs your real home directory to locate the Docker socket. In your terminal session (and the terminal you run BioFlow from), verify:

```bash
echo $HOME
# Should output: /Users/your-username
# (NOT a path containing /Library/Containers/)
```

If you run BioFlow from Xcode or a script and `HOME` is wrong, fix it:

```bash
export HOME="/Users/$(whoami)"
```

To make this permanent, add it to your shell profile:

```bash
echo 'export HOME="/Users/$(whoami)"' >> ~/.zshrc
source ~/.zshrc
```

---

#### Step 5 — Verify Docker daemon is fully reachable

Run this to confirm BioFlow will be able to connect:

```bash
# Set the same env BioFlow uses internally
export DOCKER_HOST="unix://$HOME/.docker/run/docker.sock"
export DOCKER_CONFIG="$HOME/.docker"

docker info | head -5
# Should print Docker version, OS, architecture — no errors
```

If you get `"Cannot connect to the Docker daemon"` here, BioFlow will also fail. Fix Docker Desktop first.

---

#### Step 6 — Test running a container (end-to-end test)

This mirrors exactly what BioFlow does when you run a node:

```bash
# Simple test — run alpine and print hello
docker run --rm alpine echo "BioFlow Docker connection works!"

# Expected output:
# BioFlow Docker connection works!
```

If this works, BioFlow pipeline execution will work too.

---

### Windows Setup (Brief)

On Windows, Docker Desktop uses WSL2 (Windows Subsystem for Linux 2).

```powershell
# 1. Install Docker Desktop for Windows
# https://desktop.docker.com/win/main/amd64/Docker%20Desktop%20Installer.exe

# 2. During install: enable WSL2 backend (recommended)

# 3. Verify in PowerShell or Command Prompt
docker --version
docker run --rm alpine echo "BioFlow Docker works on Windows!"
```

BioFlow finds the Docker binary as `docker.exe` on Windows — no extra setup needed beyond having Docker Desktop running.

---

### Apple Silicon (M1/M2/M3) Users

BioFlow automatically detects Apple Silicon and adds `--platform linux/amd64` when needed for x86-only images. However, **Rosetta 2 must be installed**:

```bash
# Install Rosetta 2 (one-time setup)
softwareupdate --install-rosetta --agree-to-license

# Verify it's installed
/usr/bin/pgrep -q oahd && echo "Rosetta 2 is running" || echo "Rosetta 2 not active"
```

In Docker Desktop → Settings → General, ensure **"Use Rosetta for x86/amd64 emulation on Apple Silicon"** is checked.

---

### Quick Troubleshooting

| Symptom | Fix |
|---------|-----|
| BioFlow banner shows "Docker not running" | Start Docker Desktop, wait for whale icon |
| `docker: command not found` in terminal | Run `sudo ln -sf /Applications/Docker.app/Contents/Resources/bin/docker /usr/local/bin/docker` |
| Socket file missing (`~/.docker/run/docker.sock`) | Docker Desktop not fully started; wait or restart it |
| `Cannot connect to Docker daemon` | Set `DOCKER_HOST=unix://$HOME/.docker/run/docker.sock` and retry |
| Apple Silicon: image fails with architecture error | Enable Rosetta in Docker Desktop settings |
| App works in debug but not release build | Ensure `com.apple.security.app-sandbox` is `false` in Release.entitlements |

---

### macOS Entitlements (for developers building from source)

The app requires these macOS entitlements to spawn Docker CLI processes and access the filesystem. These are already set in the repo:

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

---

## 🙏 Acknowledgments

- Built with [Flutter](https://flutter.dev)
- Docker integration via [Docker Hub API](https://hub.docker.com)
- Icons from [Material Design](https://material.io/icons)
- Inspired by n8n's visual workflow UX

---

<div align="center">

**Made with ❤️ for the bioinformatics community**

⭐ Star this repo if it helps your research!

</div>
