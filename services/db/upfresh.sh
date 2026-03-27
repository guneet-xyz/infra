#!/usr/bin/zsh

cd /mnt/infra/services/db
#infisical export --output-file '.env' --env prod
docker compose up -d
