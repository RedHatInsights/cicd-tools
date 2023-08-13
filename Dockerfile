FROM registry.access.redhat.com/ubi9/python-39:latest

RUN pip install --upgrade pip "setuptools<58" wheel && \
    pip install "pipenv==2023.7.23"

RUN curl https://downloads-openshift-console.apps.stone-prd-rh01.pg1f.p1.openshiftapps.com/amd64/linux/oc.tar \
    | tar -C /opt/app-root/bin/ -xvf -

COPY Pipfile.lock /opt/app-root/src/
RUN cd /opt/app-root/src && pip install -r <(pipenv requirements)

COPY bin/* /opt/app-root/bin/
