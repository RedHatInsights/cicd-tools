FROM registry.access.redhat.com/ubi9-minimal:9.4-949.1717074713

COPY image_build_scripts/* /setup/

ENV WORKDIR=/tools
ENV TOOLS_DEP_LOCATION="$WORKDIR/bin"
ENV PYTHON_DEP_LOCATION="$WORKDIR/.local/bin"
ENV PATH="$PYTHON_DEP_LOCATION:$TOOLS_DEP_LOCATION:$PATH"

# Run install_system_dependencies.sh and create user
RUN /setup/install_system_dependencies.sh && useradd -d "$WORKDIR" tools
USER tools
WORKDIR "$WORKDIR"

# Install python dependencies
RUN /setup/install_python_dependencies.sh "$PYTHON_DEP_LOCATION" && \
# Install third party dependencies
    /setup/install_third_party_tools.sh "$TOOLS_DEP_LOCATION"
