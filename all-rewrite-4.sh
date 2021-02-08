#!/bin/bash
TESTDIR=${TESTDIR:-$(dirname $0)}
export FIO=/home/akupczyk/adam/fio-pareto/fio

#define center point of our phase space of all tests
#out tests will probe phase space throught this point
export TEST_SPACE="--size=150000M --nrfiles=37500"
export IOSIZE="--bsrange 4k-64k"
export BLOB_SIZE=65536
export COMPRESS_MODE=aggressive
export COMPRESS_RATIO=50
export DISTR=pareto:0.20:0 #this gives 20% objects handle 80% requests 
export NUMCPU=8
export OSD_MEMORY=4G
export TOTAL_TRANSFER=15000M


#TEST=onode-kv-uniform-only-high NEW_CLUSTER=1 FILL_CLUSTER=1 \
#DISTR=random IOSIZE="--bs 4k-32k" COMPRESS_MODE=aggressive OSD_MEMORY=3G \
#${TESTDIR}/testrun-rewrite.sh
#../src/stop.sh
#exit

#center probe
#TEST=${BASETEST}rewrite-default NEW_CLUSTER=1 FILL_CLUSTER=1 \
#${TESTDIR}/testrun-rewrite-4.sh
#../src/stop.sh


#cut through available memory
for m in 3G 6G #4G is default
do
  TEST=${BASETEST}rewrite-mem${m} NEW_CLUSTER=1 FILL_CLUSTER=1 \
  OSD_MEMORY=${m} \
  ${TESTDIR}/testrun-rewrite-4.sh
  ../src/stop.sh
done

#cut through compress ratios
for c in 0 25 75 #50 is in default
do
  TEST=${BASETEST}rewrite-comp${c} NEW_CLUSTER=1 FILL_CLUSTER=1 \
  COMPRESS_RATIO=${c} \
  ${TESTDIR}/testrun-rewrite-4.sh
  ../src/stop.sh
done

TEST=${BASETEST}rewrite-nocomp NEW_CLUSTER=1 FILL_CLUSTER=1 \
COMPRESS_MODE=none \
${TESTDIR}/testrun-rewrite-4.sh
../src/stop.sh

#cut through distributions
for d in 0.30 0.40 #0.20 is default
do
  TEST=${BASETEST}rewrite-par${d} NEW_CLUSTER=1 FILL_CLUSTER=1 \
  DISTR=pareto:${d}:0 \
  ${TESTDIR}/testrun-rewrite-4.sh
  ../src/stop.sh
done

TEST=${BASETEST}rewrite-uniform NEW_CLUSTER=1 FILL_CLUSTER=1 \
DISTR=random \
${TESTDIR}/testrun-rewrite-4.sh
../src/stop.sh

export BLOB_SIZE=65536
for b in 16384 262144 #65536 is default
do
  TEST=${BASETEST}rewrite-blob${b} NEW_CLUSTER=1 FILL_CLUSTER=1 \
  BLOB_SIZE=${b} \
  ${TESTDIR}/testrun-rewrite-4.sh
  ../src/stop.sh
done




