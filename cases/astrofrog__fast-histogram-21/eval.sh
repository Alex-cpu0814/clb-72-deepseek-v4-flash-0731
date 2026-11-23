#!/bin/bash
set -uxo pipefail
cd /testbed
git config --global --add safe.directory /testbed
git status
git show --no-patch --oneline HEAD
git -c core.fileMode=false diff 76b6f57a27f31cdefc23444f91611a00c9b4332d
git checkout 76b6f57a27f31cdefc23444f91611a00c9b4332d -- fast_histogram/tests/test_histogram.py
git apply -v - <<'CLB_TEST_PATCH'
diff --git a/fast_histogram/tests/test_histogram.py b/fast_histogram/tests/test_histogram.py
index 2215f02..0771e6a 100644
--- a/fast_histogram/tests/test_histogram.py
+++ b/fast_histogram/tests/test_histogram.py
@@ -85,3 +85,21 @@ def test_2d_compare_with_numpy(size, nx, xmin, xmax, ny, ymin, ymax, weights):
                        range=((xmin, xmax), (ymin, ymax)))
 
     np.testing.assert_equal(fast, reference)
+
+
+def test_nd_arrays():
+
+    x = np.random.random(1000)
+
+    result_1d = histogram1d(x, bins=10, range=(0, 1))
+    result_3d = histogram1d(x.reshape((10, 10, 10)), bins=10, range=(0, 1))
+
+    np.testing.assert_equal(result_1d, result_3d)
+
+    y = np.random.random(1000)
+
+    result_1d = histogram2d(x, y, bins=(10, 10), range=[(0, 1), (0, 1)])
+    result_3d = histogram2d(x.reshape((10, 10, 10)), y.reshape((10, 10, 10)),
+                            bins=(10, 10), range=[(0, 1), (0, 1)])
+
+    np.testing.assert_equal(result_1d, result_3d)
CLB_TEST_PATCH
python setup.py build_ext --inplace --force || exit 2
: '>>>>> Start Test Output'
(python -m pytest -vv --color=no -o console_output_style=classic -p no:warnings --hypothesis-show-statistics \
    fast_histogram/tests/test_histogram.py::test_1d_compare_with_numpy \
    fast_histogram/tests/test_histogram.py::test_2d_compare_with_numpy \
    fast_histogram/tests/test_histogram.py::test_nd_arrays) | cat
: '>>>>> End Test Output'
git checkout 76b6f57a27f31cdefc23444f91611a00c9b4332d -- fast_histogram/tests/test_histogram.py
