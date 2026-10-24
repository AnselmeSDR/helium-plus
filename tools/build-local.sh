#!/bin/zsh
# Local build of Helium+ with live progress, a log file and a macOS notification at the end.
# Usage: tools/build-local.sh [slow|full]
#   slow (default): 6 parallel jobs, low priority, the Mac stays usable
#   full: all cores
root=${0:A:h:h}
mode=${1:-slow}
logFile="$root/build/build-$(date +%Y%m%d-%H%M).log"
export PATH="$(brew --prefix python@3.13)/libexec/bin:$PATH"

buildArgs=""
priority=0
if [[ $mode == slow ]]; then
  buildArgs="-j 6"
  priority=10
fi

# siso shows no remaining time: put percentage and ETA in the window title and Ghostty's progress bar
showProgress() {
  local samples=() line doneSteps totalSteps now first rate percent
  local -i eta
  while sleep 30; do
    line=$(tail -c 4000 "$logFile" 2>/dev/null | tr '\r' '\n' | grep -oE '\[[0-9]+/[0-9]+\]' | tail -1)
    [[ -z $line ]] && continue
    doneSteps=${${line#\[}%/*}
    totalSteps=${${line%\]}#*/}
    now=$(date +%s)
    # rate over the last 10 minutes
    samples+=("$now:$doneSteps")
    (( ${#samples} > 20 )) && samples=("${(@)samples[-20,-1]}")
    first=${samples[1]}
    percent=$(( doneSteps * 100 / totalSteps ))
    rate=$(( (doneSteps - ${first#*:}) * 1.0 / (now - ${first%%:*} + 1) ))
    if (( rate > 0 )); then
      eta=$(( (totalSteps - doneSteps) / rate / 60 ))
      printf '\e]0;Helium+ %d %% — reste ~%d h %02d\a' $percent $((eta / 60)) $((eta % 60)) > /dev/tty
    fi
    printf '\e]9;4;1;%d\a' $percent > /dev/tty
  done
}

echo "Helium+ : compilation $mode, journal : $logFile"
start=$(date +%s)
showProgress &
progressPid=$!
# script keeps a real terminal so the live progress line stays visible, and records it to the log
script -q "$logFile" nice -n $priority zsh -c "cd '$root' && source ./dev.sh && helium_build $buildArgs"
buildStatus=$?
kill $progressPid 2>/dev/null
printf '\e]9;4;0\a\e]0;Helium+ build terminé\a' > /dev/tty
elapsed=$(( ($(date +%s) - start) / 60 ))

if [[ $buildStatus -eq 0 ]]; then
  message="Compilation réussie en $((elapsed / 60)) h $((elapsed % 60)) min"
else
  message="Compilation en échec après $((elapsed / 60)) h $((elapsed % 60)) min (voir le journal)"
fi
echo "\n$message"
osascript -e "display notification \"$message\" with title \"Helium+\" sound name \"Glass\""
exit $buildStatus
