#!/bin/bash
################################################################################
# redis-dump.sh - Creates a new Redis snapshot
################################################################################
#
# Copyright (C) 2015 stepping stone GmbH
#                    Switzerland
#                    http://www.stepping-stone.ch
#                    support@stepping-stone.ch
#
# Authors:
#  Christian Affolter <christian.affolter@stepping-stone.ch>
#
# This program is free software: you can redistribute it and/or
# modify it under the terms of the GNU Affero General Public 
# License as published  by the Free Software Foundation, version
# 3 of the License.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public
# License  along with this program.
# If not, see <http://www.gnu.org/licenses/>.
#
#
# Description:
# Creates a new Redis database snapshot (RDB) with the BGSAVE command
# The snapshot will be stored at /var/lib/redis/dump.rdb
# See: http://redis.io/commands/bgsave and http://redis.io/topics/persistence
#
# Usage:
# redis-dump.sh
#
# Example
# redis-dump.sh
################################################################################

REDIS_CLI_CMD="/usr/bin/redis-cli"
REDIS_SOCKET="/run/redis/redis.sock"

if ! test -x "${REDIS_CLI_CMD}"; then
    echo "Command not found or not executable: '${REDIS_CLI_CMD}'" >&2
    exit 1
fi

if ! test -S "${REDIS_SOCKET}"; then
    echo "Redis socket does not exist: '${REDIS_SOCKET}'" >&2
    exit 1
fi

redisCmd="${REDIS_CLI_CMD} -s ${REDIS_SOCKET} --raw"

# Get the UNIX TIME of the last DB save executed with success
originalLastSave="$( ${redisCmd} LASTSAVE )" 

if [ $? -ne 0 ]; then
    echo "Redis LASTSAVE command failed" >&2
    exit 2
fi

lastSave=0

# Issue a background DB save
${redisCmd} BGSAVE

if [ $? -ne 0 ]; then
    echo "Redis BGSAVE command failed" >&2
    exit 2
fi

# Wait until the last DB save timestamp has changed
until [ ${lastSave} -gt ${originalLastSave} ]; do
    lastSave="$( ${redisCmd} LASTSAVE )"

    if [ $? -ne 0 ]; then
        echo "Redis LASTSAVE command failed" >&2
        exit 2
    fi

    #echo "originalLastSave: ${originalLastSave}"
    #echo "lastSave:         $lastSave"
    #echo ""
    sleep 1
done
