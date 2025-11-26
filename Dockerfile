FROM apache/flink:2.1.1-scala_2.12-java17

USER root

COPY jars/* /opt/flink/lib/
COPY jars/* /opt/flink/plugins/

USER flink

CMD ["jobmanager"]