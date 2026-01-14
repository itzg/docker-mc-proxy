#!/bin/bash

set -euo pipefail

apt-get update

DEBIAN_FRONTEND=noninteractive \
  apt-get install -y \
    sudo \
    net-tools \
    curl \
    tzdata \
    nano \
    unzip \
    imagemagick

rm -rf /var/lib/apt/lists/*