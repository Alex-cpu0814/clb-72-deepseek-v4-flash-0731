#!/bin/bash
set -uo pipefail
ulimit -c 0

fail() {
    printf '%s\n' '>>>>> Tests Errored' "$1" >&2
    exit 2
}

cd /testbed || fail 'Cannot enter /testbed'
[[ "$(git rev-parse HEAD)" == "90716d6008c5c9cfa8a061f3d23531acaea29777" ]] || fail 'Unexpected Base commit'
git apply --whitespace=nowarn - <<'CLB_TEST_PATCH' || fail 'Test patch application failed'
diff --git a/junixsocket-common/src/test/java/org/newsclub/net/unix/Issue81GlibcProbe.java b/junixsocket-common/src/test/java/org/newsclub/net/unix/Issue81GlibcProbe.java
new file mode 100644
index 0000000..2faa0aa
--- /dev/null
+++ b/junixsocket-common/src/test/java/org/newsclub/net/unix/Issue81GlibcProbe.java
@@ -0,0 +1,47 @@
+package org.newsclub.net.unix;
+
+import java.io.DataInputStream;
+import java.io.DataOutputStream;
+import java.io.File;
+
+/** Calls the real library loader and native bind; no simulated native failures. */
+public final class Issue81GlibcProbe {
+  public static void main(String[] args) throws Exception {
+    System.out.println("JAVA_STARTED=" + System.getProperty("java.version"));
+    if (!AFUNIXSocket.isSupported()) {
+      throw new AssertionError("AF_UNIX unavailable");
+    }
+    System.out.println("LOADER_COMPLETED=" + AFUNIXSocket.getLoadedLibrary());
+    for (int iteration = 0; iteration < 3; iteration++) {
+      File file = File.createTempFile("issue81-", ".sock");
+      if (!file.delete()) {
+        throw new AssertionError("Could not prepare socket pathname");
+      }
+      AFUNIXSocketAddress address = new AFUNIXSocketAddress(file);
+      System.out.println("BEFORE_BIND=" + iteration);
+      try (AFUNIXServerSocket server = AFUNIXServerSocket.bindOn(address)) {
+        System.out.println("AFTER_BIND=" + iteration);
+        server.setSoTimeout(3000);
+        try (AFUNIXSocket client = AFUNIXSocket.connectTo(address);
+             AFUNIXSocket accepted = server.accept()) {
+          client.setSoTimeout(3000);
+          accepted.setSoTimeout(3000);
+          int value = 0x1638100 + iteration;
+          new DataOutputStream(client.getOutputStream()).writeInt(value);
+          if (new DataInputStream(accepted.getInputStream()).readInt() != value) {
+            throw new AssertionError("Request corrupted");
+          }
+          new DataOutputStream(accepted.getOutputStream()).writeInt(~value);
+          if (new DataInputStream(client.getInputStream()).readInt() != ~value) {
+            throw new AssertionError("Response corrupted");
+          }
+        }
+      } finally {
+        if (file.exists() && !file.delete()) {
+          throw new AssertionError("Socket cleanup failed");
+        }
+      }
+      System.out.println("ROUNDTRIP_OK=" + iteration);
+    }
+  }
+}
diff --git a/junixsocket-common/src/test/java/org/newsclub/net/unix/Issue81CompatibilityTest.java b/junixsocket-common/src/test/java/org/newsclub/net/unix/Issue81CompatibilityTest.java
new file mode 100644
index 0000000..11d0f95
--- /dev/null
+++ b/junixsocket-common/src/test/java/org/newsclub/net/unix/Issue81CompatibilityTest.java
@@ -0,0 +1,64 @@
+package org.newsclub.net.unix;
+
+import static org.junit.jupiter.api.Assertions.assertEquals;
+import static org.junit.jupiter.api.Assertions.assertTrue;
+
+import java.nio.charset.StandardCharsets;
+import java.nio.file.Files;
+import java.nio.file.Path;
+import java.nio.file.Paths;
+import java.util.ArrayList;
+import java.util.Arrays;
+import java.util.Collections;
+import java.util.List;
+import java.util.concurrent.TimeUnit;
+import org.junit.jupiter.api.Test;
+import org.junit.jupiter.api.io.TempDir;
+
+class Issue81CompatibilityTest {
+  @TempDir
+  Path tempDir;
+
+  @Test
+  void testAutomaticFallbackOldGlibc() throws Exception {
+    runProbe(Arrays.asList("/opt/tools/qemu-x86_64-static", "-L", "/opt/legacy"));
+  }
+
+  @Test
+  void testModernGlibcRoundTrip() throws Exception {
+    runProbe(Collections.emptyList());
+  }
+
+  private void runProbe(List<String> launcher) throws Exception {
+    List<String> command = new ArrayList<>(launcher);
+    String java = Paths.get(System.getProperty("java.home"), "bin", "java").toString();
+    Collections.addAll(command, java, "-Xint", "-Xms16m", "-Xmx64m", "-XX:+UseSerialGC",
+        "-XX:ActiveProcessorCount=2", "-cp", System.getProperty("java.class.path"),
+        Issue81GlibcProbe.class.getName());
+
+    Path log = tempDir.resolve("probe.log");
+    Process child = new ProcessBuilder(command)
+        .redirectErrorStream(true)
+        .redirectOutput(log.toFile())
+        .start();
+    boolean finished;
+    try {
+      finished = child.waitFor(30, TimeUnit.SECONDS);
+    } finally {
+      if (child.isAlive()) {
+        child.destroyForcibly();
+      }
+    }
+
+    String output = new String(Files.readAllBytes(log), StandardCharsets.UTF_8);
+    assertTrue(finished, () -> "Probe JVM timed out:\n" + output);
+    assertEquals(0, child.exitValue(), () -> "Probe JVM failed:\n" + output);
+
+    List<String> lines = Arrays.asList(output.split("\\R"));
+    for (int iteration = 0; iteration < 3; iteration++) {
+      String marker = "ROUNDTRIP_OK=" + iteration;
+      assertEquals(1, Collections.frequency(lines, marker),
+          () -> "Expected one " + marker + " line from the probe:\n" + output);
+    }
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
cat > /benchmark/build_project.py <<'EOF_754a2091a4b6' || fail 'Cannot write /benchmark/build_project.py'
"""Source build adapter for the historical core JNI modules (Python 3.5+)."""
from __future__ import print_function
import hashlib
import json
from pathlib import Path
import re
import shlex
import shutil
import subprocess
import xml.etree.ElementTree as ET

ROOT = Path('/testbed')
OUT = ROOT / 'target/case163'
NS = {'m': 'http://maven.apache.org/POM/4.0.0'}
MANIFEST = json.loads(Path('/benchmark/upstream_tests.json').read_text(encoding='utf-8'))


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def guard():
    for name, expected in MANIFEST['source_sha256'].items():
        path = ROOT / name
        if not path.is_file() or digest(path) != expected:
            raise SystemExit('protected_upstream_test_modified: ' + name)


def run(argv):
    print('BUILD_ARGV=' + json.dumps([str(x) for x in argv]), flush=True)
    subprocess.check_call([str(x) for x in argv], cwd=str(ROOT))


guard()
OUT.mkdir(parents=True, exist_ok=True)
classes = OUT / 'classes'
tests = OUT / 'testclasses'
native = OUT / 'native'
for directory in (classes, tests, native):
    directory.mkdir(parents=True, exist_ok=True)
properties = {}
for pom in (ROOT / 'pom.xml', ROOT / 'junixsocket-native/pom.xml'):
    tree = ET.parse(str(pom)).getroot()
    for node in tree.findall('m:properties/*', NS):
        properties[node.tag.split('}', 1)[-1]] = node.text or ''
properties.update({'project.basedir': str(ROOT / 'junixsocket-native'),
                   'junixsocket.native.llvm.target': 'current'})


def expand(value):
    for unused in range(30):
        replacement = re.sub(r'\$\{([^}]+)\}', lambda m: properties.get(m.group(1), m.group(0)), value)
        if replacement == value:
            break
        value = replacement
    if '${' in value:
        raise ValueError('Unresolved native compiler property: ' + value)
    return value


options = None
for line in (ROOT / 'junixsocket-native/src/main/nar/aol.properties').read_text(encoding='utf-8').splitlines():
    if line.startswith('amd64.Linux.clang.c.options='):
        options = line.split('=', 1)[1]
        break
if options is None:
    raise SystemExit('Missing upstream amd64 Linux compiler options')
configured = shlex.split(expand(options))
flags = ['-fPIC']
index = 0
while index < len(configured):
    item = configured[index]
    if item == '-target':
        if configured[index + 1] != 'current':
            raise SystemExit('This evaluator targets the native Linux architecture')
        index += 2
        continue
    if item not in ('-finline-functions', '-Xcrossclang-with-and-without-lc'):
        flags.append(item)
    index += 1
print('NATIVE_FLAGS=' + json.dumps(flags), flush=True)
objects = {False: [], True: []}
for source in sorted((ROOT / 'junixsocket-native/src/main/c').rglob('*.c')):
    for nodeps in (False, True):
        suffix = '.nodeps.o' if nodeps else '.o'
        object_file = native / (source.stem + suffix)
        extra = ['-D__CROSSCLANG_NODEPS__=1'] if nodeps else []
        run(['clang'] + flags + extra + ['-c', source, '-o', object_file])
        objects[nodeps].append(object_file)
for nodeps in (False, True):
    suffix = '.nodeps.so' if nodeps else '.so'
    library = native / ('libjunixsocket-native-2.3.2' + suffix)
    run(['clang', '-shared'] + (['-nostdlib'] if nodeps else []) + objects[nodeps] + ['-o', library])

sources = []
for module in ('junixsocket-common', 'junixsocket-native-common'):
    sources += sorted(p for p in (ROOT / module / 'src/main/java').rglob('*.java') if p.name != 'module-info.java')
run(['javac', '-encoding', 'UTF-8', '-source', '8', '-target', '8', '-d', classes] + sources)
resources = classes / 'lib/amd64-Linux-clang/jni'
resources.mkdir(parents=True, exist_ok=True)
for library in native.glob('*.so'):
    shutil.copyfile(str(library), str(resources / library.name))
for artifact in ('junixsocket-common', 'junixsocket-native-common'):
    metadata = classes / ('META-INF/maven/com.kohlschutter.junixsocket/' + artifact)
    metadata.mkdir(parents=True, exist_ok=True)
    (metadata / 'pom.properties').write_text('version=2.3.2\n', encoding='utf-8')
classpath = str(classes) + ':/opt/deps/junit-console.jar:/opt/deps/annotations.jar'
sources = sorted((ROOT / 'junixsocket-common/src/test/java').rglob('*.java'))
run(['javac', '-encoding', 'UTF-8', '-source', '8', '-target', '8', '-cp', classpath,
     '-d', tests] + sources)
guard()
artifacts = {p.relative_to(OUT).as_posix(): digest(p) for p in OUT.rglob('*') if p.is_file()}
Path('/results/build-artifacts.json').write_text(json.dumps(artifacts, indent=2) + '\n', encoding='utf-8')
EOF_754a2091a4b6
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
cat > /benchmark/run_case_tests.py <<'EOF_70289fa37672' || fail 'Cannot write /benchmark/run_case_tests.py'
"""Run all case 163 tests through JUnit and report their XML results (Python 3.5+)."""
from __future__ import print_function
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import xml.etree.ElementTree as ET

RESULTS = Path('/results')
OUT = Path('/testbed/target/case163')
MANIFEST = json.loads(Path('/benchmark/upstream_tests.json').read_text(encoding='utf-8'))
CLASSPATH = str(OUT / 'classes') + ':' + str(OUT / 'testclasses')
JAVA = '/opt/java/jdk8u292-b10/bin/java'
TEST_IDS = MANIFEST['test_ids'] + [
    'org.newsclub.net.unix.Issue81CompatibilityTest.testAutomaticFallbackOldGlibc',
    'org.newsclub.net.unix.Issue81CompatibilityTest.testModernGlibcRoundTrip',
]


def execute(command, prefix, timeout):
    process = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    timed_out = False
    try:
        stdout, stderr = process.communicate(timeout=timeout)
    except subprocess.TimeoutExpired:
        timed_out = True
        process.kill()
        stdout, stderr = process.communicate()
    prefix.parent.mkdir(parents=True, exist_ok=True)
    Path(str(prefix) + '.stdout.log').write_bytes(stdout)
    Path(str(prefix) + '.stderr.log').write_bytes(stderr)
    record = {'command': command, 'exit_code': process.returncode, 'timed_out': timed_out,
              'stdout_sha256': hashlib.sha256(stdout).hexdigest(),
              'stderr_sha256': hashlib.sha256(stderr).hexdigest()}
    Path(str(prefix) + '.json').write_text(json.dumps(record, indent=2) + '\n', encoding='utf-8')
    return record, stdout.decode('utf-8', 'replace')


def emit(test_id, status):
    owner, method = test_id.rsplit('.', 1)
    print('{} ({}) ... {}'.format(method, owner, status), flush=True)


reports = RESULTS / 'junit'
reports.mkdir(exist_ok=True)
command = [JAVA, '-cp', CLASSPATH + ':/opt/deps/junit-console.jar:/opt/deps/annotations.jar',
           'org.junit.platform.console.ConsoleLauncher', '--disable-ansi-colors',
           '--reports-dir', str(reports), '--details', 'summary', '--fail-if-no-tests']
for test_id in TEST_IDS:
    owner, method = test_id.rsplit('.', 1)
    command += ['--select-method', owner + '#' + method]
result, stdout = execute(command, RESULTS / 'junit-run', 180)
print(stdout, end='', flush=True)
stderr = (RESULTS / 'junit-run.stderr.log').read_bytes().decode('utf-8', 'replace')
print(stderr, end='', file=sys.stderr, flush=True)
observed = {}
parse_error = None
try:
    for report in reports.glob('*.xml'):
        for test in ET.parse(str(report)).getroot().iter('testcase'):
            method = test.get('name', '')
            if not method.endswith('()'):
                raise ValueError('Unexpected JUnit testcase name: ' + method)
            test_id = test.get('classname', '') + '.' + method[:-2]
            if test_id in observed:
                raise ValueError('Duplicate JUnit testcase: ' + test_id)
            if test.find('failure') is not None or test.find('error') is not None:
                status = 'FAIL'
            elif test.find('skipped') is not None:
                status = 'skipped'
            else:
                status = 'ok'
            observed[test_id] = status
    if set(observed) != set(TEST_IDS):
        raise ValueError('JUnit testcase set differs from expected test IDs')
except Exception as error:
    parse_error = str(error)
if parse_error:
    print('JUNIT_REPORT_ERROR=' + parse_error, flush=True)
failed = result['exit_code'] != 0 or result['timed_out'] or parse_error is not None
for test_id in TEST_IDS:
    status = observed.get(test_id, 'ERROR') if parse_error is None else 'ERROR'
    emit(test_id, status)
    failed = failed or status != 'ok'
sys.exit(1 if failed else 0)
EOF_70289fa37672
cat > /benchmark/upstream_tests.json <<'EOF_b0a685040733' || fail 'Cannot write /benchmark/upstream_tests.json'
{
  "test_ids": [
    "org.newsclub.net.unix.AFUNIXSocketAddressTest.testPort",
    "org.newsclub.net.unix.AcceptTimeoutTest.testCatchTimeout",
    "org.newsclub.net.unix.AcceptTimeoutTest.testTimeoutAfterDelay",
    "org.newsclub.net.unix.BufferOverflowTest.readOutOfBounds",
    "org.newsclub.net.unix.BufferOverflowTest.readUpTo",
    "org.newsclub.net.unix.BufferOverflowTest.writeOverflow",
    "org.newsclub.net.unix.CancelAcceptTest.issue6test1",
    "org.newsclub.net.unix.EndOfFileJavaTest.bidirectionalSanity",
    "org.newsclub.net.unix.EndOfFileJavaTest.clientReadEof",
    "org.newsclub.net.unix.EndOfFileJavaTest.clientWriteToSocketClosedByClient",
    "org.newsclub.net.unix.EndOfFileJavaTest.clientWriteToSocketClosedByServer",
    "org.newsclub.net.unix.EndOfFileJavaTest.serverReadEof",
    "org.newsclub.net.unix.EndOfFileJavaTest.serverWriteToSocketClosedByClient",
    "org.newsclub.net.unix.EndOfFileJavaTest.serverWriteToSocketClosedByServer",
    "org.newsclub.net.unix.EndOfFileTest.bidirectionalSanity",
    "org.newsclub.net.unix.EndOfFileTest.clientReadEof",
    "org.newsclub.net.unix.EndOfFileTest.clientWriteToSocketClosedByClient",
    "org.newsclub.net.unix.EndOfFileTest.clientWriteToSocketClosedByServer",
    "org.newsclub.net.unix.EndOfFileTest.serverReadEof",
    "org.newsclub.net.unix.EndOfFileTest.serverWriteToSocketClosedByClient",
    "org.newsclub.net.unix.EndOfFileTest.serverWriteToSocketClosedByServer",
    "org.newsclub.net.unix.FileDescriptorsTest.testAncillaryReceiveBufferTooSmall",
    "org.newsclub.net.unix.FileDescriptorsTest.testBadFileDescriptor",
    "org.newsclub.net.unix.FileDescriptorsTest.testFileInputStream",
    "org.newsclub.net.unix.FileDescriptorsTest.testFileInputStreamPartiallyConsumed",
    "org.newsclub.net.unix.FileDescriptorsTest.testNoAncillaryReceiveBuffer",
    "org.newsclub.net.unix.FileDescriptorsTest.testSendRecvFileDescriptors",
    "org.newsclub.net.unix.PeerCredentialsTest.testSameProcess",
    "org.newsclub.net.unix.ServerSocketCloseTest.testUnblockAcceptsWithSoTimeout",
    "org.newsclub.net.unix.ServerSocketCloseTest.testUnblockAcceptsWithoutSoTimeout",
    "org.newsclub.net.unix.SoTimeoutTest.issue14Fail",
    "org.newsclub.net.unix.SoTimeoutTest.issue14Pass",
    "org.newsclub.net.unix.TcpNoDelayTest.testDefaultImpl",
    "org.newsclub.net.unix.TcpNoDelayTest.testStrictImpl"
  ],
  "upstream_discovered_count": 36,
  "excluded_ids": [
    "org.newsclub.net.unix.AvailableTest.testAvailableAtClient",
    "org.newsclub.net.unix.AvailableTest.testAvailableAtServer"
  ],
  "exclusion_reason": "AvailableTest shares a timing-dependent helper; untouched Base already fails testAvailableAtServer (22 expected, 23 observed). Neither test is counted as passing.",
  "source_sha256": {
    "junixsocket-common/src/test/java/org/newsclub/net/unix/AcceptTimeoutTest.java": "9212e41e0e6247541f7e1011b791c860d49a0fbe8b1becd8b837da1f7b668c33",
    "junixsocket-common/src/test/java/org/newsclub/net/unix/AFUNIXSocketAddressTest.java": "04c93933f165d87adb90b5110e5ac47351b2f2fcad91ca98e93471e3fcf8b401",
    "junixsocket-common/src/test/java/org/newsclub/net/unix/AFUNIXSocketCapabilityCondition.java": "27ff0dbac0a1ab5636b9d1cbbaf298fae63042651e190430707625e1e1ef76cf",
    "junixsocket-common/src/test/java/org/newsclub/net/unix/AFUNIXSocketCapabilityRequirement.java": "6be468a9157a1cc2962e74076abc6cb9f4d54721019448258a270526434bc7c4",
    "junixsocket-common/src/test/java/org/newsclub/net/unix/AvailableTest.java": "9967b6ffb0b27889f145799de8b600ffd29e66efd4ed743bc9c72d0adde46dd0",
    "junixsocket-common/src/test/java/org/newsclub/net/unix/BufferOverflowTest.java": "522ac7be6bdf54f602b530a7cab9813fe7069c15d9c884e7adcff8624d8edb2c",
    "junixsocket-common/src/test/java/org/newsclub/net/unix/CancelAcceptTest.java": "07be4528ca80e82411d972a867d5b7d01d37dc068d40f38981f2ab1ef2276950",
    "junixsocket-common/src/test/java/org/newsclub/net/unix/EndOfFileJavaTest.java": "4b3921091adee97584a348d609a01e1169d71055e5310813b6d81b5ac524e9ed",
    "junixsocket-common/src/test/java/org/newsclub/net/unix/EndOfFileTest.java": "1503d8bc26f841f77180a67e15ec8478af5e0624fcbceb9d35f2c364d16bb8b6",
    "junixsocket-common/src/test/java/org/newsclub/net/unix/FileDescriptorsTest.java": "fe6c9beb3836382dc873f453245c8d5f19ba3b052a9e48babcd0e5dbd1aade4a",
    "junixsocket-common/src/test/java/org/newsclub/net/unix/PeerCredentialsTest.java": "eeb242b5bf775d7769651dea8f386f667d599d930fdf2ad83f972e971a47c9f0",
    "junixsocket-common/src/test/java/org/newsclub/net/unix/ServerSocketCloseTest.java": "4145bb10092e41dc4928dd898e86934e41a32c09aefa8370935370a2d29369b3",
    "junixsocket-common/src/test/java/org/newsclub/net/unix/SocketTestBase.java": "de31da44f2fea27721ebfeb6562165948245971dec366c512809b81a045e6ecb",
    "junixsocket-common/src/test/java/org/newsclub/net/unix/SoTimeoutTest.java": "6feaf6d430c62bfe716f530dbe4aec895014f67aac7da9979fe9f9c6023af984",
    "junixsocket-common/src/test/java/org/newsclub/net/unix/TcpNoDelayTest.java": "8eb0851d8836318b907f8fdf0665916ccc5eecb0a45a75fda3fb8981487ca757",
    "junixsocket-common/src/test/java/org/newsclub/net/unix/TestUtils.java": "304b09831dfe02a5a72d2ad29fbc7b1ad7278f224fd3f86bb50b67610f562c92"
  }
}
EOF_b0a685040733
source /benchmark/case_adapter.sh || fail 'Cannot load case adapter'
mkdir -p /results || fail 'Cannot create test output directory'
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
