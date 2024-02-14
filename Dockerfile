FROM antsx/ants:v2.5.1

RUN \
    --mount=type=cache,sharing=private,target=/var/cache/apt \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        python3-minimal \
        python-is-python3 \
        procps

COPY bin/minc-toolkit-extras/antsRegistration_affine_SyN.sh /usr/local/bin
COPY bin/minc-toolkit-extras/ants_generate_iterations.py /usr/local/bin
