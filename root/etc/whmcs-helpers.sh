# WHMCS init helpers. Sourced (not executed) by /etc/cont-init.d/* scripts via `source`.
# No shebang; file is read by bash's source builtin from a bash environment.
# Mode 0644 is intentional -- sourced files don't need the executable bit.

seed_default() {
  local defaults_path="${1:?defaults_path required}"
  local config_path="${2:?config_path required}"

  if [ ! -f "${defaults_path}" ]; then
    echo "**** ERROR: default file missing: ${defaults_path} ****" >&2
    return 1
  fi

  mkdir -p "$(dirname "${config_path}")"

  if [ ! -f "${config_path}" ]; then
    cp -vf "${defaults_path}" "${config_path}"
    return 0
  fi

  if ! cmp -s "${defaults_path}" "${config_path}"; then
    cp -vf "${defaults_path}" "${config_path}.new"
    echo "**** WARNING: ${config_path} differs from the image default; wrote ${config_path}.new ****" >&2
  fi
}

_whmcs_sha256() {
  sha256sum "${1:?path required}" | awk '{print $1}'
}

seed_rendered() {
  local rendered_temp_path="${1:?rendered_temp_path required}"
  local config_path="${2:?config_path required}"
  local sum_dir="/config/.seed-tracking"
  local rel_path="${config_path#/config/}"
  local sum_name
  local sum_path
  local rendered_sum
  local prior_sum=""
  local current_sum

  if [ ! -f "${rendered_temp_path}" ]; then
    echo "**** ERROR: rendered file missing: ${rendered_temp_path} ****" >&2
    return 1
  fi

  sum_name=$(printf '%s' "${rel_path}" | tr / _)
  sum_path="${sum_dir}/${sum_name}.sha256"

  mkdir -p "${sum_dir}" "$(dirname "${config_path}")"
  rendered_sum=$(_whmcs_sha256 "${rendered_temp_path}")

  if [ ! -f "${config_path}" ]; then
    cp -vf "${rendered_temp_path}" "${config_path}"
    printf '%s\n' "${rendered_sum}" > "${sum_path}"
    return 0
  fi

  if [ -f "${sum_path}" ]; then
    prior_sum=$(tr -d '[:space:]' < "${sum_path}")
  fi
  current_sum=$(_whmcs_sha256 "${config_path}")

  if [ "${current_sum}" = "${prior_sum}" ]; then
    if [ "${current_sum}" != "${rendered_sum}" ]; then
      cp -vf "${rendered_temp_path}" "${config_path}"
      printf '%s\n' "${rendered_sum}" > "${sum_path}"
    fi
  else
    if [ "${current_sum}" != "${rendered_sum}" ]; then
      cp -vf "${rendered_temp_path}" "${config_path}.new"
      echo "**** WARNING: ${config_path} has local changes; wrote rendered update to ${config_path}.new ****" >&2
    fi
  fi
}
