# Allow build scripts to be referenced without being copied into the final image
FROM scratch AS ctx
COPY build_files /

# Base Image
FROM quay.io/fedora/fedora-bootc:42

# Copy akmods-nvidia container contents
COPY --from=ghcr.io/ublue-os/akmods-nvidia:main-42 / /tmp/akmods-nvidia
RUN find /tmp/akmods-nvidia
# Install NVIDIA support packages and signed modules
RUN dnf install /tmp/akmods-nvidia/rpms/ublue-os/ublue-os-nvidia*.rpm
RUN dnf install /tmp/akmods-nvidia/rpms/kmods/kmod-nvidia*.rpm

### MODIFICATIONS
## make modifications desired in your image and install packages by modifying the build.sh script
## the following RUN directive does all the things required to run "build.sh" as recommended.

RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/build.sh && \
    ostree container commit
    
### LINTING
## Verify final image and contents are correct.
RUN bootc container lint
