#!/usr/bin/env bash

VERSION=3.0.3
BOOTSTRAP_BRANCH=${BRANCH:-master}
BOOTSTRAP_DIR=/srv/aviatx/bootstrap
BOOTSTRAP_REPO=https://github.com/andrewromm/aviatx_setup.git
SSH_DIR=/srv/aviatx/ssh
SSH_FILE=aviatx_rsa
KICKSTART_CMD="sudo -E bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/andrewromm/aviatx_setup/${BOOTSTRAP_BRANCH}/setup.sh)\""
BINALIAS=/usr/local/bin/aviatx
FACT_CONF=/etc/ansible/facts.d/config.fact
INSTALL_LOG=$(mktemp /tmp/aviatx-setup.XXXXXXXX)
CUSTOM_TASKS_FILE=tasks/custom.yml

# state vars
INSTALLED=""
EMAIL=""
DOMAIN=""
# DEF_HOSTALIAS="aviatx"
HOSTALIAS=""
PG_USER=""
PG_PASSWORD=""
SSL_TEST="false"
BACKEND_DEBUG=0

ROLES_UPDATED=0

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
## System deps
################################################################################

update_bootstrap() {
  set -e
  if [[ -d "$BOOTSTRAP_DIR" ]]; then
    print_status "Updating repo $BOOTSTRAP_REPO"
    cd $BOOTSTRAP_DIR
    git fetch --all && git reset --hard "origin/$BOOTSTRAP_BRANCH" && print_ok
    # git checkout $BOOTSTRAP_BRANCH && git pull --rebase
  else
    print_status "Cloning repo $BOOTSTRAP_REPO"
    mkdir -p $BOOTSTRAP_DIR
    cd $BOOTSTRAP_DIR
    echo $(pwd)
    git clone $BOOTSTRAP_REPO . && git checkout $BOOTSTRAP_BRANCH && print_ok
  fi
}

setup_langvars() {
  set -e
  print_status "Exporting locale vars"
  export LANG=en_US.UTF-8
  export LC_ALL=en_US.UTF-8
  export LANGUAGE=en_US.UTF-8
  export LC_TYPE=en_US.UTF-8
  print_ok
}

setup_locale() {
  export DEBIAN_FRONTEND=noninteractive
  set -e
  print_status "Setting en_US.UTF-8 locale"
  # echo -e 'LANGUAGE=en_US.UTF-8\nLANG=en_US.UTF-8\nLC_ALL=en_US.UTF-8\nLC_TYPE=en_US.UTF-8' > /etc/default/locale
  echo -e '# Generated by AviaTX setup script\nLANGUAGE=en_US.UTF-8\nLANG=en_US.UTF-8\nLC_ALL=en_US.UTF-8\nLC_TYPE=en_US.UTF-8' | tee /etc/default/locale
  locale-gen en_US.UTF-8 > $INSTALL_LOG
  dpkg-reconfigure locales > $INSTALL_LOG
  setup_langvars
  print_ok
}

update_apt_repo(){
  export DEBIAN_FRONTEND=noninteractive
  print_status "Updating packages registry"
  apt-get -yqq update \
    && print_ok
}

setup_system_packages() {
  export DEBIAN_FRONTEND=noninteractive
  print_status "Installing requirements"
  apt-get -yqq install apt-utils > $INSTALL_LOG \
    && apt-get -yqq install dialog whiptail nano \
      curl git locales \
      python3 python3-dev python3-pip python3-netaddr python3-setuptools python3-requests \
      build-essential libffi-dev ca-certificates zlib1g-dev libssl-dev openssl > $INSTALL_LOG \
    && print_ok
}

setup_python_packages() {
  print_status "Update pip and install required python packages"
  python3 -m pip install --upgrade pip \
    && pip3 -q install wheel \
    && pip3 -q install -r $BOOTSTRAP_DIR/requirements.txt -U \
    && print_ok
}

setup_runner() {
  print_status "Installing/Updating AviaTX shortcut"
  rm -f $BINALIAS \
    && echo -e "#!/bin/bash\n${KICKSTART_CMD}\n" > $BINALIAS \
    && chmod +x $BINALIAS \
    && print_ok
}

setup_playbook() {
  if [ $ROLES_UPDATED -eq 1 ]; then return 0; fi
  print_status "Updating ansible roles" \
  && cd $BOOTSTRAP_DIR \
  && ansible-galaxy install -r install_roles.yml --force > $INSTALL_LOG \
  && touch $CUSTOM_TASKS_FILE \
  && print_ok \
  && ROLES_UPDATED=1
}

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
                enc=$(echo -n ${value})  #$(echo "md5`echo -n ${value}${PG_USER} | md5sum | awk '{print $1}'`") $(openssl passwd -1 ${value})
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
  whiptailInput "DOMAIN" "Domain" "Please enter domain for your system." 8 78
}

request_hostalias(){
  whiptailInput "HOSTALIAS" "Short hostname" "Short server hostname that you can see at command line prompt." 8 78
}

request_email(){
  whiptailInput "EMAIL" "Email" "Email required for issuing letsencrypt SSL." 8 78
}

request_pg_user(){
  whiptailInput "PG_USER" "Postgres user" "Define postgreSQL user" 8 78
}

request_pg_password(){
  whiptailInput "PG_PASSWORD" "Postgres password" "Define postgreSQL password" 8 78
}

request_ssl_test(){
  whiptailInput "SSL_TEST" "If SSL test mode" "Select if receive test Letsencrypt SSL certificate." 8 78
}

request_backend_debug(){
  whiptailInput "BACKEND_DEBUG" "Backend debug mode" "Set backend debug mode (0 or 1)." 8 78
}

update_reboot_dialog(){
  show_dialog "System upgrade" "After upgrade complete server will be rebooted and you need to connect agant to continue."
}

greate_success_dialog(){
  show_dialog "Execution completed" "Greate success!"
}

run_full_setup_to_apply_dialog(){
  show_dialog "Applying changes" "Run full install/upgrade to apply changes"
}

################################################################################
## Actions
################################################################################

ANS_PY="-e ansible_python_interpreter=/usr/bin/python3"
ANS_BRANCH="-e branch=${BOOTSTRAP_BRANCH}"

run_postgresql_setup() { # (tags, custom)
  print_status "Starting PostgreSQL setup"
  cmd="postgresql.yml --connection=local $ANS_PY"
  echo "executing ansible-playbook ${cmd}"
  ansible-playbook $cmd
  if [ $? -eq 0 ]; then print_status "Done"; else print_error "FAILED"; exit 1; fi
  greate_success_dialog
}

run_platform_playbook() { # (tags, custom)
  print_status "Starting ansible"
  cmd="platform.yml --connection=local --tags=${1} $ANS_PY $ANS_BRANCH ${2}"
  echo "executing ansible-playbook ${cmd}"
  ansible-playbook $cmd
  if [ $? -eq 0 ]; then print_status "Done"; else print_error "FAILED"; exit 1; fi
  greate_success_dialog
}

run_upgrade_playbook() {
  print_status "Starting ansible"
  ansible-playbook os_upgrade.yml --connection=local $ANS_PY && exit 0
  if [ $? -eq 0 ]; then print_status "Done"; else print_error "FAILED"; exit 1; fi
  # server shold be go to reboot
}

################################################################################
## Configs
################################################################################

load_config(){
  if [ -a "$FACT_CONF" ]; then
    INSTALLED=$(awk -F "=" '/installed/ {print $2}' $FACT_CONF)
    DOMAIN=$(awk -F "=" '/domain/ {print $2}' $FACT_CONF)
    HOSTALIAS=$(awk -F "=" '/hostalias/ {print $2}' $FACT_CONF)
    EMAIL=$(awk -F "=" '/email/ {print $2}' $FACT_CONF)
    PG_USER=$(awk -F "=" '/pg_user/ {print $2}' $FACT_CONF)
    PG_PASSWORD=$(awk -F "=" '/pg_password/ {print $2}' $FACT_CONF)
    SSL_TEST=$(awk -F "=" '/ssl_test/ {print $2}' $FACT_CONF)
    BACKEND_DEBUG=$(awk -F "=" '/backend_debug/ {print $2}' $FACT_CONF)
    # if [[ -z "$HOSTALIAS" ]]; then HOSTALIAS=$DEF_HOSTALIAS; fi
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
email=${EMAIL}
domain=${DOMAIN}
hostalias=${HOSTALIAS}
pg_user=${PG_USER}
pg_password=${PG_PASSWORD}
ssl_test=${SSL_TEST}
backend_debug=${BACKEND_DEBUG}
installed=${INSTALLED}""" > $FACT_CONF
}

################################################################################
## Executing
################################################################################

setup_platform(){
  setup_langvars
  update_apt_repo
  setup_system_packages
  setup_locale
  update_bootstrap
  setup_python_packages
  setup_runner
  setup_playbook
  INSTALLED=$VERSION
  save_config
}

update_platform(){
  update_bootstrap
  setup_runner
}

delete_ssh_file(){
  if [ -f "$SSH_DIR/$SSH_FILE" ]; then
    rm "$SSH_DIR/$SSH_FILE"
    echo "SSH key file deleted: $SSH_DIR/$SSH_FILE"
  else
    echo "SSH key file does not exist: $SSH_DIR/$SSH_FILE"
  fi
}

initialize(){
  # check if ssh_key exists if not create
  print_status "Checking SSH key"
  if [ ! -d "$SSH_DIR" ]; then
    mkdir -p "$SSH_DIR"
  fi
  if [ ! -f "$SSH_DIR/$SSH_FILE" ]; then
      nano "$SSH_DIR/$SSH_FILE"
      if [ -f "$SSH_DIR/$SSH_FILE" ]; then
          chmod 0600 "$SSH_DIR/$SSH_FILE"
          echo "SSH key file created at $SSH_DIR/$SSH_FILE"
      else
          echo "Failed to create SSH key file"
          exit 1
      fi
  else
      echo "SSH key file already exists at $SSH_DIR/$SSH_FILE"
  fi

  #########################
  while [ -z "${EMAIL// }" ]; do request_email
  done
  while [ -z "${DOMAIN// }" ]; do request_domain
  done
  while [ -z "${PG_USER// }" ]; do request_pg_user
  done
  while [ -z "${PG_PASSWORD// }" ]; do request_pg_password
  done
  while [ -z "${HOSTALIAS// }" ]; do request_hostalias
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
  "02" "    Install PostgreSQL" \
  "03" "    Full Install" \
  "04" "    Upgrade Frontend" \
  "05" "    Upgrade Backend" \
  "12" "    Change domain '${DOMAIN}'" \
  "13" "    Change host alias '${HOSTALIAS}'" \
  "14" "    Change Email '${EMAIL}'" \
  "15" "    Change SSL Letsencrypt test mode '${SSL_TEST}'" \
  "16" "    Change Backend DEBUG mode '${BACKEND_DEBUG}'" \
  "17" "    Delete SSH key file" \
  "00" "    Exit"  3>&1 1>&2 2>&3)
  EXITCODE=$?
  [[ "$EXITCODE" = 1 ]] && break;
  [[ "$EXITCODE" = 255 ]] && break;
  # echo "exitcode: $EXITCODE"

  case "$OPTION" in
    "01") update_reboot_dialog; run_upgrade_playbook ;;
    "02") run_postgresql_setup ;;
    "03") run_platform_playbook full ;;
    "04") run_platform_playbook upgradefrontend ;;
    "05") run_platform_playbook upgradebackend ;;
    "12") request_domain ;;
    "13") request_hostalias ;;
    "14") request_email ;;
    "15") request_ssl_test ;;
    "16") request_backend_debug ;;
    "17") delete_ssh_file ;;
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