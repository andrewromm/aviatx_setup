#!/usr/bin/env bash

VERSION=2.0.1
BOOTSTRAP_BRANCH=${BRANCH:-master}
INSTALL_LOG=$(mktemp /tmp/aviatx-setup.XXXXXXXX)

################################################################################
# Library
################################################################################

umask 022
export DEBIAN_FRONTEND=noninteractive

if test -t 1; then # if terminal
    ncolors=$(which tput > /dev/null && tput colors) # supports color
    if test -n "$ncolors" && test $ncolors -ge 8; then
        termcols=$(tput cols)
        bold="$(tput bold)"
        underline="$(tput smul)"
        standout="$(tput smso)"
        normal="$(tput sgr0)"
        black="$(tput setaf 0)"
        red="$(tput setaf 1)"
        green="$(tput setaf 2)"
        yellow="$(tput setaf 3)"
        blue="$(tput setaf 4)"
        magenta="$(tput setaf 5)"
        cyan="$(tput setaf 6)"
        white="$(tput setaf 7)"
    fi
fi

base_print() {
    echo -e "\n$1\n"
}

print_status() {
  base_print "${cyan}${bold}>> ${blue}${1}${normal}"
}

print_error() {
  base_print "${red}${bold}!> ${1}${normal}"
}

print_ok() {
  echo "${cyan}${bold}>> ${normal}Ok"
}

################################################################################
## Request root and banner
################################################################################

clear
base_print """
${cyan}${bold}##${normal}
${cyan}${bold}## AviaTX Bootstrap${normal}
${cyan}${bold}##${normal}
${cyan}${bold}## ${normal}version ${VERSION}
${cyan}${bold}## ${normal}branch ${BOOTSTRAP_BRANCH}
${cyan}${bold}## ${normal}logs output $INSTALL_LOG
${cyan}${bold}##${normal}"""

################################################################################
## Checks
################################################################################

# check credentials
if [ ! "$UID" -eq 0 ]; then print_error "Run as root or insert 'sudo -E' before 'bash'"; exit 1; fi
# check debian-like
if [[ ! -f /etc/debian_version ]]; then print_error "Target OS is Ubutu 20.04"; exit 1; fi

