FROM docker.io/library/maven:3.9.9-eclipse-temurin-17@sha256:f58d59b6273e785ac0a4477f6e9b5ba1d7731c75b906c0f7b34076f1851318cc

ARG DEBIAN_FRONTEND=noninteractive
ENV TZ=Etc/UTC

RUN apt update && apt install -y \
    wget \
    git \
    ca-certificates \
    build-essential \
    clang \
    python3 \
    python-is-python3 \
    && rm -rf /var/lib/apt/lists/*

ENV LANG=C.UTF-8 LC_ALL=C.UTF-8

ARG REPO_URL=https://github.com/kohlschutter/junixsocket.git
ARG BASE_COMMIT=7578a2470871e12dd72716925f60d857ad7eb409
ARG INSTANCE_ID=kohlschutter__junixsocket-116

RUN <<'EOF_b1406053c7c0'
#!/bin/bash
set -euo pipefail
git --version
git clone -o origin --single-branch "$REPO_URL" /testbed
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
mvn -B -Puse-snapshots,release-native \
    -pl junixsocket-native-custom -am clean install -DskipTests \
    -Djunixsocket.custom.arch=amd64-Linux-clang-jni \
    -Djunixsocket.custom.shaded=default
mvn -B -Puse-snapshots -pl junixsocket-common -am test \
    '-Dtest=AFUNIXSocketAddressTest' -Dsurefire.failIfNoSpecifiedTests=false
rm -rf /root/.m2/repository/com/kohlschutter/junixsocket
git clean -fdx
mkdir -p /benchmark /inputs /results

test "$(git rev-parse HEAD)" = "$BASE_COMMIT"
git diff --exit-code "$BASE_COMMIT" --
worktree_status=$(git status --porcelain)
test -z "$worktree_status"
EOF_b1406053c7c0

WORKDIR /testbed
CMD ["/bin/bash"]
LABEL benchmark.instance_id="${INSTANCE_ID}" \
      benchmark.base_commit="${BASE_COMMIT}" \
      org.opencontainers.image.source="https://github.com/kohlschutter/junixsocket"
