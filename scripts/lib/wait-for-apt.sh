# shellcheck shell=bash
# Wait until apt/dpkg locks are free (unattended-upgrades, parallel apt, etc.).
# Source from setup scripts:  # shellcheck source=wait-for-apt.sh
#   source "$(dirname ...)/lib/wait-for-apt.sh"
#   wait_for_apt

wait_for_apt() {
  local max_wait="${APT_WAIT_SECONDS:-600}"
  local waited=0
  local locks=(
    /var/lib/dpkg/lock-frontend
    /var/lib/dpkg/lock
    /var/lib/apt/lists/lock
    /var/cache/apt/archives/lock
  )

  while true; do
    local busy=0
    local holder=""
    for lock in "${locks[@]}"; do
      if [[ -e "${lock}" ]] && fuser "${lock}" >/dev/null 2>&1; then
        busy=1
        holder="${lock}"
        break
      fi
    done
    if [[ "${busy}" -eq 0 ]]; then
      if (( waited > 0 )); then
        echo "apt/dpkg lock released after ${waited}s"
      fi
      return 0
    fi
    if (( waited >= max_wait )); then
      echo "Timed out waiting for apt/dpkg locks after ${max_wait}s (held: ${holder})" >&2
      echo "Inspect: ps -fp \$(fuser ${holder} 2>/dev/null) 2>/dev/null; sudo lsof ${holder}" >&2
      echo "Do NOT delete lock files. Wait for the other apt process or reboot if stuck." >&2
      return 1
    fi
    if (( waited % 30 == 0 )); then
      echo "Waiting for apt/dpkg lock (${holder})... ${waited}s / ${max_wait}s"
    fi
    sleep 5
    waited=$((waited + 5))
  done
}
