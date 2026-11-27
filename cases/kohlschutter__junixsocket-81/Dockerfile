FROM centos@sha256:a93df2e96e07f56ea48f215425c6f1673ab922927894595bb5c0ee4c5a955133 AS legacy

FROM ubuntu:16.04@sha256:1f1a2d56de1d604801a9671f301190704c25d604a416f59e03c04f5c6ffee0d6

ARG DEBIAN_FRONTEND=noninteractive
ENV TZ=Etc/UTC

RUN printf '%s\n' \
    'Acquire::Check-Valid-Until "false";' \
    'Acquire::Retries "5";' \
    'Acquire::http::Pipeline-Depth "0";' \
    'APT::Install-Recommends "false";' \
    > /etc/apt/apt.conf.d/99-clb-archive \
    && sed -i 's|http://security.ubuntu.com/ubuntu|http://archive.ubuntu.com/ubuntu|g' /etc/apt/sources.list \
    && apt-get update \
    && apt-get install -y apt-transport-https ca-certificates \
    && sed -i 's|http://|https://|g' /etc/apt/sources.list

RUN apt update && apt install -y \
    wget \
    git \
    ca-certificates \
    clang \
    gcc \
    libc6-dev \
    binutils \
    xz-utils \
    python3 \
    curl \
    && rm -rf /var/lib/apt/lists/*

COPY --from=legacy / /opt/legacy/

RUN <<'EOF_b1406053c7c0'
#!/bin/bash
set -euo pipefail
mkdir -p /opt/tools /opt/java /opt/deps
curl -fL --retry 3 --connect-timeout 30 -o /tmp/openjdk8.tar.gz https://github.com/AdoptOpenJDK/openjdk8-binaries/releases/download/jdk8u292-b10/OpenJDK8U-jdk_x64_linux_hotspot_8u292b10.tar.gz
echo '0949505fcf42a1765558048451bb2a22e84b3635b1a31dd6191780eeccaa4ada  /tmp/openjdk8.tar.gz' | sha256sum -c -
curl -fL --retry 3 --connect-timeout 30 -o /opt/tools/qemu-x86_64-static https://github.com/multiarch/qemu-user-static/releases/download/v7.2.0-1/qemu-x86_64-static
echo '7132ffd39aef71c26d3344cc0c7dffc530e10e3e720c58c8279a97ef6fdd7784  /opt/tools/qemu-x86_64-static' | sha256sum -c -
curl -fL --retry 3 --connect-timeout 30 -o /opt/deps/junit-console.jar https://repo.maven.apache.org/maven2/org/junit/platform/junit-platform-console-standalone/1.6.0-M1/junit-platform-console-standalone-1.6.0-M1.jar
echo 'e86b2abb61724235c281cc4325329a68fe8731f84bb5628b8fbb2a09d52b117e  /opt/deps/junit-console.jar' | sha256sum -c -
curl -fL --retry 3 --connect-timeout 30 -o /opt/deps/annotations.jar https://repo.maven.apache.org/maven2/com/google/code/findbugs/annotations/3.0.1/annotations-3.0.1.jar
echo '6b47ff0a6de0ce17cbedc3abb0828ca5bce3009d53ea47b3723ff023c4742f79  /opt/deps/annotations.jar' | sha256sum -c -
tar -xzf /tmp/openjdk8.tar.gz -C /opt/java
rm /tmp/openjdk8.tar.gz
chmod 0755 /opt/tools/qemu-x86_64-static
ln -s /usr/bin/python3 /usr/local/bin/python
EOF_b1406053c7c0

ENV JAVA_HOME=/opt/java/jdk8u292-b10
ENV PATH=${JAVA_HOME}/bin:${PATH}
ENV LANG=C.UTF-8 LC_ALL=C.UTF-8

ARG REPO_URL=https://github.com/kohlschutter/junixsocket.git
ARG BASE_COMMIT=90716d6008c5c9cfa8a061f3d23531acaea29777
ARG INSTANCE_ID=kohlschutter__junixsocket-81

RUN <<'EOF_b1406053c7c0'
#!/bin/bash
set -euo pipefail
git --version
git clone -o origin --single-branch "$REPO_URL" /testbed
cd /testbed
git reset --hard "$BASE_COMMIT"
# Git 2.7.4 can leave origin/HEAD dangling after remote removal.
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
mkdir -p /benchmark /inputs /results
/opt/tools/qemu-x86_64-static -L /opt/legacy /opt/legacy/lib64/libc.so.6
/opt/tools/qemu-x86_64-static -L /opt/legacy "${JAVA_HOME}/bin/java" -Xint -Xmx64m -XX:+UseSerialGC -XX:ActiveProcessorCount=2 -version

test "$(git rev-parse HEAD)" = "$BASE_COMMIT"
git diff --exit-code "$BASE_COMMIT" --
worktree_status=$(git status --porcelain)
test -z "$worktree_status"
EOF_b1406053c7c0

WORKDIR /testbed
CMD ["/bin/bash"]
LABEL benchmark.instance_id="${INSTANCE_ID}" benchmark.base_commit="${BASE_COMMIT}"
