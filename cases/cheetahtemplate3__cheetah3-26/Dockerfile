FROM quay.io/pypa/manylinux2010_x86_64@sha256:3b5eb5ab9bc73b93740ae4eda9962078951cd3bb7efe837b770360e78c7366fb

ENV TZ=Etc/UTC

ENV PYTHONUNBUFFERED=1 PYTHONDONTWRITEBYTECODE=1 LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8

ADD --checksum=sha256:cf3098950cb4d853ad95c0841f1f9c6d3dc102dccfcacd521d93925208b76ac8 https://www.openssl.org/source/old/1.1.1/openssl-1.1.1w.tar.gz /tmp/openssl.tgz
RUN tar -xzf /tmp/openssl.tgz -C /tmp \
    && cd /tmp/openssl-1.1.1w \
    && ./config --prefix=/opt/openssl --openssldir=/etc/pki/tls shared >/tmp/openssl-configure.log \
    && make -j4 >/tmp/openssl-make.log 2>&1 \
    && make install_sw >/tmp/openssl-install.log 2>&1 \
    && rm -rf /tmp/openssl-1.1.1w /tmp/openssl.tgz
ENV LD_LIBRARY_PATH=/opt/openssl/lib:${LD_LIBRARY_PATH} SSL_CERT_FILE=/etc/pki/tls/certs/ca-bundle.crt

ADD --checksum=sha256:da3080e3b488f648a3d7a4560ddee895284c3380b11d6de75edb986526b9a814 https://www.python.org/ftp/python/2.7.18/Python-2.7.18.tgz /tmp/python.tgz
RUN tar -xzf /tmp/python.tgz -C /tmp \
    && cd /tmp/Python-2.7.18 \
    && CPPFLAGS=-I/opt/openssl/include LDFLAGS=-L/opt/openssl/lib \
       ./configure --prefix=/opt/python27 --enable-unicode=ucs4 --with-ensurepip=install >/tmp/python-configure.log \
    && make -j4 >/tmp/python-make.log 2>&1 \
    && make install >/tmp/python-install.log 2>&1 \
    && /opt/python27/bin/python2.7 -c 'import ssl; print(ssl.OPENSSL_VERSION)' \
    && rm -rf /tmp/Python-2.7.18 /tmp/python.tgz
ENV PATH=/opt/python27/bin:${PATH}
RUN python2.7 -m pip install --no-cache-dir pip==20.3.4 setuptools==43.0.0 wheel==0.37.1

ARG REPO_URL=https://github.com/CheetahTemplate3/cheetah3.git
ARG BASE_COMMIT=c86628cad04edc5167f9a9c8999abc62c6558e7b
ARG INSTANCE_ID=cheetahtemplate3__cheetah3-26

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
python2.7 setup.py build_ext --inplace --force
python2.7 -c 'import inspect; import Cheetah.NameMapper as nm; import Cheetah._namemapper as cnm; assert nm.valueFromSearchList is cnm.valueFromSearchList; assert inspect.isbuiltin(nm.valueFromSearchList); print(cnm.__file__)'
grep -Fx 'CentOS release 6.10 (Final)' /etc/centos-release

test "$(git rev-parse HEAD)" = "$BASE_COMMIT"
git diff --exit-code "$BASE_COMMIT" --
worktree_status=$(git status --porcelain)
test -z "$worktree_status"
EOF_b1406053c7c0

WORKDIR /testbed
CMD ["/bin/bash"]
