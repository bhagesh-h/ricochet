import 'package:archive/archive.dart';
import '../models/pipeline_node.dart';
import 'docker_service.dart';

/// Service to generate a production-ready docker-compose export of a BioFlow pipeline.
class DockerComposeExportService {
  final DockerService _dockerService = DockerService();

  /// Generates the complete zip archive for the docker-compose export
  Future<List<int>> generateExportZip(
      List<PipelineNode> sortedNodes, List<Connection> connections) async {
    final archive = Archive();
    final timestamp =
        DateTime.now().toIso8601String().replaceAll(':', '-').split('.')[0];
    final folderName = 'bioflow-export_$timestamp';

    // 1. Generate docker-compose.yml
    final composeYaml = await _generateDockerComposeYaml(sortedNodes, connections);
    archive.addFile(ArchiveFile('$folderName/docker-compose.yml', composeYaml.length, composeYaml.codeUnits));

    // 2. Generate pipeline_config.env
    final envContent = _generateEnvFile(sortedNodes);
    archive.addFile(ArchiveFile('$folderName/pipeline_config.env', envContent.length, envContent.codeUnits));

    // 3. Generate README.md
    final readmeContent = _generateReadme(sortedNodes);
    archive.addFile(ArchiveFile('$folderName/README.md', readmeContent.length, readmeContent.codeUnits));

    // 4. Create empty directories (Archive handles this by ending with /)
    // Add dummy files to ensure directories are created when extracted
    archive.addFile(ArchiveFile('$folderName/raw_data/.gitkeep', 0, []));
    archive.addFile(ArchiveFile('$folderName/results/.gitkeep', 0, []));

    // Encode to ZIP
    final zipEncoder = ZipEncoder();
    final zipData = zipEncoder.encode(archive);
    return zipData;
  }

  /// Extracts the specific Docker command from a node's parameters
  String _getNodeCommand(PipelineNode node) {
    // Look for a custom command override
    final cmdParam = node.parameters.firstWhere(
        (p) => p.key == 'docker_command' || p.key == 'command',
        orElse: () => BlockParameter(key: 'cmd', label: 'cmd', type: ParameterType.text, value: ''));
        
    if (cmdParam.value != null && cmdParam.value.toString().isNotEmpty) {
      return cmdParam.value.toString();
    }
    
    // Fallback: If no explicit command is set, just return empty string 
    // and rely on container's default Entrypoint
    return '';
  }

  String _slugify(String text) {
    return text.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_').trim();
  }

  Future<String> _generateDockerComposeYaml(
      List<PipelineNode> sortedNodes, List<Connection> connections) async {
        
    final bool needsEmulation = await _dockerService.needsPlatformEmulation();
        
    final buffer = StringBuffer();
    buffer.writeln('version: "3.8"');
    buffer.writeln('services:');

    // Build incoming connections map
    final Map<String, List<Connection>> incomingDeps = {};
    for (var conn in connections) {
      if (!incomingDeps.containsKey(conn.toNodeId)) {
        incomingDeps[conn.toNodeId] = [];
      }
      incomingDeps[conn.toNodeId]!.add(conn);
    }

    final Map<String, String> nodeSlugMap = {};
    for (var node in sortedNodes) {
      final baseSlug = _slugify(node.title);
      // Ensure unique slugs
      String slug = baseSlug;
      int counter = 1;
      while (nodeSlugMap.containsValue(slug)) {
        slug = '${baseSlug}_$counter';
        counter++;
      }
      nodeSlugMap[node.id] = slug;
    }

    for (var node in sortedNodes) {
      final slug = nodeSlugMap[node.id]!;
      buffer.writeln('  $slug:');
      buffer.writeln('    image: ${node.dockerImage ?? "alpine:latest"}');
      buffer.writeln('    container_name: $slug');
      
      if (needsEmulation) {
        final platformInfo = await _dockerService.getPlatformInfo();
        buffer.writeln('    platform: ${platformInfo.dockerPlatformFlag}');
      }
      
      buffer.writeln('    user: "\${UID}:\${GID}"');
      buffer.writeln('    volumes:');
      buffer.writeln('      - ./raw_data:/input:ro');
      buffer.writeln('      - ./results:/output');

      // Depends On
      final deps = incomingDeps[node.id] ?? [];
      if (deps.isNotEmpty) {
        buffer.writeln('    depends_on:');
        for (var dep in deps) {
          final upstreamNode = sortedNodes.firstWhere((n) => n.id == dep.fromNodeId);
          final upstreamSlug = nodeSlugMap[upstreamNode.id];
          buffer.writeln('      $upstreamSlug:');
          buffer.writeln('        condition: service_completed_successfully');
        }
      }

      // Environment Variables (Data Flow)
      final envVars = <String>[];
      if (deps.length == 1) {
        final upstreamNode = sortedNodes.firstWhere((n) => n.id == deps.first.fromNodeId);
        final ext = upstreamNode.outputFileName ?? '\${${_slugify(upstreamNode.title).toUpperCase()}_EXT:-txt}';
        final outName = upstreamNode.outputFileName ?? '${nodeSlugMap[upstreamNode.id]}_output.$ext';
        envVars.add('INPUT_FILE=/output/$outName');
      } else if (deps.length > 1) {
        for (int i = 0; i < deps.length; i++) {
          final upstreamNode = sortedNodes.firstWhere((n) => n.id == deps[i].fromNodeId);
          final outName = upstreamNode.outputFileName ?? '${nodeSlugMap[upstreamNode.id]}_output.\${${_slugify(upstreamNode.title).toUpperCase()}_EXT:-txt}';
          envVars.add('INPUT_FILE_${i + 1}=/output/$outName');
        }
      }

      // Output File Name exposed to env
      if (node.outputFileName != null) {
        envVars.add('OUTPUT_FILE=/output/${node.outputFileName}');
      }

      // Custom parameters passed as ENV
      for (var param in node.parameters) {
        if (param.key != 'command' && param.key != 'docker_command' && param.value != null) {
          final envKey = param.key.toUpperCase();
          envVars.add('$envKey=\${$envKey:-${param.value}}');
        }
      }

      if (envVars.isNotEmpty) {
        buffer.writeln('    environment:');
        for (var env in envVars) {
          // Careful with quotes for complex expressions
          buffer.writeln('      - "$env"');
        }
      }

      // Ports (Aggregator)
      if (node.isAggregator) {
        buffer.writeln('    ports:');
        buffer.writeln('      - "8080:8080"');
      }

      // Command
      String command = _getNodeCommand(node);
      if (node.isAggregator) {
        if (command.isNotEmpty) command += ' && ';
        command += 'python3 -m http.server 8080 --directory /output';
      }
      
      if (command.isNotEmpty) {
        // We use sh -c to ensure environment variables are evaluated in the container shell
        // Using > to represent folded scalar in YAML for multiline commands
        buffer.writeln('    command: >');
        buffer.writeln('      sh -c "$command"');
      }
      
      buffer.writeln('');
    }

    return buffer.toString();
  }

  String _generateEnvFile(List<PipelineNode> sortedNodes) {
    final buffer = StringBuffer();
    buffer.writeln('# BioFlow Pipeline Configuration Environment Variables');
    buffer.writeln('# These overrides will be injected into your docker-compose services.');
    buffer.writeln('');
    buffer.writeln('UID=1000 # Change to your user ID');
    buffer.writeln('GID=1000 # Change to your group ID');
    buffer.writeln('');

    for (var node in sortedNodes) {
      buffer.writeln('# --- ${node.title} Settings ---');
      for (var param in node.parameters) {
        if (param.key != 'command' && param.key != 'docker_command' && param.value != null) {
          final envKey = param.key.toUpperCase();
          buffer.writeln('$envKey=${param.value}');
        }
      }
      buffer.writeln('');
    }

    return buffer.toString();
  }

  String _generateReadme(List<PipelineNode> sortedNodes) {
    // Generate identical template as requested
    final buffer = StringBuffer();
    
    buffer.writeln('# BioFlow Pipeline: bioflow_pipeline');
    buffer.writeln('');
    buffer.writeln('This folder contains a fully reproducible, production-ready bioinformatics pipeline generated by BioFlow.');
    buffer.writeln('');
    buffer.writeln('## 📁 Directory Structure');
    buffer.writeln('```');
    buffer.writeln('bioflow-export/');
    buffer.writeln('├── docker-compose.yml       ← The pipeline definition');
    buffer.writeln('├── pipeline_config.env      ← Customizable parameters');
    buffer.writeln('├── README.md                ← This documentation');
    buffer.writeln('├── raw_data/                ← Place your input files here');
    buffer.writeln('└── results/                 ← Output files will appear here');
    buffer.writeln('```');
    buffer.writeln('');
    
    buffer.writeln('## Complete Bioinformatics Pipeline Example');
    buffer.writeln('');
    buffer.writeln('This pipeline includes the following services, executed in exact topological order:');
    for (var i = 0; i < sortedNodes.length; i++) {
      buffer.writeln('${i + 1}. **${_slugify(sortedNodes[i].title)}** (image: `${sortedNodes[i].dockerImage ?? "alpine:latest"}`)');
    }
    buffer.writeln('');
    
    buffer.writeln('## How to run your BioFlow pipeline');
    buffer.writeln('');
    buffer.writeln('### 1. Identify Input Files');
    buffer.writeln('Place any starting data (FASTA, FASTQ, BAM, CSV) directly into the `raw_data/` folder. The first node(s) in your pipeline will access these files at `/input/`.');
    buffer.writeln('');
    buffer.writeln('### 2. Configure Environment (Optional)');
    buffer.writeln('Check `pipeline_config.env` to tune threads, quality scores, and other block parameters.');
    buffer.writeln('');
    
    buffer.writeln('### 3. Run the complete pipeline');
    buffer.writeln('```bash');
    buffer.writeln('docker compose up --build');
    buffer.writeln('```');
    buffer.writeln('To run in the background without locking your terminal:');
    buffer.writeln('```bash');
    buffer.writeln('docker compose up -d');
    buffer.writeln('```');
    buffer.writeln('');
    
    buffer.writeln('## Cheat Sheet: Docker Compose Lifecycle');
    buffer.writeln('```bash');
    buffer.writeln('# View live logs of all nodes:');
    buffer.writeln('docker compose logs -f');
    buffer.writeln('');
    buffer.writeln('# View logs for a specific node:');
    buffer.writeln('docker compose logs -f ${_slugify(sortedNodes.first.title)}');
    buffer.writeln('');
    buffer.writeln('# Stop a running pipeline:');
    buffer.writeln('docker compose stop');
    buffer.writeln('');
    buffer.writeln('# Completely remove containers (keeps results/ data intact):');
    buffer.writeln('docker compose down');
    buffer.writeln('```');
    buffer.writeln('');
    
    buffer.writeln('## Cheat Sheet: Resource Flags');
    buffer.writeln('If your tools are OOM (Out of Memory) crashing, you can constrain limits directly in the docker-compose.yml `deploy` section, or run with inline overrides if supported by your docker daemon.');
    buffer.writeln('');
    
    buffer.writeln('## Cheat Sheet: Running Specific Tools');
    buffer.writeln('If you want to re-run only ONE step without re-running the entire pipeline, use the `run` command instead of `up`. Notice the depends_on condition is ignored this way.');
    buffer.writeln('```bash');
    buffer.writeln('docker compose run --rm ${_slugify(sortedNodes.first.title)}');
    buffer.writeln('```');
    buffer.writeln('');
    
    buffer.writeln('## Cheat Sheet: Docker Swarm');
    buffer.writeln('To deploy this across a multi-node cluster (HPC):');
    buffer.writeln('```bash');
    buffer.writeln('docker stack deploy -c docker-compose.yml bioflow_pipeline');
    buffer.writeln('```');
    buffer.writeln('');
    
    buffer.writeln('## Common Bio-Patterns & Fixes');
    buffer.writeln('1. **Permission Denied in Results**: If your outputs are locked by `root`, ensure the `UID` and `GID` inside `pipeline_config.env` match your host user. (Find them via `id -u` and `id -g`).');
    buffer.writeln('2. **Multiple Inputs**: Nodes receiving multiple connections use `\$INPUT_FILE_1`, `\$INPUT_FILE_2`, etc., corresponding to the chronological order the connections were made.');
    buffer.writeln('3. **Aggregator Nodes**: If the last node is marked as an aggregator, it automatically starts a local web server binding to port 8080. Open `http://localhost:8080` to view results directly in your browser.');

    return buffer.toString();
  }
}
