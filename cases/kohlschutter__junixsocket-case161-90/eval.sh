#!/bin/bash
set -uxo pipefail
cd /testbed
git config --global --add safe.directory /testbed
git status
git show --no-patch --oneline HEAD
git -c core.fileMode=false diff 1df1513c64079a5100cdc2a372558e1f77849c0f
git checkout 1df1513c64079a5100cdc2a372558e1f77849c0f -- junixsocket-common/src/test/java/org/newsclub/net/unix/SoTimeoutTest.java || exit 2
git apply -v - <<'EOF_114329324912' || exit 2
diff --git a/junixsocket-common/src/test/java/org/newsclub/net/unix/SoTimeoutTest.java b/junixsocket-common/src/test/java/org/newsclub/net/unix/SoTimeoutTest.java
index 00be130..c173164 100644
--- a/junixsocket-common/src/test/java/org/newsclub/net/unix/SoTimeoutTest.java
+++ b/junixsocket-common/src/test/java/org/newsclub/net/unix/SoTimeoutTest.java
@@ -18,12 +18,15 @@
 package org.newsclub.net.unix;
 
 import static org.junit.jupiter.api.Assertions.assertFalse;
+import static org.junit.jupiter.api.Assertions.assertThrows;
 import static org.junit.jupiter.api.Assertions.assertTrue;
 
+import java.io.File;
 import java.io.IOException;
 import java.io.InputStream;
 import java.net.Socket;
 import java.net.SocketException;
+import java.net.SocketTimeoutException;
 import java.util.concurrent.Semaphore;
 import java.util.concurrent.TimeUnit;
 
@@ -100,4 +103,24 @@ public class SoTimeoutTest extends SocketTestBase {
       }
     }
   }
+
+  @Test
+  public void testSocketTimeoutException() throws Exception {
+    final File tempFile = newTempFile();
+    final AFUNIXSocketAddress address = AFUNIXSocketAddress.of(tempFile);
+    try (AFUNIXServerSocket server = AFUNIXServerSocket.bindOn(address);
+        AFUNIXSocket client = AFUNIXSocket.connectTo(address)) {
+
+      final AFUNIXSocket socket = server.accept();
+      socket.setSoTimeout(500);
+      byte[] buf = new byte[socket.getReceiveBufferSize()];
+      InputStream in = socket.getInputStream();
+
+      assertThrows(SocketTimeoutException.class, () -> {
+        in.read(buf);
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
        '-Djunixsocket.native.clang.c.options=-Wall -Wextra -Wno-reserved-id-macro -Wno-undef -Wno-cast-qual -Wno-disabled-macro-expansion -Wno-language-extension-token -Wno-gnu-auto-type -Wno-c++11-extensions -Wno-c++98-compat -Wno-empty-translation-unit -Wno-gnu-empty-initializer -Werror-implicit-function-declaration -Wint-conversion -Wno-unused-command-line-argument -fno-strict-overflow -finline-functions -fwrapv -fPIC -fvisibility=hidden -fno-common -Os -std=gnu11 -Djunixsocket_use_poll_for_read' \
        -Djunixsocket.custom.arch=amd64-Linux-clang-jni \
        -Djunixsocket.custom.shaded=default || exit 2
: '>>>>> Start Test Output'
(mvn -B -o -Dstyle.color=never -f junixsocket-common/pom.xml test \
    -Dtest=org.newsclub.net.unix.SoTimeoutTest#issue14Pass && \
mvn -B -o -Dstyle.color=never -f junixsocket-common/pom.xml test \
    -Dsurefire.timeout=30 -Dtest=org.newsclub.net.unix.SoTimeoutTest#testSocketTimeoutException) | cat
: '>>>>> End Test Output'
git checkout 1df1513c64079a5100cdc2a372558e1f77849c0f -- junixsocket-common/src/test/java/org/newsclub/net/unix/SoTimeoutTest.java
