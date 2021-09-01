#!/bin/bash
if [[ x$1 != x ]]
then
  cd $1
  ../report.sh
  cd ..
  exit
fi

function sum() {
  A="$*"
  B=$(echo $A | sed "s/ /+/g")
  C=$(echo "print($B) " | python -)
  echo $C
}


#iops, ios, osd-time
echo
echo iops-report:
echo iter write-iops write-ios write-cpu-used \
rw-iops rw-ios rw-cpu-used \
read-iops read-ios read-cpu-used \

for iter in 0 1 2 3 4 5 6 7 11-lat
do
line=
for mode in randwrite randrw randread
do
base=run-${iter}-${mode}
#echo ${base}
A=$(cat ${base}.fio | grep \"iops\" | sed "s/.*: //;s/,//")
#echo ${A}
iops=$(sum "${A}")
A=$(cat ${base}.fio | grep \"total_ios\" | sed "s/.*: //;s/,//")
#echo ${A}
total_ios=$(sum "${A}")
A=$(cat ${base}-osd-* | grep task-clock | sed "s/[.].*//;s/,//g")
#echo ${A}
osd_time=$(sum "${A}")
line="${line} ${iops} ${total_ios} ${osd_time}"
done
echo ${iter} ${line}
done




#ceph df report
echo
echo ceph-df-report:
echo iter op size raw-use data

for iter in 0 1 2 3 4 5 6 7 11-lat
do
base=run-${iter}-randwrite
A=$(cat ${base}.after.df | sed "2q;d" | sed "s/  */ /g" |cut -d " " -f 6,8,10)
echo ${iter} w ${A}
base=run-${iter}-randrw
B=$(cat ${base}.after.df | sed "2q;d" | sed "s/  */ /g" |cut -d " " -f 6,8,10)
echo ${iter} rw ${B}
done




#cache use
echo
echo cache-use-report:
echo iter w-target w-mapped w-unmapped w-heap w-cache \
rw-target rw-mapped rw-unmapped rw-heap rw-cache \
r-target r-mapped r-unmapped r-heap r-cache \

for iter in 0 1 2 3 4 5 6 7 11-lat
do
line=
for mode in randwrite randrw randread
do
base=run-${iter}-${mode}
A=$(cat ${base}.after.perf | grep -A 6 '"bluestore-pricache"' \
| egrep "(target_bytes|mapped_bytes|unmapped_bytes|heap_bytes|cache_bytes)" | sed "s/.*: //;s/,//")
line="${line} ${A}"
done
echo ${iter} ${line}
done




#bluestore allocation/compression use
echo
echo bluestore-allocation-compression-report:
echo iter op alloc stored compressed compr-alloc compr-orig

for iter in 0 1 2 3 4 5 6 7 11-lat
do
line=
base=run-${iter}-randwrite
A=$(cat ${base}.after.perf \
| egrep "bluestore_(allocated|stored|compressed|compressed_allocated|compressed_original)" | sed "s/.*: //;s/,//")
echo ${iter} w ${A}

base=run-${iter}-randrw
A=$(cat ${base}.after.perf \
| egrep "bluestore_(allocated|stored|compressed|compressed_allocated|compressed_original)" | sed "s/.*: //;s/,//")
echo ${iter} rw ${A}
done




#onode misses
echo
echo onode-misses-report:
echo iter w-hits w-misses rw-hits rw-misses r-hits r-misses

for iter in 0 1 2 3 4 5 6 7 11-lat
do
line=
for mode in randwrite randrw randread
do
base=run-${iter}-${mode}
onode_hits_pre=$(cat ${base}.pre.perf | grep bluestore_onode_hits | sed "s/.*: //;s/,//")
onode_hits_after=$(cat ${base}.after.perf | grep bluestore_onode_hits | sed "s/.*: //;s/,//")
onode_misses_pre=$(cat ${base}.pre.perf | grep bluestore_onode_misses | sed "s/.*: //;s/,//")
onode_misses_after=$(cat ${base}.after.perf | grep bluestore_onode_misses | sed "s/.*: //;s/,//")
line="${line} $((onode_hits_after-onode_hits_pre)) $((onode_misses_after-onode_misses_pre))"
done
echo ${iter} ${line}
done




# latency table
echo
echo latency-report:
echo iter write_mean write_dev \
rw_write_mean rw_write_dev \
rw_read_mean rw_read_dev \
read_mean read_dev

for iter in 0 1 2 3 4 5 6 7 11-lat
do
base=run-${iter}-randwrite
randwrite_mean=$(cat ${base}.fio |grep -A 50 '"write"' |grep -A 6 '"clat_ns"' |grep mean | sed "s/.*: //;s/,//")
randwrite_stddev=$(cat ${base}.fio |grep -A 50 '"write"' |grep -A 6 '"clat_ns"' |grep stddev | sed "s/.*: //;s/,//")

base=run-${iter}-randrw
randrw_write_mean=$(cat ${base}.fio |grep -A 50 '"write"' |grep -A 6 '"clat_ns"' |grep mean | sed "s/.*: //;s/,//")
randrw_write_stddev=$(cat ${base}.fio |grep -A 50 '"write"' |grep -A 6 '"clat_ns"' |grep stddev | sed "s/.*: //;s/,//")
randrw_read_mean=$(cat ${base}.fio |grep -A 50 '"read"' |grep -A 6 '"clat_ns"' |grep mean | sed "s/.*: //;s/,//")
randrw_read_stddev=$(cat ${base}.fio |grep -A 50 '"read"' |grep -A 6 '"clat_ns"' |grep stddev | sed "s/.*: //;s/,//")

base=run-${iter}-randread
randread_mean=$(cat ${base}.fio |grep -A 50 '"read"' |grep -A 6 '"clat_ns"' |grep mean | sed "s/.*: //;s/,//")
randread_stddev=$(cat ${base}.fio |grep -A 50 '"read"' |grep -A 6 '"clat_ns"' |grep stddev | sed "s/.*: //;s/,//")

echo ${iter} ${randwrite_mean} ${randwrite_stddev} \
${randrw_write_mean} ${randrw_write_stddev} \
${randrw_read_mean} ${randrw_read_stddev} \
${randread_mean} ${randread_stddev}
done
