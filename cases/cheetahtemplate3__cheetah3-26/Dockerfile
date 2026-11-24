# syntax=docker/dockerfile:1
# CentOS 6.10; PyPA backports the glibc 2.12 vsyscall fix for modern kernels (PEP 571).
FROM quay.io/pypa/manylinux2010_x86_64@sha256:3b5eb5ab9bc73b93740ae4eda9962078951cd3bb7efe837b770360e78c7366fb
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
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
RUN python2.7 -m pip install --no-cache-dir pip==20.3.4 setuptools==43.0.0 wheel==0.37.1 \
    && python2.7 -m pip install --no-cache-dir pytest==4.6.11
ARG REPO_URL=https://github.com/CheetahTemplate3/cheetah3.git
ARG BASE_COMMIT=c86628cad04edc5167f9a9c8999abc62c6558e7b
ARG INSTANCE_ID=cheetahtemplate3__cheetah3-26
RUN git init /testbed && cd /testbed && git remote add origin "${REPO_URL}" \
    && git fetch --depth=1 --no-tags origin "${BASE_COMMIT}" && git checkout --detach FETCH_HEAD \
    && git remote remove origin && git config core.autocrlf false \
    && test "$(git rev-parse HEAD)" = "${BASE_COMMIT}"
WORKDIR /testbed
RUN python2.7 setup.py build_ext --inplace --force \
    && python2.7 -c 'import inspect; import Cheetah.NameMapper as nm; import Cheetah._namemapper as cnm; assert nm.valueFromSearchList is cnm.valueFromSearchList; assert inspect.isbuiltin(nm.valueFromSearchList); print(cnm.__file__)' \
    && grep -Fx 'CentOS release 6.10 (Final)' /etc/centos-release \
    && test -z "$(git status --porcelain)"
CMD ["/bin/bash"]
