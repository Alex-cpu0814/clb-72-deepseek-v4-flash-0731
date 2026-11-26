#!/bin/bash
set -uxo pipefail
cd /testbed
git config --global --add safe.directory /testbed
git status
git show --no-patch --oneline HEAD
git -c core.fileMode=false diff 7e58cea7c2551d0b590eff3959341ee823ec43c1
git checkout 7e58cea7c2551d0b590eff3959341ee823ec43c1 -- src/test/python/jpy_overload_test.py
git apply -v - <<'EOF_114329324912'
diff --git a/src/test/python/jpy_overload_test.py b/src/test/python/jpy_overload_test.py
index 5df06e9..84d5569 100644
--- a/src/test/python/jpy_overload_test.py
+++ b/src/test/python/jpy_overload_test.py
@@ -99,9 +99,10 @@ class TestStaticMethodOverloads(unittest.TestCase):
         String = jpy.get_type('java.lang.String')
         Arrays = jpy.get_type('java.util.Arrays')
         a = jpy.array(String, ['A', 'B', 'C'])
+        #jpy.diag.flags = jpy.diag.F_METH
         s = Arrays.toString(a)
-        print("Arrays.toString: " + str(type(Arrays.toString)))
-        self.assertEqual(str(s), '[A,B,C]')
+        #jpy.diag.flags = 0
+        self.assertEqual(str(s), '[A, B, C]')
 
 
 
EOF_114329324912
(python2.7 setup.py clean build_ext --inplace --force && mvn -o -B clean test-compile) || exit 2
: '>>>>> Start Test Output'
(python2.7 /opt/clb/run_unittest.py \
    src/test/python/jpy_overload_test.py::TestMethodOverloads::test_2ArgOverloadsWithVaryingTypes \
    src/test/python/jpy_overload_test.py::TestMethodOverloads::test_nArgOverloads \
    src/test/python/jpy_overload_test.py::TestMethodOverloads::test_nArgOverloadsAreFoundInBaseClass \
    src/test/python/jpy_overload_test.py::TestStaticMethodOverloads::test_staticMethodIsFoundOverNonStatic) | cat
: '>>>>> End Test Output'
git checkout 7e58cea7c2551d0b590eff3959341ee823ec43c1 -- src/test/python/jpy_overload_test.py
