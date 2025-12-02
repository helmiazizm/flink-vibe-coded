FROM apache/flink:2.0.1-scala_2.12-java21

USER root

COPY jars/* /opt/flink/lib/

USER flink

CMD ["jobmanager"]