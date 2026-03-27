FROM alpine:latest

RUN apk add --no-cache openssh-server \
    && sed -i 's/#AllowTcpForwarding no/AllowTcpForwarding no/' /etc/ssh/sshd_config \
    && sed -i 's/AllowTcpForwarding no/AllowTcpForwarding yes/' /etc/ssh/sshd_config \
    && sed -i 's/#GatewayPorts no/GatewayPorts no/' /etc/ssh/sshd_config \
    && sed -i 's/GatewayPorts no/GatewayPorts yes/' /etc/ssh/sshd_config \
    && sed -i 's/#PermitTunnel no/PermitTunnel no/' /etc/ssh/sshd_config \
    && sed -i 's/PermitTunnel no/PermitTunnel yes/' /etc/ssh/sshd_config \
    && mkdir -p /root/.ssh \
    && chmod 700 /root/.ssh

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 22

VOLUME ["/root/.ssh", "/etc/ssh/keys"]

ENTRYPOINT ["/entrypoint.sh"]
