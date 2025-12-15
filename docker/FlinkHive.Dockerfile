FROM apache/flink:1.20.3-scala_2.12-java8

USER root

RUN \
    wget https://github.com/apache/flink-cdc/releases/download/release-3.5.0/flink-cdc-3.5.0-bin.tar.gz && \
    tar -xzf flink-cdc-3.5.0-bin.tar.gz --strip-components=1 -C /opt/flink && \
    chown -R flink:flink /opt/flink

COPY ../jars/* /opt/flink/lib/

USER flink