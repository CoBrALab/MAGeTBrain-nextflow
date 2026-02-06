FROM antsx/ants:v2.6.5

RUN \
    --mount=type=cache,sharing=private,target=/var/cache/apt \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        python3-minimal \
        python-is-python3 \
        procps

COPY bin/antsRegistration_affine_SyN/antsRegistration_affine_SyN.sh /usr/local/bin
