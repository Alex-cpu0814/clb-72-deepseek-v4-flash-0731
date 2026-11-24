#!/bin/bash
set -uxo pipefail
cd /testbed
git config --global --add safe.directory /testbed
git status
git show --no-patch --oneline HEAD
git -c core.fileMode=false diff c86628cad04edc5167f9a9c8999abc62c6558e7b
git checkout c86628cad04edc5167f9a9c8999abc62c6558e7b -- Cheetah/Tests/SyntaxAndOutput.py
git apply -v - <<'EOF_114329324912'
diff --git a/Cheetah/Tests/SyntaxAndOutput.py b/Cheetah/Tests/SyntaxAndOutput.py
index c6fa39d..a2ee63c 100755
--- a/Cheetah/Tests/SyntaxAndOutput.py
+++ b/Cheetah/Tests/SyntaxAndOutput.py
@@ -3049,6 +3049,12 @@ class GetVar(OutputTest):               # Template.getVar()
         self.verify("$getVar('$bogus',  1234)",
                     "1234")
 
+    def test6(self):
+        """$getVar('$') raises ValueError
+        """
+        with self.assertRaises(ValueError):
+            self.verify("$getVar('$')", "never get here")
+
 
 class MiscComplexSyntax(OutputTest):
     def test1(self):
EOF_114329324912
: '>>>>> Start Test Output'
(./buildandrun --clean -- Cheetah/Tests/SyntaxAndOutput.py -v GetVar.test1 GetVar.test2 GetVar.test6 2>&1) | cat
: '>>>>> End Test Output'
git checkout c86628cad04edc5167f9a9c8999abc62c6558e7b -- Cheetah/Tests/SyntaxAndOutput.py
