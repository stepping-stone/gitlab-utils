#!/bin/bash
################################################################################
# zabbix-maintenance-enable.sh - Enables Zabbix GitLab backup maintenance mode
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
# Enables the "Zabbix maintenance mode trigger" for the services unicorn and
# sidekiq by sennding a Zabbix trapper message for the following keys:
#  - sst.maintenance.status[unicorn] = 1
#  - sst.maintenance.status[sidekiq] = 1
#
# Usage:
# zabbix-maintenance-enable.sh
#
# Example:
# zabbix-maintenance-enable.sh
################################################################################

ZABBIX_SENDER_CMD="/usr/bin/zabbix_sender"

if ! test -x "${ZABBIX_SENDER_CMD}"; then
    echo "Command not found or not executable: '${ZABBIX_SENDER_CMD}'" >&2
    exit 1
fi

${ZABBIX_SENDER_CMD} --config /etc/zabbix/zabbix_agentd.conf \
                     --key 'sst.maintenance.status[unicorn]' \
                     --value 1 \
                     --verbose

${ZABBIX_SENDER_CMD} --config /etc/zabbix/zabbix_agentd.conf \
                     --key 'sst.maintenance.status[sidekiq]' \
                     --value 1 \
                     --verbose
