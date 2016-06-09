#!/bin/bash

# ---------------------------------------------------------------------

trap onexit 1 2 3 15
function onexit() {
local exit_status=${1:-$?}
pkill -f hstore.tag
exit $exit_status
}

# ---------------------------------------------------------------------

ENABLE_ANTICACHE=true

SITE_HOST="localhost"

CLIENT_HOSTS=( \
        "localhost" \
)
BASE_CLIENT_THREADS=1
BASE_SITE_MEMORY=4096
BASE_SITE_MEMORY_PER_PARTITION=1024
BASE_PROJECT="tpcc"
#BASE_DIR=`pwd`
#OUTPUT_DIR="~/data/ycsb/read-heavy/2/80-20"

ANTICACHE_BLOCK_SIZE=1048576
#ANTICACHE_EVICT_SIZE=268400000
#ANTICACHE_THRESHOLD=.75



# MUST BE IN THE LOOP
NUM_EVICT=100
THRESHOLD=1000
INTERVAL=10000

for THRESHOLD in 1000 1500; do
  for NUM_EVICT in 200 250 300; do
    for INTERVAL in 10000 12000 15000; do
      for round in 1 2 3; do
         sudo sh -c 'echo 3 > /proc/sys/vm/drop_caches'
         cp /home/yujinee/h-store/scripts/timestamps/freq/buildtools.py /home/yujinee/h-store/
        OUTPUT_PREFIX="logs/freq/T${THRESHOLD}-E${NUM_EVICT}-I${INTERVAL}-$round"
        echo $OUTPUT_PREFIX
        mkdir -p $OUTPUT_PREFIX
        BASE_ARGS=( \
          # SITE DEBUG
        "-Dsite.status_enable=false" \
          "-Dsite.status_interval=1000" \
          #    "-Dsite.status_exec_info=true" \
          #    "-Dsite.status_check_for_zombies=true" \
          #    "-Dsite.exec_profiling=true" \
          #    "-Dsite.pool_profiling=true" \
          #     "-Dsite.network_profiling=false" \
          #     "-Dsite.log_backup=true"\
          #    "-Dnoshutdown=true" \
          "-Dsite.log_dir=$OUTPUT_PREFIX" \

          # Site Params
        "-Dsite.jvm_asserts=false" \
          "-Dsite.specexec_enable=false" \
          "-Dsite.cpu_affinity_one_partition_per_core=true" \
          #"-Dsite.cpu_partition_blacklist=0,2,4,6,8,10,12,14,16,18" \
          #"-Dsite.cpu_utility_blacklist=0,2,4,6,8,10,12,14,16,18" \
          "-Dsite.network_incoming_limit_txns=40000" \
          "-Dsite.commandlog_enable=false" \
          #"-Dsite.commandlog_dir=/mnt/pmfs/cmdlog" \
          "-Dsite.txn_incoming_delay=5" \
          "-Dsite.exec_postprocessing_threads=false" \
          "-Dsite.anticache_profiling=true" \
          #    "-Dsite.anticache_eviction_distribution=EVEN" \
          "-Dsite.specexec_enable=false" \


          #    "-Dsite.queue_allow_decrease=true" \
          #    "-Dsite.queue_allow_increase=true" \
          #    "-Dsite.queue_threshold_factor=0.5" \

          # Client Params
          "-Dclient.scalefactor=1" \
            "-Dclient.memory=2048" \
            # "-Dclient.txnrate=1562" \
            "-Dclient.txnrate=10000" \
            "-Dclient.warmup=10000" \
            "-Dclient.duration=900000" \
            "-Dclient.shared_connection=false" \
            "-Dclient.blocking=true" \
            "-Dclient.blocking_concurrent=100" \
            "-Dclient.throttle_backoff=100" \
            "-Dclient.output_anticache_evictions=${OUTPUT_PREFIX}/evictions.csv" \
            "-Dclient.output_memory=${OUTPUT_PREFIX}/memory.csv" \

            # Anti-Caching Experiments
          "-Dsite.anticache_enable=${ENABLE_ANTICACHE}" \
            "-Dsite.anticache_block_size=${ANTICACHE_BLOCK_SIZE}" \
            "-Dsite.anticache_dir=../../../media/SSD/anticache/tpcc" \
            "-Dsite.anticache_reset=true" \
            "-Dsite.anticache_check_interval=${INTERVAL}" \
            "-Dsite.anticache_threshold_mb=${THRESHOLD}" \
            "-Dsite.anticache_blocks_per_eviction=${NUM_EVICT}" \
            "-Dsite.anticache_max_evicted_blocks=100000" \
            #"-Dsite.anticache_evict_size=${ANTICACHE_EVICT_SIZE}" \
            #    "-Dsite.anticache_threshold=${ANTICACHE_THRESHOLD}" \
            "-Dsite.anticache_eviction_distribution=PROPORTIONAL" \

            # now batching..
          #    "-Dsite.anticache_batching=true" \

            # PROPORTIONAL or even ? 

          "-Dclient.interval=1000" \
            "-Dclient.anticache_enable=false" \
            "-Dclient.anticache_evict_interval=10000" \
            "-Dclient.anticache_evict_size=4194304" \
            "-Dclient.output_results_csv=${OUTPUT_PREFIX}/results.csv" \
            "-Dclient.output_interval=true" \

            # CLIENT DEBUG
          #    "-Dclient.output_txn_counters=${OUTPUT_PREFIX}/txncounters.csv" \
            "-Dclient.output_clients=false" \
            "-Dclient.profiling=false" \
            "-Dclient.output_response_status=false" \
            #    "-Dclient.output_queue_profiling=${OUTPUT_PREFIX}/queue.csv" \
            #    "-Dclient.output_basepartitions=true" \
            #     "-Dclient.jvm_args=\"-verbose:gc -XX:+PrintGCDetails -XX:+PrintGCTimeStamps -XX:-TraceClassUnloading\""
          )

          EVICTABLE_TABLES=( \
            "orders" \
            "order_line" \
            "history" \
            "new_order" \
            )

          EVICTABLES=""
          if [ "$ENABLE_ANTICACHE" = "true" ]; then
            for t in ${EVICTABLE_TABLES[@]}; do
              EVICTABLES="${t},${EVICTABLES}"
            done
          fi

          # Compile
          HOSTS_TO_UPDATE=("$SITE_HOST")
          for CLIENT_HOST in ${CLIENT_HOSTS[@]}; do
            NEED_UPDATE=1
            for x in ${HOSTS_TO_UPDATE[@]}; do
              if [ "$CLIENT_HOST" = "$x" ]; then
                NEED_UPDATE=0
                break
              fi
            done
            if [ $NEED_UPDATE = 1 ]; then
              HOSTS_TO_UPDATE+=("$CLIENT_HOST")
            fi
          done
          #for HOST in ${HOSTS_TO_UPDATE[@]}; do
          #    ssh $HOST "cd $BASE_DIR && git pull && ant compile" &
          #done
          wait

          ant compile

          ant build

          for i in 8; do
            HSTORE_HOSTS="${SITE_HOST}:0:0-"`expr $i - 1`
            NUM_CLIENTS=`expr $i \* $BASE_CLIENT_THREADS`
            SITE_MEMORY=`expr $BASE_SITE_MEMORY + \( $i \* $BASE_SITE_MEMORY_PER_PARTITION \)`

            # BUILD PROJECT JAR
            ant hstore-prepare \
              -Dproject=${BASE_PROJECT} \
              -Dhosts=${HSTORE_HOSTS} \
              -Devictable=${EVICTABLES}
            test -f ${BASE_PROJECT}.jar || exit -1

            # UPDATE CLIENTS
            CLIENT_COUNT=0
            CLIENT_HOSTS_STR=""
            for CLIENT_HOST in ${CLIENT_HOSTS[@]}; do
              CLIENT_COUNT=`expr $CLIENT_COUNT + 1`
              if [ ! -z "$CLIENT_HOSTS_STR" ]; then
                CLIENT_HOSTS_STR="${CLIENT_HOSTS_STR},"
              fi
              CLIENT_HOSTS_STR="${CLIENT_HOSTS_STR}${CLIENT_HOST}"
            done


            # DISTRIBUTE PROJECT JAR
            #    for HOST in ${HOSTS_TO_UPDATE[@]}; do
            #        if [ "$HOST" != $(hostname) ]; then
            #            scp -r ${BASE_PROJECT}.jar ${HOST}:${BASE_DIR} &
            #        fi
            #    done
            wait

            # STATUS

   #         iostat -xtc 1 > ${OUTPUT_PREFIX}/diskutil.txt &

            # EXECUTE BENCHMARK
            ant hstore-benchmark ${BASE_ARGS[@]} \
              -Dproject=${BASE_PROJECT} \
              -Dkillonzero=false \
              -Dclient.threads_per_host=${NUM_CLIENTS} \
              -Dsite.memory=${SITE_MEMORY} \
              -Dclient.hosts=${CLIENT_HOSTS_STR} \
              -Dclient.count=${CLIENT_COUNT} | tee ${OUTPUT_PREFIX}/record.txt

  #          sudo pkill iostat


            result=$?
            if [ $result != 0 ]; then
              exit $result
            fi
          done
        done
      done
    done
  done
