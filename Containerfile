ARG IMAGE_NAME="${IMAGE_NAME:-kinoite}"
ARG SOURCE_IMAGE="${SOURCE_IMAGE:-kinoite}"
ARG SOURCE_ORG="${SOURCE_ORG:-fedora-ostree-desktops}"
ARG BASE_IMAGE="quay.io/${SOURCE_ORG}/${SOURCE_IMAGE}"
ARG FEDORA_MAJOR_VERSION="${FEDORA_MAJOR_VERSION:-42}"
ARG IMAGE_REGISTRY=ghcr.io/ublue-os
ARG AKMODS_DIGEST=""
ARG AKMODS_NVIDIA_DIGEST=""
ARG BASE_IMAGE_DIGEST=""

FROM scratch AS ctx
COPY /build_files /

FROM ${IMAGE_REGISTRY}/akmods:main-${FEDORA_MAJOR_VERSION}${AKMODS_DIGEST:+@${AKMODS_DIGEST}} AS akmods

FROM ${BASE_IMAGE}:${FEDORA_MAJOR_VERSION}${BASE_IMAGE_DIGEST:+@${BASE_IMAGE_DIGEST}}

ARG IMAGE_NAME="${IMAGE_NAME:-kinoite}"
ARG FEDORA_MAJOR_VERSION="${FEDORA_MAJOR_VERSION:-42}"
ARG BUILD_NVIDIA="${BUILD_NVIDIA:-Y}"

# Allow build scripts to be referenced without being copied into the final image
# FROM scratch AS ctx
# COPY build_files /

# Base Image
# FROM quay.io/fedora/fedora-bootc:42

### MODIFICATIONS
## make modifications desired in your image and install packages by modifying the build.sh script
## the following RUN directive does all the things required to run "build.sh" as recommended.

RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    --mount=type=bind,from=akmods,source=/rpms/ublue-os,dst=/tmp/akmods-rpms \
    --mount=type=bind,from=akmods,source=/kernel-rpms,dst=/tmp/kernel-rpms \
    --mount=type=bind,from=akmods_nvidia,source=/rpms,dst=/tmp/akmods-nv-rpms \
    if [ "${BUILD_NVIDIA}" == "Y" ]; then \
        AKMODNV_PATH=/tmp/akmods-nv-rpms /ctx/nvidia-install.sh \
    ; fi && \
    /ctx/build.sh && \
    ostree container commit



# Cleanup
# Remove tmp files and everything in dirs that make bootc unhappy
rm -rf /tmp/* || true
rm -rf /usr/etc
rm -rf /boot && mkdir /boot

### LINTING
## Verify final image and contents are correct.
RUN bootc container lint
