#!/bin/bash
set -uxo pipefail
cd /testbed
git config --global --add safe.directory /testbed
git status
git show --no-patch --oneline HEAD
git -c core.fileMode=false diff 2a159927761424440f7dbd7674992e4b5273a459
git checkout 2a159927761424440f7dbd7674992e4b5273a459 -- junixsocket-jetty/src/test/java/org/eclipse/jetty/unixdomain/server/UnixDomainTest.java || exit 2
git apply -v - <<'EOF_114329324912' || exit 2
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
EOF_114329324912
mvn -B -o -Prelease-native \
        -pl junixsocket-native-custom,junixsocket-jetty -am clean install \
        -DskipTests \
        -Djunixsocket.custom.arch=amd64-Linux-clang-jni \
        -Djunixsocket.custom.shaded=default || exit 2
: '>>>>> Start Test Output'
(mvn -B -o -Dstyle.color=never -f junixsocket-jetty/pom.xml test \
    -Dtest=org.eclipse.jetty.unixdomain.server.UnixDomainTest#testHTTPOverUnixDomain && \
mvn -B -o -Dstyle.color=never -f junixsocket-jetty/pom.xml test -Dsurefire.timeout=30 \
    -Dtest=org.eclipse.jetty.unixdomain.server.UnixDomainTest#testLargeBody) | cat
: '>>>>> End Test Output'
git checkout 2a159927761424440f7dbd7674992e4b5273a459 -- junixsocket-jetty/src/test/java/org/eclipse/jetty/unixdomain/server/UnixDomainTest.java
