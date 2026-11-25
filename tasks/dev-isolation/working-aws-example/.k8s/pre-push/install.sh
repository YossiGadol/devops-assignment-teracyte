#!/bin/bash

root_dir=$(git rev-parse --show-toplevel)
cp "${root_dir}/.k8s/pre-push/hook" "${root_dir}/.git/hooks/pre-push"
chmod +x "${root_dir}/.git/hooks/pre-push"