#!/bin/bash
set -uxo pipefail
set +x
ulimit -c 0
cd /testbed || exit 2
fail() {
    printf '%s\n' ">>>>> Tests Errored" "$1" >&2
    exit 2
}
[[ "$(git rev-parse HEAD)" == "2a159927761424440f7dbd7674992e4b5273a459" ]] || fail "Unexpected Base commit"
git apply --check --whitespace=nowarn - <<'CLB_TEST_PATCH'
diff --git a/junixsocket-jetty/src/test/java/org/eclipse/jetty/unixdomain/server/UnixDomainTest.java b/junixsocket-jetty/src/test/java/org/eclipse/jetty/unixdomain/server/UnixDomainTest.java
index 76e3a6d..9bfa373 100644
--- a/junixsocket-jetty/src/test/java/org/eclipse/jetty/unixdomain/server/UnixDomainTest.java
+++ b/junixsocket-jetty/src/test/java/org/eclipse/jetty/unixdomain/server/UnixDomainTest.java
@@ -31,6 +31,7 @@
 package org.eclipse.jetty.unixdomain.server;
 
 import static org.hamcrest.MatcherAssert.assertThat;
+import static org.junit.jupiter.api.Assertions.assertArrayEquals;
 import static org.junit.jupiter.api.Assertions.assertDoesNotThrow;
 import static org.junit.jupiter.api.Assertions.assertEquals;
 import static org.junit.jupiter.api.Assertions.assertNotNull;
@@ -45,6 +46,7 @@ import java.net.SocketException;
 import java.nio.file.Files;
 import java.nio.file.Path;
 import java.util.Objects;
+import java.util.Random;
 import java.util.concurrent.TimeUnit;
 
 import org.eclipse.jetty.client.HttpClient;
@@ -75,6 +77,7 @@ import org.newsclub.net.unix.AFUNIXSocketAddress;
 import org.newsclub.net.unix.jetty.AFSocketClientConnector;
 import org.newsclub.net.unix.jetty.AFSocketServerConnector;
 
+import jakarta.servlet.ServletOutputStream;
 import jakarta.servlet.http.HttpServletRequest;
 import jakarta.servlet.http.HttpServletResponse;
 
@@ -317,4 +320,43 @@ public class UnixDomainTest {
     }
     return ret.toString();
   }
+
+  @Test
+  public void testLargeBody() throws Exception {
+    String uri = "http://localhost:1234/path";
+
+    byte[] payload = new byte[512 * 1024]; // 512k
+    Random random = new Random();
+    for (int i = 0, n = payload.length; i < n; i++) {
+      payload[i] = (byte) (random.nextInt() & 0xFF);
+    }
+
+    start(new AbstractHandler() {
+      @Override
+      public void handle(String target, Request jettyRequest, HttpServletRequest request,
+          HttpServletResponse response) throws IOException {
+        jettyRequest.setHandled(true);
+
+        response.setContentType(" application/octet-stream");
+        try (ServletOutputStream out = response.getOutputStream()) {
+          out.write(payload);
+        }
+      }
+    });
+
+    // ClientConnector clientConnector = ClientConnector.forUnixDomain(unixDomainPath);
+    ClientConnector clientConnector = AFSocketClientConnector.withSocketAddress(AFUNIXSocketAddress
+        .of(unixDomainPath));
+    HttpClient httpClient = new HttpClient(new HttpClientTransportDynamic(clientConnector));
+    httpClient.start();
+    try {
+      ContentResponse response = httpClient.newRequest(uri).timeout(5, TimeUnit.SECONDS).send();
+
+      assertEquals(HttpStatus.OK_200, response.getStatus());
+      byte[] data = response.getContent();
+      assertArrayEquals(payload, data);
+    } finally {
+      httpClient.stop();
+    }
+  }
 }
\ No newline at end of file
CLB_TEST_PATCH
[[ "$?" == 0 ]] || fail "Test patch does not apply"
git apply --whitespace=nowarn - <<'CLB_TEST_PATCH'
diff --git a/junixsocket-jetty/src/test/java/org/eclipse/jetty/unixdomain/server/UnixDomainTest.java b/junixsocket-jetty/src/test/java/org/eclipse/jetty/unixdomain/server/UnixDomainTest.java
index 76e3a6d..9bfa373 100644
--- a/junixsocket-jetty/src/test/java/org/eclipse/jetty/unixdomain/server/UnixDomainTest.java
+++ b/junixsocket-jetty/src/test/java/org/eclipse/jetty/unixdomain/server/UnixDomainTest.java
@@ -31,6 +31,7 @@
 package org.eclipse.jetty.unixdomain.server;
 
 import static org.hamcrest.MatcherAssert.assertThat;
+import static org.junit.jupiter.api.Assertions.assertArrayEquals;
 import static org.junit.jupiter.api.Assertions.assertDoesNotThrow;
 import static org.junit.jupiter.api.Assertions.assertEquals;
 import static org.junit.jupiter.api.Assertions.assertNotNull;
@@ -45,6 +46,7 @@ import java.net.SocketException;
 import java.nio.file.Files;
 import java.nio.file.Path;
 import java.util.Objects;
+import java.util.Random;
 import java.util.concurrent.TimeUnit;
 
 import org.eclipse.jetty.client.HttpClient;
@@ -75,6 +77,7 @@ import org.newsclub.net.unix.AFUNIXSocketAddress;
 import org.newsclub.net.unix.jetty.AFSocketClientConnector;
 import org.newsclub.net.unix.jetty.AFSocketServerConnector;
 
+import jakarta.servlet.ServletOutputStream;
 import jakarta.servlet.http.HttpServletRequest;
 import jakarta.servlet.http.HttpServletResponse;
 
@@ -317,4 +320,43 @@ public class UnixDomainTest {
     }
     return ret.toString();
   }
+
+  @Test
+  public void testLargeBody() throws Exception {
+    String uri = "http://localhost:1234/path";
+
+    byte[] payload = new byte[512 * 1024]; // 512k
+    Random random = new Random();
+    for (int i = 0, n = payload.length; i < n; i++) {
+      payload[i] = (byte) (random.nextInt() & 0xFF);
+    }
+
+    start(new AbstractHandler() {
+      @Override
+      public void handle(String target, Request jettyRequest, HttpServletRequest request,
+          HttpServletResponse response) throws IOException {
+        jettyRequest.setHandled(true);
+
+        response.setContentType(" application/octet-stream");
+        try (ServletOutputStream out = response.getOutputStream()) {
+          out.write(payload);
+        }
+      }
+    });
+
+    // ClientConnector clientConnector = ClientConnector.forUnixDomain(unixDomainPath);
+    ClientConnector clientConnector = AFSocketClientConnector.withSocketAddress(AFUNIXSocketAddress
+        .of(unixDomainPath));
+    HttpClient httpClient = new HttpClient(new HttpClientTransportDynamic(clientConnector));
+    httpClient.start();
+    try {
+      ContentResponse response = httpClient.newRequest(uri).timeout(5, TimeUnit.SECONDS).send();
+
+      assertEquals(HttpStatus.OK_200, response.getStatus());
+      byte[] data = response.getContent();
+      assertArrayEquals(payload, data);
+    } finally {
+      httpClient.stop();
+    }
+  }
 }
\ No newline at end of file
CLB_TEST_PATCH
[[ "$?" == 0 ]] || fail "Test patch application failed"
mkdir -p /opt/clb-pilot || fail 'Cannot create evaluation fixture directory'
cat > /opt/clb-pilot/case_adapter.sh <<'EOF_94b139701c52' || fail 'Cannot write /opt/clb-pilot/case_adapter.sh'
#!/usr/bin/env bash

build_project() {
    mvn -B -o -Prelease-native \
        -pl junixsocket-native-custom,junixsocket-jetty -am clean install \
        -DskipTests \
        -Djunixsocket.custom.arch=amd64-Linux-clang-jni \
        -Djunixsocket.custom.shaded=default
}

run_project_tests() {
    local control_status target_status
    local report_dir=/testbed/junixsocket-jetty/target/surefire-reports

    rm -rf "${report_dir}"
    mvn -B -o -f junixsocket-jetty/pom.xml test \
        '-Dtest=UnixDomainTest#testHTTPOverUnixDomain'
    control_status=$?
    python3 /opt/clb-pilot/report_surefire.py "${report_dir}"
    if [[ "${control_status}" -ne 0 ]]; then
        return "${control_status}"
    fi

    rm -rf "${report_dir}"
    timeout --signal=TERM --kill-after=5s 30s \
        mvn -B -o -f junixsocket-jetty/pom.xml test \
        '-Dtest=UnixDomainTest#testLargeBody'
    target_status=$?
    if [[ "${target_status}" -eq 124 || "${target_status}" -eq 137 ]]; then
        printf '%s\n' \
            'testLargeBody (org.eclipse.jetty.unixdomain.server.UnixDomainTest) ... ERROR'
        return 1
    fi
    python3 /opt/clb-pilot/report_surefire.py "${report_dir}"
    return "${target_status}"
}
EOF_94b139701c52
cat > /opt/clb-pilot/normalize_results.py <<'EOF_c05e792222b6' || fail 'Cannot write /opt/clb-pilot/normalize_results.py'
"""Translate CLB test result lines to the upstream status-first format."""

import io
import re
import sys


PYTEST = re.compile(
    r"^(scipy/\S.*?)\s+(PASSED|FAILED|ERROR|SKIPPED)(?:\s+\[\s*\d+%\])?$"
)
UNITTEST = re.compile(r"^(\S+) \(([^)]+)\) \.\.\.(?: (.*))?$")


def statuses(lines, mode):
    pending = None
    mapping = {"ok": "PASSED", "FAIL": "FAILED", "ERROR": "ERROR", "skipped": "SKIPPED"}
    for raw in lines:
        line = raw.strip()
        if mode == "pytest":
            result = PYTEST.match(line)
            if result:
                yield result.group(2), result.group(1)
            continue
        result = UNITTEST.match(line)
        if result:
            method, test_class, line = result.groups()
            if mode == "jep" and test_class.startswith("tests."):
                test_class = test_class[len("tests."):]
            pending = test_class + "." + method
            line = line or ""
        if pending and line:
            status = mapping.get("skipped" if line.startswith("skipped") else line)
            if status:
                yield status, pending
                pending = None


if __name__ == "__main__":
    with io.open(sys.argv[2], encoding="utf-8", errors="replace") as stream:
        for status, test_id in statuses(stream, sys.argv[1]):
            print("{} {}".format(status, test_id))
EOF_c05e792222b6
cat > /opt/clb-pilot/report_surefire.py <<'EOF_9596d4de326e' || fail 'Cannot write /opt/clb-pilot/report_surefire.py'
#!/usr/bin/env python3
"""Emit Maven Surefire XML results in the evaluator's stable line format."""

import pathlib
import sys
import xml.etree.ElementTree as ET


def main():
    report_dir = pathlib.Path(sys.argv[1])
    found = 0
    for path in sorted(report_dir.glob("TEST-*.xml")):
        root = ET.parse(path).getroot()
        for case in root.iter("testcase"):
            class_name = case.get("classname", "unknown")
            method = case.get("name", "unknown")
            if case.find("failure") is not None:
                status = "FAIL"
            elif case.find("error") is not None:
                status = "ERROR"
            elif case.find("skipped") is not None:
                status = "skipped"
            else:
                status = "ok"
            print(f"{method} ({class_name}) ... {status}")
            found += 1
    if found == 0:
        print("No Surefire test results found", file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
EOF_9596d4de326e
source /opt/clb-pilot/case_adapter.sh || fail "Cannot load the case adapter"
build_project || fail "Project build failed"
raw_log=$(mktemp) || fail "Cannot create a test log"
trap 'rm -f "$raw_log"' EXIT
run_project_tests >"$raw_log" 2>&1
test_status=$?
cat "$raw_log"
printf '%s\n' '>>>>> Start Test Output'
emit_results() {
    python3 /opt/clb-pilot/normalize_results.py unittest "$raw_log" || return 2
    return "$test_status"
}
emit_results
printf '%s\n' '>>>>> End Test Output'
exit "$test_status"
