FROM centos@sha256:a93df2e96e07f56ea48f215425c6f1673ab922927894595bb5c0ee4c5a955133 AS legacy
FROM docker.io/library/maven:3.9.9-eclipse-temurin-17-focal@sha256:45ddc84a2e7f75ab7faf290085a0292dd8adc5e7674a89231f6a879b60f4358d AS maven_tools

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
COPY --from=maven_tools /opt/java/openjdk /opt/jdk17
COPY --from=maven_tools /usr/share/maven /opt/maven

RUN <<'EOF_b1406053c7c0'
#!/bin/bash
set -euo pipefail
mkdir -p /opt/tools
curl -fL --retry 3 --connect-timeout 30 -o /opt/tools/qemu-x86_64-static https://github.com/multiarch/qemu-user-static/releases/download/v7.2.0-1/qemu-x86_64-static
echo '7132ffd39aef71c26d3344cc0c7dffc530e10e3e720c58c8279a97ef6fdd7784  /opt/tools/qemu-x86_64-static' | sha256sum -c -
chmod 0755 /opt/tools/qemu-x86_64-static
EOF_b1406053c7c0

ENV JAVA_HOME=/opt/jdk17
ENV PATH=${JAVA_HOME}/bin:/opt/maven/bin:${PATH}
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
mkdir -p /inputs /results /tmp/dependency-warmup
/opt/tools/qemu-x86_64-static -L /opt/legacy /opt/legacy/lib64/libc.so.6
/opt/tools/qemu-x86_64-static -L /opt/legacy "$JAVA_HOME/bin/java" -Xint -Xmx64m -XX:+UseSerialGC -XX:ActiveProcessorCount=2 -version
git archive HEAD | tar -x -C /tmp/dependency-warmup
(
    cd /tmp/dependency-warmup
    mvn -B -ntp -pl junixsocket-native-common,junixsocket-native-custom -am \
        -Djunixsocket.custom.arch=amd64-Linux-clang-jni \
        '-Djunixsocket.native.clang.c.options=-Werror -Wall -Wextra -pedantic -Wno-unused-parameter -fno-strict-overflow -std=c11 -Xcrossclang-with-and-without-lc' \
        -Dcheckstyle.skip=true -Dmaven.javadoc.skip=true -Djacoco.skip=true \
        -Dpmd.skip=true -Dcpd.skip=true -Dlicense.skip=true \
        -Dspotbugs.disabled=true -Dspotbugs.skip=true \
        -DskipTests clean install
    mvn -B -ntp -f junixsocket-common/pom.xml \
        -Djunixsocket.custom.arch=amd64-Linux-clang-jni -Djacoco.skip=true \
        -Djunixsocket.test.legacyLauncher=/opt/tools/qemu-x86_64-static \
        -Djunixsocket.test.legacyRoot=/opt/legacy test \
        '-Dtest=org.newsclub.net.unix.AFUNIXSocketAddressTest#testPort'
)
rm -rf /tmp/dependency-warmup /root/.m2/repository/com/kohlschutter/junixsocket

test "$(git rev-parse HEAD)" = "$BASE_COMMIT"
git diff --exit-code "$BASE_COMMIT" --
worktree_status=$(git status --porcelain)
test -z "$worktree_status"
EOF_b1406053c7c0

WORKDIR /testbed
CMD ["/bin/bash"]
