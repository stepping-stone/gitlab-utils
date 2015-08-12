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
# gitlab-backup.sh
################################################################################

# Root directory of the GitLab utils
ROOT_DIR="$(dirname $(readlink -f ${0}))/../.."

# bash lib directory
LIB_DIR="${ROOT_DIR}/usr/share/stepping-stone/lib/bash"

# Required external commands
GETENT_CMD="/usr/bin/getent"
SU_CMD="/bin/su"

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
# Script Version
_VERSION="1.0.1"

# Default configuration file
_DEFAULT_CONFIG_FILE="${ROOT_DIR}/etc/gitlab-backup.conf"


# Process all arguments passed to this script
#
# processArguments
function processArguments ()
{
    # Define all options as unset by default
    declare -A optionFlags

    for optionName in c d h v; do
        optionFlags[${optionName}]=false
    done

    while getopts ":c:dhv" option; do
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

            v )
                printVersion
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
    -v              Display the version and exit
EOF
}

# Displays the version of this script
#
# printVersion
function printVersion ()
{
    cat << EOF
$( ${BASENAME_CMD} "$0" ) (gitlab-utils) ${_VERSION}

Copyright (C) 2015 stepping stone GmbH
License AGPLv3: GNU Affero General Public License version 3
                https://www.gnu.org/licenses/agpl-3.0.html
EOF
}


# Load and check the configuration values
#
# loadAndCheckConfig CONFIGFILE
function loadAndCheckConfig ()
{
    configLoadConfig "$1"

    # Get number of defined tasks (array values)
    local numberOfDefinedTasks=${#gitLabBackupTaskDescription[@]}
    debug "Defined tasks: ${numberOfDefinedTasks}"


    local configParameters='gitLabBackupTaskActive
                            gitLabBackupTaskDescription
                            gitLabBackupTaskCmd
                            gitLabBackupTaskUser
                           '

    local parameter=''
    for parameter in ${configParameters}; do
        configDieIfValueNotPresent "$parameter"

        local numberOfValues="$( eval echo \$\{\#${parameter}\[\@\]\} )"

        if [ ${numberOfValues} -ne ${numberOfDefinedTasks} ]; then
            error "Values doesn't match with defined number of tasks"
            error "${numberOfDefinedTasks} tasks vs. ${numberOfValues} values."
            die "Fix your task configuration for ${parameter}"
        fi
    done

    local i
    for i in ${!gitLabBackupTaskDescription[*]}; do
        if [ "${gitLabBackupTaskActive[$i]}" != true ]; then
            debug "Skipping task ${i} ($gitLabBackupTaskDescription)"
            continue
        fi

        configDieIfValueNotPresent "gitLabBackupTaskDescription[$i]"

        configDieIfValueNotPresent "gitLabBackupTaskCmd[$i]"

        # Passing ${gitLabBackupTaskCmd[$i]} unquoted is intentional to split
        # of the possible script arguments.
        validationDieIfCommandMissing ${gitLabBackupTaskCmd[$i]}

        configDieIfValueNotPresent "gitLabBackupTaskUser[$i]"

        if ! ${GETENT_CMD} passwd "${gitLabBackupTaskUser[$i]}" > /dev/null
        then
            die "User '${gitLabBackupTaskUser[$i]}' does not exist"
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
               ${SU_CMD}
    do
        validationDieIfCommandMissing "${cmd}"
    done
}

# Checks if the effective user ID is 0 (root)
#
# Terminates with an error message if not run as root
#
# checkRoot
function checkRoot ()
{
    if [[ $EUID -ne 0 ]]; then
        die "This script must be run as root"
    fi
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
    checkRoot
    loadAndCheckConfig "${configFile}"
    checkEnvironment

    # Uppercase the first letter of the action name and call the function
    action${action^}

    return $?
}

function actionBackup ()
{

    info "Starting GitLab backup"

    local errorCounter=0

    local i
    for i in ${!gitLabBackupTaskDescription[*]}; do
        if [ "${gitLabBackupTaskActive[$i]}" != true ]; then
            info "Skipping task ${i} - '${gitLabBackupTaskDescription[$i]}')"
            continue
        fi

        info "Run task ${i} - '${gitLabBackupTaskDescription[$i]}'"

        local message="Finished task '${gitLabBackupTaskDescription[$i]}'"
        if executeScript "${gitLabBackupTaskCmd[$i]}" \
                         "${gitLabBackupTaskUser[$i]}"
        then
            info "${message} successfully"
        else
            error "${message} with errors"
            ((errorCounter++))
        fi
    done

    local message="GitLab backup finished"
    test ${errorCounter} -eq 0 || die "${message} with ${errorCounter} errors"

    info "${message} successfully"
}

function executeScript ()
{
    local script="$1"
    local user="$2"

    info "Executing Script '$1' as user '$user'"

    local exitCode
    ${SU_CMD} --command "$script" \
              --login \
              --shell "/bin/bash" \
              "$user" 2> >(error -)

    exitCode=$?

    if [ $exitCode -ne 0 ]; then
        error "Script terminated with exit code: $exitCode"
    fi

    return $exitCode
}

main $@
