#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
TARGET_FILE="${REPO_ROOT}/.env.local"

prompt_value() {
  local var_name="$1"
  local prompt_text="$2"
  local default_value="${3:-}"
  local secret="${4:-false}"
  local value=""

  while [[ -z "${value}" ]]; do
    if [[ "${secret}" == "true" ]]; then
      if [[ -n "${default_value}" ]]; then
        read -r -s -p "${prompt_text} [hidden, default kept if empty]: " value
        echo
        if [[ -z "${value}" ]]; then
          value="${default_value}"
        fi
      else
        read -r -s -p "${prompt_text}: " value
        echo
      fi
    else
      if [[ -n "${default_value}" ]]; then
        read -r -p "${prompt_text} [${default_value}]: " value
        value="${value:-${default_value}}"
      else
        read -r -p "${prompt_text}: " value
      fi
    fi

    if [[ -z "${value}" ]]; then
      echo "${var_name} is required."
    fi
  done

  printf '%s' "${value}"
}

if [[ -f "${TARGET_FILE}" && "${1:-}" != "--force" ]]; then
  echo ".env.local already exists at ${TARGET_FILE}"
  echo "Run scripts/setup-local-env.sh --force if you want to overwrite it."
  exit 1
fi

echo "Creating ${TARGET_FILE}"
echo "Press Enter to accept defaults where shown."
echo

arm_subscription_id="$(prompt_value "ARM_SUBSCRIPTION_ID" "Azure subscription ID" "00000000-0000-0000-0000-000000000000")"
arm_tenant_id="$(prompt_value "ARM_TENANT_ID" "Azure tenant ID" "11111111-1111-1111-1111-111111111111")"

cat > "${TARGET_FILE}" <<EOF
export ARM_SUBSCRIPTION_ID=$(printf '%q' "${arm_subscription_id}")
export ARM_TENANT_ID=$(printf '%q' "${arm_tenant_id}")
EOF

chmod 600 "${TARGET_FILE}"

echo
echo "Created ${TARGET_FILE}"
echo "Next step:"
echo "  az login"
echo "  az account set --subscription ${arm_subscription_id}"
echo "  source .env.local"
echo
echo "Then you can run:"
echo "  terraform init"
