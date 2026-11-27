#!/bin/bash
set -uxo pipefail
cd /testbed
git config --global --add safe.directory /testbed
git status
git show --no-patch --oneline HEAD
git -c core.fileMode=false diff f6c82e695f5b6964daeec2c4e0bc449a89be892a
git checkout f6c82e695f5b6964daeec2c4e0bc449a89be892a -- tditest/testing/test-treeshr.ans || exit 2
git apply -v - <<'EOF_114329324912' || exit 2
diff --git a/tditest/testing/test-treeshr.ans b/tditest/testing/test-treeshr.ans
index df6b7e82c0ebe73d5e2a608d23e0fdea9e3d4bfa..f443686d66c54261f4dde23488ceda667330c55c 100644
--- a/tditest/testing/test-treeshr.ans
+++ b/tditest/testing/test-treeshr.ans
@@ -140,7 +140,7 @@ getnci(.subtree:a12,"parent_relationship")
 getnci(.subtree:a12,"get_flags")
 128LU
 getnci(.subtree:a12,"owner_id")
-4194368LU
+64LU
 getnci(.subtree:a12,"status")
 0LU
 getnci(.subtree:a12,"brother")
EOF_114329324912
./bootstrap && make -C /build || exit 2
: '>>>>> Start Test Output'
(make -C /build/tditest/testing check TESTS='test-tdishr.tdi test-treeshr.tdi') | cat
: '>>>>> End Test Output'
git checkout f6c82e695f5b6964daeec2c4e0bc449a89be892a -- tditest/testing/test-treeshr.ans
