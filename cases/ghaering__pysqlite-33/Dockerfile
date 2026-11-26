FROM public.ecr.aws/ubuntu/ubuntu:18.04@sha256:975b418c2c6c72bdfb978ac631c3fae2f42b752f5ab29dec706a01f3f6acc14b

ARG DEBIAN_FRONTEND=noninteractive
ENV TZ=Etc/UTC

RUN apt update && apt install -y \
    wget \
    git \
    ca-certificates \
    build-essential \
    pkg-config \
    python-minimal \
    python2.7 \
    python2.7-dev \
    libsqlite3-dev \
    && rm -rf /var/lib/apt/lists/*

ENV PYTHONUNBUFFERED=1 LC_ALL=C.UTF-8 LANG=C.UTF-8 PYTHONPATH=/testbed/build/lib.linux-x86_64-2.7

ARG REPO_URL=https://github.com/ghaering/pysqlite.git
ARG BASE_COMMIT=d7c44a6b62ccf27ae2a006d32dc25cd49ca45320
ARG INSTANCE_ID=ghaering__pysqlite-33

RUN <<'EOF_b1406053c7c0'
#!/bin/bash
set -euo pipefail
git --version
git clone -o origin --single-branch "$REPO_URL" /testbed
cd /testbed
git reset --hard "$BASE_COMMIT"
# Git 2.17.1 can fail during gc if origin/HEAD is left dangling.
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
python2.7 setup.py build_ext --force build_py --force
python2.7 -c "import pysqlite2.dbapi2 as db,pysqlite2._sqlite as native; print(db.version,db.sqlite_version,native.__file__); assert db.version == '2.6.3'; assert native.__file__.startswith('/testbed/build/lib.linux-x86_64-2.7/pysqlite2/_sqlite')"
git checkout HEAD -- .
printf '%s\n' '/build/' '*.pyc' >> .git/info/exclude

test "$(git rev-parse HEAD)" = "$BASE_COMMIT"
git diff --exit-code "$BASE_COMMIT" --
worktree_status=$(git status --porcelain)
test -z "$worktree_status"
EOF_b1406053c7c0

WORKDIR /testbed
CMD ["/bin/bash"]
