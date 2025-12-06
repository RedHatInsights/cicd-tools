FROM registry.access.redhat.com/ubi9-minimal:9.7-1763362218

LABEL \
    io.k8s.description=hcc-cicd-tools \
    io.openshift.tags="" \
    summary=hcc-cicd-tools

COPY image_build_scripts/* /setup/

ENV WORKDIR=/tools
ENV TOOLS_DEP_LOCATION="$WORKDIR/bin"
ENV KONFLUX_SCRIPTS_LOCATION="$WORKDIR/konflux"
ENV PYTHON_VENV="$WORKDIR/.venv"
ENV PATH="$PYTHON_VENV/bin:$TOOLS_DEP_LOCATION:$KONFLUX_SCRIPTS_LOCATION:$PATH"

# Run install_system_dependencies.sh and create user
RUN /setup/install_system_dependencies.sh && useradd -d "$WORKDIR" tools
USER tools
WORKDIR "$WORKDIR"

# Install python dependencies
RUN /setup/install_python_dependencies.sh
# Install third party dependencies
RUN /setup/install_third_party_tools.sh

# Copy konflux scripts
COPY konflux_scripts/* "$KONFLUX_SCRIPTS_LOCATION/"

# Copy local helper scripts
COPY bin/oc_wrapper "$TOOLS_DEP_LOCATION/"

USER 0
RUN chown -R tools:0 $WORKDIR
RUN chmod -R g+rwx $WORKDIR
USER tools
