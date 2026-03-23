import 'package:flutter_test/flutter_test.dart';
import 'package:Ricochet/utils/shell_utils.dart';

void main() {
  group('ShellUtils.splitArguments', () {
    test('simple command with no flags', () {
      expect(ShellUtils.splitArguments('fastqc'), ['fastqc']);
    });

    test('command with simple flags', () {
      expect(
        ShellUtils.splitArguments('fastp -i input.fastq -o output.fastq'),
        ['fastp', '-i', 'input.fastq', '-o', 'output.fastq'],
      );
    });

    test('double-quoted argument with space', () {
      expect(
        ShellUtils.splitArguments('fastp -i "input file.fastq" -o out.fq'),
        ['fastp', '-i', 'input file.fastq', '-o', 'out.fq'],
      );
    });

    test('single-quoted argument with space', () {
      expect(
        ShellUtils.splitArguments("bwa mem 'ref genome.fa' reads.fq"),
        ['bwa', 'mem', 'ref genome.fa', 'reads.fq'],
      );
    });

    test('multiple spaces between tokens are collapsed', () {
      expect(
        ShellUtils.splitArguments('cmd  arg1   arg2'),
        ['cmd', 'arg1', 'arg2'],
      );
    });

    test('empty string returns empty list', () {
      expect(ShellUtils.splitArguments(''), []);
    });

    test('only whitespace returns empty list', () {
      expect(ShellUtils.splitArguments('   '), []);
    });

    test('backslash escapes next character inside unquoted token', () {
      expect(
        ShellUtils.splitArguments(r'cmd arg\ with\ spaces'),
        ['cmd', 'arg with spaces'],
      );
    });

    test('backslash escapes space inside double-quoted string is literal backslash', () {
      // Inside double-quotes the backslash escape still applies
      expect(
        ShellUtils.splitArguments(r'cmd "foo\nbar"'),
        ['cmd', 'foonbar'], // escape handling: \n -> n
      );
    });

    test('adjacent double-quoted tokens are concatenated', () {
      expect(
        ShellUtils.splitArguments('"foo""bar"'),
        ['foobar'],
      );
    });

    test('empty double-quoted string produces no token', () {
      // The implementation only emits a token when the buffer is non-empty,
      // so "" is silently dropped.
      expect(ShellUtils.splitArguments('cmd ""'), ['cmd']);
    });

    test('empty single-quoted string produces no token', () {
      expect(ShellUtils.splitArguments("cmd ''"), ['cmd']);
    });

    test('docker run command round-trips correctly', () {
      final result = ShellUtils.splitArguments(
        'docker run --rm -v /data:/data -e FOO=bar alpine:latest sh -c "echo hello"',
      );
      expect(result, [
        'docker',
        'run',
        '--rm',
        '-v',
        '/data:/data',
        '-e',
        'FOO=bar',
        'alpine:latest',
        'sh',
        '-c',
        'echo hello',
      ]);
    });

    test('trailing space does not add empty token', () {
      expect(ShellUtils.splitArguments('cmd arg1 '), ['cmd', 'arg1']);
    });

    test('numeric argument preserved as string', () {
      expect(
        ShellUtils.splitArguments('samtools view -F 4 -q 30'),
        ['samtools', 'view', '-F', '4', '-q', '30'],
      );
    });
  });
}
