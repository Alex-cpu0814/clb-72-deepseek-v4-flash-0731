#!/bin/bash
set -uo pipefail
ulimit -c 0

fail() {
    printf '%s\n' '>>>>> Tests Errored' "$1" >&2
    exit 2
}

cd /testbed || fail 'Cannot enter /testbed'
[[ "$(git rev-parse HEAD)" == "20cdbb714300bdb2502d9ac44740c85c64cce691" ]] || fail 'Unexpected Base commit'
git checkout 20cdbb714300bdb2502d9ac44740c85c64cce691 -- src/test/python/jpy_array_test.py || fail 'Test file restoration failed'
git apply --whitespace=nowarn - <<'EOF_114329324912' || fail 'Test patch application failed'
diff --git a/src/test/python/jpy_array_test.py b/src/test/python/jpy_array_test.py
index 85f159e..431011e 100644
--- a/src/test/python/jpy_array_test.py
+++ b/src/test/python/jpy_array_test.py
@@ -98,6 +98,16 @@ class TestJavaArrays(unittest.TestCase):
         self.do_test_array_protocol('java.lang.Object', [None, None, None], [File('A'), 'B', 3])
 
 
+    # see https://github.com/bcdev/jpy/issues/52
+    def test_array_item_del(self):
+        Integer = jpy.get_type('java.lang.Integer')
+        a = jpy.array(Integer, 3)
+        try:
+            del a[1]
+        except RuntimeError as err:
+            self.assertEqual(err.args[0], 'cannot delete items of Java arrays')
+
+
     def do_test_basic_buffer_protocol(self, type, itemsize, values):
 
         a = jpy.array(type, 4)
EOF_114329324912

(python2.7 setup.py clean build_ext --inplace --force && mvn -o -B clean test-compile) || fail 'Project build failed'
set +x
printf '%s\n' '>>>>> Start Test Output'
python2.7 -m pytest --forked -vv -rA --color=no -o console_output_style=classic -p no:cacheprovider \
    src/test/python/jpy_array_test.py::TestJavaArrays::test_array_int \
    src/test/python/jpy_array_test.py::TestJavaArrays::test_array_object \
    src/test/python/jpy_array_test.py::TestJavaArrays::test_buffer_int \
    src/test/python/jpy_array_test.py::TestJavaArrays::test_array_item_del
test_status=$?
# SWE-bench records the status of the command immediately before the end marker.
(exit "$test_status")
printf '%s\n' '>>>>> End Test Output'
git checkout 20cdbb714300bdb2502d9ac44740c85c64cce691 -- src/test/python/jpy_array_test.py || fail 'Test file restoration failed'
exit "$test_status"
