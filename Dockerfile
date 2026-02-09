FROM registry.access.redhat.com/ubi9-minimal:9.7-1770267347

LABEL \
    io.k8s.description=hcc-cicd-tools \
    io.openshift.tags="" \
    summary=hcc-cicd-tools

COPY image_build_scripts/* /setup/

ENV HOME=/tools
ENV TOOLS_DEP_LOCATION="$HOME/bin"
ENV KONFLUX_SCRIPTS_LOCATION="$HOME/konflux"
ENV PYTHON_VENV="$HOME/.venv"
ENV PATH="$PYTHON_VENV/bin:$TOOLS_DEP_LOCATION:$KONFLUX_SCRIPTS_LOCATION:$PATH"
ENV REQUESTS_CA_BUNDLE=/etc/pki/tls/certs/ca-bundle.crt \
    SSL_CERT_FILE=/etc/pki/tls/certs/ca-bundle.crt \
    CURL_CA_BUNDLE=/etc/pki/tls/certs/ca-bundle.crt

# Run install_system_dependencies.sh and create user
RUN /setup/install_system_dependencies.sh && useradd -d "$HOME" tools

# Install Red Hat IT CA certificates for internal services
RUN curl -k https://certs.corp.redhat.com/certs/Current-IT-Root-CAs.pem \
         -o /etc/pki/ca-trust/source/anchors/redhat-it-root-ca.pem && \
    update-ca-trust

USER tools
WORKDIR "$HOME"

# Install python dependencies
RUN /setup/install_python_dependencies.sh
# Install third party dependencies
RUN /setup/install_third_party_tools.sh

# Copy konflux scripts
COPY konflux_scripts/* "$KONFLUX_SCRIPTS_LOCATION/"

# Copy local helper scripts
COPY bin/oc_wrapper "$TOOLS_DEP_LOCATION/"

USER 0
RUN chown -R tools:0 $HOME
RUN chmod -R g+rwx $HOME
USER tools
