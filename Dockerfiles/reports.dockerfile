FROM ubuntu:24.04

WORKDIR /app

RUN DEBIAN_FRONTEND=noninteractive apt-get update && apt-get install -y \
    wget curl unzip gcc ca-certificates \
    libncurses-dev libstdc++6 \
    flex bison \
    python3 \
    bc \
    && rm -rf /var/lib/apt/lists/*

RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o awscliv2.zip \
    && unzip awscliv2.zip \
    && ./aws/install \
    && rm -rf aws awscliv2.zip

COPY SikrakenDevSpace/bin/helper /app/ReportScripts
COPY SikrakenPythonScripts /app/SikrakenPythonScripts

RUN chmod +x /app/ReportScripts/*
RUN chmod +x /app/SikrakenPythonScripts/*

ENTRYPOINT ["/app/ReportScripts/generate_reports.sh"]
