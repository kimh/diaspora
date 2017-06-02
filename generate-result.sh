#!/bin/bash

set -ex

benchmark_dir="/tmp/benchmark"
db_migrate=$(cat $benchmark_dir/db_migrate)
rspec=$(cat $benchmark_dir/rspec)

cat << EOF
{
  "platform":"$PLATFORM",
  "build_num":$CIRCLE_BUILD_NUM,
  "time":"$(date +'%Y/%m/%d %I:%M:%S')",
  "benchmarks": {
    "db_migrate":$db_migrate,
    "rspec":$rspec
  }
}
EOF
