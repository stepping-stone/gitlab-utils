#!/bin/bash
################################################################################
# gitlab-backup.sh - Performs a consistent GitLab backup
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
# See https://github.com/stepping-stone/gitlab-utils/blob/develop/README.md
#
# Usage:
# gitlab-backup.sh <OPTIONS-AND-ARGUMENTS>
#
# Example:
# gitlab-backup.sh <EXAMPLE-OPTIONS-AND-ARGUMENTS>
################################################################################

# Root directory of the GitLab utils
ROOT_DIR="$(dirname $(readlink -f ${0}))/../.."

# bash lib directory
LIB_DIR="${ROOT_DIR}/usr/share/stepping-stone/lib/bash"

# Required external commands
GETENT_CMD="/usr/bin/getent"
REDIS_CLI_CMD="/usr/bin/redis-cli"

source "${LIB_DIR}/input-output.lib.sh"
source "${LIB_DIR}/config.lib.sh"
source "${LIB_DIR}/validation.lib.sh"
source "${LIB_DIR}/input-validation.lib.sh"


# Set restrictive umask by default
umask 0077

# Patterns that match no files shall expand to zero arguments, rather than to
# themselves.
shopt -s nullglob


##
# Private variables, do not overwrite them
#
# Default configuration file
_DEFAULT_CONFIG_FILE="${ROOT_DIR}/etc/gitlab-backup.conf"


# Process all arguments passed to this script
#
# processArguments
function processArguments ()
{
    # Define all options as unset by default
    declare -A optionFlags

    for optionName in a c d h i; do
        optionFlags[${optionName}]=false
    done

    while getopts ":c:dhi:" option; do
        debug "Processing option '${option}'"

        case $option in
            c )
                configFile="${OPTARG}"
                debug "Using config file: ${configFile}"
            ;;

            d )
                export DEBUG="yes"
                debug "Enabling debug messages"
            ;;

            h )
                printUsage
                exit 0
            ;;

            \? )
                error "Invalid option '-${OPTARG}' specified"
                printUsage
                exit 1
            ;;

            : )
                error "Missing argument for '-${OPTARG}'"
                printUsage
                exit 1
            ;;
        esac

        optionFlags[${option}]=true # Option was provided
    done

    # Set static action, as there are currently no other ones
    action="backup"

    if ! ${optionFlags[c]}; then
        debug "No config file was provided, use the default one"
        configFile="${_DEFAULT_CONFIG_FILE}"
    fi
}


# Displays the help message
#
# printUsage
function printUsage ()
{
    cat << EOF

Usage: $( ${BASENAME_CMD} "$0" ) [OPTION]...

    -c CONFIGFILE   Specifies the configuration file to use, which defaults to
                    $(realpath -m ${_DEFAULT_CONFIG_FILE})

    -d              Enable debug messages
    -h              Display this help and exit
EOF
}


# Load and check the configuration values
#
# loadAndCheckConfig CONFIGFILE
function loadAndCheckConfig ()
{
    configLoadConfig "$1"

    local configParameters='gitLabUtilsMaintenanceModeActive
                            gitLabUtilsMaintenanceModeEnableScript
                            gitLabUtilsMaintenanceModeDisableScript
                            gitLabUtilsMaintenanceModeUser
                            gitLabUtilsServiceShutdown
                            gitLabUtilsServiceShutdownStopScript
                            gitLabUtilsServiceShutdownStartScript
                            gitLabUtilsServiceShutdownUser
                            gitLabUtilsRdbmsDump
                            gitLabUtilsRdbmsDumpScript
                            gitLabUtilsRdbmsDumpUser
                            gitLabUtilsFileBackup
                            gitLabUtilsFileBackupScript
                            gitLabUtilsFileBackupUser
                            gitLabUtilsNoSqlDump
                            gitLabUtilsNoSqlDumpScript
                            gitLabUtilsNoSqlDumpUser
                           '

    local parameter=''
    for parameter in ${configParameters}; do
        configDieIfValueNotPresent "$parameter"
    done

    local script=''
    for script in ${gitLabUtilsMaintenanceModeEnableScript} \
                  ${gitLabUtilsMaintenanceModeDisableScript} \
                  ${gitLabUtilsServiceShutdownStopScript} \
                  ${gitLabUtilsServiceShutdownStartScript} \
                  ${gitLabUtilsRdbmsDumpScript} \
                  ${gitLabUtilsFileBackupScript} \
                  ${gitLabUtilsNoSqlDumpScript}
    do
        # Passing ${script} unquoted was intentional to split of the possible
        # script arguments.
        validationDieIfCommandMissing ${script}
    done

    local user
    for user in ${gitLabUtilsMaintenanceModeUser} \
                ${gitLabUtilsServiceShutdownUser} \
                ${gitLabUtilsRdbmsDumpUser} \
                ${gitLabUtilsFileBackupUser} \
                ${gitLabUtilsNoSqlDumpUser};
    do
        if ! ${GETENT_CMD} passwd "${user}" > /dev/null; then
            die "User '$user' does not exist"
        fi
    done
}


# Checks the local environment
#
# Ensures that all external commands are available
#
# checkEnvironment
function checkEnvironment ()
{
    local cmd=''
    for cmd in ${GETENT_CMD} \
               ${REDIS_CMD}
    do
        validationDieIfCommandMissing "${cmd}"
    done
}


# The main function of this script
#
# Processes the passed command line options and arguments,
# loads and validates the configuration and calls the action.
#
# main $@
function main ()
{
    processArguments $@
    loadAndCheckConfig "${configFile}"
    checkEnvironment

    # Uppercase the first letter of the action name and call the function
    action$(action^)

    return $?
}

function actionBackup ()
{
    return true
}


main
