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
    pip==21.3.1 setuptools==59.6.0 wheel==0.37.1 \
    numpy==1.14.5 pytest==3.6.3 hypothesis==3.66.32 coverage==4.5.1 \
    attrs==19.3.0 py==1.5.4 pluggy==0.6.0 atomicwrites==1.1.5 \
    more-itertools==4.2.0 six==1.11.0 sortedcontainers==2.1.0

ARG REPO_URL=https://github.com/astrofrog/fast-histogram.git
ARG BASE_COMMIT=76b6f57a27f31cdefc23444f91611a00c9b4332d
ARG INSTANCE_ID=astrofrog__fast-histogram-21

RUN <<'EOF_b1406053c7c0'
#!/bin/bash
set -euo pipefail
git --version
git clone -o origin --single-branch "$REPO_URL" /testbed
cd /testbed
git reset --hard "$BASE_COMMIT"
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
python -c 'import fast_histogram as pkg, fast_histogram._histogram_core as native, numpy; print(pkg.__version__, numpy.__version__, native.__file__); assert pkg.__version__ == "0.5.dev0"; assert numpy.__version__ == "1.14.5"; assert native.__file__.startswith("/testbed/fast_histogram/_histogram_core.")'
git checkout HEAD -- .
printf '%s\n' '/build/' '**/__pycache__/' '*.pyc' '*.so' '/fast_histogram.egg-info/' >> .git/info/exclude

test "$(git rev-parse HEAD)" = "$BASE_COMMIT"
git diff --exit-code "$BASE_COMMIT" --
worktree_status=$(git status --porcelain)
test -z "$worktree_status"
EOF_b1406053c7c0

WORKDIR /testbed
CMD ["/bin/bash"]
