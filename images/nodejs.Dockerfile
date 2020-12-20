FROM registry.access.redhat.com/ubi8/ubi-minimal:8.3
ENV LANG='en_US.UTF-8' LANGUAGE='en_US:en'
RUN microdnf install nodejs npm nodejs-nodemon nss_wrapper \
    && microdnf update \
    && microdnf clean all
