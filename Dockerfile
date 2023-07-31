FROM registry.access.redhat.com/ubi9/python-39:latest

RUN pip install --upgrade pip 'setuptools<58' wheel && \
    pip install --upgrade 'crc-bonfire>=4.10.4'

RUN curl https://downloads-openshift-console.apps.stone-prd-rh01.pg1f.p1.openshiftapps.com/amd64/linux/oc.tar \
    | tar -C /opt/app-root/bin/ -xvf - 

COPY bin/* /opt/app-root/bin/
