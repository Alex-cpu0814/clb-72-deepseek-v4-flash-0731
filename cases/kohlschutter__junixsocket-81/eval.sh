#!/bin/bash
set -uxo pipefail
cd /testbed
git config --global --add safe.directory /testbed
ulimit -c 0
[[ "$(git rev-parse HEAD)" == "90716d6008c5c9cfa8a061f3d23531acaea29777" ]] || exit 2
git status
git show --no-patch --oneline HEAD
git -c core.fileMode=false diff 90716d6008c5c9cfa8a061f3d23531acaea29777
git diff --quiet 90716d6008c5c9cfa8a061f3d23531acaea29777 -- junixsocket-common/src/test/java || exit 2
git apply -v - <<'EOF_114329324912' || exit 2
diff --git a/junixsocket-common/src/test/java/org/newsclub/net/unix/Issue81GlibcProbe.java b/junixsocket-common/src/test/java/org/newsclub/net/unix/Issue81GlibcProbe.java
new file mode 100644
index 0000000..f738f3c
--- /dev/null
+++ b/junixsocket-common/src/test/java/org/newsclub/net/unix/Issue81GlibcProbe.java
@@ -0,0 +1,34 @@
+/*
+ * junixsocket
+ *
+ * Licensed under the Apache License, Version 2.0 (the "License");
+ * you may not use this file except in compliance with the License.
+ * You may obtain a copy of the License at
+ *
+ *     http://www.apache.org/licenses/LICENSE-2.0
+ *
+ * Unless required by applicable law or agreed to in writing, software
+ * distributed under the License is distributed on an "AS IS" BASIS,
+ * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
+ * See the License for the specific language governing permissions and
+ * limitations under the License.
+ */
+package org.newsclub.net.unix;
+
+import java.io.File;
+import java.io.IOException;
+
+public final class Issue81GlibcProbe {
+  private Issue81GlibcProbe() {
+    throw new IllegalStateException("No instances");
+  }
+
+  public static void main(String[] args) throws IOException {
+    AFUNIXSocketAddress address = new AFUNIXSocketAddress(new File(args[0]));
+    try (AFUNIXServerSocket server = AFUNIXServerSocket.bindOn(address)) {
+      if (!server.isBound()) {
+        throw new AssertionError("The AF_UNIX server socket should be bound");
+      }
+    }
+  }
+}
diff --git a/junixsocket-common/src/test/java/org/newsclub/net/unix/Issue81CompatibilityTest.java b/junixsocket-common/src/test/java/org/newsclub/net/unix/Issue81CompatibilityTest.java
new file mode 100644
index 0000000..8ed595a
--- /dev/null
+++ b/junixsocket-common/src/test/java/org/newsclub/net/unix/Issue81CompatibilityTest.java
@@ -0,0 +1,91 @@
+/*
+ * junixsocket
+ *
+ * Licensed under the Apache License, Version 2.0 (the "License");
+ * you may not use this file except in compliance with the License.
+ * You may obtain a copy of the License at
+ *
+ *     http://www.apache.org/licenses/LICENSE-2.0
+ *
+ * Unless required by applicable law or agreed to in writing, software
+ * distributed under the License is distributed on an "AS IS" BASIS,
+ * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
+ * See the License for the specific language governing permissions and
+ * limitations under the License.
+ */
+package org.newsclub.net.unix;
+
+import static org.junit.jupiter.api.Assertions.assertEquals;
+import static org.junit.jupiter.api.Assertions.assertNotNull;
+import static org.junit.jupiter.api.Assertions.assertTrue;
+import static org.junit.jupiter.api.Assumptions.assumeTrue;
+
+import java.io.DataInputStream;
+import java.io.DataOutputStream;
+import java.io.IOException;
+import java.nio.charset.StandardCharsets;
+import java.nio.file.Files;
+import java.nio.file.Path;
+import java.nio.file.Paths;
+import java.util.concurrent.TimeUnit;
+
+import org.junit.jupiter.api.Test;
+import org.junit.jupiter.api.io.TempDir;
+
+public final class Issue81CompatibilityTest {
+  @TempDir
+  Path tempDir;
+
+  @Test
+  public void testAutomaticFallbackOldGlibc() throws IOException, InterruptedException {
+    String launcher = System.getProperty("junixsocket.test.legacyLauncher");
+    String legacyRoot = System.getProperty("junixsocket.test.legacyRoot");
+    assumeTrue(launcher != null || legacyRoot != null, "Requires a legacy glibc runtime");
+    assertNotNull(launcher, "Set junixsocket.test.legacyLauncher");
+    assertNotNull(legacyRoot, "Set junixsocket.test.legacyRoot");
+
+    String java = Paths.get(System.getProperty("java.home"), "bin", "java").toString();
+    String classpath = System.getProperty("surefire.test.class.path",
+        System.getProperty("java.class.path"));
+    Path log = tempDir.resolve("probe.log");
+
+    // A symbol lookup failure during bind can terminate the JVM before JUnit can report it.
+    Process probe = new ProcessBuilder(launcher, "-L", legacyRoot, java, "-Xint", "-Xms16m", "-Xmx64m",
+        "-XX:+UseSerialGC", "-XX:ActiveProcessorCount=2", "-cp", classpath,
+        Issue81GlibcProbe.class.getName(), tempDir.resolve("legacy.sock").toString())
+        .redirectErrorStream(true).redirectOutput(log.toFile()).start();
+    boolean finished;
+    try {
+      finished = probe.waitFor(30, TimeUnit.SECONDS);
+    } finally {
+      if (probe.isAlive()) {
+        probe.destroyForcibly();
+      }
+    }
+
+    String output = new String(Files.readAllBytes(log), StandardCharsets.UTF_8);
+    assertTrue(finished, () -> "Probe JVM timed out" + System.lineSeparator() + output);
+    assertEquals(0, probe.exitValue(), () -> "Probe JVM failed" + System.lineSeparator() + output);
+  }
+
+  @Test
+  public void testModernGlibcRoundTrip() throws IOException {
+    for (int i = 0; i < 3; i++) {
+      AFUNIXSocketAddress address = new AFUNIXSocketAddress(tempDir.resolve("modern-" + i + ".sock")
+          .toFile());
+      try (AFUNIXServerSocket server = AFUNIXServerSocket.bindOn(address)) {
+        server.setSoTimeout(3000);
+        try (AFUNIXSocket client = AFUNIXSocket.connectTo(address);
+            AFUNIXSocket accepted = server.accept()) {
+          client.setSoTimeout(3000);
+          accepted.setSoTimeout(3000);
+          int value = 0x1638100 + i;
+          new DataOutputStream(client.getOutputStream()).writeInt(value);
+          assertEquals(value, new DataInputStream(accepted.getInputStream()).readInt());
+          new DataOutputStream(accepted.getOutputStream()).writeInt(~value);
+          assertEquals(~value, new DataInputStream(client.getInputStream()).readInt());
+        }
+      }
+    }
+  }
+}
EOF_114329324912
mvn -B -o -ntp -Dstyle.color=never -pl junixsocket-native-common,junixsocket-native-custom -am \
        -Djunixsocket.custom.arch=amd64-Linux-clang-jni \
        '-Djunixsocket.native.clang.c.options=-Werror -Wall -Wextra -pedantic -Wno-unused-parameter -fno-strict-overflow -std=c11 -Xcrossclang-with-and-without-lc' \
        -Dcheckstyle.skip=true -Dmaven.javadoc.skip=true -Djacoco.skip=true \
        -Dpmd.skip=true -Dcpd.skip=true -Dlicense.skip=true \
        -Dspotbugs.disabled=true -Dspotbugs.skip=true \
        -DskipTests clean install || exit 2
: '>>>>> Start Test Output'
(
    mvn -B -o -ntp -Dstyle.color=never -f junixsocket-common/pom.xml -Djunixsocket.custom.arch=amd64-Linux-clang-jni -Djacoco.skip=true -Djunixsocket.test.legacyLauncher=/opt/tools/qemu-x86_64-static -Djunixsocket.test.legacyRoot=/opt/legacy test -Dtest='org.newsclub.net.unix.Issue81CompatibilityTest#testModernGlibcRoundTrip' &&
    mvn -B -o -ntp -Dstyle.color=never -f junixsocket-common/pom.xml -Djunixsocket.custom.arch=amd64-Linux-clang-jni -Djacoco.skip=true -Djunixsocket.test.legacyLauncher=/opt/tools/qemu-x86_64-static -Djunixsocket.test.legacyRoot=/opt/legacy test -Dtest='org.newsclub.net.unix.Issue81CompatibilityTest#testAutomaticFallbackOldGlibc'
) | cat
test_status=$?
(exit "$test_status")
: '>>>>> End Test Output'
rm -f -- junixsocket-common/src/test/java/org/newsclub/net/unix/Issue81CompatibilityTest.java junixsocket-common/src/test/java/org/newsclub/net/unix/Issue81GlibcProbe.java || exit 2
exit "$test_status"
