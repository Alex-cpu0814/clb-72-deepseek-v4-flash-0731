FROM eclipse-temurin:8-jdk-jammy@sha256:185d4ef919b98cd195690c33f3fd93bd49c66c70f0b662e54566c0dbaebea6ce

ARG DEBIAN_FRONTEND=noninteractive
ENV TZ=Etc/UTC

USER root
RUN printf '%s\n' \
    'Acquire::Retries "5";' \
    'APT::Install-Recommends "false";' \
    > /etc/apt/apt.conf.d/99-clb-downloads \
    && sed -i 's|http://|https://|g' /etc/apt/sources.list

RUN apt update && apt install -y \
    wget \
    git \
    ca-certificates \
    python3 \
    curl \
    && rm -rf /var/lib/apt/lists/*

ENV LC_ALL=C.UTF-8

RUN <<'EOF_b1406053c7c0'
#!/bin/bash
set -euo pipefail
mkdir -p /opt/deps
curl -fL --retry 3 --connect-timeout 30 -o /opt/deps/junixsocket-native-common-2.8.0.jar https://repo.maven.apache.org/maven2/com/kohlschutter/junixsocket/junixsocket-native-common/2.8.0/junixsocket-native-common-2.8.0.jar
curl -fL --retry 3 --connect-timeout 30 -o /opt/deps/compiler-annotations-1.6.3.jar https://repo.maven.apache.org/maven2/com/kohlschutter/compiler-annotations/1.6.3/compiler-annotations-1.6.3.jar
curl -fL --retry 3 --connect-timeout 30 -o /opt/deps/org.eclipse.jdt.annotation-2.2.700.jar https://repo.maven.apache.org/maven2/org/eclipse/jdt/org.eclipse.jdt.annotation/2.2.700/org.eclipse.jdt.annotation-2.2.700.jar
curl -fL --retry 3 --connect-timeout 30 -o /opt/deps/error_prone_annotations-2.22.0.jar https://repo.maven.apache.org/maven2/com/google/errorprone/error_prone_annotations/2.22.0/error_prone_annotations-2.22.0.jar
curl -fL --retry 3 --connect-timeout 30 -o /opt/deps/animal-sniffer-annotations-1.23.jar https://repo.maven.apache.org/maven2/org/codehaus/mojo/animal-sniffer-annotations/1.23/animal-sniffer-annotations-1.23.jar
curl -fL --retry 3 --connect-timeout 30 -o /opt/deps/junit-platform-console-standalone-1.10.0.jar https://repo.maven.apache.org/maven2/org/junit/platform/junit-platform-console-standalone/1.10.0/junit-platform-console-standalone-1.10.0.jar
curl -fL --retry 3 --connect-timeout 30 -o /opt/deps/kohlschutter-test-util-1.6.3.jar https://repo.maven.apache.org/maven2/com/kohlschutter/kohlschutter-test-util/1.6.3/kohlschutter-test-util-1.6.3.jar
curl -fL --retry 3 --connect-timeout 30 -o /opt/deps/kohlschutter-util-1.6.3.jar https://repo.maven.apache.org/maven2/com/kohlschutter/kohlschutter-util/1.6.3/kohlschutter-util-1.6.3.jar
sha256sum -c <<'CHECKSUMS'
88213e301b8c0b1d743f1e1926b5f5f36257b28ecf352bf9578d8c126039b557  /opt/deps/junixsocket-native-common-2.8.0.jar
5f7e6949e47c10675c6522c134d55839a2223296ce8f184a32c19403170ef653  /opt/deps/compiler-annotations-1.6.3.jar
525b777435de57aa8f7d140d552ddc40ad9c6ad753f9d2bab7dd2101de60e431  /opt/deps/org.eclipse.jdt.annotation-2.2.700.jar
82a027b86541f58d1f9ee020cdf6bebe82acc7a267d3c53a2ea5cd6335932bbd  /opt/deps/error_prone_annotations-2.22.0.jar
9ffe526bf43a6348e9d8b33b9cd6f580a7f5eed0cf055913007eda263de974d0  /opt/deps/animal-sniffer-annotations-1.23.jar
8192d377bdb53969273ca3805af0eef3b864690f7818300c0d39ac7758da39a0  /opt/deps/junit-platform-console-standalone-1.10.0.jar
d7a87b17c05b7558efebb1ff36c739bb52c21433a1647e69d0a6116edf6e72d9  /opt/deps/kohlschutter-test-util-1.6.3.jar
2775cde3790a9a26cb0aeff7a79b2311e56a2ff9fb0fa7f53f003ec8f4e4a024  /opt/deps/kohlschutter-util-1.6.3.jar
CHECKSUMS
EOF_b1406053c7c0

ARG REPO_URL=https://github.com/kohlschutter/junixsocket.git
ARG BASE_COMMIT=71a134bce58a22fb17a7a14f00799196c0c71a60
ARG INSTANCE_ID=kohlschutter__junixsocket-140

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
git config --global --add safe.directory /testbed
java -version
python3 --version

test "$(git rev-parse HEAD)" = "$BASE_COMMIT"
git diff --exit-code "$BASE_COMMIT" --
worktree_status=$(git status --porcelain)
test -z "$worktree_status"
EOF_b1406053c7c0

WORKDIR /testbed
CMD ["/bin/bash"]
