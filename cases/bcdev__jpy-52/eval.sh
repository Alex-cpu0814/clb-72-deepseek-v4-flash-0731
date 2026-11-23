#!/bin/bash
set -uxo pipefail
cd /testbed
git config --global --add safe.directory /testbed
git status
git show --no-patch --oneline HEAD
git -c core.fileMode=false diff 20cdbb714300bdb2502d9ac44740c85c64cce691
git checkout 20cdbb714300bdb2502d9ac44740c85c64cce691 -- src/test/python/jpy_array_test.py
git apply -v - <<'CLB_TEST_PATCH'
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
CLB_TEST_PATCH
(python2.7 setup.py clean build_ext --inplace --force && mkdir -p target/test-classes && javac -d target/test-classes src/main/java/org/jpy/annotations/*.java src/test/java/org/jpy/fixtures/*.java) || exit 2
: '>>>>> Start Test Output'
(
set +x
export PYTHONPATH="src/test/python${PYTHONPATH:+:$PYTHONPATH}"
# OpenJDK 8 can report a fatal error without writing a core dump.
export JAVA_TOOL_OPTIONS="${JAVA_TOOL_OPTIONS:+$JAVA_TOOL_OPTIONS }-XX:-CreateMinidumpOnCrash"

run_group() {
    local group=$1 output status=0
    shift
    output=$(python2.7 -m unittest -v "$@" 2>&1) || status=$?
    printf '%s\n' "$output"
    # unittest may exit zero for skipped tests, with a qualified OK summary.
    if [[ $status == 0 && ${output##*$'\n'} == OK ]]; then
        printf 'PASS: %s\n' "$group"
        return 0
    fi
    printf 'FAIL: %s\n' "$group"
    return "$((status == 0 ? 1 : status))"
}

test_status=0
run_group java_array_regressions \
    jpy_array_test.TestJavaArrays.test_array_int \
    jpy_array_test.TestJavaArrays.test_array_object \
    jpy_array_test.TestJavaArrays.test_buffer_int || test_status=$?
run_group java_array_item_deletion \
    jpy_array_test.TestJavaArrays.test_array_item_del || test_status=$?
exit "$test_status"
) | cat
: '>>>>> End Test Output'
git checkout 20cdbb714300bdb2502d9ac44740c85c64cce691 -- src/test/python/jpy_array_test.py
