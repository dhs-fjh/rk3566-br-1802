#!/bin/sh

EVENT=${1:-short-press}

TIMEOUT=2 # s
PIDFILE="/tmp/$(basename $0).pid"
LOCKFILE=/tmp/.power_key


short_press()
{
	echo "Power key short press... nothing..." > /dev/console
}

short_press_bak()
{
	logger -t $(basename $0) "[$$]: Power key short press..."

	if type pm-suspend &>/dev/null; then
		SUSPEND_CMD="pm-suspend"
	else
		SUSPEND_CMD="echo -n mem > /sys/power/state"
	fi

	if [ ! -f $LOCKFILE ]; then
		logger -t $(basename $0) "[$$]: Prepare to suspend..."

		touch $LOCKFILE
		sh -c "$SUSPEND_CMD"
		{ sleep 2 && rm $LOCKFILE; }&
	fi
}

long_press()
{
	logger -t $(basename $0) "[$$]: Power key long press (${TIMEOUT}s)..."

	logger -t $(basename $0) "[$$]: Prepare to power off..."

	# 关闭 record_auto 进程
	echo "close record_auto process" > /dev/console
	pkill -f record_auto || true
	pkill -f record || true

	echo "Power key long press..." > /dev/console
	echo "Prepare to power off..." > /dev/console
	sync

	poweroff
}

logger -t $(basename $0) "[$$]: Received power key event: $@..."

case "$EVENT" in
	press)
		# Lock it
		exec 3<$0
		flock -x 3

		start-stop-daemon -K -q -p $PIDFILE || true
		start-stop-daemon -S -q -b -m -p $PIDFILE -x /bin/sh -- \
			-c "sleep $TIMEOUT; $0 long-press"

		# Unlock
		flock -u 3
		;;
	release)
		# Avoid race with press event
		sleep .5

		start-stop-daemon -K -q -p $PIDFILE && short_press
		;;
	short-press)
		short_press
		;;
	long-press)
		long_press
		;;
esac
