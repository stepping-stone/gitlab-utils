#!/bin/bash
################################################################################
# zabbix-maintenance-disable.sh - Disables Zabbix GitLab backup maintenance mode
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
# Disables the "Zabbix maintenance mode trigger" for the services unicorn and
# sidekiq by sennding a Zabbix trapper message for the following keys:
#  - sst.maintenance.status[unicorn] = 0
#  - sst.maintenance.status[sidekiq] = 0
#
# The scripts optionally sleeps for a specific amount of seconds (passed as the
# first argument) before it disables the maintenance mode.
# This ensures, that the Zabbix agent has sent new data before the maintenance
# mode will be be disabled.
#
# Usage:
# zabbix-maintenance-disable.sh
#
# Example:
# zabbix-maintenance-disable.sh
################################################################################
ZABBIX_SENDER_CMD="/usr/bin/zabbix_sender"

if ! test -x "${ZABBIX_SENDER_CMD}"; then
    echo "Command not found or not executable: '${ZABBIX_SENDER_CMD}'" >&2
    exit 1
fi

if [[ $1 =~ ^[0-9]+$ ]]; then
    echo "Ensure that the Zabbix agent has sent new data, by waiting for"
    echo "$1 seconds before disabling the maintenance mode"
    sleep $1
fi

${ZABBIX_SENDER_CMD} --config /etc/zabbix/zabbix_agentd.conf \
                     --key 'sst.maintenance.status[unicorn]' \
                     --value 0 \
                     --verbose

${ZABBIX_SENDER_CMD} --config /etc/zabbix/zabbix_agentd.conf \
                     --key 'sst.maintenance.status[sidekiq]' \
                     --value 0 \
                     --verbose
