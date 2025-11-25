# BioFlow - Visual Pipeline Designer

<div align="center">

![Flutter](https://img.shields.io/badge/Flutter-3.5.3-02569B?logo=flutter)
![Dart](https://img.shields.io/badge/Dart-3.5.3-0175C2?logo=dart)
![License](https://img.shields.io/badge/License-MIT-green)
![Platform](https://img.shields.io/badge/Platform-Windows%20%7C%20macOS%20%7C%20Linux%20%7C%20Web-lightgrey)

**A modern, n8n-inspired visual workflow designer for bioinformatics pipelines built with Flutter**

</div>

---

## 📋 Table of Contents

- [Overview](#-overview)
- [Features](#-features)
- [Architecture](#-architecture)
- [Getting Started](#-getting-started)
- [Project Structure](#-project-structure)
- [Current Implementation Status](#-current-implementation-status)
- [Roadmap](#-roadmap)
- [Technology Stack](#-technology-stack)
- [Contributing](#-contributing)

---

## 🎯 Overview

**BioFlow** is a visual pipeline designer application that enables users to create, configure, and execute bioinformatics workflows through an intuitive drag-and-drop interface. Inspired by n8n's workflow automation platform, BioFlow provides a modern, cross-platform solution for building complex data processing pipelines without writing code.

### Key Highlights

- 🎨 **Modern UI/UX** - Clean, professional interface with smooth animations
- 🔄 **Visual Workflow Builder** - Drag-and-drop blocks to create pipelines
- 🐳 **Docker Integration** - Search and integrate Docker Hub images
- 📊 **Real-time Execution** - Execute pipelines with live console output
- 🔌 **Extensible Architecture** - Easy to add custom blocks and tools
- 🌐 **Cross-Platform** - Runs on Windows, macOS, Linux, and Web

---

## ✨ Features

### Implemented Features ✅

#### 1. **Visual Canvas**
- Infinite scrollable canvas (50,000 x 50,000 virtual space)
- Smooth pan and zoom controls (10% - 500%)
- Grid background with dynamic scaling
- Fit-to-view and reset view buttons
- Drag-and-drop block placement

#### 2. **Block Management**
- **Built-in Blocks:**
  - Input/Output blocks
  - FastQC (Quality Control)
  - Trimmomatic (Data Processing)
  - BWA (Alignment)
  - Variant Caller (Analysis)
- Draggable blocks from sidebar
- Visual feedback during drag operations
- Block selection and highlighting
- Node deletion support

#### 3. **Docker Integration**
- Real-time Docker Hub search
- Display official and community images
- Show image metadata (stars, pull count)
- Drag Docker images directly onto canvas
- Auto-configure Docker container blocks

#### 4. **Parameter Configuration**
- Right-side parameter sidebar
- Multiple parameter types:
  - Text input
  - Numeric input
  - Dropdown selection
  - Toggle switches
  - File selection
- Dynamic parameter addition/removal
- Real-time parameter validation
- Required field indicators

#### 5. **Connection System**
- Visual connection lines between blocks
- Bezier curve rendering
- Input/output port management
- Connection drag-and-drop
- Connection validation
- Color-coded connections by block type

#### 6. **Execution Engine**
- Pipeline execution with visual feedback
- Real-time execution console
- Block status indicators (pending, running, success, failed)
- Execution logs with emojis
- Resizable execution panel
- Toggle panel visibility
- Clear console functionality

#### 7. **UI/UX Enhancements**
- Professional color scheme
- Gradient backgrounds
- Box shadows and elevation
- Smooth animations and transitions
- Responsive layout
- Status bar with execution state
- Modern iconography

---

## 🏗️ Architecture

### Design Patterns

- **MVC Pattern** - Model-View-Controller separation
- **GetX State Management** - Reactive state management
- **Observer Pattern** - Real-time UI updates
- **Repository Pattern** - Data access abstraction

### Core Components

```
lib/
├── controllers/          # Business logic and state management
│   ├── pipeline_controller.dart      # Pipeline and node management
│   ├── execution_controller.dart     # Execution engine
│   └── docker_search_controller.dart # Docker Hub integration
├── models/              # Data models
│   ├── pipeline_node.dart           # Node and connection models
│   └── docker_image.dart            # Docker image model
├── views/               # UI components
│   ├── modern_canvas.dart           # Main canvas area
│   ├── modern_sidebar.dart          # Tool sidebar
│   └── widgets/                     # Reusable widgets
│       ├── n8n_block_widget.dart
│       ├── parameter_sidebar.dart
│       ├── execution_panel.dart
│       └── ...
└── main.dart            # Application entry point
```

---

## 🚀 Getting Started

### Prerequisites

- Flutter SDK 3.5.3 or higher
- Dart SDK 3.5.3 or higher
- An IDE (VS Code, Android Studio, or IntelliJ IDEA)

### Installation

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd n8n_application_2
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Run the application**
   ```bash
   flutter run
   ```

### Platform-Specific Builds

```bash
# Desktop
flutter run -d windows
flutter run -d macos
flutter run -d linux

# Web
flutter run -d chrome

# Build release
flutter build windows
flutter build macos
flutter build linux
flutter build web
```

---

## 📁 Project Structure

```
n8n_application_2/
├── lib/
│   ├── controllers/
│   │   ├── docker_search_controller.dart    # Docker Hub API integration
│   │   ├── execution_controller.dart        # Pipeline execution logic
│   │   └── pipeline_controller.dart         # Node/connection management
│   ├── models/
│   │   ├── docker_image.dart               # Docker image data model
│   │   └── pipeline_node.dart              # Pipeline node data model
│   ├── views/
│   │   ├── modern_canvas.dart              # Main canvas with zoom/pan
│   │   ├── modern_sidebar.dart             # Tool/Docker search sidebar
│   │   └── widgets/
│   │       ├── connection_dot.dart         # Connection port widget
│   │       ├── draggable_connection_point.dart
│   │       ├── execution_panel.dart        # Bottom execution console
│   │       ├── n8n_block_widget.dart       # Individual block widget
│   │       ├── n8n_connection_painter.dart # Connection line renderer
│   │       ├── parameter_panel.dart        # Parameter input widgets
│   │       └── parameter_sidebar.dart      # Right sidebar for params
│   └── main.dart                           # App entry point
├── pubspec.yaml                            # Dependencies
└── README.md                               # This file
```

---

## 📊 Current Implementation Status

### ✅ Completed (80%)

| Feature | Status | Notes |
|---------|--------|-------|
| Visual Canvas | ✅ Complete | Infinite canvas with zoom/pan |
| Block Library | ✅ Complete | 6 built-in blocks |
| Docker Search | ✅ Complete | Real-time Docker Hub search |
| Drag & Drop | ✅ Complete | Blocks and connections |
| Parameter Sidebar | ✅ Complete | 5 parameter types |
| Execution Engine | ✅ Complete | Mock execution with logs |
| Connection System | ✅ Complete | Visual connections |
| UI/UX Polish | ✅ Complete | Modern design |

### 🚧 In Progress (15%)

| Feature | Status | Notes |
|---------|--------|-------|
| Connection Validation | 🚧 Partial | Basic validation exists |
| Error Handling | 🚧 Partial | Network errors handled |
| Undo/Redo | ❌ Not Started | - |

### ❌ Not Started (5%)

| Feature | Status | Priority |
|---------|--------|----------|
| Save/Load Pipelines | ❌ Not Started | High |
| Export to Code | ❌ Not Started | Medium |
| Real Docker Execution | ❌ Not Started | High |

---

## 🗺️ Roadmap

### Phase 1: Core Functionality Enhancement (High Priority)

#### 1.1 Pipeline Persistence
- [ ] **Save Pipeline to JSON**
  - Serialize pipeline nodes and connections
  - Save to local file system
  - Auto-save functionality
  
- [ ] **Load Pipeline from JSON**
  - Deserialize and restore pipeline state
  - File picker integration
  - Recent files list

- [ ] **Export/Import**
  - Export to shareable format
  - Import from external sources
  - Template library

#### 1.2 Real Docker Execution
- [ ] **Docker Engine Integration**
  - Connect to local Docker daemon
  - Execute containers with parameters
  - Stream container logs to execution panel
  
- [ ] **Container Management**
  - Pull images on-demand
  - Monitor container status
  - Stop/restart containers
  - Resource monitoring (CPU, memory)

- [ ] **Volume Mapping**
  - Configure input/output directories
  - Automatic volume mounting
  - Data persistence between blocks

#### 1.3 Advanced Connection System
- [ ] **Connection Validation**
  - Type checking (data compatibility)
  - Prevent circular dependencies
  - Port compatibility validation
  
- [ ] **Data Flow Visualization**
  - Animated data flow on connections
  - Connection status indicators
  - Data preview on hover

- [ ] **Multiple Connections**
  - Support multiple inputs/outputs per port
  - Connection branching
  - Merge/split operations

### Phase 2: User Experience (Medium Priority)

#### 2.1 Undo/Redo System
- [ ] Command pattern implementation
- [ ] Keyboard shortcuts (Ctrl+Z, Ctrl+Y)
- [ ] History panel
- [ ] Action stack visualization

#### 2.2 Block Templates
- [ ] Pre-configured block templates
- [ ] Custom block creation
- [ ] Template marketplace
- [ ] Block versioning

#### 2.3 Search & Filter
- [ ] Canvas block search
- [ ] Filter by category
- [ ] Quick add menu (Cmd+K)
- [ ] Recent blocks

#### 2.4 Keyboard Shortcuts
- [ ] Delete selected blocks (Delete key)
- [ ] Copy/paste blocks (Ctrl+C/V)
- [ ] Select all (Ctrl+A)
- [ ] Zoom shortcuts (Ctrl+/-)
- [ ] Pan with arrow keys

#### 2.5 Multi-Selection
- [ ] Shift+click for multi-select
- [ ] Drag selection box
- [ ] Group operations
- [ ] Bulk delete/move

### Phase 3: Advanced Features (Medium Priority)

#### 3.1 Pipeline Validation
- [ ] Pre-execution validation
- [ ] Dependency checking
- [ ] Parameter validation
- [ ] Warning/error indicators
- [ ] Validation report

#### 3.2 Execution History
- [ ] Execution log persistence
- [ ] Execution replay
- [ ] Performance metrics
- [ ] Error tracking
- [ ] Execution comparison

#### 3.3 Block Marketplace
- [ ] Community block sharing
- [ ] Block ratings and reviews
- [ ] Installation from marketplace
- [ ] Version management
- [ ] Update notifications

#### 3.4 Collaboration Features
- [ ] Real-time collaboration
- [ ] User cursors
- [ ] Comments on blocks
- [ ] Change tracking
- [ ] Conflict resolution

### Phase 4: Integration & Extensibility (Low Priority)

#### 4.1 API Integration
- [ ] REST API for pipeline management
- [ ] Webhook triggers
- [ ] External service integration
- [ ] OAuth authentication
- [ ] API key management

#### 4.2 Plugin System
- [ ] Plugin architecture
- [ ] Custom block plugins
- [ ] Theme plugins
- [ ] Extension marketplace
- [ ] Plugin SDK

#### 4.3 Cloud Deployment
- [ ] Cloud pipeline execution
- [ ] Remote Docker hosts
- [ ] Kubernetes integration
- [ ] Serverless execution
- [ ] Cost tracking

#### 4.4 Advanced Visualizations
- [ ] Pipeline analytics dashboard
- [ ] Execution timeline
- [ ] Resource usage graphs
- [ ] Performance profiling
- [ ] Custom visualizations

### Phase 5: Enterprise Features (Future)

#### 5.1 Access Control
- [ ] User authentication
- [ ] Role-based permissions
- [ ] Pipeline sharing
- [ ] Organization management
- [ ] Audit logs

#### 5.2 Scheduling
- [ ] Cron-based scheduling
- [ ] Event-driven triggers
- [ ] Conditional execution
- [ ] Retry logic
- [ ] Timeout handling

#### 5.3 Monitoring & Alerts
- [ ] Real-time monitoring
- [ ] Email/Slack notifications
- [ ] Custom alerts
- [ ] SLA tracking
- [ ] Incident management

#### 5.4 Data Lineage
- [ ] Data provenance tracking
- [ ] Version control for data
- [ ] Compliance reporting
- [ ] Data quality metrics
- [ ] Lineage visualization

---

## 🛠️ Technology Stack

### Frontend
- **Flutter** 3.5.3 - Cross-platform UI framework
- **Dart** 3.5.3 - Programming language
- **GetX** 4.7.2 - State management & dependency injection

### Backend Integration
- **Dio** - HTTP client for Docker Hub API
- **HTTP** 1.2.2 - Additional HTTP requests

### Utilities
- **UUID** 4.5.1 - Unique ID generation
- **Vector Math** 2.1.4 - Canvas transformations

### Development
- **Flutter Lints** 4.0.0 - Code quality
- **Flutter Test** - Unit & widget testing

---

## 🎨 Design Philosophy

BioFlow follows modern design principles:

1. **Clarity** - Clear visual hierarchy and intuitive interactions
2. **Consistency** - Uniform design language across all components
3. **Feedback** - Immediate visual feedback for all actions
4. **Efficiency** - Keyboard shortcuts and quick actions
5. **Aesthetics** - Beautiful, professional appearance

### Color Palette

```dart
Primary: #6366F1 (Indigo)
Success: #10B981 (Green)
Error: #EF4444 (Red)
Warning: #F59E0B (Amber)
Processing: #8B5CF6 (Purple)
Background: #F7F8FA (Light Gray)
```

---

## 🤝 Contributing

Contributions are welcome! Here's how you can help:

1. **Report Bugs** - Open an issue with detailed reproduction steps
2. **Suggest Features** - Share your ideas for new features
3. **Submit PRs** - Fix bugs or implement features
4. **Improve Docs** - Help improve documentation
5. **Share Feedback** - Let us know what you think

### Development Workflow

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

---

## 📝 License

This project is licensed under the MIT License - see the LICENSE file for details.

---

## 🙏 Acknowledgments

- Inspired by [n8n.io](https://n8n.io) - Workflow automation platform
- Built with [Flutter](https://flutter.dev)
- Icons from [Material Design](https://material.io/icons)
- Docker integration via [Docker Hub API](https://hub.docker.com)

---

## 📧 Contact

For questions, suggestions, or support, please open an issue on GitHub.

---

<div align="center">

**Made with ❤️ using Flutter**

⭐ Star this repo if you find it useful!

</div>
