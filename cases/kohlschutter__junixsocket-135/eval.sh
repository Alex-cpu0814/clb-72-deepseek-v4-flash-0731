#!/bin/bash
set -uo pipefail
ulimit -c 0

fail() {
    printf '%s\n' '>>>>> Tests Errored' "$1" >&2
    exit 2
}

cd /testbed || fail 'Cannot enter /testbed'
[[ "$(git rev-parse HEAD)" == "2a159927761424440f7dbd7674992e4b5273a459" ]] || fail 'Unexpected Base commit'
git checkout 2a159927761424440f7dbd7674992e4b5273a459 -- junixsocket-jetty/src/test/java/org/eclipse/jetty/unixdomain/server/UnixDomainTest.java || fail 'Test file restoration failed'
git apply --whitespace=nowarn - <<'CLB_TEST_PATCH' || fail 'Test patch application failed'
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

mkdir -p /benchmark || fail 'Cannot create evaluation fixture directory'
cat > /benchmark/surefire_test_nodes.py <<'EOF_4c395be7a6ea' || fail 'Cannot write /benchmark/surefire_test_nodes.py'
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
                status = "FAILED"
            elif case.find("error") is not None:
                status = "ERROR"
            elif case.find("skipped") is not None:
                status = "SKIPPED"
            else:
                status = "PASSED"
            print(f"{class_name}.{method} {status}")
            found += 1
    if found == 0:
        print("No Surefire test results found", file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
EOF_4c395be7a6ea
mvn -B -o -Prelease-native \
        -pl junixsocket-native-custom,junixsocket-jetty -am clean install \
        -DskipTests \
        -Djunixsocket.custom.arch=amd64-Linux-clang-jni \
        -Djunixsocket.custom.shaded=default || fail 'Project build failed'
set +x
printf '%s\n' '>>>>> Start Test Output'
(
    report_dir=/testbed/junixsocket-jetty/target/surefire-reports
    rm -rf "$report_dir" || exit 2
    mvn -B -o -Dstyle.color=never -f junixsocket-jetty/pom.xml test \
        '-Dtest=UnixDomainTest#testHTTPOverUnixDomain'
    control_status=$?
    python3 /benchmark/surefire_test_nodes.py "$report_dir" || exit 2
    if [[ "$control_status" -ne 0 ]]; then
        exit "$control_status"
    fi

    rm -rf "$report_dir" || exit 2
    timeout --signal=TERM --kill-after=5s 30s \
        mvn -B -o -Dstyle.color=never -f junixsocket-jetty/pom.xml test \
        '-Dtest=UnixDomainTest#testLargeBody'
    target_status=$?
    if [[ "$target_status" -eq 124 || "$target_status" -eq 137 ]]; then
        printf '%s\n' 'org.eclipse.jetty.unixdomain.server.UnixDomainTest.testLargeBody ERROR'
        exit 1
    fi
    python3 /benchmark/surefire_test_nodes.py "$report_dir" || exit 2
    exit "$target_status"
)
test_status=$?
# SWE-bench records the status of the command immediately before the end marker.
(exit "$test_status")
printf '%s\n' '>>>>> End Test Output'
git checkout 2a159927761424440f7dbd7674992e4b5273a459 -- junixsocket-jetty/src/test/java/org/eclipse/jetty/unixdomain/server/UnixDomainTest.java || fail 'Test file restoration failed'
exit "$test_status"
