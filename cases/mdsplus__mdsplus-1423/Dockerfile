FROM docker.io/library/ubuntu:20.04@sha256:8feb4d8ca5354def3d8fce243717141ce31e2c428701f6682bd2fafe15388214

ARG DEBIAN_FRONTEND=noninteractive
ENV TZ=Etc/UTC

RUN printf '%s\n' \
    'Acquire::Retries "5";' \
    'APT::Install-Recommends "false";' \
    > /etc/apt/apt.conf.d/99-clb-downloads \
    && apt-get update \
    && apt-get install -y ca-certificates \
    && sed -i 's|http://|https://|g' /etc/apt/sources.list

RUN apt update && for attempt in 1 2 3 4; do \
    apt install -y \
    wget \
    git \
    ca-certificates \
    autoconf \
    automake \
    bison \
    build-essential \
    flex \
    gfortran \
    liblzma-dev \
    libreadline-dev \
    libtool \
    libxml2-dev \
    openjdk-11-jdk-headless \
    pkg-config \
    python3 \
    python-is-python3 && break; \
    test "$attempt" -lt 4 || exit 1; \
    done \
    && rm -rf /var/lib/apt/lists/*

ENV LANG=C.UTF-8 LC_ALL=C.UTF-8

ARG REPO_URL=https://github.com/MDSplus/mdsplus.git
ARG BASE_COMMIT=a73d6e87149698e49026e3bf8055efc6bbe71d90
ARG INSTANCE_ID=mdsplus__mdsplus-1423

RUN <<'EOF_b1406053c7c0'
#!/bin/bash
set -euo pipefail
git --version
git clone -o origin --branch alpha_release-7-54-3 --single-branch "$REPO_URL" /testbed
cd /testbed
git reset --hard "$BASE_COMMIT"
git remote remove origin
base_epoch=$(git show -s --format=%ct "$BASE_COMMIT")
for tag in $(git tag -l); do if tag_epoch=$(git log -1 --format=%ct "refs/tags/$tag" -- 2>/dev/null) && [[ -n "$tag_epoch" && "$tag_epoch" -gt "$base_epoch" ]]; then git tag -d "$tag"; fi; done
git branch | grep -v '^\*' | xargs -r git branch -D || true
git reflog expire --expire=now --all
git gc --prune=now --aggressive
newer_commits=$(git rev-list --count --all --since="@$((base_epoch + 1))")
test "$newer_commits" -eq 0
git config core.autocrlf false
mkdir -p /build /benchmark /inputs /results
(
    cd /build
    NOF77=yes /testbed/configure --prefix=/usr/local/mdsplus --disable-java --without-x
    make
    make install
)
make -C /build/tditest/testing check TESTS=test-tdishr.tdi
git clean -fdx

test "$(git rev-parse HEAD)" = "$BASE_COMMIT"
git diff --exit-code "$BASE_COMMIT" --
worktree_status=$(git status --porcelain)
test -z "$worktree_status"
EOF_b1406053c7c0

WORKDIR /testbed
CMD ["/bin/bash"]
