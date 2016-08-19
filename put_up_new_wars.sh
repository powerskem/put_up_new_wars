#!/bin/bash
# ##################################################
#
version="0.0.1"              # Sets version variable
#
# HISTORY:
#
# * DATE - v0.0.1  - First Creation
#
# USAGE: ./put_up_new_wars.sh newfile1.war newfile2.war
#
# ##################################################
# Immediately exit if any cmd has non-zero exit status
set -e
# Immediately exit if ref to any var not previously
# defined - with the exceptions of $* and $@
set -u
# If any cmd in a pipeline fails, use that return code
# as the return code of the whole pipeline
set -o pipefail
# Set Internal Field Separator
IFS=$'\n\t'

# ##################################################
# test tputcolors
#echo
#echo -e "$(tput bold) reg  bld  und   tput-command-colors$(tput sgr0)"
#for i in $(seq 1 7); do echo " $(tput setaf $i)Text$(tput sgr0) $(tput bold)$(tput setaf $i)Text$(tput sgr0) $(tput sgr 0 1)$(tput setaf $i)Text$(tput sgr0)  \$(tput setaf $i)"
#done
#echo ' Bold            $(tput bold)'
#echo ' Underline       $(tput sgr 0 1)'
#echo ' Reset           $(tput sgr0)'
#echo
# ##################################################

# ------------------------------------------------------
# Set Colors
# ------------------------------------------------------
export TERM=xterm

bold=$(tput bold)
underline=$(tput sgr 0 1)
reset=$(tput sgr0)

red=$(tput setaf 1)
green=$(tput setaf 2)
yellow=$(tput setaf 3)
blue=$(tput setaf 4)
purple=$(tput setaf 5)
ltblue=$(tput setaf 6)
white=$(tput setaf 7)

# ##################################################
# utils from https://github.com/natelandau/shell-scripts/
# ------------------------------------------------------
# Traps - These functions are for use with trap scenarios
# Non destructive exit for when script exits naturally.
# Usage: Add this function at the end of every script
# ------------------------------------------------------

function safeExit() {
  # Delete temp files, if any
  debug "Checking ${tmpDir} before deleting..."
  if is_dir "${tmpDir}"; then
    debug "Removing temporary directory"
    rm -r "${tmpDir}"
    if is_exists "${tmpDir}"; then
      warning "Could not remove $tmpDir"
    fi
  else
    warning "${tmpDir} is not a directory or doesn't exist"
  fi
  trap - INT TERM EXIT
  exit
}


# ------------------------------------------------------
# File Checks - A series of functions which make checks 
# against the filesystem. For use in if/then statements.
#
# Usage:
#    if is_file "file"; then
#       ...
#    fi
# ------------------------------------------------------

function is_exists() {
  if [[ -e "$1" ]]; then
    return 0
  fi
  return 1
}

function is_not_exists() {
  if [[ ! -e "$1" ]]; then
    return 0
  fi
  return 1
}

function is_file() {
  if [[ -f "$1" ]]; then
    return 0
  fi
  return 1
}

function is_not_file() {
  if [[ ! -f "$1" ]]; then
    return 0
  fi
  return 1
}

function is_dir() {
  if [[ -d "$1" ]]; then
    return 0
  fi
  return 1
}

function is_not_dir() {
  if [[ ! -d "$1" ]]; then
    return 0
  fi
  return 1
}

function is_symlink() {
  if [[ -L "$1" ]]; then
    return 0
  fi
  return 1
}

function is_not_symlink() {
  if [[ ! -L "$1" ]]; then
    return 0
  fi
  return 1
}

function is_empty() {
  if [[ -z "$1" ]]; then
    return 0
  fi
  return 1
}

function is_not_empty() {
  if [[ -n "$1" ]]; then
    return 0
  fi
  return 1
}

# ------------------------------------------------------
# Alert functions
# ------------------------------------------------------

function _alert() {
  set +x

  if [ "${1}" = "emergency" ]; then local color="${bold}${red}"; fi
  if [ "${1}" = "error" ]; then local color="${bold}${red}"; fi
  if [ "${1}" = "warning" ]; then local color="${yellow}"; fi
  if [ "${1}" = "info" ] || [ "${1}" = "notice" ]; then local color="${bold}"; fi
  if [ "${1}" = "debug" ]; then local color="${purple}"; fi
  if [ "${1}" = "success" ]; then local color="${green}"; fi
  if [ "${1}" = "input" ]; then local color="${bold}"; printLog="false"; fi
  if [ "${1}" = "header" ]; then local color="${bold}""${yellow}"; fi
  # Don't use colors on pipes or non-recognized terminals
  if [[ "${TERM}" != "xterm"* ]] || [ -t 1 ]; then color=""; reset=""; fi
  # Print to $logFile
  if [[ ${printLog} = "true" ]] || [ "${printLog}" == "1" ]; then
    echo -e "$(date +"%Y-%m-%d %H:%M:%S.%3N") $(printf "[%9s]" "${1}") ${_message}" >> "${logFile}";
  fi
  # Print to console when script is not 'quiet'
  if [[ "${quiet}" = "true" ]] || [ "${quiet}" == "1" ]; then
   return
  else
   echo -e "$(date +"%Y-%m-%d %H:%M:%S.%3N") ${color}$(printf "[%9s]" "${1}") ${_message}${reset}";
  fi

  if [ "${debug}" == "1" ]; then
    set -x; # Print commands and their arguments as they are executed
  fi

}

function die ()       { local _message="${*} Exiting."; echo "$(_alert emergency)"; safeExit; }
function error ()     { local _message="${*}"         ; echo "$(_alert error)"; }
function warning ()   { local _message="${*}"         ; echo "$(_alert warning)"; }
function info ()      { local _message="${*}"         ; echo "$(_alert info)"; }
function notice ()    { local _message="${*}"         ; echo "$(_alert notice)"; }
function debug ()     { local _message="${*}"         ; echo "$(_alert debug)"; }
function success ()   { local _message="${*}"         ; echo "$(_alert success)"; }
function input()      { local _message="${*}"         ; echo "$(_alert input)"; }
function header()     { local _message="========== ${*} ==========  "; echo "$(_alert header)"; }

function trapCleanup() {
  if is_dir "${tmpDir}"; then
    rm -r "${tmpDir}"
  fi
  die "Exit trapped."
}

# ##################################################
# SETUP...
# 
# -----------------------------------
# Flags which can be overridden by user input.
# Default values are below
# -----------------------------------
quiet=0
printLog=0
verbose=0
force=0
debug=0
args=()

# Setting script and path variables
#scriptPath="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
scriptName=$(basename "$0")
scriptBasename="$(basename ${scriptName} .sh)" # Strips '.sh' from scriptName

# -----------------------------------
# Log is only used when the '-l' flag is set.
# -----------------------------------
logFile="$HOME/${scriptBasename}.log"

# -----------------------------------
# Create temp directory with three random numbers and the process ID
# in the name.  This directory is removed automatically at exit.
# -----------------------------------
tmpDir="/tmp/${scriptName}.$RANDOM.$RANDOM.$RANDOM.$$"

debug "Creating temporary directory at ${tmpDir}"
(umask 077 && mkdir "${tmpDir}") || {
  die "Could not create $tmpDir"
}

# ##################################################
# ##################################################
# ##################################################

function mainScript() {

####################################################
############## Begin Script Here ###################
####################################################
header "Starting mainScript of ${scriptName}"

if [ "${#args[@]}" = "0" ]; then
  usage >&2; safeExit
fi

#TODO HANDLE LOCAL WAR

#-----------------------------------
# Set mandatory vars
set +u
if [ -z "$remote" ]; then
  read -ep $'\nWhat is the remote host name where the new wars should go? ' remoteHost
  case $remoteHost in
    ? ) break;;
    "" ) die "Empty remote host name." ;;
  esac
else
  remoteHost=$remote
fi

if [ -z "$username" ]; then
  read -ep $'\nWhat is the username on remote host? ' user
  case $user in
    ? ) break;;
    "" ) die "Empty username." ;;
  esac
else
  user=$username
fi

if [ -z "$password" ]; then
  read -sep $'\nWhat is the password for user on remote host? ' passwd
else
  passwd=$password
fi
set -u

#TODO pass the webapps location
tomcatHomeDir="/home/${user}/${user}/client/apache-tomcat"
webappsDir="${tomcatHomeDir}/webapps"
workScript="new_war.sh"

#-----------------------------------

if is_not_file "./delete_folders_on_remote.sh"; then
  die "Missing file: ./delete_folders_on_remote.sh"
fi

if is_not_file "./put_files_on_remote.sh"; then
  die "Missing file: ./put_files_on_remote.sh"
fi

if is_not_file "./${workScript}"; then
  die "Missing file: ./${workScript}"
fi

while true; do
    read -ep $'\n\nAre you ready to stop the tomcat server on remote host? ' yn
    case $yn in
        [Yy]* ) runForReal="true"; break;;
        [Nn]* ) die "User answered no. Not ready to install new wars.";;
        * ) echo "Please answer yes or no.";;
    esac
done

if [ ${runForReal} = "true" ]; then
  set +x
  info "Stopping ${user}_tomcat server ..."
  expect<<eod_StopServer
    set timeout 9
    spawn ssh ${user}@${remoteHost}
    expect "${user}@${remoteHost}'s password: "
    send "$passwd\r"
    expect "*$ "
    sleep 1

    send "sudo service ${user}_tomcat stop\r"
    expect "*?password for ${user}: "
    send "$passwd\r"
    expect "*$ "
    sleep 1
    
    send "exit\r"
    send_user "\n"
eod_StopServer
  if [ "${debug}" == "1" ]; then
    set -x; # Print commands and their arguments as they are executed
  fi
fi


info "Putting ${workScript} and war files on $remoteHost ..."
./put_files_on_remote.sh $user $passwd $remoteHost $workScript ${args[@]}
echo -e "\n"


set +x
info "Running ${workScript} on $remoteHost ..."
expect<<eod_RunScript
  set timeout 9
  spawn ssh ${user}@${remoteHost}
  expect "${user}@${remoteHost}'s password: "
  send "$passwd\r"
  expect "Last login:"
  expect " *?$ "
  send "./${workScript} -u ${user} --remote ${remoteHost} ${args[@]}\r"
  expect " *?$ "
  sleep 10

  send "rm ${workScript}\r"
  expect "*?${user}@${remoteHost} *?"
  sleep 1

  send "exit\r"
  send_user "\n"
eod_RunScript
if [ "${debug}" == "1" ]; then
  set -x; # Print commands and their arguments as they are executed
fi


if [ ${runForReal} = "true" ]; then
  info "Deleting contents of work folder ..."
  ./delete_folders_on_remote.sh $user $passwd $remoteHost $tomcatHomeDir/work
  echo -e "\n"


  info "Deleting contents of war folders ..."
  ./delete_folders_on_remote.sh $user $passwd $remoteHost $webappsDir/${args[@]%.war}
  echo -e "\n"


  set +x
  info "Restarting ${user}_tomcat server ..."
  expect<<eod_StartServer
    set timeout 9
    spawn ssh ${user}@${remoteHost}
    expect "${user}@${remoteHost}'s password: "
    send "$passwd\r"
    expect "*$ "
    sleep 1

    send "sudo service ${user}_tomcat start\r"
    expect "*?password for ${user}: "
    send "$passwd\r"
    expect "*$ "
    sleep 1
    
    send "exit\r"
    send_user "\n"
eod_StartServer
  if [ "${debug}" == "1" ]; then
    set -x; # Print commands and their arguments as they are executed
  fi
fi


set +x
info "Getting the tar file backup from ${remoteHost} ..."
expect<<eod_GetTarFile
  set timeout "[expr 15*60]"
  spawn sftp ${user}@${remoteHost}
  expect "*assword: "
  send "$passwd\r"
  expect "sftp> "
  sleep 1

  send "get backup_wars_${remoteHost}_*hrs.tar\r"
  expect "sftp> "
  sleep 1

  send "rm backup_wars_${remoteHost}_*hrs.tar\r"
  expect "sftp> "
  sleep 1

  send "exit\r"
  send_user "\n"
eod_GetTarFile
if [ "${debug}" == "1" ]; then
  set -x; # Print commands and their arguments as they are executed
fi



####################################################
############### End Script Here ####################
####################################################
}
# ##################################################
# ##################################################
# Print usage
usage() {
  echo -n "${scriptName} [OPTIONS]... FILE LIST...

 Options:
  -u, --username    Username for remote host
  -p, --password    User password for remote host
  --host            remote host
  --force           Skip all user interaction.  Implied 'Yes' to all actions.
  -q, --quiet       Quiet (no output)
  -l, --log         Print log to file
  -v, --verbose     Output more information. (Items echoed to 'verbose')
  -d, --debug       Runs script in BASH debug mode (set -x)
  -h, --help        Display this help and exit
      --version     Output version information and exit
"
}
# ##################################################

# Iterate over options breaking -ab into -a -b when needed and --foo=bar into
# --foo bar
optstring=h
unset options

[ $# -gt 0  ] || {
die "No args provided."
}

while (($#)); do
  case $1 in
    # If option is of type -ab
    -[!-]?*)
      # Loop over each character starting with the second
      for ((i=1; i < ${#1}; i++)); do
        c=${1:i:1}
        debug "c = ${c}"

        # Add current char to options
        options+=("-$c")

        # If option takes a required argument, and it's not the last char make
        # the rest of the string its argument
        if [[ $optstring = *"$c:"* && ${1:i+1} ]]; then
          options+=("${1:i+1}")
          break
        fi
      done
      ;;

    # If option is of type --foo=bar
    --?*=*)
      options+=("${1%%=*}" "${1#*=}") ;;
    # add --endopts for --
    --)
      options+=(--endopts) ;;
    # Otherwise, nothing special
    *) 
      arguments+=("$1")
      options+=("$1") 
      ;;
  esac
  shift
done

set -- "${options[@]}"
unset options

#-----------------------------------
#Check for mandatory vars
#echo "$@"
#if [ ($@) == "" ]; then
  #usage >&2; safeExit
#fi
#-----------------------------------
# Read the options and set stuff
while [[ $1 = -?* ]]; do
  case $1 in
    -h|--help)
      usage >&2; safeExit ;;
    --version)
      echo "$(basename $0) ${version}"; safeExit ;;
    -u|--username)
      shift; username=${1} ;;
    -p|--password)
      shift; password=${1} ;;
      #shift; echo "Enter Pass: "; stty -echo; read PASS; stty echo;
      #echo ;;
    --remote)
      shift; remote=${1} ;;
    -v|--verbose)
      verbose=1 ;;
    -l|--log)
      printLog=1 ;;
    -q|--quiet)
      quiet=1 ;;
    -d|--debug)
      debug=1;;
    --force)
      force=1 ;;
    --endopts)
      shift; break ;;
    *)
      die "invalid option: '$1'." ;;
  esac
  shift
done

if [ "${debug}" == "1" ]; then
  set -x; # Print commands and their arguments as they are executed
fi

# Store the remaining part as arguments.
args+=("$@")

# ##################################################
# ##################################################

trap trapCleanup EXIT INT TERM # Trap bad exits with your cleanup function

mainScript # Run your script

safeExit # Exit cleanly
# ##################################################
# ##################################################
