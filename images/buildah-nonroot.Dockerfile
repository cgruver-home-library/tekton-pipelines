FROM quay.io/buildah/stable:latest
RUN touch /etc/subgid /etc/subuid \
&& chmod g=u /etc/subgid /etc/subuid /etc/passwd \
&& chmod 4755 /usr/bin/newuidmap \
&& chmod 4755 /usr/bin/newgidmap