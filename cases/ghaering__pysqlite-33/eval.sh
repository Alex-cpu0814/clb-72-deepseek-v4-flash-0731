#!/bin/bash
set -uxo pipefail
cd /testbed
git config --global --add safe.directory /testbed
git status
git show --no-patch --oneline HEAD
git -c core.fileMode=false diff d7c44a6b62ccf27ae2a006d32dc25cd49ca45320
git checkout d7c44a6b62ccf27ae2a006d32dc25cd49ca45320 -- lib/test/hooks.py
git apply -v - <<'EOF_114329324912'
diff --git a/lib/test/hooks.py b/lib/test/hooks.py
index e7cd49d..60adb5b 100644
--- a/lib/test/hooks.py
+++ b/lib/test/hooks.py
@@ -152,10 +152,31 @@ class ProgressTests(unittest.TestCase):
         con.execute("select 1 union select 2 union select 3").fetchall()
         self.assertEqual(action, 0, "progress handler was not cleared")
 
+class LimitTests(unittest.TestCase):
+    def CheckGetLimit(self):
+        """
+        Test that the get limit method return something useful.
+        """
+        con = sqlite.connect(":memory:")
+        val = con.get_limit(sqlite.SQLITE_LIMIT_VARIABLE_NUMBER)
+        self.assertTrue(val > 0)
+
+    def CheckSetLimit(self):
+        """
+        Test that the set limit method actally changes limits.
+        """
+        con = sqlite.connect(":memory:")
+        oldval = con.get_limit(sqlite.SQLITE_LIMIT_VARIABLE_NUMBER)
+        con.set_limit(sqlite.SQLITE_LIMIT_VARIABLE_NUMBER, oldval - 1)
+        newval = con.get_limit(sqlite.SQLITE_LIMIT_VARIABLE_NUMBER)
+
+        self.assertEqual(newval, oldval - 1)
+
 def suite():
     collation_suite = unittest.makeSuite(CollationTests, "Check")
     progress_suite = unittest.makeSuite(ProgressTests, "Check")
-    return unittest.TestSuite((collation_suite, progress_suite))
+    limit_suite = unittest.makeSuite(LimitTests, "Check")
+    return unittest.TestSuite((collation_suite, progress_suite, limit_suite))
 
 def test():
     runner = unittest.TextTestRunner()
EOF_114329324912
python2.7 setup.py build_ext --force build_py --force || exit 2
: '>>>>> Start Test Output'
(python2.7 -m unittest -v \
    pysqlite2.test.hooks.CollationTests.CheckCreateCollationNotCallable \
    pysqlite2.test.hooks.ProgressTests.CheckProgressHandlerUsed \
    pysqlite2.test.hooks.ProgressTests.CheckCancelOperation \
    pysqlite2.test.hooks.LimitTests.CheckGetLimit \
    pysqlite2.test.hooks.LimitTests.CheckSetLimit 2>&1) | cat
: '>>>>> End Test Output'
git checkout d7c44a6b62ccf27ae2a006d32dc25cd49ca45320 -- lib/test/hooks.py
