#!/bin/bash

./bin/blockchan -h 9000 >> logs/bootstrap.log&
echo "launched bootstrap node"

for index in {1..1}; do
  ./bin/blockchan -h $((9000 + $index)) -b 9000 -m >> logs/$index.log&
  echo "launched miner $index"
done

for index in {2..20}; do
  ./bin/blockchan -h $((9000 + $index)) -b 9000 $([ $((RANDOM % 2)) -eq 0 ] && echo '-s') >> logs/$index.log&
  echo "launched node $index"
  sleep 1
done
