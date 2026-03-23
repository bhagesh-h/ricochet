/// Versioned failure scenario used across all service and orchestrator tests.
///
/// Each [FailureScenario] has a stable [id] (e.g. `"docker_not_installed_v1"`).
/// Adding a new behaviour variant means minting a **new** id — existing ids are
/// never mutated.  Tests that reference a scenario by id are therefore never
/// silently broken by future matrix changes.
class FailureScenario {
  /// Stable, immutable identifier for this scenario.
  final String id;

  /// Human-readable description for test output.
  final String description;

  /// Pre-configured [ProcessStub] entries to register with [FakeProcessRunner].
  final List<ProcessStub> processStubs;

  /// The expected outcome when this scenario is exercised.
  final ExpectedOutcome expected;

  const FailureScenario({
    required this.id,
    required this.description,
    required this.processStubs,
    required this.expected,
  });
}

/// A single stubbed subprocess call.
class ProcessStub {
  final String executable;
  final List<String> arguments;
  final int exitCode;
  final String stdout;
  final String stderr;
  final Duration? delay;
  final bool sigtermIgnored;
  final Duration? hangDuration;

  const ProcessStub({
    required this.executable,
    this.arguments = const [],
    this.exitCode = 1,
    this.stdout = '',
    this.stderr = '',
    this.delay,
    this.sigtermIgnored = false,
    this.hangDuration,
  });
}

/// Describes what a test should assert after exercising a [FailureScenario].
class ExpectedOutcome {
  /// The exception type name, if any (e.g. `'TimeoutException'`).
  final String? exceptionType;

  /// Human-readable message the caller should surface (substring match allowed
  /// only in the [ExpectedOutcome] layer, never in the test body itself).
  final String? messageContains;

  /// Expected [DockerStatus] name if applicable.
  final String? dockerStatusName;

  /// Whether the pipeline should be considered failed.
  final bool pipelineFailed;

  const ExpectedOutcome({
    this.exceptionType,
    this.messageContains,
    this.dockerStatusName,
    this.pipelineFailed = false,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// v1 Failure Injection Matrix
// ─────────────────────────────────────────────────────────────────────────────

/// The canonical v1 set of failure scenarios.  Import this constant in tests.
const List<FailureScenario> kFailureMatrixV1 = [
  _dockerNotInstalled,
  _imagePullFails,
  _processTimeout,
  _invalidFastqInput,
  _malformedComposeYaml,
  _workspaceUnwritable,
  _cyclicPipelineGraph,
  _zeroPipelineNodes,
];

/// Look up a scenario by id — throws if not found, keeping tests honest.
FailureScenario scenarioById(String id) {
  return kFailureMatrixV1.firstWhere(
    (s) => s.id == id,
    orElse: () => throw ArgumentError('No FailureScenario with id "$id"'),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Scenario definitions
// ─────────────────────────────────────────────────────────────────────────────

const _dockerNotInstalled = FailureScenario(
  id: 'docker_not_installed_v1',
  description: 'Docker executable is not present on PATH',
  processStubs: [
    // All known docker paths fail.
    ProcessStub(executable: 'docker', arguments: ['--version'], exitCode: 127),
    ProcessStub(executable: '/usr/local/bin/docker', arguments: ['--version'], exitCode: 127),
    ProcessStub(executable: '/opt/homebrew/bin/docker', arguments: ['--version'], exitCode: 127),
    ProcessStub(executable: '/usr/bin/docker', arguments: ['--version'], exitCode: 127),
  ],
  expected: ExpectedOutcome(
    dockerStatusName: 'notInstalled',
    messageContains: 'not found',
    pipelineFailed: true,
  ),
);

const _imagePullFails = FailureScenario(
  id: 'image_pull_fails_mid_layer_v1',
  description: 'Docker pull fails partway through a layer download',
  processStubs: [
    // Docker is installed and running.
    ProcessStub(executable: 'docker', arguments: ['--version'], exitCode: 0, stdout: 'Docker version 24.0.6'),
    ProcessStub(
      executable: 'docker',
      arguments: ['pull', 'staphb/fastqc:latest'],
      exitCode: 1,
      stderr: 'error pulling image manifest: unexpected EOF',
    ),
  ],
  expected: ExpectedOutcome(
    exceptionType: 'DockerPullException',
    messageContains: 'pull',
    pipelineFailed: true,
  ),
);

const _processTimeout = FailureScenario(
  id: 'process_timeout_v1',
  description: 'A subprocess exceeds its allowed timeout',
  processStubs: [
    ProcessStub(
      executable: 'docker',
      arguments: ['run', '--rm', 'staphb/fastqc:latest'],
      exitCode: -1,
      hangDuration: Duration(hours: 1), // effectively infinite
    ),
  ],
  expected: ExpectedOutcome(
    exceptionType: 'TimeoutException',
    messageContains: 'timeout',
    pipelineFailed: true,
  ),
);

const _invalidFastqInput = FailureScenario(
  id: 'invalid_fastq_input_v1',
  description: 'Input file has wrong format or does not exist',
  processStubs: [],
  expected: ExpectedOutcome(
    exceptionType: 'ValidationException',
    messageContains: 'input',
    pipelineFailed: true,
  ),
);

const _malformedComposeYaml = FailureScenario(
  id: 'malformed_compose_yaml_v1',
  description: 'docker-compose.yml generation produces invalid YAML',
  processStubs: [],
  expected: ExpectedOutcome(
    exceptionType: 'FormatException',
    messageContains: 'yaml',
    pipelineFailed: true,
  ),
);

const _workspaceUnwritable = FailureScenario(
  id: 'workspace_unwritable_v1',
  description: 'Run directory cannot be created due to permissions',
  processStubs: [],
  expected: ExpectedOutcome(
    exceptionType: 'FileSystemException',
    messageContains: 'permission',
    pipelineFailed: true,
  ),
);

const _cyclicPipelineGraph = FailureScenario(
  id: 'cyclic_pipeline_graph_v1',
  description: 'Pipeline contains a dependency cycle',
  processStubs: [],
  expected: ExpectedOutcome(
    exceptionType: 'CycleDetectedException',
    messageContains: 'cycle',
    pipelineFailed: true,
  ),
);

const _zeroPipelineNodes = FailureScenario(
  id: 'zero_pipeline_nodes_v1',
  description: 'Pipeline canvas is empty — no nodes to execute',
  processStubs: [],
  expected: ExpectedOutcome(
    exceptionType: 'ValidationException',
    messageContains: 'empty',
    pipelineFailed: true,
  ),
);
