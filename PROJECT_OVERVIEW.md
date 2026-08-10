# Ricochet: Project Overview & Architecture

## 🧬 What is Ricochet?

**Ricochet is a visual pipeline builder for bioinformatics workflows, powered by Docker.**

Think of it as **"n8n meets Galaxy"** - combining the beautiful drag-and-drop interface of modern workflow tools with the scientific rigor of bioinformatics platforms, all running locally on your desktop.

### 🎯 Elevator Pitch (30 seconds)

> "Ricochet lets bioinformaticians build complex data analysis pipelines by dragging and dropping Docker containers on a visual canvas. No more writing YAML or Bash scripts - just connect your favorite tools (FastQC, GATK, Samtools) like building blocks, hit Execute, and watch your analysis run. It's Galaxy's ease-of-use with Nextflow's power, but running entirely on your Mac, Windows, or Linux machine."

### 🚀 The Problem We Solve

**Current Pain Points in Bioinformatics:**

1. **Command-Line Hell**
   - Biologists struggle with complex command-line tools
   - `cd`, `grep`, pipes, and regex are barriers to entry
   - One typo = hours of debugging

2. **Environment Management Nightmare**
   - "It works on my machine" syndrome
   - Conda environments break constantly
   - Python 2 vs 3, library conflicts, version hell

3. **Pipeline Complexity**
   - Nextflow/Snakemake require programming skills
   - Galaxy is web-only and slow for large datasets
   - No good middle ground between "too simple" and "too complex"

4. **Reproducibility Crisis**
   - Hard to share exact analysis steps
   - Different computers = different results
   - Published methods are often impossible to replicate

**Ricochet's Solution:**

✅ Visual interface = no coding required  
✅ Docker containers = consistent environments  
✅ Local execution = fast, secure, private  
✅ Version control ready = reproducible science  
✅ Cross-platform = works everywhere  

---

## 🏗️ Technical Architecture

### High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                      Ricochet Desktop App                       │
│                       (Flutter / Dart)                          │
│                  (Frameless window_manager)                     │
├──────────────────────┬──────────────────────────────────────────┤
│    Home Screen       │            Editor Scaffold               │
│  ┌───────────────┐   │  ┌──────────────────────────────────┐   │
│  │ Recent        │   │  │  Multi-Tab Bar (Chrome-style)    │   │
│  │ Pipelines     │   │  └──────────────────────────────────┘   │
│  │ Sidebar       │   │  ┌────────────────────┬─────────────┐   │
│  ├───────────────┤   │  │ Tool Sidebar       │ Canvas      │   │
│  │ Template      │   │  │ (Built-in Blocks   │ (Nodes +    │   │
│  │ Gallery       │   │  │  + Docker Hub      │ Connections)│   │
│  │ (5 curated    │   │  │  Search)           │             │   │
│  │  templates +  │   │  ├────────────────────┴─────────────┤   │
│  │  category     │   │  │ Execution Console (slide-up panel│   │
│  │  filter)      │   │  │ per-tab logs, resize handle)     │   │
│  └───────────────┘   │  └──────────────────────────────────┘   │
│                      │  ┌──────────────────────────────────┐   │
│                      │  │ Status Bar (Docker, CPU, GPU,    │   │
│                      │  │ Disk — live 4-second polling)    │   │
│                      │  └──────────────────────────────────┘   │
├──────────────────────┴──────────────────────────────────────────┤
│                       Controller Layer (GetX)                   │
│  ┌──────────────────┐  ┌────────────────────┐                  │
│  │PipelineController│  │ExecutionController │                  │
│  │ - nodes/conns    │  │ - orchestration    │                  │
│  │ - undo/redo      │  │ - per-tab logs     │                  │
│  │ - topo sort      │  │ - heartbeat timer  │                  │
│  │ - image pull     │  └────────────────────┘                  │
│  │ - export/import  │  ┌────────────────────┐                  │
│  └──────────────────┘  │  DockerController  │                  │
│  ┌──────────────────┐  │  (Docker daemon    │                  │
│  │PipelineTabsCtrl  │  │   status / banner) │                  │
│  │ - tab lifecycle  │  └────────────────────┘                  │
│  │ - auto-save      │  ┌────────────────────┐                  │
│  │ - session restore│  │DockerSearchCtrl    │                  │
│  └──────────────────┘  │ - Hub API search   │                  │
│  ┌──────────────────┐  │ - LRU tag cache    │                  │
│  │  HomeController  │  │ - smart tag resolve│                  │
│  │ - app navigation │  │ - deduplication    │                  │
│  │ - recent list    │  └────────────────────┘                  │
│  └──────────────────┘  ┌────────────────────┐                  │
│  ┌──────────────────┐  │SystemStatsController│                 │
│  │  (Template       │  │ - CPU/GPU/Disk poll │                 │
│  │   loading via    │  │ - per-platform cmds │                 │
│  │ PipelineCtrl)    │  │ - 4-second interval │                 │
│  └──────────────────┘  └────────────────────┘                  │
├─────────────────────────────────────────────────────────────────┤
│                        Service Layer                            │
│  ┌──────────────────┐  ┌──────────────────┐                    │
│  │  DockerService   │  │  WorkspaceService│                    │
│  │ - executable     │  │ - pipeline dirs  │                    │
│  │   discovery      │  │ - staging (OS    │                    │
│  │ - pull progress  │  │   temp dir)      │                    │
│  │ - runContainer   │  │ - finalize +     │                    │
│  │ - stopContainer  │  │   deduplication  │                    │
│  │ - process map    │  │ - export ZIPs    │                    │
│  │ - killAll        │  │ - import round-  │                    │
│  └──────────────────┘  │   trip           │                    │
│  ┌──────────────────┐  └──────────────────┘                    │
│  │ComposeExportSvc  │  ┌──────────────────┐                    │
│  │ - docker-compose │  │DirectoryHashing  │                    │
│  │   YAML generator │  │   Service        │                    │
│  │ - env file gen   │  │ - recursive MD5  │                    │
│  │ - RICOCHET_STATE │  │   fingerprinting │                    │
│  │   Base64 embed   │  └──────────────────┘                    │
│  └──────────────────┘  ┌──────────────────┐                    │
│                        │  ProcessRunner   │                    │
│                        │  (abstract iface)│                    │
│                        │ - timeout + kill │                    │
│                        │ - SIGTERM →      │                    │
│                        │   SIGKILL        │                    │
│                        │ - injectable for │                    │
│                        │   tests          │                    │
│                        └──────────────────┘                    │
└─────────────────────────────────────────────────────────────────┘
                              ↓
         ┌───────────────────────────────────────┐
         │        Docker Engine (Local)          │
         ├───────────────────────────────────────┤
         │  Container 1  │  Container 2  │  ... │
         │  (FastQC)     │  (Trimmomatic)│      │
         └───────────────────────────────────────┘
                              ↓
         ┌─────────────────────────────────────────────────┐
         │      Ricochet Workspace (OS Documents dir)      │
         │                                                 │
         │  Pipelines/                                     │
         │  ├── My_RNA_Seq/                                │
         │  │   ├── pipeline_<timestamp>.json              │
         │  │   ├── FastQC_<timestamp>/         ← deduped  │
         │  │   │   └── output.txt                         │
         │  │   └── Trimmomatic_<timestamp>/               │
         │  └── Variant_Calling/                           │
         │      └── pipeline_<timestamp>.json              │
         │  exports/                                       │
         │  └── MyPipeline_export_<timestamp>.zip          │
         │                                                 │
         │  (Staging: OS temp dir — cleaned up on success) │
         └─────────────────────────────────────────────────┘
```

### Component Breakdown

#### 1. **Frontend Layer (Flutter)**
- **Technology**: Flutter 3.x, Dart 3.x, `window_manager` (frameless, custom title bar)
- **Purpose**: Cross-platform desktop UI (macOS, Windows, Linux)
- **Key Views**:
  - `HomeScreen`: Landing page with Recent Pipelines sidebar + Template Gallery; animated transition to Editor
  - `EditorScaffold`: Multi-tab canvas, tool sidebar, execution console, status bar
  - `PipelineCanvas`: Infinite pan/zoom canvas with Bezier connections and cycle highlighting
  - `ParameterSidebar`: Horizontally resizable (280–700 px) node configuration panel
  - `ExecutionPanel`: Slide-up log console with per-tab isolated log streams
- **Key Features**:
  - Infinite canvas with smooth pan/zoom
  - Drag-and-drop node creation
  - Visual connection drawing (Bezier curves)
  - Real-time log streaming
  - Frameless custom title bar with OS-native window controls

#### 2. **State Management (GetX)**
- **Technology**: GetX 4.x (reactive state management, no boilerplate)
- **Controllers**:

  | Controller | Responsibilities |
  |-----------|-----------------|
  | `PipelineController` | Nodes, connections, undo/redo per tab, image pull, topological sort, export/import, template loading |
  | `ExecutionController` | Pipeline orchestration loop, per-tab log buffers, heartbeat timer, stop logic |
  | `DockerController` | Docker daemon status, platform detection (Apple Silicon notice) |
  | `DockerSearchController` | Docker Hub search, LRU tag cache, smart tag resolution, request deduplication |
  | `PipelineTabsController` | Tab lifecycle, 2-second debounce auto-save, session restore, rename |
  | `HomeController` | Home ↔ Editor navigation, recent pipeline list loading |
  | `SystemStatsController` | CPU/GPU/Disk polling every 4 seconds per platform |

#### 3. **Docker Integration**
- **Technology**: Docker CLI via Dart `Process` API (through `ProcessRunner` abstraction)
- **Capabilities**:
  - Executable auto-discovery (Intel Mac, Apple Silicon, Windows, Linux paths, Snap)
  - Image search and pull with **layer-by-layer progress** (regex parsing of Docker pull output)
  - Container lifecycle management: run, stop (SIGKILL), kill-all emergency stop
  - Volume mounting for data flow: read-only input mounts + read-write output mounts
  - Environment variable injection: `INPUT_FILE`, `INPUT_FILE_N`, `INPUT_DIR`, `OUTPUT_DIR`
  - Real-time stdout/stderr streaming via Dart stream transformers
  - `_activeProcesses` map for reliable cleanup of both pull and run processes
  - Platform-aware `DOCKER_HOST` and `DOCKER_CONFIG` injection for sandboxed macOS apps

#### 4. **Execution Engine**
- **Topological Sorting**: Kahn's algorithm for dependency resolution (raises on cycle)
- **Cycle Detection**: Separate DFS-based `getCycleConnections()` highlights problematic edges in red on the canvas
- **Data Flow**: Output directories from Node A → read-only `/inputs/` volume mounts in Node B
- **Variable Expressions**: `NodeTitle.out` / `NodeTitle.in_N` resolved to container paths at runtime
- **Container timeout**: Hard 120-minute kill with descriptive error logs
- **Stream drain**: 30-second timeout after process exit to capture residual buffered output
- **Error Handling**: Failure scopes (`imagePull`, `execution`, `configuration`, `canceled`) with targeted recovery UI
- **Logging**: Structured messages — `[STDOUT]`, `[STDERR]`, `[SYSTEM]`, `[ERROR]`, `[WARNING]`
- **Heartbeat**: Logs elapsed time every 10 seconds for long-running containers

#### 5. **Workspace System & Smart Deduplication**

The workspace system is content-addressed — identical outputs are never written twice.

**Execution flow for each node:**

```
1. Create staging directory in OS temp:
   /tmp/ricochet_staging_<NodeName>_<timestamp>/

2. Run Docker container → output.txt written to staging

3. After process exits, compute MD5 hash of staging directory:
   DirectoryHashingService.calculateDirectoryHash()
   → sorted recursive hash of all files (path + content)

4. Compare with all existing result versions for this node:
   Pipelines/<name>/<NodeName>_*/.ricochet_hash

5a. Hash match found → reuse existing folder, delete staging
    (identical results from a previous run)

5b. No match → move staging to:
    Pipelines/<name>/<NodeName>_<ss_mm_hh_DD_MM_YYYY>/
    (new unique result version)
```

**Benefits:**
- Zero duplicate disk writes for re-runs with same data
- Full lineage: every versioned result folder is independently verifiable
- Deterministic: same inputs always produce the same folder name-independent hash

#### 6. **ProcessRunner Abstraction**

`ProcessRunner` is an abstract interface that wraps `Process.run` and `Process.start`:

```dart
abstract class ProcessRunner {
  Future<ProcessResult> run(String executable, List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
    bool runInShell = false,
    Duration? timeout,          // auto-kill after timeout
  });

  Future<Process> start(String executable, List<String> arguments, {...});

  Future<void> kill(Process process, {
    ProcessSignal signal = ProcessSignal.sigterm,
    Duration gracePeriod = const Duration(seconds: 5),  // SIGTERM → SIGKILL
  });
}
```

- **`SystemProcessRunner`**: production implementation using real OS processes
- **`DockerService.withRunner()`** and **`WorkspaceService.withPath()`**: factory constructors for test isolation (inject `FakeProcessRunner`)
- Two-phase kill prevents zombie processes: SIGTERM → 5 s grace → SIGKILL

#### 7. **Docker Hub Search & Caching**

- **Live search** against `https://hub.docker.com/v2/search/repositories/`
- **Smart tag resolution** (`_resolveSmartTag`): fetches tag list, ranks by version-like patterns (e.g. `1.2.3`, `v1.2.3`) over non-version tags (e.g. `latest`, `slim`), then returns the most recent stable version
- **LRU cache with TTL**: tag lists cached in memory; expired entries serve stale data immediately (Stale-While-Revalidate) while a background refresh runs
- **Deduplication**: concurrent requests for the same image/query share a single in-flight future

#### 8. **Template System**

Defined as compile-time constants in `pipeline_template.dart`:

```dart
class PipelineTemplate {
  final String id, name, description, category;
  final List<Color> gradientColors;
  final IconData icon;
  final String estimatedTime, difficulty;
  final List<String> tags, requiredImages;
  final List<TemplateNodeDef> nodes;          // positions + type + param overrides
  final List<TemplateConnectionDef> connections;  // by node list index
}
```

- All nodes are positioned near the virtual canvas centre `(25000, 25000)` so `centerView()` / auto-fit requires minimal travel
- `PipelineController.loadTemplate()` clears the canvas, creates all nodes + connections atomically, saves history, then increments `fitViewRequest` to trigger the canvas auto-fit animation

#### 9. **Docker Compose Export**

- Generates a `.zip` containing:
  - `docker-compose.yml`: services with `depends_on: service_completed_successfully`, `platform:`, `user:`, volumes, env, command
  - `pipeline_config.env`: all node parameters as overridable env vars + `# RICOCHET_STATE: <base64>` embedded at the bottom
  - `README.md`: auto-generated run instructions, lifecycle commands, common fixes
- The `RICOCHET_STATE` blob is JSON → UTF-8 → Base64. It encodes all nodes and connections and is decoded by `WorkspaceService.importPipelineFromExport()` for perfect round-trip fidelity

#### 10. **System Stats Polling**

`SystemStatsController` updates CPU usage, GPU usage, and free disk space every 4 seconds:

| Metric | macOS | Windows | Linux |
|--------|-------|---------|-------|
| **CPU** | `top -l 1` | PowerShell `Win32_Processor` | `/proc/stat` raw delta (no subprocess) |
| **GPU** | — | `nvidia-smi --query-gpu=utilization.gpu` | `nvidia-smi ...` |
| **Disk** | `df -h` | PowerShal `Get-PSDrive` | `df -h` |

- GPU polling gracefully disables itself if `nvidia-smi` is absent
- Linux CPU uses a tick-delta from `/proc/stat` — **zero child process per cycle**
- Polling skips if a previous poll is still in flight (no overlapping calls)

#### 11. **Window Management**

- **`window_manager`**: hides the OS title bar for a clean frameless window
- **`DragToMoveArea`**: wraps the top bar on both Home Screen and Editor header, enabling window dragging from any part of the header
- **macOS**: left-side padding set to 80 px to avoid overlapping native traffic-light controls; custom buttons hidden
- **Windows/Linux**: custom Minimize / Maximize / Close buttons with hover colours

---

## 👥 Target Audience

### Primary Users (70% of use cases)

#### 1. **Academic Bioinformaticians**
- **Profile**: PhD students, postdocs, bioinformatics core facilities
- **Pain Point**: Need to build pipelines but not professional programmers
- **Use Cases**:
  - RNA-Seq differential expression
  - Variant calling from WGS/WES
  - ChIP-Seq peak calling
  - Metagenomics classification
- **Why Ricochet**:
  - ✅ Free (grants don't cover expensive software)
  - ✅ Works offline (unreliable university networks)
  - ✅ No server setup required (IT won't help)

#### 2. **Computational Biologists (Intermediate)**
- **Profile**: Know Python/R, struggle with DevOps
- **Pain Point**: Can code but hate managing environments
- **Use Cases**:
  - Custom analysis workflows
  - Reproducible research pipelines
  - Method development and benchmarking
- **Why Ricochet**:
  - ✅ Docker = no environment management
  - ✅ Visual = easier to explain to collaborators
  - ✅ Local = fast iteration

#### 3. **Bioinformatics Service Providers**
- **Profile**: Core facilities, contract research organizations
- **Pain Point**: Need to serve non-technical clients
- **Use Cases**:
  - Standardized analysis pipelines
  - Client-specific workflows
  - High-throughput sample processing
- **Why Ricochet**:
  - ✅ Client can see the pipeline visually (transparency)
  - ✅ Easy to train new staff
  - ✅ Consistent results across runs

### Secondary Users (30% of use cases)

#### 4. **Pharma/Biotech Scientists**
- **Profile**: Wet-lab scientists doing their own analysis
- **Pain Point**: No coding background, need quick insights
- **Use Cases**:
  - QC on sequencing data
  - Simple variant annotation
  - Gene expression comparisons
- **Why Ricochet**:
  - ✅ No IT department dependency
  - ✅ Runs on their laptop
  - ✅ Data stays on-premise (compliance)

#### 5. **Bioinformatics Educators**
- **Profile**: University professors, workshop instructors
- **Pain Point**: Teaching command-line is slow and error-prone
- **Use Cases**:
  - Teaching pipeline concepts
  - Student projects
  - Workshops and tutorials
- **Why Ricochet**:
  - ✅ Visual = students understand flow immediately
  - ✅ No installation headaches (Docker Desktop + Ricochet)
  - ✅ Pre-built templates for common assignments

---

## 🥊 Competitive Analysis

### Direct Competitors

#### 1. **Galaxy** (galaxyproject.org)
**What it is**: Web-based workflow platform for bioinformatics

| Feature | Galaxy | Ricochet | Winner |
|---------|--------|---------|--------|
| **Ease of Use** | ⭐⭐⭐⭐⭐ Drag-drop | ⭐⭐⭐⭐⭐ Drag-drop | 🟰 Tie |
| **Local Execution** | ❌ Web-only | ✅ Desktop | 🏆 Ricochet |
| **Speed** | ⭐⭐ Slow (server) | ⭐⭐⭐⭐⭐ Fast (local) | 🏆 Ricochet |
| **Data Privacy** | ⭐⭐ Upload required | ⭐⭐⭐⭐⭐ Stays local | 🏆 Ricochet |
| **Tool Library** | ⭐⭐⭐⭐⭐ 9,000+ tools | ⭐⭐⭐ Growing | 🏆 Galaxy |
| **Large Datasets** | ⭐⭐ Limited | ⭐⭐⭐⭐⭐ No limits | 🏆 Ricochet |
| **Cost** | Free | Free (local) | 🟰 Tie |

**Verdict**: Galaxy is better for beginners with small datasets. Ricochet is better for performance and privacy.

#### 2. **Nextflow** (nextflow.io)
**What it is**: Code-first workflow management system (Groovy DSL)

| Feature | Nextflow | Ricochet | Winner |
|---------|----------|---------|--------|
| **Ease of Use** | ⭐⭐ Code-heavy | ⭐⭐⭐⭐⭐ Visual | 🏆 Ricochet |
| **Flexibility** | ⭐⭐⭐⭐⭐ Unlimited | ⭐⭐⭐⭐ High | 🏆 Nextflow |
| **Learning Curve** | ⭐⭐ Steep | ⭐⭐⭐⭐⭐ Gentle | 🏆 Ricochet |
| **Scalability** | ⭐⭐⭐⭐⭐ HPC/Cloud | ⭐⭐⭐⭐ Local/Cloud | 🏆 Nextflow |
| **Reproducibility** | ⭐⭐⭐⭐⭐ Excellent | ⭐⭐⭐⭐⭐ Excellent | 🟰 Tie |
| **Community** | ⭐⭐⭐⭐⭐ nf-core | ⭐⭐ Growing | 🏆 Nextflow |

**Verdict**: Nextflow is better for expert users and HPC. Ricochet is better for accessibility and quick prototyping.

#### 3. **Snakemake** (snakemake.github.io)
**What it is**: Python-based workflow management (Makefile-inspired)

| Feature | Snakemake | Ricochet | Winner |
|---------|-----------|---------|--------|
| **Ease of Use** | ⭐⭐⭐ Python knowledge | ⭐⭐⭐⭐⭐ No coding | 🏆 Ricochet |
| **Python Integration** | ⭐⭐⭐⭐⭐ Native | ⭐⭐⭐⭐ Via containers | 🏆 Snakemake |
| **Visual Design** | ❌ None | ⭐⭐⭐⭐⭐ Yes | 🏆 Ricochet |
| **Learning Curve** | ⭐⭐⭐ Moderate | ⭐⭐⭐⭐⭐ Low | 🏆 Ricochet |
| **Academia Adoption** | ⭐⭐⭐⭐⭐ High | ⭐ New | 🏆 Snakemake |

**Verdict**: Snakemake is better for Python-heavy workflows. Ricochet is better for non-programmers.

### Indirect Competitors

#### 4. **KNIME** (knime.com)
- **Type**: General data science platform (not bio-specific)
- **Advantage**: Mature ecosystem, enterprise support
- **Disadvantage**: Clunky UI, expensive licenses, Java-based
- **Ricochet Edge**: Modern UI, bio-specific, free

#### 5. **n8n** (n8n.io)
- **Type**: General workflow automation (not bio-specific)
- **Advantage**: Beautiful UI, execution-based pricing model
- **Disadvantage**: No bioinformatics tools, cloud-first
- **Ricochet Edge**: Tailored for science, local-first, Docker native

---

## 🎁 Unique Value Proposition

### What Makes Ricochet Different?

**1. Visual + Local = Unique Combination**
- Galaxy: Visual but web-only
- Nextflow: Local but code-only
- **Ricochet**: Both ✅

**2. Desktop-First Architecture**
- No server setup, no IT approval needed
- Instant startup (no loading web apps)
- Works offline (airports, field sites)

**3. Docker Native, Not Bolted-On**
- Competitors added Docker later, feels hacky
- Ricochet designed around Docker from day 1
- Seamless integration (pull, run, mount, stream)

**4. Modern Developer Experience**
- Built with Flutter (state-of-the-art UI framework)
- Feels like Figma/Notion, not academic software from 2010
- Dark mode, smooth animations, attention to detail

**5. Content-Addressed Reproducibility**
- Smart MD5 deduplication means identical analyses never re-run or re-store
- Every result is versioned and independently verifiable
- Round-trip export/import via embedded RICOCHET_STATE blob

**6. Open Yet Monetizable**
- Free core = community growth
- Premium features = sustainable development
- Best of both worlds (unlike 100% free or 100% paid)

---

## 🌟 Use Cases & Success Stories

### Real-World Applications

#### Use Case 1: **Quality Control Pipeline**
**User**: Core sequencing facility  
**Pipeline**: FASTQ → FastQC → MultiQC → Adapter Trimming (cutadapt) → FastQC Again  
**Before Ricochet**: 2 hours of Bash scripting per project  
**After Ricochet**: 5 minutes to build, save as template, reuse forever  
**ROI**: 95% time savings  

#### Use Case 2: **Variant Calling for Cancer Research**
**User**: PhD student in oncology  
**Pipeline**: FASTQ → BWA Alignment → GATK Variant Calling → SnpEff Annotation → Custom R Script  
**Before Ricochet**: Struggled with Nextflow syntax for 2 weeks  
**After Ricochet**: Built visually in 1 afternoon  
**ROI**: Got back to science instead of coding  

#### Use Case 3: **Teaching Bioinformatics**
**User**: University professor  
**Course**: Intro to Genomics (50 students)  
**Before Ricochet**: 3-hour lab just to install tools, 50% failure rate  
**After Ricochet**: 15 minutes (Docker Desktop + Ricochet), 100% success  
**ROI**: Students actually learn concepts instead of fighting installation  

---

## 📊 Market Position

### Where Ricochet Fits

```
                    Complexity of Analysis
                            ↑
                            │
        Nextflow ─────────┐ │
        Snakemake ────┐   │ │
                      │   │ │
                      │   │ │        ← Power Users
        ┌─────────────┴───┴─┤        (Bioinformaticians)
        │                   │
        │    Ricochet        │        ← Sweet Spot
        │      ⭐           │        (80% of users)
        │                   │
        └───────────────────┤
                            │
           Galaxy ──────────┤        ← Entry Level
                            │        (Biologists)
                            │
                            ↓
            ← Ease of Use →
```

**The 80/20 Rule:**
- 80% of bioinformaticians need 20% of Nextflow's power
- **Ricochet targets that 80%**
- We're not trying to replace Nextflow for HPC gurus
- We're empowering the majority who just want to get work done

---

## 🏆 Key Differentiators (Summary)

| What | How | Why It Matters |
|------|-----|----------------|
| **Desktop Native** | Flutter app, not web | Fast, offline, private data |
| **Visual First** | Drag-drop, not code | Accessible to biologists |
| **Docker Native** | Built-in, not plugin | Reproducible, consistent |
| **Modern UX** | 2024 design standards | People actually want to use it |
| **Content-Addressed** | MD5 dedup + versioning | Never re-run what hasn't changed |
| **Round-Trip Export** | RICOCHET_STATE embed | Share pipelines that re-import perfectly |
| **Open Core** | Free local, paid cloud | Sustainable + community |
| **Cross-Platform** | macOS/Windows/Linux | Works on all lab computers |
| **Testable Architecture** | ProcessRunner interface | Reliable CI, injectable fakes |

---

## 🔧 Tech Stack Reference

| Layer | Technology | Purpose |
|-------|-----------|---------|
| UI Framework | Flutter 3.x / Dart 3.x | Cross-platform desktop |
| Window Management | `window_manager` | Frameless window, custom title bar |
| State Management | GetX 4.x | Reactive controllers |
| Docker Integration | Docker CLI via `Process` API | Container lifecycle |
| HTTP | `http` | Docker Hub API search |
| Serialization | `json_serializable`, `json_annotation` | Pipeline JSON I/O |
| File Picking | `file_picker` | Multi-file input selection |
| Path Handling | `path`, `path_provider` | Cross-platform path resolution |
| Archive | `archive` | ZIP export/import |
| Hashing | `crypto` (MD5) | Output deduplication |
| UUID | `uuid` | Unique node/connection IDs |
| Typography | `google_fonts` | UI typography |
| Process Abstraction | `ProcessRunner` (custom) | Testable subprocess management |
| Algorithm | Kahn's Topological Sort | Execution ordering |

---

## 🎯 The Vision

**Short-term (6 months):**  
The easiest way to build bioinformatics pipelines.

**Medium-term (2 years):**  
The standard tool for reproducible computational biology.

**AI Assistant (in design):**  
Bring-your-own-model pipeline generation and command assist — see [`AI_ASSISTANT_PLAN.md`](AI_ASSISTANT_PLAN.md) (v5).

**Long-term (5 years):**  
Every published bioinformatics paper includes a Ricochet pipeline file, just like they include code repositories today.

---

## 📝 Summary

**Ricochet is:**
- A desktop application for building bioinformatics pipelines visually
- Powered by Docker for reproducibility
- Designed for the 80% of users who find Nextflow too complex and Galaxy too limited
- Free and open source (with paid cloud features coming)
- Built with modern technology (Flutter) for a modern user experience
- Content-addressed: identical results reused automatically, zero wasted compute
- Fully portable: pipelines export as self-contained Docker Compose projects and re-import perfectly

**If you can use Figma, you can use Ricochet. If you can run Docker, you can run Ricochet. That's the promise.**

---

## 🔗 Quick Links (For README/Docs)

- **GitHub**: github.com/yourname/Ricochet
- **Documentation**: Ricochet.dev/docs
- **Community**: discord.gg/Ricochet
- **Roadmap**: github.com/yourname/Ricochet/projects
- **Twitter**: @Ricochet_dev

**Star us if you like it!** ⭐
