FROM apache/flink:2.0.1-scala_2.12-java21

USER root

COPY jars/* /opt/flink/lib/
# RUN apt-get update
# RUN apt-get install -y python3 python3-pip && \
#     ln -s /usr/bin/python3 /usr/bin/python && \
#     apt-get clean && \
#     rm -rf /var/lib/apt/lists/*
# RUN pip install typing_extensions

USER flink

CMD ["jobmanager"]