#!/bin/bash

print_usage() {
  printf "Usage: ./reindex.sh [-t|--types <types>] [--min <number> --max <number>] [-c|--concurrency <number>] [-s|--session <name>] [-d|--delete]\n"
  printf "\n"
  printf "This script is used to concurrently reindex objects in the configured search engine.\n"
  printf "Reindexing of objects can be made concurrently by specifying either multiple object types or min/max IDs.\n"
  printf "\n"
  printf "Available parameters:\n"
  printf "\t -h|--help\n"
  printf "\t\t print this help\n\n"
  printf "\t -t|--types <types>\n"
  printf "\t\t comma-separated list of object types\n"
  printf "\t\t WARN: mutually exclusive with --min and --max parameters\n\n"
  printf "\t --min <number> | --max <number>\n"
  printf "\t\t minimum and maximum object ID to index\n"
  printf "\t\t WARN: both must be defined; mutually exclusive with --types parameter\n\n"
  printf "\t -c|--concurrency <number>\n"
  printf "\t\t concurrent reindex shells\n\n"
  printf "\t -s|--session <name>\n"
  printf "\t\t tmux session name, will be created if doesn't exists\n\n"
  printf "\t -d|--delete\n"
  printf "\t\t delete current index before starting\n"
  printf "\t\t WARN: if using object types, be sure that the first type has few objects otherwise it will delay all others!\n\n"
  printf "\t -l|--log\n"
  printf "\t\t log errors in rebuildIndex.log file\n\n"
}

session_exist() {
  tmux has-session -t "$SESSION" 2> /dev/null
}

select_window() {
  tmux select-window -t "$SESSION":0
}

create_session() {
  tmux new-session -d -s "$SESSION"
}

kill_session() {
  tmux kill-session -t "$SESSION"
}

split_window() {
  tmux split-window -t "$SESSION":0.0 "$1"
  tmux select-layout -t "$SESSION":0 tiled
}

count_panes() {
  tmux list-panes -t "$SESSION":0 | wc -l
}

current_time() {
  date +"%F %T"
}

current_timestamp() {
  date +"%s"
}

reindex_by_types() {
  printf "[%s] Starting reindex of %s types, %s at a time\n" "$(current_time)" "${#TYPES[@]}" "$MAX_PANES"
  
  if [ "$DELETE" -eq "1" ]; then
    # pop first type from array
    type="${TYPES[0]}"
    TYPES=("${TYPES[@]:1}")

    printf "[%s] Deleting old index and starting reindex of type '%s'\n" "$(current_time)" "$type"
    split_window "echo Reindex of type $type && ./cake.sh dbadmin rebuildIndex -delete -type $type$LOG"
  
    # wait first type to finish
    while [ "$(count_panes)" -gt "$INITIAL_PANES" ]; do
      sleep 1
    done
  fi
  
  for type in "${TYPES[@]}"; do
    while [ "$(count_panes)" -ge "$(( MAX_PANES + INITIAL_PANES ))" ]; do
      sleep 1
    done
  
    printf "[%s] Starting reindex of type '%s'\n" "$(current_time)" "$type"
    split_window "echo Reindex of type $type && ./cake.sh dbadmin rebuildIndex -type $type$LOG"
    sleep 1
  done
}

reindex_by_ids() {
  printf "[%s] Starting reindex of %s objects, %s at a time\n" "$(current_time)" "$(( 1 + $MAX_ID - $MIN_ID ))" "$MAX_PANES"
  
  size="$(( ($MAX_ID - $MIN_ID) / $MAX_PANES ))"
  start_id="$MIN_ID"
  end_id="$(( start_id + size ))"

  if [ "$DELETE" -eq "1" ]; then
    printf "[%s] Deleting old index and starting reindex from object ID %s\n" "$(current_time)" "$start_id"
    split_window "echo Reindex of object $start_id && ./cake.sh dbadmin rebuildIndex -delete -id $start_id$LOG"
    (( start_id += 1 ))
  
    # wait first type to finish
    while [ "$(count_panes)" -gt "$INITIAL_PANES" ]; do
      sleep 1
    done
  fi
  
  while [ "$start_id" -le "$MAX_ID" ]; do
    while [ "$(count_panes)" -ge "$(( MAX_PANES + INITIAL_PANES ))" ]; do
      sleep 1
    done

    printf "[%s] Starting reindex of objects in range %s-%s\n" "$(current_time)" "$start_id" "$end_id"
    split_window "echo Reindex of range $start_id-$end_id && ./cake.sh dbadmin rebuildIndex -min $start_id -max $end_id$LOG"
    start_id="$(( end_id + 1 ))"
    end_id="$(( start_id + size ))"
    if [ "$end_id" -gt "$MAX_ID" ]; then
      end_id="$MAX_ID"
    fi
  done
}

# default
SESSION='reindex'
MAX_PANES="$(getconf _NPROCESSORS_ONLN)"
TYPES=()
MIN_ID=
MAX_ID=
DELETE=0
LOG=

if [ "$#" -eq "0" ]; then
  print_usage
  exit 0
fi

# read parameters (thanks https://stackoverflow.com/a/14203146/2270403)
while [ "$#" -gt "0" ]; do
  key="$1"

  case $key in
    -h|--help)
      print_usage
      exit 0
      ;;
    -t|--types)
      OLD_IFS="$IFS"
      IFS=',' read -r -a TYPES <<< "$2"
      IFS="$OLD_IFS"
      shift
      shift
      ;;
    --min)
      MIN_ID="$2"
      shift
      shift
      ;;
    --max)
      MAX_ID="$2"
      shift
      shift
      ;;
    -c|--concurrency)
      MAX_PANES="$2"
      shift
      shift
      ;;
    -s|--session)
      SESSION="$2"
      shift
      shift
      ;;
    -d|--delete)
      DELETE=1
      shift
      ;;
    -l|--log)
      LOG=" -log"
      shift
      ;;
    *) # unknown option, ignore
      shift
      ;;
  esac
done

if ([ -n "$MIN_ID" ] || [ -n "$MAX_ID" ]) && [ "${#TYPES[@]}" -gt "0" ]; then
  printf "Parameters --types and --min|--max are mutually exclusive\n"
  exit 1
fi

if ([ -n "$MIN_ID" ] && [ -z "$MAX_ID" ]) || ([ -z "$MIN_ID" ] && [ -n "$MAX_ID" ]); then
  printf "Both --min and --max must be defined\n"
  exit 1
fi

if [ -z "$MIN_ID" ] && [ -z "$MAX_ID" ] && [ "${#TYPES[@]}" -eq "0" ]; then
  printf "Either --types or --min|--max must be defined\n"
  exit 1
fi

START_TIME="$(current_timestamp)"
DID_CREATE=0

if session_exist; then
  printf "[%s] Using tmux session '%s'\n" "$(current_time)" "$SESSION"
else
  create_session
  DID_CREATE=1
  printf "[%s] Created tmux session '%s'\n" "$(current_time)" "$SESSION"
fi

INITIAL_PANES="$(count_panes)"
#(( MAX_PANES += INITIAL_PANES ))
select_window

if [ "${#TYPES[@]}" -gt "0" ]; then
  reindex_by_types
elif [ -n "$MIN_ID" ] && [ -n "$MAX_ID" ]; then
  reindex_by_ids
else
  printf "How did you get here?\n"
  exit 1
fi
  
printf "[%s] All reindexing started, waiting to finish..." "$(current_time)"

# wait for all reindexing to finish
while [ "$(count_panes)" -gt "$INITIAL_PANES" ]; do
  sleep 1
done

printf "done!\n"
END_TIME="$(current_timestamp)"
ELAPSED_TIME="$((END_TIME - START_TIME))"
printf "[%s] Total elapsed time: %s\n" "$(current_time)" "$(date -u -d @"$ELAPSED_TIME" +"%T")"

# kill session if we created it
if [ "$DID_CREATE" -eq "1" ]; then
  kill_session
fi
