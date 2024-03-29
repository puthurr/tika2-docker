#
# Copy of https://github.com/oracle/docker-images/blob/main/OracleJava/8/Dockerfile
#

# Copyright (c) 2019, 2022 Oracle and/or its affiliates. 
#
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.
#
# ORACLE DOCKERFILES PROJECT
# --------------------------
# This is the Dockerfile for Oracle Server JRE 8
#
# REQUIRED FILES TO BUILD THIS IMAGE
# ----------------------------------
#
# (1) server-jre-8uXX-linux-x64.tar.gz
#     Download from https://www.oracle.com/java/technologies/javase-server-jre8-downloads.html
#
# HOW TO BUILD THIS IMAGE
# -----------------------
# Put all downloaded files in the same directory as this Dockerfile
# Run:
#      $ docker build -t oracle/serverjre:8 .
#
# This command is already scripted in build.sh so you can alternatively run
#		$ bash build.sh
#
# The builder image will be used to uncompress the tar.gz file with the Java Runtime.

FROM oraclelinux:7-slim as builder

LABEL maintainer="Aurelio Garcia-Ribeyro <aurelio.garciaribeyro@oracle.com>"

# Since the files is compressed as tar.gz first yum install gzip and tar
RUN set -eux; \
	yum install -y \
		gzip \
		tar \
	; \
	rm -rf /var/cache/yum

# Default to UTF-8 file.encoding
ENV LANG en_US.UTF-8

# Environment variables for the builder image.
# Required to validate that you are using the correct file

ENV JAVA_PKG=server-jre-8u361-linux-x64.tar.gz \
	JAVA_SHA256=413e658db77d33fc2587557d4b1093ca2268892d2c75e6298927db8bb8622d13 \
	JAVA_HOME=/usr/java/jdk-8

COPY $JAVA_PKG /tmp/jdk.tgz
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
RUN set -eux; \
	echo "$JAVA_SHA256 */tmp/jdk.tgz" | sha256sum -c -; \
	mkdir -p "$JAVA_HOME"; \
	tar --extract --file /tmp/jdk.tgz --directory "$JAVA_HOME" --strip-components 1; 

## Get a fresh version of SLIM for the final image

FROM oraclelinux:7-slim

# Default to UTF-8 file.encoding
ENV LANG en_US.UTF-8

ENV JAVA_VERSION=1.8.0_361 \
	JAVA_HOME=/usr/java/jdk-8 
	
ENV	PATH $JAVA_HOME/bin:$PATH

# Copy the uncompressed Java Runtime from the builder image
COPY --from=builder $JAVA_HOME $JAVA_HOME

##
RUN	yum -y update; \
	rm -rf /var/cache/yum; \
	ln -sfT "$JAVA_HOME" /usr/java/default; \
	ln -sfT "$JAVA_HOME" /usr/java/latest; \
	for bin in "$JAVA_HOME/bin/"*; do \
		base="$(basename "$bin")"; \
		[ ! -e "/usr/bin/$base" ]; \
		alternatives --install "/usr/bin/$base" "$base" "$bin" 20000; \
	done; \
# -Xshare:dump will create a CDS archive to improve startup in subsequent runs	
# the file will be stored as /usr/java/jdk-8/jre/lib/amd64/server/classes.jsa 
# See https://docs.oracle.com/javase/8/docs/technotes/guides/vm/class-data-sharing.html
	java -Xshare:dump;

# ----------------------------
# Tika part
# ----------------------------

ENV TIKA_VERSION 2.7.0-20230704
ENV TIKA_SERVER_PKG=tika-server-standard-$TIKA_VERSION.jar
ENV TIKA_HOME=/usr/local

COPY $TIKA_SERVER_PKG $TIKA_HOME

EXPOSE 9998
ENTRYPOINT java -XX:MaxRAMPercentage=90.0 -jar ${TIKA_HOME}/tika-server-standard-${TIKA_VERSION}.jar -h 0.0.0.0
