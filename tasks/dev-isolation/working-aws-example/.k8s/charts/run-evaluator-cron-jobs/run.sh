#!/bin/bash

helm upgrade --install run-evaluator-cron-jobs "$(git rev-parse --show-toplevel)"/.k8s/charts/run-evaluator-cron-jobs \
  --kube-context="arn:aws:eks:us-east-2:999999999999:cluster/python-backend-production" \
  --set-literal promptIds="79,98,92,66,70,91,99,96,95,94,67,71,72,74,76,78,81,83,84" \
  --set storageDriver="clickhouse" \
  --set runConfigPath="config/predefined_config_run_prompt_yvesrocherusa.json" \
  --set evalConfigPath="evaluator/config/predefined_config_eval_plan_gen.json" \
  --set userId="23" \
  --set snippetId="spfy86467412261"