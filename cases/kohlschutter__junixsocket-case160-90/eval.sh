#!/bin/bash
set -uxo pipefail
cd /testbed
git config --global --add safe.directory /testbed
git status
git show --no-patch --oneline HEAD
git -c core.fileMode=false diff ba3d20f60e7fbf1a49ae1f4bac09111299d104ee
git checkout ba3d20f60e7fbf1a49ae1f4bac09111299d104ee -- junixsocket-common/src/test/java/org/newsclub/net/unix/SoTimeoutTest.java || exit 2
git apply -v - <<'EOF_114329324912' || exit 2
diff --git a/junixsocket-common/src/test/java/org/newsclub/net/unix/SoTimeoutTest.java b/junixsocket-common/src/test/java/org/newsclub/net/unix/SoTimeoutTest.java
index c1731641..b1ff3691 100644
--- a/junixsocket-common/src/test/java/org/newsclub/net/unix/SoTimeoutTest.java
+++ b/junixsocket-common/src/test/java/org/newsclub/net/unix/SoTimeoutTest.java
@@ -24,6 +24,7 @@ import static org.junit.jupiter.api.Assertions.assertTrue;
 import java.io.File;
 import java.io.IOException;
 import java.io.InputStream;
+import java.io.OutputStream;
 import java.net.Socket;
 import java.net.SocketException;
 import java.net.SocketTimeoutException;
@@ -105,7 +106,7 @@ public class SoTimeoutTest extends SocketTestBase {
   }
 
   @Test
-  public void testSocketTimeoutException() throws Exception {
+  public void testSocketTimeoutExceptionRead() throws Exception {
     final File tempFile = newTempFile();
     final AFUNIXSocketAddress address = AFUNIXSocketAddress.of(tempFile);
     try (AFUNIXServerSocket server = AFUNIXServerSocket.bindOn(address);
@@ -123,4 +124,25 @@ public class SoTimeoutTest extends SocketTestBase {
       tempFile.delete();
     }
   }
+
+  @Test
+  public void testSocketTimeoutExceptionWrite() throws Exception {
+    final File tempFile = newTempFile();
+    final AFUNIXSocketAddress address = AFUNIXSocketAddress.of(tempFile);
+    try (AFUNIXServerSocket server = AFUNIXServerSocket.bindOn(address);
+        AFUNIXSocket client = AFUNIXSocket.connectTo(address)) {
+
+      final AFUNIXSocket socket = server.accept();
+      socket.setSoTimeout(500);
+      byte[] buf = new byte[socket.getSendBufferSize()];
+      OutputStream out = socket.getOutputStream();
+
+      assertThrows(SocketTimeoutException.class, () -> {
+        out.write(buf);
+        out.write(buf);
+      });
+    } finally {
+      tempFile.delete();
+    }
+  }
 }
EOF_114329324912
mvn -B -o -Prelease-native \
        -pl junixsocket-native-common,junixsocket-native-custom -am clean install \
        -Dmaven.test.skip=true \
        -Djunixsocket.custom.arch=amd64-Linux-clang-jni \
        -Djunixsocket.custom.shaded=default || exit 2
: '>>>>> Start Test Output'
(mvn -B -o -Dstyle.color=never -f junixsocket-common/pom.xml test \
    -Dtest=org.newsclub.net.unix.SoTimeoutTest#testSocketTimeoutExceptionRead && \
mvn -B -o -Dstyle.color=never -f junixsocket-common/pom.xml test \
    -Dsurefire.timeout=15 -Dtest=org.newsclub.net.unix.SoTimeoutTest#testSocketTimeoutExceptionWrite) | cat
: '>>>>> End Test Output'
git checkout ba3d20f60e7fbf1a49ae1f4bac09111299d104ee -- junixsocket-common/src/test/java/org/newsclub/net/unix/SoTimeoutTest.java
