#!/bin/sh
#
# check_vcs_heartbeatlinks.sh
#
# Check Veritas Cluster Server HeartBeat link status.
# Currently only tested on Solaris 10 x86 with OP5
#
# Author: Andreas Lindh <andreas@innovationgroup.se>
#
# Requirements:
#   Linux:
#       Ethtool
#

RC=0

SUDOBIN=$(which sudo)
DLADMBIN=$(which dladm)
GREPBIN=$(which grep)
AWKBIN=$(which awk)
SEDBIN=$(which sed)
ETHTOOLBIN=$(which ethtool)

# Check platform/OS/distro and CPU architecture, prepare for
# anomalities in uname binary between OS'
OS_PLATFORM=$(uname -s)
case "$OS_PLATFORM" in
    SunOS)
        OS_VERSION=$(uname -r)
        PLATFORM_ARCH=$(uname -p)
        ;;
    Linux)
        OS_VERSION=$(uname -r)
        PLATFORM_ARCH=$(uname -p)
        ;;
    *)
        OS_VERSION=$(uname -r)
        PLATFORM_ARCH=$(uname -p)
        ;;
esac

# Check if we do have OP5 utils
if [ -f /opt/op5/plugins/utils.sh ] ; then
    . /opt/op5/plugins/utils.sh
fi

HBDEVS=`$GREPBIN ^link /etc/llttab|$AWKBIN '{print $3}'|$SEDBIN 's/://;s_/dev/__'`

# $1 is interface name
get_link_status () {
    case "$OS_PLATFORM" in
        SunOS)
            echo `$SUDOBIN $DLADMBIN show-dev $1 -p|$AWKBIN '{print $2}'|$AWKBIN -F'=' '{print $2}'`
            ;;
        Linux)
            echo `$SUDOBIN $ETHTOOLBIN $1|$AWKBIN '/Link detected/ {print $3}'|$SEDBIN 's/yes/UP/;s/no/DOWN/;'`
    esac
}

STATUSLINE=""
for dev in $HBDEVS; do
    DEVSTATUS=`get_link_status $dev|tr '[a-z]' '[A-Z]'`
    STATUSLINE="${STATUSLINE} ${dev}:${DEVSTATUS}"
    if [ "$DEVSTATUS" != "UP" ]; then
        RC=$STATE_CRITICAL
    fi
done

if [ "$RC" == "$STATE_CRITICAL" ]; then
    echo "CRITICAL: $STATUSLINE - one or more HB links offline"
else
    echo "OK: $STATUSLINE - all HB links are online"
fi
exit $RC