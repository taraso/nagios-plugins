#!/usr/bin/env bash
#  vim:ts=4:sts=4:sw=4:et
#
#  Author: Hari Sekhon
#  Date: 2016-05-06 12:12:15 +0100 (Fri, 06 May 2016)
#
#  https://github.com/harisekhon/nagios-plugins
#
#  License: see accompanying Hari Sekhon LICENSE file
#
#  If you're using my code you're welcome to connect with me on LinkedIn and optionally send me feedback
#
#  https://www.linkedin.com/in/harisekhon
#

set -euo pipefail
[ -n "${DEBUG:-}" ] && set -x

srcdir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

cd "$srcdir/.."

. "$srcdir/utils.sh"

is_travis && exit 0

section "M a p R"

export SANDBOX_CLUSTER="demo.mapr.com"
export MAPR_PORT="${MAPR_PORT:-8443}"
export MAPR_USER="${MAPR_USER:-mapr}"
export MAPR_PASSWORD="${MAPR_USER:-mapr}"
export MAPR_CLUSTER="${MAPR_CLUSTER:-$SANDBOX_CLUSTER}"
export MAPR_VERSION="${MAPR_VERSION:-.*}"
export NO_SSL="${NO_SSL-}"
PROTOCOL="https"

trap_debug_env mapr

no_ssl=""
if [ "$MAPR_CLUSTER" = "$SANDBOX_CLUSTER" -o -n "$NO_SSL" ]; then
    no_ssl="--no-ssl"
    PROTOCOL="http"
fi

if [ -z "${MAPR_HOST:-}" ]; then
    echo "WARNING: \$MAPR_HOST not set, skipping MapR Control System checks"
    exit 0
fi

if ! when_ports_available 5 "$MAPR_HOST" "$MAPR_PORT"; then
    echo "WARNING: MapR Control System host $MAPR_HOST:$MAPR_PORT not up, skipping MapR Control System checks"
    exit 0
fi

if ! when_url_content 5 "$PROTOCOL://$MAPR_HOST:$MAPR_PORT/mcs" MapR; then
    echo "WARNING: MapR Control System host $PROTOCOL://$MAPR_HOST:$MAPR_PORT/mcs did not contain MapR in html, may be some other service bound to the port, skipping..."
    exit 0
fi

# ============================================================================ #

set +o pipefail

# messes up geting these variables right which impacts the runs of the plugins further down
if [ -n "${DEBUG:-}" ]; then
    DEBUG2="$DEBUG"
    export DEBUG=""
fi

node="$(check_mapr_node_mapr-fs_disks.pl --list-nodes $no_ssl | tail -n1)"

volumes="$(./check_mapr-fs_volume_mirroring.pl --list-volumes $no_ssl | awk '{print $1}' | tail -n +5)"

set -o pipefail

echo "Volumes:

$volumes
"

volume="$(bash-tools/random_select.sh $volumes)"

echo "Selected volume for tests: $volume"

if [ -n "${DEBUG2:-}" ]; then
    export DEBUG="$DEBUG2"
fi

# Sandbox often has some broken stuff, we're testing the code works, not the cluster
[ "$MAPR_CLUSTER" = "$SANDBOX_CLUSTER" ] && set +e

# ============================================================================ #

hr
run $perl -T check_mapr-fs_space.pl $no_ssl
hr
run $perl -T check_mapr-fs_volume.pl $no_ssl
hr
run $perl -T check_mapr-fs_volume_mirroring.pl $no_ssl -L $volume
hr
run $perl -T check_mapr-fs_volume_replication.pl $no_ssl -L $volume
hr
run $perl -T check_mapr-fs_volume_snapshots.pl $no_ssl -L $volume
hr
run $perl -T check_mapr-fs_volume_space_used.pl $no_ssl -L $volume
hr
run $perl -T check_mapr_alarms.pl $no_ssl
hr
run $perl -T check_mapr_cluster_version.pl $no_ssl -e "$MAPR_VERSION"
hr
run $perl -T check_mapr_dashboard.pl $no_ssl
hr
run $perl -T check_mapr_dialhome.pl $no_ssl
hr
# must be run locally
#run $perl -T check_mapr_disk_balancer_metrics.pl
hr
run $perl -T check_mapr_license.pl $no_ssl
hr
run $perl -T check_mapr_mapreduce_mode.pl $no_ssl
hr
run $perl -T check_mapr_memory_utilization.pl $no_ssl
hr
run $perl -T check_mapr_node_alarms.pl $no_ssl
hr
run $perl -T check_mapr_node_failed_disks.pl $no_ssl
hr
run $perl -T check_mapr_node_health.pl $no_ssl
hr
run $perl -T check_mapr_node_heartbeats.pl $no_ssl
hr
run $perl -T check_mapr_node_mapr-fs_disks.pl $no_ssl -N $node
hr
run $perl -T check_mapr_node_services.pl $no_ssl -N $node
hr
run $perl -T check_mapr_nodes.pl $no_ssl
hr
# must be run locally
#run $perl -T check_mapr_role_balancer.pl $no_ssl
hr
# must be run locally
#run $perl -T check_mapr_role_balancer_metrics.pl $no_ssl
hr
# when inheriting $MAPR_CLUSTER=demo.mapr.com it doesn't get back services, only when omitting --cluster / -C
run $perl -T check_mapr_services.pl $no_ssl -C ""
hr
echo "Completed $run_count MapR tests"
echo
echo "All MapR tests completed successfully"
echo
echo
