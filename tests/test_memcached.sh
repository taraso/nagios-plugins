#!/usr/bin/env bash
#  vim:ts=4:sts=4:sw=4:et
#
#  Author: Hari Sekhon
#  Date: 2015-05-25 01:38:24 +0100 (Mon, 25 May 2015)
#
#  https://github.com/harisekhon/nagios-plugins
#
#  License: see accompanying Hari Sekhon LICENSE file
#
#  If you're using my code you're welcome to connect with me on LinkedIn and optionally send me feedback to help improve or steer this or other code I publish
#
#  https://www.linkedin.com/in/harisekhon
#

set -euo pipefail
[ -n "${DEBUG:-}" ] && set -x
srcdir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

cd "$srcdir/..";

. ./tests/utils.sh

section "M e m c a c h e d"

export MEMCACHED_VERSIONS="${@:-${MEMCACHED_VERSIONS:-latest 1.4}}"

MEMCACHED_HOST="${DOCKER_HOST:-${MEMCACHED_HOST:-${HOST:-localhost}}}"
MEMCACHED_HOST="${MEMCACHED_HOST##*/}"
MEMCACHED_HOST="${MEMCACHED_HOST%%:*}"
export MEMCACHED_HOST

export MEMCACHED_PORT_DEFAULT=11211

check_docker_available

trap_debug_env memcached

startupwait 1

test_memcached(){
    local version="$1"
    section2 "Setting up Memcached $version test container"
    if is_CI; then
        VERSION="$version" docker-compose pull $docker_compose_quiet
    fi
    VERSION="$version" docker-compose up -d
    echo "getting Memcached dynamic port mapping:"
    printf "Memcached port => "
    export MEMCACHED_PORT="`docker-compose port "$DOCKER_SERVICE" "$MEMCACHED_PORT_DEFAULT" | sed 's/.*://'`"
    echo "$MEMCACHED_PORT"
    hr
    when_ports_available "$MEMCACHED_HOST" "$MEMCACHED_PORT"
    hr
    echo "creating test Memcached key-value"
    echo -ne "add myKey 0 100 4\r\nhari\r\n" | nc "$MEMCACHED_HOST" "$MEMCACHED_PORT"
    echo done
    if [ -n "${NOTESTS:-}" ]; then
        exit 0
    fi
    hr
    # TODO: add memcached version test

    # MEMCACHED_HOST obtained via .travis.yml
    run $perl -T ./check_memcached_write.pl -v
    hr
    run_conn_refused $perl -T ./check_memcached_write.pl -v
    hr
    run $perl -T ./check_memcached_key.pl -k myKey -e hari -v
    hr
    run_conn_refused $perl -T ./check_memcached_key.pl -k myKey -e hari -v
    hr
    run $perl -T ./check_memcached_stats.pl -w 15 -c 20 -v
    hr
    run_conn_refused $perl -T ./check_memcached_stats.pl -w 15 -c 20 -v
    hr
    echo "Completed $run_count Memcached tests"
    hr
    [ -n "${KEEPDOCKER:-}" ] ||
    docker-compose down
    hr
    echo
}

run_test_versions Memcached
