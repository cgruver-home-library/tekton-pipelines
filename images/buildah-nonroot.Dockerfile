FROM quay.io/buildah/stable:latest
RUN dnf -y reinstall shadow-utils \ 
&& touch /etc/subgid /etc/subuid \
&& chmod g=u /etc/subgid /etc/subuid /etc/passwd
