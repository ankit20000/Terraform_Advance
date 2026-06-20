#!/bin/bash
# Minimal bootstrap — application + dependencies are already baked into
# the custom AMI by Packer. This just sets per-environment config.
echo "APP_ENV=${environment}" >> /etc/environment
systemctl restart app.service || true
