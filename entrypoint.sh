#!/bin/sh

shutdown() {
  echo "shutting down container"

  # first shutdown any service started by runit
  for _srv in $(ls -1 /etc/service); do
    sv force-stop $_srv
  done

  echo "shutting down runsvdir"

  # shutdown runsvdir command
  kill -HUP $RUNSVDIR
  wait $RUNSVDIR

  # give processes time to stop
  sleep 0.5

  echo "killing rest processes"
  # kill any other processes still running in the container
  for _pid  in $(ps -eo pid | grep -v PID  | tr -d ' ' | grep -v '^1$' | head -n -6); do
    timeout -t 5 /bin/sh -c "kill $_pid && wait $_pid || kill -9 $_pid"
  done
  exit
}


echo "---------> Start Executing Processes <-------------"
. /opt/graphite/bin/activate

PATH="${PATH}:/usr/local/bin"

# run all scripts in the run_once folder
[ -d /etc/run_once ] && /bin/run-parts /etc/run_once

## check services to disable
for _srv in $(ls -1 /etc/service); do
    eval X=$`echo -n $_srv | tr [:lower:]- [:upper:]_`_DISABLED
    [ -n "$X" ] && touch /etc/service/$_srv/down
done

# remove stale pids
find /opt/graphite/storage -maxdepth 1 -name '*.pid' -delete

# chown logrotate fle (#111)
chown 0644 /etc/logrotate.d/*

exec runsvdir -P /etc/service &
RUNSVDIR=$!
echo "Started runsvdir, PID is $RUNSVDIR"
echo "wait for processes to start...."

sleep 5
for _srv in $(ls -1 /etc/service); do
    sv status $_srv
done

echo "--------> Finsihed Executing Processes <---------------"
shutdown
