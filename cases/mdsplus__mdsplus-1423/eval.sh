#!/bin/bash
set -uxo pipefail
cd /testbed
git config --global --add safe.directory /testbed
git status
git show --no-patch --oneline HEAD
git -c core.fileMode=false diff a73d6e87149698e49026e3bf8055efc6bbe71d90
git checkout a73d6e87149698e49026e3bf8055efc6bbe71d90 -- tditest/testing/test-treeshr.ans tditest/testing/test-treeshr.tdi || exit 2
git apply -v - <<'EOF_114329324912' || exit 2
diff --git a/tditest/testing/test-treeshr.ans b/tditest/testing/test-treeshr.ans
index dd8bccbc1..60452431a 100644
--- a/tditest/testing/test-treeshr.ans
+++ b/tditest/testing/test-treeshr.ans
@@ -18,6 +18,12 @@ getnci('?ember','fullpath')
 "\\MAIN::TOP:MEMBER"
 getnci('%ember','fullpath')
 ["\\MAIN::TOP:MEMBER"]
+getnci('\n','fullpath')
+%TREE-W-NNF, Node Not Found
+%TDI Error in GETNCI("\n", "fullpath")
+%TDI Error in EVALUATE(GETNCI("\n", "fullpath"))
+%TDI Error in EXECUTE("getnci('\\n','fullpath')")
+
 _tim=getnci(member,'time_inserted')
 49776423271761650QU
 date_time(_tim)
diff --git a/tditest/testing/test-treeshr.tdi b/tditest/testing/test-treeshr.tdi
index 4712199cf..9d6510c2d 100644
--- a/tditest/testing/test-treeshr.tdi
+++ b/tditest/testing/test-treeshr.tdi
@@ -9,6 +9,7 @@ getnci(member,'length')
 getnci(member,'on')
 getnci('?ember','fullpath')
 getnci('%ember','fullpath')
+getnci('\n','fullpath')
 _tim=getnci(member,'time_inserted')
 date_time(_tim)
 .subtree:a12:name
EOF_114329324912
make -C /build && make -C /build install || exit 2
: '>>>>> Start Test Output'
(make -C /build/tditest/testing check TESTS=test-tdishr.tdi && make -C /build/tditest/testing check TESTS=test-treeshr.tdi) | cat
: '>>>>> End Test Output'
git checkout a73d6e87149698e49026e3bf8055efc6bbe71d90 -- tditest/testing/test-treeshr.ans tditest/testing/test-treeshr.tdi
