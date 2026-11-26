"""Run JPY's unittest entry point in a fresh process for each case."""

from __future__ import print_function

import argparse
import resource
import subprocess
import sys


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("nodes", nargs="+", metavar="FILE::CLASS::METHOD")
    args = parser.parse_args()
    resource.setrlimit(resource.RLIMIT_CORE, (0, 0))

    any_failed = False
    for node in args.nodes:
        path, test_class, method = node.split("::")
        child = subprocess.Popen(
            [sys.executable, path, "-v", test_class + "." + method],
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
        )
        output, _ = child.communicate()
        sys.stdout.write(output)
        if output and not output.endswith("\n"):
            print()

        label = "{} (__main__.{}) ...".format(method, test_class)
        lines = output.splitlines()
        if child.returncode == 0 and label + " ok" in lines:
            status = "PASSED"
        elif child.returncode != 0 and any(line.startswith(label) for line in lines):
            print("unittest process return code: {}".format(child.returncode), file=sys.stderr)
            status = "FAILED"
            any_failed = True
        else:
            print("Missing unittest result for {}".format(node), file=sys.stderr)
            return 2
        print("{} {}".format(status, node))

    return int(any_failed)


if __name__ == "__main__":
    sys.exit(main())
