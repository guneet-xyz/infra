#!/usr/bin/zsh

cd /mnt/infra/services/registry
infisical export --output-file '.env' --env prod
docker compose up -d
