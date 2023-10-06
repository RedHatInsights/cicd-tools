FROM registry.access.redhat.com/ubi9/python-311:latest

RUN pip install "pipenv==2023.7.23"

RUN curl -L https://mirror.openshift.com/pub/openshift-v4/x86_64/clients/ocp/4.12.36/openshift-client-linux.tar.gz \
    | tar -C /opt/app-root/bin/ -xvzf -

RUN wget https://dl.min.io/client/mc/release/linux-amd64/mc \
    && chmod +x mc && mv mc /opt/app-root/bin/mc

RUN wget https://github.com/jqlang/jq/releases/download/jq-1.6/jq-linux64 \
    && mv jq-linux64 /opt/app-root/bin/jq && chmod +x /opt/app-root/bin/jq

COPY Pipfile.lock /opt/app-root/src/
RUN cd /opt/app-root/src && pip install -r <(pipenv requirements)

COPY bin/* /opt/app-root/bin/

LABEL \
    io.k8s.description=bonfire-cicd-tools \
    io.openshift.tags="" \
    summary=bonfire-cicd-tools
