#!/usr/bin/env bash

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


whiptailInput "HOSTALIAS" "Short hostname" "Short server hostname that you can see at command line prompt." 8 78