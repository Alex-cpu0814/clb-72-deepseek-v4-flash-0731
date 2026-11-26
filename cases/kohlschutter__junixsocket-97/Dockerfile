FROM docker.io/library/maven:3.9.9-eclipse-temurin-17-focal@sha256:45ddc84a2e7f75ab7faf290085a0292dd8adc5e7674a89231f6a879b60f4358d

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

ARG FIX_COMMIT=2f8f096b84fba1ae26058d41cc03df47719379df

ARG REPO_URL=https://github.com/kohlschutter/junixsocket.git
ARG BASE_COMMIT=4f7667c4655712fc7371c0dbab0de5bf785e5d3d
ARG INSTANCE_ID=kohlschutter__junixsocket-97

RUN <<'EOF_b1406053c7c0'
#!/bin/bash
set -euo pipefail
git --version
git clone -o origin --single-branch "$REPO_URL" /testbed
cd /testbed
git reset --hard "$BASE_COMMIT"
# Git 2.25.1 can fail during gc if origin/HEAD is left dangling.
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
warm_maven_dependencies() {
    mvn -B -Prelease-native \
        -pl junixsocket-native-common,junixsocket-native-custom -am clean install \
        -Dmaven.test.skip=true \
        -Djunixsocket.custom.arch=amd64-Linux-clang-jni \
        -Djunixsocket.custom.shaded=default
    mvn -B -f junixsocket-common/pom.xml package -Dmaven.test.skip=true
}

(
    git init /tmp/dependency-warmup
    cd /tmp/dependency-warmup
    git remote add origin "$REPO_URL"
    git fetch --depth 1 origin "$FIX_COMMIT"
    git checkout --detach FETCH_HEAD
    warm_maven_dependencies
)
rm -rf /tmp/dependency-warmup /root/.m2/repository/com/kohlschutter/junixsocket

warm_maven_dependencies
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
