FROM public.ecr.aws/docker/library/python:3.6.15-buster@sha256:56ba32a1c5aa030914cc957f1c9fe58d9d462bdf89a1e5f2b4dbdda68085327e

ARG DEBIAN_FRONTEND=noninteractive
ENV TZ=Etc/UTC

# Debian Buster packages are served from the signed archive.
RUN printf '%s\n' \
    'deb [check-valid-until=no] https://archive.debian.org/debian buster main' \
    'deb [check-valid-until=no] https://archive.debian.org/debian-security buster/updates main' \
    > /etc/apt/sources.list

RUN apt update && apt install -y \
    wget \
    git \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

ENV PYTHONUNBUFFERED=1 LC_ALL=C.UTF-8 LANG=C.UTF-8 PYTHONPATH=/testbed

RUN python -m pip install --no-cache-dir \
    pip==21.3.1 setuptools==59.6.0 wheel==0.37.1 setuptools_scm==3.3.3 \
    numpy==1.15.4 pytest==5.4.2 hypothesis==5.16.0 attrs==19.3.0 \
    sortedcontainers==2.1.0 py==1.8.1 pluggy==0.13.1 packaging==20.4 \
    pyparsing==2.4.7 more-itertools==8.3.0 wcwidth==0.1.9 \
    importlib-metadata==1.6.0 zipp==3.1.0 six==1.15.0

ARG REPO_URL=https://github.com/astrofrog/fast-histogram.git
ARG BASE_COMMIT=085efdad6570e25440beab781ef70e1f81605c12
ARG INSTANCE_ID=astrofrog__fast-histogram-52

RUN <<'EOF_b1406053c7c0'
#!/bin/bash
set -euo pipefail
git --version
git clone -o origin --single-branch "$REPO_URL" /testbed
cd /testbed
git reset --hard "$BASE_COMMIT"
# setuptools_scm uses v0.8 to derive the package version.
test "$(git rev-parse 'refs/tags/v0.8^{commit}')" = "$BASE_COMMIT"
# Git 2.20.1 can fail during gc if origin/HEAD is left dangling.
if git symbolic-ref --quiet refs/remotes/origin/HEAD >/dev/null; then git symbolic-ref --delete refs/remotes/origin/HEAD; fi
git remote remove origin
base_epoch=$(git show -s --format=%ct "$BASE_COMMIT")
for tag in $(git tag -l); do if tag_epoch=$(git log -1 --format=%ct "refs/tags/$tag" -- 2>/dev/null) && [[ -n "$tag_epoch" && "$tag_epoch" -gt "$base_epoch" ]]; then git tag -d "$tag"; fi; done
git branch | grep -v '^\*' | xargs -r git branch -D || true
git reflog expire --expire=now --all
git gc --prune=now --aggressive
newer_commits=$(git rev-list --count --all --since="@$((base_epoch + 1))")
test "$newer_commits" -eq 0
git config core.autocrlf false
python setup.py build_ext --inplace --force
python -c 'import fast_histogram as pkg, fast_histogram._histogram_core as native, numpy; print(pkg.__version__, numpy.__version__, native.__file__); assert pkg.__version__ == "0.8"; assert numpy.__version__ == "1.15.4"; assert native.__file__.startswith("/testbed/fast_histogram/_histogram_core.")'
git checkout HEAD -- .
printf '%s\n' '/build/' '**/__pycache__/' '*.pyc' '*.so' '/fast_histogram/version.py' '/fast_histogram.egg-info/' >> .git/info/exclude

test "$(git rev-parse HEAD)" = "$BASE_COMMIT"
git diff --exit-code "$BASE_COMMIT" --
worktree_status=$(git status --porcelain)
test -z "$worktree_status"
EOF_b1406053c7c0

WORKDIR /testbed
CMD ["/bin/bash"]
