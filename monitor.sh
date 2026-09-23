#!/bin/bash

set -euo pipefail

: <<EOF
NOTE: RUN WITH SUDO!
    & make sure TERM_PROGRAM is set to a command which opens your terminal.

Description: wrapper for airmon-ng & airodump-ng for my setup w/ two NICs.

Dev notes:
    possible bug - on saved .cap files - not sure if killing processes writes a corrupt cap files
    instead of just using airmon-ng stop command?
EOF


function usage() {
    cat <<EOF
Usage: ./monitor.sh -0 '-c 6' -1 '-c 11'

    -0 <str> : Appends <str> to airodump-ng wlan0 command.
    -1 <str> : Appends <str> to airodump-ng wlan1 command.
    -h       : Shows this info.

Example shows specifying channels to each NIC monitoring (wlan0=ch-6 & wlan1=ch-11).
Hint: Channels 1, 6, 11 are most common.
EOF
}


TERM_PROGRAM='kitty' # change me -> your terminal command
ARG0=''              # forward wrapper args to the actual program
ARG1=''

# colors
R='\033[0;31m' # red
G='\033[0;32m' # green
U='\033[0m'    # reset

# fancy output
ERR="${R}- [ ERR ] ${U}"
OK="${G}- [ OK ] ${U}"

# restore network settings on <CTRL+C>
trap 'unset_monitor_mode ; cleanup ; echo -e "$OK Script finished."' SIGINT


function set_monitor_mode() {
    local err="$ERR Failed to start monitor mode for"
    local ok="$OK Started monitor mode for"

    echo -e "$OK Setting monitor mode."

    # kills processes holding the nic
    airmon-ng check kill

    # monitor mode on
    airmon-ng start wlan0 1>/dev/null &&
        echo -e "$ok wlan0" ||
        echo -e "$err wlan0"

    airmon-ng start wlan1 1>/dev/null &&
        echo -e "$ok wlan1" ||
        echo -e "$err wlan1"
}


function sniff() {
    local err="$ERR Failed to start monitor mode for"
    local ok="$OK Started capturing on"

    echo -e "$OK Starting packet capture."

    sleep 1

    # cur terminal for waln1mon
    (eval "airodump-ng wlan0mon -w wlan0mon $ARG0") & # using eval for appening your optargs

    # new terminal for wlan0mon
    ("$TERM_PROGRAM" bash -c "airodump-ng wlan1mon -w wlan1mon $ARG1") &
}


function unset_monitor_mode() {
    local err="$ERR Failed to kill PID"
    local ok="$OK Killed PID "

    clear

    echo -e "$OK Quitting."
    echo -e "$OK Unsetting monitor mode."

    # nic monitor mode off
    airmon-ng stop wlan0mon &>/dev/null ||
        echo -e "$err Couldn't stop wlan0mon."

    airmon-ng stop wlan1mon &>/dev/null ||
        echo -e "$err Couldn't stop wlan1mon."

    systemctl restart NetworkManager ||
        echo -e "$err Coudn't restart NetworkManager service."

    echo -e "$OK Network restored."
}


function cleanup() {
    # organize -> .cap files remain, rest moves to dump_data
    mkdir -p other_data

    mv wlan* other_data || echo "$ERR failed to organize output files"
    mv other_data/*.cap . || echo "$ERR failed to organize output files"

    echo -e "$OK Files organized."
}


function parse_args() {
    while getopts ":0:1:h" opt; do
        case "${opt}" in
        0) ARG0="${OPTARG}" && echo -e "$OK Added arg for wlan0 = ${OPTARG}" ;;
        1) ARG1="${OPTARG}" && echo -e "$OK Added arg for wlan1 = ${OPTARG}" ;;
        h)
            echo -e "$OK Showing usage." && usage
            exit 0
            ;;
        \?)
            echo -e "$ERR wrong args." && usage
            exit 1
            ;;
        esac
    done
}


function main() {
    parse_args "$@"
    set_monitor_mode
    sniff
    wait # -> unset_monitor_mode on <Ctrl+C>
}

main "$@"
