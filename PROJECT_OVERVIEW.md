# BioFlow: Project Overview & Architecture

## 🧬 What is BioFlow?

**BioFlow is a visual pipeline builder for bioinformatics workflows, powered by Docker.**

Think of it as **"n8n meets Galaxy"** - combining the beautiful drag-and-drop interface of modern workflow tools with the scientific rigor of bioinformatics platforms, all running locally on your desktop.

### 🎯 Elevator Pitch (30 seconds)

> "BioFlow lets bioinformaticians build complex data analysis pipelines by dragging and dropping Docker containers on a visual canvas. No more writing YAML or Bash scripts - just connect your favorite tools (FastQC, GATK, Samtools) like building blocks, hit Execute, and watch your analysis run. It's Galaxy's ease-of-use with Nextflow's power, but running entirely on your Mac, Windows, or Linux machine."

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

**BioFlow's Solution:**

✅ Visual interface = no coding required  
✅ Docker containers = consistent environments  
✅ Local execution = fast, secure, private  
✅ Version control ready = reproducible science  
✅ Cross-platform = works everywhere  

---

## 🏗️ Technical Architecture

### High-Level Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     BioFlow Desktop App                     │
│                      (Flutter / Dart)                       │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐     │
│  │   Canvas     │  │  Sidebar     │  │  Execution   │     │
│  │   (Nodes +   │  │  (Docker     │  │  Panel       │     │
│  │  Connections)│  │   Images)    │  │  (Logs)      │     │
│  └──────────────┘  └──────────────┘  └──────────────┘     │
│                                                             │
├─────────────────────────────────────────────────────────────┤
│                    Controller Layer                         │
│  ┌──────────────────┐  ┌──────────────────┐               │
│  │ PipelineController│  │ExecutionController│              │
│  │  (State Mgmt)    │  │  (Orchestration)  │              │
│  └──────────────────┘  └──────────────────┘               │
├─────────────────────────────────────────────────────────────┤
│                     Service Layer                           │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐     │
│  │ DockerService│  │  Workspace   │  │   Storage    │     │
│  │   (CLI API)  │  │   Service    │  │   Service    │     │
│  └──────────────┘  └──────────────┘  └──────────────┘     │
└─────────────────────────────────────────────────────────────┘
                            ↓
        ┌───────────────────────────────────────┐
        │        Docker Engine (Local)          │
        ├───────────────────────────────────────┤
        │  Container 1  │  Container 2  │  ... │
        │  (python)     │  (alpine)     │      │
        └───────────────────────────────────────┘
                            ↓
        ┌───────────────────────────────────────┐
        │      BioFlow Workspace Directory      │
        │   ~/Documents/bioflow_workspace/      │
        │                                       │
        │   run_2025-12-04T10-30-15/           │
        │   ├── node1_alpine/output.txt        │
        │   ├── node2_python/output.txt        │
        │   └── node3_gatk/variants.vcf        │
        └───────────────────────────────────────┘
```

### Component Breakdown

#### 1. **Frontend Layer (Flutter)**
- **Technology**: Flutter 3.x, Dart 3.x
- **Purpose**: Cross-platform desktop UI (macOS, Windows, Linux)
- **Key Features**:
  - Infinite canvas with pan/zoom
  - Drag-and-drop node creation
  - Visual connection drawing (Bezier curves)
  - Real-time log streaming
  - Dark mode support

#### 2. **State Management (GetX)**
- **Technology**: GetX 4.x (reactive state management)
- **Controllers**:
  - `PipelineController`: Manages nodes, connections, selection
  - `ExecutionController`: Orchestrates pipeline execution
  - `DockerController`: Manages Docker image library

#### 3. **Docker Integration**
- **Technology**: Docker CLI via Dart `Process` API
- **Capabilities**:
  - Image search and pull (with progress tracking)
  - Container lifecycle management (run, stop, kill)
  - Volume mounting for data flow
  - Environment variable injection
  - Real-time stdout/stderr streaming

#### 4. **Execution Engine**
- **Topological Sorting**: Kahn's algorithm for dependency resolution
- **Data Flow**: Output files from Node A → Input mounts for Node B
- **Error Handling**: Cycle detection, graceful failure, pipeline stopping
- **Logging**: Structured logs (STDOUT, STDERR, SYSTEM messages)

#### 5. **Workspace System**
- **Structure**: Timestamped runs, node-specific output directories
- **File Management**: Automatic cleanup, path resolution
- **Data Provenance**: Full lineage tracking (which node produced which file)

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
- **Why BioFlow**:
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
- **Why BioFlow**:
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
- **Why BioFlow**:
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
- **Why BioFlow**:
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
- **Why BioFlow**:
  - ✅ Visual = students understand flow immediately
  - ✅ No installation headaches (Docker Desktop + BioFlow)
  - ✅ Pre-built templates for common assignments

---

## 🥊 Competitive Analysis

### Direct Competitors

#### 1. **Galaxy** (galaxyproject.org)
**What it is**: Web-based workflow platform for bioinformatics

| Feature | Galaxy | BioFlow | Winner |
|---------|--------|---------|--------|
| **Ease of Use** | ⭐⭐⭐⭐⭐ Drag-drop | ⭐⭐⭐⭐⭐ Drag-drop | 🟰 Tie |
| **Local Execution** | ❌ Web-only | ✅ Desktop | 🏆 BioFlow |
| **Speed** | ⭐⭐ Slow (server) | ⭐⭐⭐⭐⭐ Fast (local) | 🏆 BioFlow |
| **Data Privacy** | ⭐⭐ Upload required | ⭐⭐⭐⭐⭐ Stays local | 🏆 BioFlow |
| **Tool Library** | ⭐⭐⭐⭐⭐ 9,000+ tools | ⭐⭐⭐ Growing | 🏆 Galaxy |
| **Large Datasets** | ⭐⭐ Limited | ⭐⭐⭐⭐⭐ No limits | 🏆 BioFlow |
| **Cost** | Free | Free (local) | 🟰 Tie |

**Verdict**: Galaxy is better for beginners with small datasets. BioFlow is better for performance and privacy.

#### 2. **Nextflow** (nextflow.io)
**What it is**: Code-first workflow management system (Groovy DSL)

| Feature | Nextflow | BioFlow | Winner |
|---------|----------|---------|--------|
| **Ease of Use** | ⭐⭐ Code-heavy | ⭐⭐⭐⭐⭐ Visual | 🏆 BioFlow |
| **Flexibility** | ⭐⭐⭐⭐⭐ Unlimited | ⭐⭐⭐⭐ High | 🏆 Nextflow |
| **Learning Curve** | ⭐⭐ Steep | ⭐⭐⭐⭐⭐ Gentle | 🏆 BioFlow |
| **Scalability** | ⭐⭐⭐⭐⭐ HPC/Cloud | ⭐⭐⭐⭐ Local/Cloud | 🏆 Nextflow |
| **Reproducibility** | ⭐⭐⭐⭐⭐ Excellent | ⭐⭐⭐⭐⭐ Excellent | 🟰 Tie |
| **Community** | ⭐⭐⭐⭐⭐ nf-core | ⭐⭐ Growing | 🏆 Nextflow |

**Verdict**: Nextflow is better for expert users and HPC. BioFlow is better for accessibility and quick prototyping.

#### 3. **Snakemake** (snakemake.github.io)
**What it is**: Python-based workflow management (Makefile-inspired)

| Feature | Snakemake | BioFlow | Winner |
|---------|-----------|---------|--------|
| **Ease of Use** | ⭐⭐⭐ Python knowledge | ⭐⭐⭐⭐⭐ No coding | 🏆 BioFlow |
| **Python Integration** | ⭐⭐⭐⭐⭐ Native | ⭐⭐⭐⭐ Via containers | 🏆 Snakemake |
| **Visual Design** | ❌ None | ⭐⭐⭐⭐⭐ Yes | 🏆 BioFlow |
| **Learning Curve** | ⭐⭐⭐ Moderate | ⭐⭐⭐⭐⭐ Low | 🏆 BioFlow |
| **Academia Adoption** | ⭐⭐⭐⭐⭐ High | ⭐ New | 🏆 Snakemake |

**Verdict**: Snakemake is better for Python-heavy workflows. BioFlow is better for non-programmers.

### Indirect Competitors

#### 4. **KNIME** (knime.com)
- **Type**: General data science platform (not bio-specific)
- **Advantage**: Mature ecosystem, enterprise support
- **Disadvantage**: Clunky UI, expensive licenses, Java-based
- **BioFlow Edge**: Modern UI, bio-specific, free

#### 5. **n8n** (n8n.io)
- **Type**: General workflow automation (not bio-specific)
- **Advantage**: Beautiful UI, execution-based pricing model
- **Disadvantage**: No bioinformatics tools, cloud-first
- **BioFlow Edge**: Tailored for science, local-first, Docker native

---

## 🎁 Unique Value Proposition

### What Makes BioFlow Different?

**1. Visual + Local = Unique Combination**
- Galaxy: Visual but web-only
- Nextflow: Local but code-only
- **BioFlow**: Both ✅

**2. Desktop-First Architecture**
- No server setup, no IT approval needed
- Instant startup (no loading web apps)
- Works offline (airports, field sites)

**3. Docker Native, Not Bolted-On**
- Competitors added Docker later, feels hacky
- BioFlow designed around Docker from day 1
- Seamless integration (pull, run, mount, stream)

**4. Modern Developer Experience**
- Built with Flutter (state-of-the-art UI framework)
- Feels like Figma/Notion, not academic software from 2010
- Dark mode, smooth animations, attention to detail

**5. Open Yet Monetizable**
- Free core = community growth
- Premium features = sustainable development
- Best of both worlds (unlike 100% free or 100% paid)

---

## 🌟 Use Cases & Success Stories

### Real-World Applications

#### Use Case 1: **Quality Control Pipeline**
**User**: Core sequencing facility  
**Pipeline**: FASTQ → FastQC → MultiQC → Adapter Trimming (cutadapt) → FastQC Again  
**Before BioFlow**: 2 hours of Bash scripting per project  
**After BioFlow**: 5 minutes to build, save as template, reuse forever  
**ROI**: 95% time savings  

#### Use Case 2: **Variant Calling for Cancer Research**
**User**: PhD student in oncology  
**Pipeline**: FASTQ → BWA Alignment → GATK Variant Calling → SnpEff Annotation → Custom R Script  
**Before BioFlow**: Struggled with Nextflow syntax for 2 weeks  
**After BioFlow**: Built visually in 1 afternoon  
**ROI**: Got back to science instead of coding  

#### Use Case 3: **Teaching Bioinformatics**
**User**: University professor  
**Course**: Intro to Genomics (50 students)  
**Before BioFlow**: 3-hour lab just to install tools, 50% failure rate  
**After BioFlow**: 15 minutes (Docker Desktop + BioFlow), 100% success  
**ROI**: Students actually learn concepts instead of fighting installation  

---

## 📊 Market Position

### Where BioFlow Fits

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
        │    BioFlow        │        ← Sweet Spot
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
- **BioFlow targets that 80%**
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
| **Open Core** | Free local, paid cloud | Sustainable + community |
| **Cross-Platform** | macOS/Windows/Linux | Works on all lab computers |

---

## 🎯 The Vision

**Short-term (6 months):**  
The easiest way to build bioinformatics pipelines.

**Medium-term (2 years):**  
The standard tool for reproducible computational biology.

**Long-term (5 years):**  
Every published bioinformatics paper includes a BioFlow pipeline file, just like they include code repositories today.

---

## 📝 Summary

**BioFlow is:**
- A desktop application for building bioinformatics pipelines visually
- Powered by Docker for reproducibility
- Designed for the 80% of users who find Nextflow too complex and Galaxy too limited
- Free and open source (with paid cloud features coming)
- Built with modern technology (Flutter) for a modern user experience

**If you can use Figma, you can use BioFlow. If you can run Docker, you can run BioFlow. That's the promise.**

---

## 🔗 Quick Links (For README/Docs)

- **GitHub**: github.com/yourname/bioflow
- **Documentation**: bioflow.dev/docs
- **Community**: discord.gg/bioflow
- **Roadmap**: github.com/yourname/bioflow/projects
- **Twitter**: @bioflow_dev

**Star us if you like it!** ⭐
