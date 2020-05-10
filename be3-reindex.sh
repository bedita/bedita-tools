#!/bin/bash

function print_usage () {
  printf "Usage: ./be3-reindex.sh -t|--types <types> [-c|--concurrency <number>] [-s|--session <name>] [-d|--delete]\n"
  printf "\n"
  printf "Available parameters:\n"
  printf "\t-h|--help\t\t print this help\n"
  printf "\t-t|--types\t\t comma-separated list of types\n"
  printf "\t-c|--concurrency\t reindex this many types concurrently\n"
  printf "\t-s|--session\t\t tmux session name, will be created if doesn't exists\n"
  printf "\t-d|--delete\t\t delete current index before starting\n"
  printf "\t           \t\t WARN: be sure that the first type has few objects, otherwise it will delay all others!\n"
}

function session_exist () {
  tmux has-session -t "$SESSION" 2> /dev/null
}

function select_window () {
  tmux select-window -t "$SESSION":0
}

function create_session () {
  tmux new-session -d -s "$SESSION"
}

function kill_session () {
  tmux kill-session -t "$SESSION"
}

function split_window () {
  tmux split-window -t "$SESSION":0.0 "$1"
  tmux select-layout -t "$SESSION":0 tiled
}

function count_panes () {
  tmux list-panes -t "$SESSION":0 | wc -l
}

function current_date () {
  date +"%F %T"
}

function current_timestamp () {
  date +"%s"
}

# default
SESSION='reindex'
MAX_PANES=4
TYPES=()
DELETE=0

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
      *)    # unknown option, ignore
      shift
      ;;
  esac
done

if [ "${#TYPES[@]}" -eq "0" ]; then
  printf "No types selected\n"
  exit 1
fi

printf "[%s] Starting reindex of %s types, %s at a time\n" "$(current_date)" "${#TYPES[@]}" "$MAX_PANES"
START_TIME="$(current_timestamp)"
DID_CREATE=0

if session_exist; then
  printf "[%s] Using tmux session '%s'\n" "$(current_date)" "$SESSION"
else
  create_session
  DID_CREATE=1
  printf "[%s] Created tmux session '%s'\n" "$(current_date)" "$SESSION"
fi

INITIAL_PANES="$(count_panes)"
(( MAX_PANES += INITIAL_PANES ))
select_window

if [ "$DELETE" -eq "1" ]; then
  # pop first type from array
  type="${TYPES[0]}"
  TYPES=("${TYPES[@]:1}")

  printf "[%s] Deleting old index and starting reindex of type '%s'\n" "$(current_date)" "$type"
  split_window "echo Reindex of type $type && ./cake.sh dbadmin rebuildIndex -delete -type $type"

  # wait first type to finish
  while [ "$(count_panes)" -gt "$INITIAL_PANES" ]; do
    sleep 1
  done
fi

for type in "${TYPES[@]}"; do
  while [ "$(count_panes)" -ge "$MAX_PANES" ]; do
    sleep 1
  done

  printf "[%s] Starting reindex of type '%s'\n" "$(current_date)" "$type"
  split_window "echo Reindex of type $type && ./cake.sh dbadmin rebuildIndex -type $type"
  sleep 1
done

printf "[%s] All types started, waiting for reindex to finish..." "$(current_date)"

# wait for all types to finish
while [ "$(count_panes)" -gt "$INITIAL_PANES" ]; do
  sleep 1
done

printf "done!\n"
END_TIME="$(current_timestamp)"
ELAPSED_TIME="$((END_TIME - START_TIME))"
printf "[%s] Total elapsed time: %s\n" "$(current_date)" "$(date -u -d @"$ELAPSED_TIME" +"%T")"

# kill session if we created it
if [ "$DID_CREATE" -eq "1" ]; then
  kill_session
fi
