#!/bin/bash
set -e
trap ctrl_c INT

function ctrl_c() {
  kill -SIGINT ${PERF_STAT_PIDS}
}

export pwd=$(pwd)
[[ $(basename $(pwd)) != build ]] && \
  { echo "Script must be run from 'build' directory."; exit 1; }

TESTDIR=${TESTDIR:-$(dirname $0)}
[[ x${TEST} == x ]] && \
  { echo "TEST must be set"; exit 1; }
OUTDIR=${TESTDIR}/${TEST}

#define specs for test space
#objects size 4MB - simulating RBD split
#actual are 4 times larger, because we run 4 jobs
TEST_SPACE=${TEST_SPACE:-"--size=150000M --nrfiles=37500"}

#define iorange. fio makes size distribution in pareto distribution
IOSIZE=${IOSIZE:-"--bssplit=4k/16:8k/10:12k/9:16k/8:20k/7:24k/7:28k/6:32k/6:36k/5:40k/5:44k/4:48k/4:52k/4:56k/3:60k/3:64k/3"}

#blob size, only used at deploy
BLOB_SIZE=${BLOB_SIZE:-65536}

COMPRESS_MODE=${COMPRESS_MODE:-aggressive}
COMPRESS_RATIO=${COMPRESS_RATIO:-50}

DISTR=${DISTR:-pareto:0.20:0}

NUMCPU=${NUMCPU:-8}
OSD_MEMORY=${OSD_MEMORY:-4G}
#actual is 4 times larger, because we run 4 jobs
TOTAL_TRANSFER=${TOTAL_TRANSFER:-15000M}

mkdir -p ${OUTDIR}
export PERF_STAT_PIDS=
export FIO=${FIO:-$(which fio)}

#/home/akupczyk/adam/fio-pareto/fio
FIO_ARGS="--ioengine=rados --pool=test_pool --invalidate=0 \
	--touch_objects=0 \
	--output-format=json,normal \
	--group_reporting \
	--randrepeat=0 \
	${TEST_SPACE} \
	--buffer_compress_percentage=${COMPRESS_RATIO} \
	--filename_format=object.\$filenum \
	--numjobs=4 --directory=g0:g1:g2:g3"

#cleanup cluster each iteration
CLEAN_CLUSTER=0

function cluster_deploy() {
  if pidof ceph-osd ceph-mon ceph-mgr radosgw fio
  then
    echo "Ceph or fio still running. Exiting."
#    exit 1
  fi

  FS=0 MON=3 MDS=0 MGR=1 OSD=3 ../src/vstart.sh -l -n -b --without-dashboard \
	-o rbd_cache=false \
	-o debug_bluestore=0/0 \
	-o debug_bluefs=0/0 \
        -o debug_rocksdb=4/4 \
	-o debug_osd=0/0 \
	-o debug_ms=0/0 \
	-o debug_mon=0 \
	--nolockdep	\
	-o bluestore_block_path=/dev/disk/by-partlabel/osd-device-\$id-block    \
        -o bluestore_block_db_path=/dev/disk/by-partlabel/osd-device-\$id-db    \
        -o bluestore_block_wal_path=/dev/disk/by-partlabel/osd-device-\$id-wal \
        -o bluestore_block_wal_size=10G \
	-o osd_memory_target=${OSD_MEMORY} \
	-o bluestore_max_blob_size=${BLOB_SIZE} \
        ${EXTRA_DEPLOY_OPTIONS}

  echo === deployed ===
  sleep 2
  echo === pinning ===
  ps -U $(whoami) -o "%p %c" |grep ceph-osd | cut -f 1 -d c |
  { 
    #read o0
    #taskset -apc 0-$((0 + NUMCPU - 1)) ${o0}
    #read o1
    #taskset -apc 10-$((10 + NUMCPU - 1)) ${o1}
    #read o2
    #taskset -apc 20-$((20 + NUMCPU - 1)) ${o2}
    true
  }
  sleep 3
  echo === setup ===
  ./bin/ceph osd pool create test_pool 64 --pg_num_min 64
  ./bin/ceph osd pool set test_pool size 3
  ./bin/ceph osd pool set test_pool compression_mode ${COMPRESS_MODE}
  ./bin/ceph osd pool set test_pool compression_max_blob_size ${BLOB_SIZE}
  ./bin/ceph osd pool set test_pool compression_min_blob_size ${BLOB_SIZE}
  #FIO needs dirs to actually exist
  mkdir -p g0 g1 g2 g3
}


function fill_cluster() {
  echo Initialize
  echo CEPH_CONF=$(pwd)/ceph.conf LD_LIBRARY_PATH=$(pwd)/lib ${FIO} ${FIO_ARGS} \
    --name=FILL --iodepth=64 --rw=write --bs=4M
  CEPH_CONF=$(pwd)/ceph.conf LD_LIBRARY_PATH=$(pwd)/lib ${FIO} ${FIO_ARGS} \
    --name=FILL --iodepth=64 --rw=write --bs=4M
  echo Cluster fill done.
}


function single_test() {
name=$1
fiomode=$2
echo ----- ${name} -----
echo cpu per OSD: ${NUMCPU}
echo memory per OSD: ${OSD_MEMORY}
echo blob size: ${BLOB_SIZE}
echo test space: ${TEST_SPACE}
echo test io sizes: ${IOSIZE}
echo compress mode: ${COMPRESS_MODE}
echo compress ratio: ${COMPRESS_RATIO}
echo distribution: ${DISTR}
echo fio mode: ${fiomode}
echo step size: ${TOTAL_TRANSFER}
echo OUTDIR=${OUTDIR} 
echo OUTPUT_FIO=${OUTDIR}/${name}.fio
echo

PERF_STAT_PIDS=
OSDS=$(ps -U $(whoami) -o "%p %c" |grep ceph-osd | cut -f 1 -d c)
for osd in ${OSDS}
do
  perf stat -p $osd -o ${OUTDIR}/${name}-osd-${osd} &
  PERF_STAT_PIDS="${PERF_STAT_PIDS} $!"
done

echo CEPH_CONF=$(pwd)/ceph.conf LD_LIBRARY_PATH=$(pwd)/lib ${FIO} ${FIO_ARGS} \
    --name=${name} --output=${OUTDIR}/${name}.fio \
    --file_service_type=${DISTR} -norandommap \
    ${IOSIZE} --iodepth=64 --io_size=${TOTAL_TRANSFER} \
    ${fiomode}

./bin/ceph daemon osd.0 perf dump > ${OUTDIR}/${name}.pre.perf
./bin/ceph osd df > ${OUTDIR}/${name}.pre.df

CEPH_CONF=$(pwd)/ceph.conf LD_LIBRARY_PATH=$(pwd)/lib ${FIO} ${FIO_ARGS} \
    --name=${name} --output=${OUTDIR}/${name}.fio \
    --file_service_type=${DISTR} -norandommap \
    ${IOSIZE} --iodepth=64 --io_size=${TOTAL_TRANSFER} \
    ${fiomode}

./bin/ceph daemon osd.0 perf dump > ${OUTDIR}/${name}.after.perf
./bin/ceph osd df > ${OUTDIR}/${name}.after.df

kill -SIGINT ${PERF_STAT_PIDS}
}

if [[ x${NEW_CLUSTER} == x1 ]] 
then
  cluster_deploy
fi

if [[ x${FILL_CLUSTER} == x1 ]] 
then
  fill_cluster
fi
#this is test for rewrite on fixed dataset size

kind=(randwrite randrw randread)
kopts=("--rw=randwrite" "--rw=randrw --rwmixwrite=50" "--rw=randread")

for (( run = 0 ; run < 8 ; run++ ))
do
  for (( k = 0 ; k < 3 ; k++ ))
  do
    single_test run-${run}-${kind[k]} "${kopts[k]}"
  done
done
for (( k = 0 ; k < 3 ; k++ ))
do
  single_test run-11-lat-${kind[k]} "${kopts[k]} --iodepth=2 --io_size=5000M"
done

