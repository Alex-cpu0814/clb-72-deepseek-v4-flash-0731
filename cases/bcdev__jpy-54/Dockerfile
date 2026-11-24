# syntax=docker/dockerfile:1
FROM public.ecr.aws/ubuntu/ubuntu:18.04@sha256:975b418c2c6c72bdfb978ac631c3fae2f42b752f5ab29dec706a01f3f6acc14b
ARG DEBIAN_FRONTEND=noninteractive
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
RUN apt-get update && apt-get install -y --no-install-recommends build-essential ca-certificates git python2.7 python2.7-dev openjdk-8-jdk-headless && rm -rf /var/lib/apt/lists/*
ENV PYTHONUNBUFFERED=1 LC_ALL=C.UTF-8 LANG=C.UTF-8 JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64 PYTHONPATH=/testbed:/testbed/src/main/python PYTHONDONTWRITEBYTECODE=1
ARG REPO_URL=https://github.com/bcdev/jpy.git
ARG BASE_COMMIT=7e58cea7c2551d0b590eff3959341ee823ec43c1
ARG INSTANCE_ID=bcdev__jpy-54
RUN git init /testbed && cd /testbed && git remote add origin "${REPO_URL}" && git fetch --depth=1 --no-tags origin "${BASE_COMMIT}" && git checkout --detach "${BASE_COMMIT}" && git remote remove origin && git config core.autocrlf false && test "$(git rev-parse HEAD)" = "${BASE_COMMIT}"
WORKDIR /testbed
RUN python2.7 setup.py clean build_ext --inplace --force && python2.7 -c "import jpy,jpyutil; print(jpy.__file__); assert jpy.__file__.startswith('/testbed/'); jpyutil.init_jvm(); assert jpy.has_jvm()" && printf '%s\n' '/build/' '/target/' '/src/main/python/*.so' >> .git/info/exclude && test -z "$(git status --porcelain)"
ADD --checksum=sha256:217ae5161a0e08c0fb873858806e3478c9775caffce5168b50ec885e358c199d https://files.pythonhosted.org/packages/27/79/8a850fe3496446ff0d584327ae44e7500daf6764ca1a382d2d02789accf7/pip-20.3.4-py2.py3-none-any.whl /tmp/pip-bootstrap.whl
RUN PYTHONPATH=/tmp/pip-bootstrap.whl python2.7 -m pip install --no-cache-dir pip==20.3.4 setuptools==44.1.1 wheel==0.37.1 && rm /tmp/pip-bootstrap.whl
RUN python2.7 -m pip install --no-cache-dir pytest==4.6.11 pytest-forked==1.1.3
# Install Maven and warm only the Java compilation lifecycle. Test execution is in eval.sh.
ADD --checksum=sha256:7a9cdf674fc1703d6382f5f330b3d110ea1b512b51f1652846d9e4e8a588d766 https://repo.maven.apache.org/maven2/org/apache/maven/apache-maven/3.9.9/apache-maven-3.9.9-bin.tar.gz /tmp/apache-maven.tar.gz
RUN tar -xzf /tmp/apache-maven.tar.gz -C /opt && mv /opt/apache-maven-3.9.9 /opt/maven && rm /tmp/apache-maven.tar.gz
ENV MAVEN_HOME=/opt/maven PATH=/opt/maven/bin:${PATH}
# Retain downloaded artifacts across transient repository/network failures.
RUN (mvn -B clean test-compile || mvn -B clean test-compile || mvn -B clean test-compile || mvn -B clean test-compile || mvn -B clean test-compile) && mvn -o -B clean test-compile && test -z "$(git status --porcelain)"
CMD ["/bin/bash"]
