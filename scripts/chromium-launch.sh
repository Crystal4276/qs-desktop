#!/usr/bin/env bash
# Transmettre à Chromium déjà lancé ; sinon exécuter la commande d’origine.
# Usage : chromium-launch.sh <commande Chromium> [arguments…]
# Adapté de https://github.com/omacom/omarchy/pull/13530 (MIT).
# Copyright (c) David Heinemeier Hansson
#
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
# WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
set -o pipefail
handoff() {
    local config resolved arg file line word socket reply
    local -a words
    local LC_ALL=C bytes
    [[ $# -gt 0 ]] || return 1
    [[ -z ${XDG_ACTIVATION_TOKEN:-}${DESKTOP_STARTUP_ID:-} ]] || return 1
    config="${XDG_CONFIG_HOME:-$HOME/.config}"
    resolved=$(type -P -- "$1")
    [[ -n $resolved && $resolved -ef /usr/bin/chromium ]] || return 1
    shift
    [[ -z ${CHROME_USER_DATA_DIR:-}${CHROME_CONFIG_HOME:-} ]] || return 1
    for arg in "$@"; do [[ $arg == --user-data-dir* ]] && return 1; done
    for file in /etc/chromium-flags.conf "$config/chromium-flags.conf"; do
     [[ -e $file ]] || continue
     [[ -r $file ]] || return 1
     while IFS= read -r line || [[ -n $line ]]; do
      line=${line%%#*}; read -r -a words <<< "$line"
      for word in "${words[@]}"; do
       case $word in
        --ozone-platform=*|--ozone-platform-hint=*|--password-store=*|--enable-features=*|--load-extension=*|--no-default-browser-check) ;;
        *) return 1 ;;
       esac
      done
     done < "$file"
    done
    bytes=$((14 + ${#PWD}))
    for arg in "$@"; do bytes=$((bytes + 1 + ${#arg})); done
    (( bytes < 32000 )) || return 1
    socket="$config/chromium/SingletonSocket"
    [[ -S $socket && -O $socket ]] || return 1
    reply=$({ printf 'START\0%s\0browser' "$PWD"; if (( $# )); then printf '\0%s' "$@"; fi; } | socat -T2 -t2 - "UNIX-CONNECT:$socket" 2>/dev/null)
    [[ $reply == ACK ]]
}
if [[ ${BASH_SOURCE[0]} == "$0" ]]; then
    [[ $# -gt 0 ]] || exit 2
    handoff "$@" && exit 0
    exec "$@"
fi
