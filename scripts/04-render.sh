#!/usr/bin/env bash
set -euo pipefail
helm lint ./my-webapp
helm template my-webapp ./my-webapp
