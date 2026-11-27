#!/bin/bash
set -uo pipefail
ulimit -c 0

fail() {
    printf '%s\n' '>>>>> Tests Errored' "$1" >&2
    exit 2
}

cd /testbed || fail 'Cannot enter /testbed'
[[ "$(git rev-parse HEAD)" == "71a134bce58a22fb17a7a14f00799196c0c71a60" ]] || fail 'Unexpected Base commit'
git apply --whitespace=nowarn - <<'CLB_TEST_PATCH' || fail 'Test patch application failed'
diff --git a/benchmark-tests/org/newsclub/net/unix/NoexecProbe.java b/benchmark-tests/org/newsclub/net/unix/NoexecProbe.java
new file mode 100644
--- /dev/null
+++ b/benchmark-tests/org/newsclub/net/unix/NoexecProbe.java
@@ -0,0 +1,82 @@
+package org.newsclub.net.unix;
+
+import java.io.DataInputStream;
+import java.io.DataOutputStream;
+import java.io.File;
+import java.nio.charset.StandardCharsets;
+import java.nio.file.Files;
+import java.nio.file.Path;
+import java.nio.file.Paths;
+import java.util.LinkedHashSet;
+import java.util.Set;
+
+/** Uses the unchanged automatic loader and real AF_UNIX sockets. */
+public final class NoexecProbe {
+  public static void main(String[] args) throws Exception {
+    System.out.println("JAVA=" + System.getProperty("java.version"));
+    System.out.println("LOADER_ORIGIN=" + NativeLibraryLoader.class.getProtectionDomain()
+        .getCodeSource().getLocation());
+    for (String directory : new String[] {System.getProperty("java.io.tmpdir"), System.getProperty("user.home"), System.getProperty("user.dir")}) {
+      Path test = Files.createTempFile(Paths.get(directory), "writable-", ".txt");
+      try {
+        Files.write(test, new byte[] {1, 2, 3});
+        if (Files.readAllBytes(test).length != 3) {
+          throw new AssertionError("File I/O control failed");
+        }
+      } finally {
+        Files.delete(test);
+      }
+      System.out.println("WRITABLE=" + directory);
+    }
+    for (String line : Files.readAllLines(Paths.get("/proc/self/mountinfo"), StandardCharsets.UTF_8)) {
+      String[] columns = line.split(" ");
+      if (columns.length > 5 && (columns[4].equals("/case-noexec") || columns[4].equals("/case-exec"))) {
+        System.out.println("MOUNT=" + columns[4] + " " + columns[5]);
+      }
+    }
+    System.out.println("BEFORE_SOCKET");
+    for (int iteration = 0; iteration < 3; iteration++) {
+      File file = File.createTempFile("case170-", ".sock", new File(System.getProperty("user.dir")));
+      if (!file.delete()) {
+        throw new AssertionError("Could not prepare socket pathname");
+      }
+      AFUNIXSocketAddress address = AFUNIXSocketAddress.of(file);
+      try (AFUNIXServerSocket server = AFUNIXServerSocket.bindOn(address)) {
+        server.setSoTimeout(3000);
+        try (AFUNIXSocket client = AFUNIXSocket.connectTo(address);
+             AFUNIXSocket accepted = server.accept()) {
+          client.setSoTimeout(3000);
+          accepted.setSoTimeout(3000);
+          int value = 0x17014000 + iteration;
+          new DataOutputStream(client.getOutputStream()).writeInt(value);
+          if (new DataInputStream(accepted.getInputStream()).readInt() != value) {
+            throw new AssertionError("Request payload mismatch");
+          }
+          new DataOutputStream(accepted.getOutputStream()).writeInt(~value);
+          if (new DataInputStream(client.getInputStream()).readInt() != ~value) {
+            throw new AssertionError("Response payload mismatch");
+          }
+        }
+      } finally {
+        if (file.exists() && !file.delete()) {
+          throw new AssertionError("Socket cleanup failed");
+        }
+      }
+      System.out.println("ROUNDTRIP_OK=" + iteration);
+    }
+    Set<String> mapped = new LinkedHashSet<String>();
+    for (String line : Files.readAllLines(Paths.get("/proc/self/maps"), StandardCharsets.UTF_8)) {
+      if (line.contains("junixsocket-native") && line.contains(".so")) {
+        String[] columns = line.split("\\s+", 6);
+        mapped.add(columns[5]);
+      }
+    }
+    for (String path : mapped) {
+      System.out.println("NATIVE_MAPPING=" + path);
+    }
+    if (mapped.isEmpty()) {
+      throw new AssertionError("No real native library mapping found");
+    }
+    System.out.println("NOEXEC_PROBE_OK");
+  }
+}
CLB_TEST_PATCH

mkdir -p /benchmark || fail 'Cannot create evaluation fixture directory'
cat > /benchmark/case_adapter.sh <<'EOF_e3f9d8ba93b3' || fail 'Cannot write /benchmark/case_adapter.sh'
#!/usr/bin/env bash
build_project() {
    python3 /benchmark/build_project.py
}
run_project_tests() {
    python3 /benchmark/run_case_tests.py
}
EOF_e3f9d8ba93b3
cat > /benchmark/build_project.py <<'EOF_fff07b8b2b4e' || fail 'Cannot write /benchmark/build_project.py'
"""Compile the candidate core Java 8 sources against a pinned released JNI fixture."""
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess

ROOT = Path('/testbed')
OUT = ROOT / 'target/case170'
MANIFEST = json.loads(Path('/benchmark/upstream_tests.json').read_text())
for name, expected in MANIFEST['source_sha256'].items():
    p = ROOT / name
    if not p.is_file() or hashlib.sha256(p.read_bytes()).hexdigest() != expected:
        raise SystemExit('protected_upstream_test_modified: ' + name)

def run(args):
    print('BUILD_ARGV=' + json.dumps([str(x) for x in args]), flush=True)
    subprocess.run([str(x) for x in args], cwd=str(ROOT), check=True)

classes = OUT / 'classes'
tests = OUT / 'testclasses'
classes.mkdir(parents=True, exist_ok=True)
tests.mkdir(parents=True, exist_ok=True)
source_root = ROOT / 'junixsocket-common/src'
sources = {}
# Upstream javaN folders contain compatibility replacements for JDK <= N.
# Apply the Java 15 stub before the Java 8 replacements, as the multi-release build does.
for layer in ('java', 'java15', 'java8', 'java7'):
    folder = source_root / 'main' / layer
    for p in sorted(folder.rglob('*.java')):
        if p.name != 'module-info.java':
            sources[p.relative_to(folder).as_posix()] = p
template = source_root / 'main/java-unresolved-properties/org/newsclub/net/unix/BuildProperties.java'
generated = OUT / 'generated/org/newsclub/net/unix/BuildProperties.java'
generated.parent.mkdir(parents=True, exist_ok=True)
text = template.read_text(encoding='utf-8')
version = re.search(r'<version>([^<]+)</version>', (ROOT / 'pom.xml').read_text(encoding='utf-8')).group(1)
values = {'project.version': version, 'git.build.version': version,
          'git.commit.id.abbrev': '71a134b', 'git.commit.id.full':
          '71a134bce58a22fb17a7a14f00799196c0c71a60', 'git.commit.time': '2023-09-29', 'git.dirty': 'true'}
for name, value in values.items():
    text = text.replace('${' + name + '}', value)
generated.write_text(text, encoding='utf-8')
sources['org/newsclub/net/unix/BuildProperties.java'] = generated
deps = ':'.join(str(p) for p in sorted(Path('/opt/deps').glob('*.jar')))
run(['javac', '-encoding', 'UTF-8', '-source', '8', '-target', '8', '-cp', deps,
     '-d', classes] + list(sources.values()))
resources = source_root / 'main/resources'
if resources.exists():
    shutil.copytree(resources, classes, dirs_exist_ok=True)
test_sources = {}
for layer in ('java', 'java15', 'java8'):
    folder = source_root / 'test' / layer
    for p in sorted(folder.rglob('*.java')):
        if p.name != 'module-info.java':
            test_sources[p.relative_to(folder).as_posix()] = p
test_sources['org/newsclub/net/unix/NoexecProbe.java'] = ROOT / 'benchmark-tests/org/newsclub/net/unix/NoexecProbe.java'
run(['javac', '-encoding', 'UTF-8', '-source', '8', '-target', '8', '-cp', str(classes) + ':' + deps,
     '-d', tests] + list(test_sources.values()))
print('BUILD_COMPLETE core_java_sources={} test_java_sources={} native_fixture=2.8.0'.format(
      len(sources), len(test_sources)), flush=True)
EOF_fff07b8b2b4e
cat > /benchmark/format_test_log.py <<'EOF_8a58ff4098c6' || fail 'Cannot write /benchmark/format_test_log.py'
"""Convert test results to the SWE-bench status-first log format."""

import io
import re
import sys

TEST_LINE = re.compile(
    r"^(?P<method>\S+) \((?P<class>[^)]+)\) \.\.\. "
    r"(?P<status>ok|FAIL|ERROR|skipped(?: .*)?)$"
)

TEST_START_LINE = re.compile(r"^(?P<method>\S+) \((?P<class>[^)]+)\) \.\.\. .*")

def normalize_status(raw_status):
    if raw_status == "ok":
        return "PASSED"
    if raw_status == "FAIL":
        return "FAILED"
    if raw_status == "ERROR":
        return "ERROR"
    if raw_status.startswith("skipped"):
        return "SKIPPED"
    return "UNKNOWN"

def parse_test_log(text):
    statuses = {}
    pending = None
    for raw_line in text.splitlines():
        line = raw_line.strip()
        match = TEST_LINE.match(line)
        if not match:
            if pending and (line in ("ok", "FAIL", "ERROR") or line.startswith("skipped")):
                statuses[pending] = normalize_status(line)
                pending = None
                continue
            start = TEST_START_LINE.match(line)
            if start:
                pending = "{}.{}".format(start.group("class"), start.group("method"))
            continue
        test_id = "{}.{}".format(match.group("class"), match.group("method"))
        statuses[test_id] = normalize_status(match.group("status"))
    return statuses


if __name__ == '__main__':
    with io.open(sys.argv[1], encoding='utf-8', errors='replace') as log:
        statuses = parse_test_log(log.read())
    for test_id, status in sorted(statuses.items()):
        # The upstream parser represents missing results by omitting the node.
        if status in ('PASSED', 'FAILED', 'ERROR', 'SKIPPED'):
            print(u'{} {}'.format(status, test_id))
EOF_8a58ff4098c6
cat > /benchmark/run_case_tests.py <<'EOF_52cbf03c2596' || fail 'Cannot write /benchmark/run_case_tests.py'
"""Run fresh-JVM noexec integration cases and unchanged, frozen upstream JUnit cases."""
import argparse
import json
from pathlib import Path
import subprocess
import sys
import xml.etree.ElementTree as ET

ROOT = Path('/testbed')
OUT = ROOT / 'target/case170'
RESULT = Path('/results')
MANIFEST = json.loads(Path('/benchmark/upstream_tests.json').read_text())
parser = argparse.ArgumentParser()
parser.add_argument('--discover', action='store_true')
args = parser.parse_args()
RESULT.mkdir(parents=True, exist_ok=True)
deps = ':'.join(str(p) for p in sorted(Path('/opt/deps').glob('*.jar')))
cp = str(OUT / 'classes') + ':' + str(OUT / 'testclasses') + ':' + deps
java = ['java', '-Xmx128m', '-XX:+UseSerialGC', '-XX:ActiveProcessorCount=2']
statuses = {}

def invoke(argv, name, cwd=ROOT, timeout=90):
    try:
        result = subprocess.run([str(x) for x in argv], cwd=str(cwd), stdout=subprocess.PIPE,
                                stderr=subprocess.STDOUT, timeout=timeout)
        text = result.stdout.decode('utf-8', errors='replace')
        code = result.returncode
    except subprocess.TimeoutExpired as error:
        text = (error.stdout or b'').decode('utf-8', errors='replace') + '\nBENCHMARK_TIMEOUT\n'
        code = None
    (RESULT / (name + '.raw.log')).write_text(text, encoding='utf-8')
    (RESULT / (name + '.json')).write_text(json.dumps({'command': [str(x) for x in argv],
              'cwd': str(cwd), 'exit_code': code, 'timeout': code is None}, indent=2) + '\n')
    return code, text

if not args.discover:
    for name, flags, positive, expected in (
            ('exec_loading', (False, False, False), True, 0),
            ('noexec_home_fallback', (True, False, False), True, 1),
            ('noexec_cwd_fallback', (True, True, False), True, 2),
            ('all_noexec_rejected', (True, True, True), False, None)):
        paths = []
        for index, blocked in enumerate(flags):
            path = Path('/case-noexec' if blocked else '/case-exec') / (name + str(index))
            path.mkdir()
            paths.append(path)
        command = java + ['-Djava.io.tmpdir=' + str(paths[0]),
                         '-Dorg.newsclub.net.unix.library.tmpdir=' + str(paths[0]),
                         '-Duser.home=' + str(paths[1]), '-Duser.dir=' + str(paths[2]),
                         '-cp', cp, 'org.newsclub.net.unix.NoexecProbe']
        code, text = invoke(command, name, cwd=paths[2], timeout=30)
        try:
            assert code is not None, 'child JVM timeout'
            assert 'LOADER_ORIGIN=file:/testbed/target/case170/classes/' in text, 'candidate class origin missing'
            for path in paths:
                assert 'WRITABLE=' + str(path) + '\n' in text, 'write/read control failed'
            mounts = dict(line[6:].split(' ', 1) for line in text.splitlines() if line.startswith('MOUNT='))
            assert 'noexec' in mounts['/case-noexec'].split(','), 'real noexec mount missing'
            assert 'noexec' not in mounts['/case-exec'].split(','), 'exec mount unexpectedly blocked'
            if positive:
                assert code == 0, 'native initialization failed (see child raw log)'
                assert text.count('NOEXEC_PROBE_OK\n') == 1, 'success marker missing'
                for i in range(3):
                    assert text.count('ROUNDTRIP_OK=' + str(i) + '\n') == 1, 'native roundtrip missing'
                mappings = [line[15:] for line in text.splitlines() if line.startswith('NATIVE_MAPPING=')]
                assert mappings and all(line.startswith(str(paths[expected]) + '/') for line in mappings), 'incorrect library extraction/mapping path'
            else:
                assert code == 1 and 'NOEXEC_PROBE_OK' not in text, 'all-blocked path falsely succeeded'
                failures = [line for line in text.splitlines() if 'UnsatisfiedLinkError' in line and 'failed to map segment from shared object' in line]
                assert failures, 'missing real noexec System.load failure'
                assert all('perm' not in line.lower() for line in failures), 'wrong error-message trigger'
            statuses['benchmark.noexec.' + name] = 'PASSED'
        except (AssertionError, KeyError) as error:
            statuses['benchmark.noexec.' + name] = 'FAILED'
            (RESULT / (name + '.assertion.log')).write_text(str(error) + '\n')

reports = RESULT / 'junit'
command = java + ['-jar', '/opt/deps/junit-platform-console-standalone-1.10.0.jar', 'execute',
                  '--disable-ansi-colors', '--details=summary', '--class-path', cp,
                  '--reports-dir', str(reports)]
for name in MANIFEST['selected_classes']:
    command += ['--select-class', name]
code, text = invoke(command, 'upstream-junit', timeout=240)
observed = {}
duplicates = []
for path in sorted(reports.glob('TEST-junit-jupiter.xml')):
    for node in ET.parse(str(path)).getroot().iter('testcase'):
        test_id = node.attrib['classname'] + '.' + node.attrib['name']
        if test_id in observed:
            duplicates.append(test_id)
        status = 'SKIPPED' if node.find('skipped') is not None else (
                 'FAILED' if node.find('failure') is not None or node.find('error') is not None else 'PASSED')
        observed[test_id] = status
(RESULT / 'upstream_observed.json').write_text(json.dumps(observed, indent=2) + '\n')
if args.discover:
    print(json.dumps({'exit_code': code, 'observed': observed, 'duplicates': duplicates}, indent=2))
    sys.exit(0 if code == 0 and observed and not duplicates else 1)
expected = set(MANIFEST['test_ids'])
valid = (code == 0 or code == 1) and not duplicates and set(observed) == expected and bool(expected)
for test_id in sorted(expected):
    statuses[test_id] = observed.get(test_id, 'MISSING') if valid else 'FAILED'
if not valid:
    (RESULT / 'upstream_structure_error.json').write_text(json.dumps({'expected': sorted(expected),
                'observed': sorted(observed), 'duplicates': duplicates, 'exit_code': code}, indent=2))
for test_id, status in sorted(statuses.items()):
    cls, method = test_id.rsplit('.', 1)
    print('{} ({}) ... {}'.format(method, cls, 'ok' if status == 'PASSED' else 'FAIL'), flush=True)
sys.exit(0 if valid and all(value == 'PASSED' for value in statuses.values()) else 1)
EOF_52cbf03c2596
cat > /benchmark/upstream_tests.json <<'EOF_fbf6eeb7abbc' || fail 'Cannot write /benchmark/upstream_tests.json'
{
  "source_sha256": {
    "junixsocket-common/src/test/java/org/newsclub/net/unix/AFDatagramUtil.java": "bf99e0f8ef3eb35e2b81cd52910896b7364c5e0673ee921c8ea36da5efb1afea",
    "junixsocket-common/src/test/java/org/newsclub/net/unix/AFSYSTEMSocketAddressTest.java": "5ee65952787033fbaa9063f0f6e02da7e4b6ac3222c459f8b54639884866dd6a",
    "junixsocket-common/src/test/java/org/newsclub/net/unix/AFSocketCapabilityCondition.java": "2a0e9257f096d9f8855a7b7b557206ef71614b18bba4a21aa8e2861610661fc3",
    "junixsocket-common/src/test/java/org/newsclub/net/unix/AFSocketCapabilityRequirement.java": "98d49d27da20f8c58dea12639153662ed9a66c6b1e2f2e7fb16da5ae88ef63e3",
    "junixsocket-common/src/test/java/org/newsclub/net/unix/AFTIPCSocketAddressTest.java": "1afa3fc40a7c2eac4879517e78ae3836ce172828a1bc782eb362a87ccdd8a5da",
    "junixsocket-common/src/test/java/org/newsclub/net/unix/AFUNIXSocketAddressTest.java": "ba79d4bcee63b0b0260ccf4e8576944244d89c0a2f313bf6d540d6421e5f7e20",
    "junixsocket-common/src/test/java/org/newsclub/net/unix/AFVSOCKSocketAddressTest.java": "658c84b3c1364adf386c5f7653f1654658e01455be0688bdbe7e6d44cd722dce",
    "junixsocket-common/src/test/java/org/newsclub/net/unix/AcceptTimeoutTest.java": "0f102518abc980ba6429e245dd64fa639261083249dbc5df3b2f5859409443ca",
    "junixsocket-common/src/test/java/org/newsclub/net/unix/AddressSpecifics.java": "1933e5388d1d108af7369e83c13a79ae52ceca8a65e9d56dfb1541b3d9859d1f",
    "junixsocket-common/src/test/java/org/newsclub/net/unix/AncillaryMessageTest.java": "5fb4a40ddd5fdc4cceae181a858343a862247c570bd694e0bba9cac0eefea02c",
    "junixsocket-common/src/test/java/org/newsclub/net/unix/AvailableTest.java": "e3d7a1e972806d179caa45c61070b2febb15593a64b7768301575a3b4e80420e",
    "junixsocket-common/src/test/java/org/newsclub/net/unix/BufferOverflowTest.java": "8e06809c3d9fc7d79dd21a47bd15b36771c6ba66196a75d37677306d8bf4a02a",
    "junixsocket-common/src/test/java/org/newsclub/net/unix/BuildPropertiesTest.java": "79105fb9e72aa02776c0ab47a450b55b2f9cd0f2f3dbd94ca9a25aa7cf52e592",
    "junixsocket-common/src/test/java/org/newsclub/net/unix/CancelAcceptTest.java": "b1e2f42f7b1d77a7d5ad9317e0973883fcf9025a63a0eba5b9f205861ea68bf9",
    "junixsocket-common/src/test/java/org/newsclub/net/unix/DatagramSocketTest.java": "b1b1881a38cb3d0cafbd13f40b0317425706ae516d6231a88e978f7c44fff39e",
    "junixsocket-common/src/test/java/org/newsclub/net/unix/EndOfFileTest.java": "42d259b4b310f35bed9ce616b865218006646c6cbdba0887a8c8797bb931f43f",
    "junixsocket-common/src/test/java/org/newsclub/net/unix/FileDescriptorCastTest.java": "4d1e8f6b2b04bc47830d50d09475163e7c226736c9a51d210884090677cbef34",
    "junixsocket-common/src/test/java/org/newsclub/net/unix/FinalizeTest.java": "72b0d9045f9df6d178c3c945047f76f0bcd02accbd1aacbf1a34f3525bfe2d1e",
    "junixsocket-common/src/test/java/org/newsclub/net/unix/FinalizeTestClient.java": "90d799e820d0fae891ec775ed3e0eeffd728cf8cb9bcc4642c27d9350c134572",
    "junixsocket-common/src/test/java/org/newsclub/net/unix/ImplUtil.java": "2b97f4e391635faac8edf6dafd7600feb88ce4afc08cc09b210923da43b0aa8a",
    "junixsocket-common/src/test/java/org/newsclub/net/unix/InetAddressTest.java": "2cf4dcaa5ea784b89f0df403c732267dac717523d27dabe8f4f4675c71eebe77",
    "junixsocket-common/src/test/java/org/newsclub/net/unix/PipeTest.java": "76dd9d11f3ea08118e2bb86d1ffa53ab7abb31afdb0e6937fbab154b56642bfd",
    "junixsocket-common/src/test/java/org/newsclub/net/unix/ReadWriteTest.java": "12a70ab32b6d6a30fd7ce0f596ce6d64ffdb77affef71f68b92a2b990fe0a86e",
    "junixsocket-common/src/test/java/org/newsclub/net/unix/SelectorTest.java": "5cd4d2bc481446e04c3b6b98fff4af63434f9bbeddea07a0751a89051772c6c0",
    "junixsocket-common/src/test/java/org/newsclub/net/unix/SelftestDiagnosticsHelper.java": "911535e6adaf04ec770780af045c4626aeb238f847ce4f9814323ca7f9e9dc13",
    "junixsocket-common/src/test/java/org/newsclub/net/unix/SelftestProvider.java": "78d517c9cac55940121b5a2d0e15b56ff5d086a3b179da075efb0fe6b18b3018",
    "junixsocket-common/src/test/java/org/newsclub/net/unix/ServerSocketCloseTest.java": "82e3a52856d563c15aa46ac7a27b14c4ff9198c49ee296180054d6f7d9982c6e",
    "junixsocket-common/src/test/java/org/newsclub/net/unix/ServerSocketTest.java": "3235ba9a7378c2f497c09c054709af7669dd051abae172ab224763216a5eaeba",
    "junixsocket-common/src/test/java/org/newsclub/net/unix/SoTimeoutTest.java": "0e524af8584911b16883bc72cd2cef0cfb3bb5287c79acf784ebef6a11522984",
    "junixsocket-common/src/test/java/org/newsclub/net/unix/SocketChannelTest.java": "b590035bdf57f18dd3bab111b765670c1887a52b25fc8408f51a77c91128318b",
    "junixsocket-common/src/test/java/org/newsclub/net/unix/SocketOptionsTest.java": "b5f5790861a00bf0910e5fead3f4735cab71cd5c0b653240b43e1a38534952d8",
    "junixsocket-common/src/test/java/org/newsclub/net/unix/SocketPairTest.java": "2a6cbd517769cbe8c9e599bccd9be379ded5c7e5f232eeff97f610d086689891",
    "junixsocket-common/src/test/java/org/newsclub/net/unix/SocketTest.java": "f6c7ed579b59963a46d92600b3a3dd0a8f862162ad646eec5512e4957a6c0a4b",
    "junixsocket-common/src/test/java/org/newsclub/net/unix/SocketTestBase.java": "cad964f6f111b42b4aff96728b7cf0cf2491c0a23ebb69095630e042f753cd79",
    "junixsocket-common/src/test/java/org/newsclub/net/unix/StandardSocketOptionsTest.java": "ade530bd28cac97aa2879a0067f2f73b0cc3f5a402f6cfb6d49b5b52dac79400",
    "junixsocket-common/src/test/java/org/newsclub/net/unix/StdinSocketApp.java": "d09ab719aa1a324903f53ad20043488342f9d01aaa6c8e1db43c2e7b2f6ccc5b",
    "junixsocket-common/src/test/java/org/newsclub/net/unix/TcpNoDelayTest.java": "4cea2045982c59da395102201d8945d01f1f63ebf86f89ab38c3006e10ae5392",
    "junixsocket-common/src/test/java/org/newsclub/net/unix/TestUtil.java": "04c0550e74fe1a87a88763cf2d57af2d8cf54610eb6390c3d266a74a514d12d1",
    "junixsocket-common/src/test/java/org/newsclub/net/unix/ThroughputTest.java": "f3a70183178e891578cec46e02ed94e0f54d2796d0cab03f90936aef05b0f10c",
    "junixsocket-common/src/test/java/org/newsclub/net/unix/domain/AFUNIXAddressSpecifics.java": "528cc9dff366ebdd0273745f9f12b7c2d228effbe4032853ba7bcea48ea3f198",
    "junixsocket-common/src/test/java/org/newsclub/net/unix/domain/AbstractNamespaceTest.java": "2bb00c516fbf7439a37e1c56da7a8758eaa318c474f1d9cd65ce707022fab3c9",
    "junixsocket-common/src/test/java/org/newsclub/net/unix/domain/AcceptTimeoutTest.java": "113d9319bee04fa9ba6903c9a999208d6d277ffcd96b8bcd7fcaa11e15ee7a94",
    "junixsocket-common/src/test/java/org/newsclub/net/unix/domain/AvailableTest.java": "dda05e658d99f8855c7185888ebfeac595f5eaaec91d535fbb260f15a5c1aa86",
    "junixsocket-common/src/test/java/org/newsclub/net/unix/domain/BufferOverflowTest.java": "be80db590ddc61475a88c1d96b667da69aecc436f6444e3a7c34ce354adb8315",
    "junixsocket-common/src/test/java/org/newsclub/net/unix/domain/CancelAcceptTest.java": "5ba6f5b815021f8e08c8ca739cfad6dcbe5b1dd9d428618407109cf94d007239",
    "junixsocket-common/src/test/java/org/newsclub/net/unix/domain/DatagramSocketTest.java": "865df66bd8167c9db2567ade64343efacc85792c69851faf989be5fdfdf5a287",
    "junixsocket-common/src/test/java/org/newsclub/net/unix/domain/EndOfFileTest.java": "a20a43c853e045092c9e17c55590189306d07fe373d94bbc5681120641a3d999",
    "junixsocket-common/src/test/java/org/newsclub/net/unix/domain/FileDescriptorCastTest.java": "356fb1eb129fb2ac235e7d32800836445d3e6960a0d13f6d5b2bfeb0d4f60d99",
    "junixsocket-common/src/test/java/org/newsclub/net/unix/domain/FileDescriptorsTest.java": "6922c2bcba3e22c3571081444764d5384d1be54981c8e3b4395db8e62fd9d602",
    "junixsocket-common/src/test/java/org/newsclub/net/unix/domain/FinalizeTest.java": "09feea21a4b9f8b73bdf035adabf325b182548814da4e635229f1e04e5f92d26",
    "junixsocket-common/src/test/java/org/newsclub/net/unix/domain/PeerCredentialsTest.java": "51756bb2497a3105d239a157e199db3be43695afe3f5987ca79a9c7cc37fd922",
    "junixsocket-common/src/test/java/org/newsclub/net/unix/domain/ReadWriteTest.java": "b08f740cc45fd18a385867f6dada0ee337abfc64a75945db0d58752351b7a86d",
    "junixsocket-common/src/test/java/org/newsclub/net/unix/domain/SelectorTest.java": "ead5653b51102c6613e2edcb3b6d92d22b70431f792badccee21b6f2bf0010c5",
    "junixsocket-common/src/test/java/org/newsclub/net/unix/domain/ServerSocketCloseTest.java": "c541bc5ac62193db7eed3a20b0af91fb290a2abaec0e17c6fc5ef48318b2beb8",
    "junixsocket-common/src/test/java/org/newsclub/net/unix/domain/ServerSocketTest.java": "925450e5de62f00557c7a080c1ccbd784a57838e667473faf6f344d502496039",
    "junixsocket-common/src/test/java/org/newsclub/net/unix/domain/SoTimeoutTest.java": "3e55b12cea2454cee9dff1aae4600191052e53d001d04f918ba139e33a88f0dc",
    "junixsocket-common/src/test/java/org/newsclub/net/unix/domain/SocketAddressTest.java": "29fa990bddaa3572324f89c5dd999961cbfd3303652e468e36cceeaae691327d",
    "junixsocket-common/src/test/java/org/newsclub/net/unix/domain/SocketChannelTest.java": "30ea9b368f815607d6c26020b931436136974e037bb0c6a417cab67488a40da2",
    "junixsocket-common/src/test/java/org/newsclub/net/unix/domain/SocketFactoryTest.java": "ba680fc88a253fa796e58fe50bb666581d867134dc50209c115c9fe0b3aa961d",
    "junixsocket-common/src/test/java/org/newsclub/net/unix/domain/SocketPairTest.java": "019833c4ebf96cf4961c16f1761509d2a67c170c7443f0c16e217571e1ba487e",
    "junixsocket-common/src/test/java/org/newsclub/net/unix/domain/SocketTest.java": "8fa4939594fb9aca4730e2deb755dd33ba49f64e0c8fc9396db2bd6a93769544",
    "junixsocket-common/src/test/java/org/newsclub/net/unix/domain/StandardSocketOptionsTest.java": "4dafe9db1020bed13ec93eddd0194153bd26ef8f815bd8edf2ffbc28fd02b0ca",
    "junixsocket-common/src/test/java/org/newsclub/net/unix/domain/TcpNoDelayTest.java": "2bc01607cd4eee962027f8f00b8c883a9075ae86f25d8afaaf8b0b15c3f9339e",
    "junixsocket-common/src/test/java/org/newsclub/net/unix/domain/ThroughputTest.java": "9627be5e6bef95d7152e5e18546b5589f68266639f32eaf4e25145768d2a8098",
    "junixsocket-common/src/test/java/org/newsclub/net/unix/domain/ThroughputTestShim.java": "69aed31bb214f5a4b031f7fabd43b9371ada00d371c9545852f861d47927ef8f",
    "junixsocket-common/src/test/java/org/newsclub/net/unix/domain/UnixDomainSocketAddressTest.java": "160a8ec17fed4ed9a4a701bcd341040d050002932716887173edfa4e0cc8595a",
    "junixsocket-common/src/test/java/org/newsclub/net/unix/java/AcceptTimeoutTest.java": "9b50d949e710ca0c58bbaa712178977cd134e0b956aac12af485d3654962b01c",
    "junixsocket-common/src/test/java/org/newsclub/net/unix/java/EndOfFileJavaTest.java": "44047285cb2f1dca7eda6391b6bdcd3fed08d5cd6a3e6a692cb4e37c2cff99fc",
    "junixsocket-common/src/test/java/org/newsclub/net/unix/java/JavaAddressSpecifics.java": "ad107a58ae8628ac7137e17ce5f7c022d2198e2156f7fec6c121b3af3332286c",
    "junixsocket-common/src/test/java/org/newsclub/net/unix/java/JavaInetStackCondition.java": "730a6ee3d673a5328e5ada20c7cb69a4489e6b01bac493ddb2678ce254c9ae2f",
    "junixsocket-common/src/test/java/org/newsclub/net/unix/java/JavaInetStackRequirement.java": "9bb8fb28d8b0d31f4ab2efbca293dae9313a587612f25282ea358c8a81b5fdd5",
    "junixsocket-common/src/test/java/org/newsclub/net/unix/java/SelectorTest.java": "fc6a08c9c287c65b5dc790b5f3a5444a72c6cfc85978cd35f3ce870a316dda0b",
    "junixsocket-common/src/test/java/org/newsclub/net/unix/java/ThroughputTest.java": "7dcbe684d1e79d5fe1f175c3a993ee0701993e916ddfdcdd29e10ae544930347",
    "junixsocket-common/src/test/java15/org/newsclub/net/unix/domain/ThroughputTestShim.java": "19a5d9921e38d83256338380da0b5ceb12ba4ce06055fb57e8ef8955a1640b94",
    "junixsocket-common/src/test/java15/org/newsclub/net/unix/domain/UnixDomainSocketAddressTest.java": "075e18b97532a446f395c124152af5c5d58a154651dd8cf1f8f3cacd426571f1",
    "junixsocket-common/src/test/java8/org/newsclub/net/unix/FinalizeTest.java": "1ac752ed26584b520a648e0adec0dc7e7822b0cbc25a955f1ac79b946aa79414",
    "junixsocket-common/src/test/java8/org/newsclub/net/unix/StandardSocketOptionsTest.java": "6d6624e8f441a90ab335b22ef16e177ef471a20d38d447498beda89ccaead193",
    "junixsocket-common/src/test/java8/org/newsclub/net/unix/domain/FinalizeTest.java": "3cdbad2ec2e223c59db0817c1ef3e0dde9465d1b91a1894560bb261533a76522"
  },
  "selected_classes": [
    "org.newsclub.net.unix.AFUNIXSocketAddressTest",
    "org.newsclub.net.unix.domain.SocketTest",
    "org.newsclub.net.unix.domain.ReadWriteTest",
    "org.newsclub.net.unix.domain.SocketFactoryTest",
    "org.newsclub.net.unix.domain.SocketAddressTest"
  ],
  "test_ids": [
    "org.newsclub.net.unix.AFUNIXSocketAddressTest.testAbstractNamespace()",
    "org.newsclub.net.unix.AFUNIXSocketAddressTest.testCraftDeserialization()",
    "org.newsclub.net.unix.AFUNIXSocketAddressTest.testFileScheme()",
    "org.newsclub.net.unix.AFUNIXSocketAddressTest.testHttpUnix()",
    "org.newsclub.net.unix.AFUNIXSocketAddressTest.testParseURIandBack()",
    "org.newsclub.net.unix.AFUNIXSocketAddressTest.testSchemesAvailable()",
    "org.newsclub.net.unix.AFUNIXSocketAddressTest.testSerialize()",
    "org.newsclub.net.unix.AFUNIXSocketAddressTest.testSocatString()",
    "org.newsclub.net.unix.AFUNIXSocketAddressTest.testURITemplate()",
    "org.newsclub.net.unix.AFUNIXSocketAddressTest.testURITemplateWithPortNumber()",
    "org.newsclub.net.unix.AFUNIXSocketAddressTest.testUnixScheme()",
    "org.newsclub.net.unix.domain.ReadWriteTest.testReceiveDataByteForByteSendByteForByte()",
    "org.newsclub.net.unix.domain.ReadWriteTest.testReceiveDataByteForByteSendWithByteArray()",
    "org.newsclub.net.unix.domain.ReadWriteTest.testReceiveWithByteArraySendByteForByte()",
    "org.newsclub.net.unix.domain.ReadWriteTest.testReceiveWithByteArraySendWithByteArray()",
    "org.newsclub.net.unix.domain.SocketAddressTest.testAbstractNamespace()",
    "org.newsclub.net.unix.domain.SocketAddressTest.testByteConstructor()",
    "org.newsclub.net.unix.domain.SocketAddressTest.testEmptyAddress()",
    "org.newsclub.net.unix.domain.SocketAddressTest.testInetAddress()",
    "org.newsclub.net.unix.domain.SocketAddressTest.testLargePort()",
    "org.newsclub.net.unix.domain.SocketAddressTest.testLegacyConstructor()",
    "org.newsclub.net.unix.domain.SocketAddressTest.testPath()",
    "org.newsclub.net.unix.domain.SocketAddressTest.testPort()",
    "org.newsclub.net.unix.domain.SocketFactoryTest.testFactoryArg()",
    "org.newsclub.net.unix.domain.SocketFactoryTest.testSystemProperty()",
    "org.newsclub.net.unix.domain.SocketFactoryTest.testURISchemeCeateSocketThenConnect()",
    "org.newsclub.net.unix.domain.SocketFactoryTest.testURISchemeCeateSocketWithHostnameValidCases()",
    "org.newsclub.net.unix.domain.SocketFactoryTest.testURISchemeCeateSocketWithIllegalArguments()",
    "org.newsclub.net.unix.domain.SocketFactoryTest.testURISchemeCeateSocketWithInvalidHostname()",
    "org.newsclub.net.unix.domain.SocketTest.testBindBadArguments()",
    "org.newsclub.net.unix.domain.SocketTest.testCloseable()",
    "org.newsclub.net.unix.domain.SocketTest.testConnectBadArguments()",
    "org.newsclub.net.unix.domain.SocketTest.testLoadedLibrary()",
    "org.newsclub.net.unix.domain.SocketTest.testMain()",
    "org.newsclub.net.unix.domain.SocketTest.testReceivedFileDescriptorsUnconnected()",
    "org.newsclub.net.unix.domain.SocketTest.testSupported()",
    "org.newsclub.net.unix.domain.SocketTest.testSupports()",
    "org.newsclub.net.unix.domain.SocketTest.testUnconnectedSocket()",
    "org.newsclub.net.unix.domain.SocketTest.testVersion()"
  ],
  "selection_reason": "Scoped loader-adjacent coverage: address serialization/URI and large native ports, socket initialization/metadata, real byte I/O, socket factories. Not the full upstream suite.",
  "excluded_ids": [],
  "exclusion_reason": "None among the selected classes; all discovered cases must execute and pass."
}
EOF_fbf6eeb7abbc
source /benchmark/case_adapter.sh || fail 'Cannot load case adapter'
mkdir -p /results || fail 'Cannot create test output directory'
mkdir -p /case-noexec /case-exec || fail 'Cannot create test mountpoints'
mount -t tmpfs -o rw,noexec,nosuid,size=64m tmpfs /case-noexec || fail 'Cannot create noexec test mount'
mount -t tmpfs -o rw,exec,nosuid,size=64m tmpfs /case-exec || fail 'Cannot create executable test mount'
build_project || fail 'Project build failed'
run_project_tests >/results/tests.raw.log 2>&1
test_status=$?
cat /results/tests.raw.log

parser_python=$(command -v python || command -v python3 || command -v python2.7) \
    || fail 'Cannot find Python for test log conversion'
printf '%s\n' '>>>>> Start Test Output'
PYTHONIOENCODING=utf-8 "$parser_python" /benchmark/format_test_log.py /results/tests.raw.log \
    || fail 'Cannot convert test output'
(exit "$test_status")
printf '%s\n' '>>>>> End Test Output'
exit "$test_status"
