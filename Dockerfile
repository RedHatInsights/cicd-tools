FROM registry.access.redhat.com/ubi9-minimal:9.6-1752587672

LABEL \
    io.k8s.description=hcc-cicd-tools \
    io.openshift.tags="" \
    summary=hcc-cicd-tools

COPY image_build_scripts/* /setup/

ENV WORKDIR=/tools
ENV TOOLS_DEP_LOCATION="$WORKDIR/bin"
ENV PYTHON_DEP_LOCATION="$WORKDIR/.local/bin"
ENV KONFLUX_SCRIPTS_LOCATION="$WORKDIR/konflux"
ENV PATH="$PYTHON_DEP_LOCATION:$TOOLS_DEP_LOCATION:$KONFLUX_SCRIPTS_LOCATION:$PATH"

# Run install_system_dependencies.sh and create user
RUN /setup/install_system_dependencies.sh && useradd -d "$WORKDIR" tools
USER tools
WORKDIR "$WORKDIR"

# Install python dependencies
RUN /setup/install_python_dependencies.sh "$PYTHON_DEP_LOCATION"
# Install third party dependencies
RUN /setup/install_third_party_tools.sh "$TOOLS_DEP_LOCATION"

# Copy konflux scripts
COPY konflux_scripts/* "$KONFLUX_SCRIPTS_LOCATION/"

# Copy local helper scripts
COPY bin/oc_wrapper "$TOOLS_DEP_LOCATION/"
