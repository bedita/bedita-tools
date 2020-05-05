#!/bin/bash

function print_usage () {
  printf "Usage: ./reindex.sh -t|--types <types> [-c|--concurrency <number>] [-s|--session <name>] [-d|--delete]\n"
  printf "\n"
  printf "Available parameters:\n"
  printf "\t-h|--help\t\tprint this help\n"
  printf "\t-t|--types\t\tcomma-separated list of types\n"
  printf "\t-c|--concurrency\treindex this many types concurrently\n"
  printf "\t-s|--session\t\ttmux session name, will be created if doesn't exists\n"
  printf "\t-d|--delete\t\tdelete current index before starting\n"
}

# default
SESSION='reindex'
CONCURRENCY=4
TYPES=()
DELETE=0
INITIAL_PANES=0

if [ "$#" -eq "0" ]; then
  print_usage
  exit 0
fi

# read parameters (thanks https://stackoverflow.com/a/14203146/2270403)
while [[ "$#" -gt "0" ]]; do
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
      CONCURRENCY="$2"
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

START_TIME="$(date +"%s")"
COMMAND="echo Reindex of type ${TYPES[0]} && ./cake.sh dbadmin rebuildIndex -type ${TYPES[0]}"

# handle delete parameter
if [ "$DELETE" -eq "0" ]; then
  printf "[%s] Starting reindex for type '%s'\n" "$(date +"%F %T")" "${TYPES[0]}"
else
  COMMAND="$COMMAND -delete"
  printf "[%s] Deleting old index and starting reindex for type '%s'\n" "$(date +"%F %T")" "${TYPES[0]}"
fi

# start reindex for first type, creating tmux session if needed
if ! tmux has-session -t "$SESSION" > /dev/null 2>&1; then
  tmux new-session -d -s "$SESSION" "$COMMAND"
  tmux select-window -t "$SESSION":0
else
  tmux select-window -t "$SESSION":0
  # account for panels already open
  INITIAL_PANES="$(tmux list-panes -s -t "$SESSION" | wc -l)"
  ((CONCURRENCY += INITIAL_PANES))
  tmux split-window -t "$SESSION":0.0 "$COMMAND"
  tmux select-layout -t "$SESSION":0 tiled
fi

# wait an arbitrary amount of time for index deletion to take effect
sleep 5

# reindex all types
for type in "${TYPES[@]:1}"; do
  while [ "$(tmux list-panes -s -t "$SESSION" | wc -l)" -ge "$CONCURRENCY" ]; do
    sleep 3
  done

  printf "[%s] Starting reindex for type '%s'\n" "$(date +"%F %T")" "$type"
  tmux split-window -t "$SESSION":0.0 "echo Reindex of type $type && ./cake.sh dbadmin rebuildIndex -type $type"
  tmux select-layout -t "$SESSION":0 tiled
  sleep 1
done

printf "[%s] All types started, waiting for reindex to finish..." "$(date +"%F %T")"

# wait for all types to finish
while [ "$(tmux list-panes -s -t "$SESSION" | wc -l)" -gt "$INITIAL_PANES" ]; do
  sleep 3

  if ! tmux has-session -t "$SESSION" > /dev/null 2>&1; then
    break
  fi
done

printf "done!\n"
ELAPSED_TIME=$(($(date +"%s") - "$START_TIME"))
printf "[%s] Total elapsed time: %s\n" "$(date +"%F %T")" "$(date -u -d @"$ELAPSED_TIME" +"%T")"
