#!/usr/bin/env bash

VERSION=2.0.1
BOOTSTRAP_BRANCH=${BRANCH:-master}
BOOTSTRAP_DIR=/srv/aviatx/bootstrap
FACT_CONF=/etc/ansible/facts.d/config.fact
INSTALL_LOG=$(mktemp /tmp/aviatx-setup.XXXXXXXX)

# state vars
DOMAIN=""
INSTALLED=""
DEF_HOSTALIAS="aviatx"
HOSTALIAS="$DEF_HOSTALIAS"

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

################################################################################
## Dialogs
################################################################################

show_dialog(){
  whiptail --title "$1" --msgbox "$2" 8 78
}

whiptailInput() {
    eval local init="\$$1"
    case "$1" in
        *PASSWORD*) local prompt='passwordbox'; showval="" ;;
        *) local prompt='inputbox'; showval=$init; ;;	
    esac
    local value=$(whiptail --title "$2" --${prompt} "$3" $4 $5 $showval 3>&1 1>&2 2>&3)
    local rc=$?
    if [ $rc = 0 ]; then
      if [ $prompt == 'passwordbox' ]; then
        local confirmation=$(whiptail --title "$2 / confirmation" --${prompt} "$3" $4 $5 $showval 3>&1 1>&2 2>&3)
        local rc=$?
        if [ $rc = 0 ]; then
          if [ "$value" != "$init" ]; then
            if [ $value == $confirmation ]; then
              if [[ -n ${value// } ]]; then
                enc=$(openssl passwd -apr1 ${value})
                eval $1="'$enc'"
                save_config
              fi
            fi
          fi
        fi
      else
        eval $1="'$value'"
        save_config
      fi
    fi
}

request_domain(){
  whiptailInput "DOMAIN" "Domain" "Please enter domain for your tracker." 8 78
}

request_hostalias(){
  whiptailInput "HOSTALIAS" "Short hostname" "Shot server hostname that you can see at command line prompt." 8 78
}

################################################################################
## Configs
################################################################################

load_config(){
  if [ -a "$FACT_CONF" ]; then
    INSTALLED=$(awk -F "=" '/installed/ {print $2}' $FACT_CONF)
    DOMAIN=$(awk -F "=" '/domain/ {print $2}' $FACT_CONF)
    HOSTALIAS=$(awk -F "=" '/hostalias/ {print $2}' $FACT_CONF)
    if [[ -z "$HOSTALIAS" ]]; then HOSTALIAS=$DEF_HOSTALIAS; fi
  fi
}

save_inventory(){
  cd "$BOOTSTRAP_DIR"
  echo """
[private]
${HOSTALIAS} ansible_host=${DOMAIN}

[aviatx]
${HOSTALIAS}
""" > inventory/private
}

save_config(){
  save_inventory \
  && mkdir -p $(dirname $FACT_CONF) \
  && echo """[general]
domain=${DOMAIN}
hostalias=${HOSTALIAS}
installed=${INSTALLED}""" > $FACT_CONF
}

################################################################################
## Executing
################################################################################

initialize(){
  while [ -z "${DOMAIN// }" ]; do request_domain
  done
  while [ -z ${HOSTALIAS// } ]; do request_hostalias
  done
}

if [[ -a "$FACT_CONF" ]]; then
  print_status "Reading local configuration"
  load_config
fi

print_status "Preparing system"
if [ "$INSTALLED" == "$VERSION" ]; then update_platform; fi
while [ "$INSTALLED" != "$VERSION" ]; do setup_platform
done

MENU_TEXT="\nChoose an option:\n"

menu() {
  # --menu <text> <height> <width> <listheight>
  OPTION=$(whiptail --title "AviaTX Shell Script Menu" --menu "${MENU_TEXT}" 30 60 18 \
  "01" "    Upgrade OS" \
  "03" "    Full Install/Upgrade" \
  "04" "    Platform Upgrade" \
  "12" "    Change domain '${DOMAIN}'" \
  "13" "    Change host alias '${HOSTALIAS}'" \
  "00"  "    Exit"  3>&1 1>&2 2>&3)
  EXITCODE=$?
  [[ "$EXITCODE" = 1 ]] && break;
  [[ "$EXITCODE" = 255 ]] && break;
  # echo "exitcode: $EXITCODE"

  case "$OPTION" in
    "01") update_reboot_dialog; run_upgrade_playbook ;;
    "03") run_platform_playbook full ;;
    "04") run_platform_playbook pservice,ppart ;;
    "12") request_domain ;;
    "13") request_hostalias ;;
    "00") exit 0 ;;
    *) echo "Unknown action '${OPTION}'" ;;	
  esac
  # sleep 0.5
}

# initial configuration
initialize
# start menu loop
while [ 1 ]; do
  menu
done