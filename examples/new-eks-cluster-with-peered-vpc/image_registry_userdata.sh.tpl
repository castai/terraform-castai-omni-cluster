#!/bin/bash
set -euo pipefail

dnf install -y docker amazon-ssm-agent
systemctl enable amazon-ssm-agent
systemctl start amazon-ssm-agent
systemctl enable docker
systemctl start docker

# Format and mount EBS data volume for registry storage
if ! blkid /dev/xvdf; then
  mkfs.ext4 /dev/xvdf
fi
mkdir -p /var/lib/registry
echo '/dev/xvdf /var/lib/registry ext4 defaults 0 2' >> /etc/fstab
mount -a

# Write Let's Encrypt certificate and key
mkdir -p /etc/registry/certs
printf '%s\n' '${tls_cert}' > /etc/registry/certs/fullchain.pem
printf '%s\n' '${tls_key}' > /etc/registry/certs/privkey.pem
chmod 600 /etc/registry/certs/privkey.pem

docker run -d \
  --name registry \
  --restart always \
  -p 443:443 \
  -v /var/lib/registry:/var/lib/registry \
  -v /etc/registry/certs:/certs:ro \
  -e REGISTRY_HTTP_ADDR=0.0.0.0:443 \
  -e REGISTRY_HTTP_TLS_CERTIFICATE=/certs/fullchain.pem \
  -e REGISTRY_HTTP_TLS_KEY=/certs/privkey.pem \
  registry:2
