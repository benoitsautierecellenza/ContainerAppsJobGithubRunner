ARG RUNNER_VERSION
FROM ghcr.io/actions/actions-runner:${RUNNER_VERSION}
USER root
# install curl and jq
RUN apt-get update && apt-get install -y curl jq && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

COPY github-actions-runner/entrypoint.sh ./entrypoint.sh
RUN chmod +x ./entrypoint.sh

USER runner
ENTRYPOINT ["./entrypoint.sh"]
