#!/bin/bash

function stripColors {
  echo "${1}" | sed 's/\x1b\[[0-9;]*m//g'
}

function hasPrefix {
  case ${2} in
    "${1}"*)
      true
      ;;
    *)
      false
      ;;
  esac
}

function parseInputs {
  # Required inputs
  if [ "${INPUT_TF_ACTIONS_VERSION}" != "" ]; then
    tfVersion=${INPUT_TF_ACTIONS_VERSION}
  else
    echo "Input terraform_version cannot be empty"
    exit 1
  fi

  if [ "${INPUT_TFENV_ACTIONS_VERSION}" != "" ]; then
    tfenvVersion=${INPUT_TFENV_ACTIONS_VERSION}
  else
    echo "Input tfenv_version cannot be empty"
    exit 1
  fi

  if [ "${INPUT_TG_ACTIONS_VERSION}" != "" ]; then
    tgVersion=${INPUT_TG_ACTIONS_VERSION}
  else
    echo "Input terragrunt_version cannot be empty"
    exit 1
  fi

  if [ "${INPUT_TF_ACTIONS_SUBCOMMAND}" != "" ]; then
    tfSubcommand=${INPUT_TF_ACTIONS_SUBCOMMAND}
  else
    echo "Input terraform_subcommand cannot be empty"
    exit 1
  fi

  # Optional inputs
  tfWorkingDir="."
  if [[ -n "${INPUT_TF_ACTIONS_WORKING_DIR}" ]]; then
    tfWorkingDir=${INPUT_TF_ACTIONS_WORKING_DIR}
  fi

  tfBinary="terragrunt"
  if [[ -n "${INPUT_TF_ACTIONS_BINARY}" ]]; then
    tfBinary=${INPUT_TF_ACTIONS_BINARY}
  fi

  tfComment=0
  if [ "${INPUT_TF_ACTIONS_COMMENT}" == "1" ] || [ "${INPUT_TF_ACTIONS_COMMENT}" == "true" ]; then
    tfComment=1
  fi

  tfCLICredentialsHostname=""
  if [ "${INPUT_TF_ACTIONS_CLI_CREDENTIALS_HOSTNAME}" != "" ]; then
    tfCLICredentialsHostname=${INPUT_TF_ACTIONS_CLI_CREDENTIALS_HOSTNAME}
  fi

  tfCLICredentialsToken=""
  if [ "${INPUT_TF_ACTIONS_CLI_CREDENTIALS_TOKEN}" != "" ]; then
    tfCLICredentialsToken=${INPUT_TF_ACTIONS_CLI_CREDENTIALS_TOKEN}
  fi

  tfFmtWrite=0
  if [ "${INPUT_TF_ACTIONS_FMT_WRITE}" == "1" ] || [ "${INPUT_TF_ACTIONS_FMT_WRITE}" == "true" ]; then
    tfFmtWrite=1
  fi

  tfWorkspace="default"
  if [ -n "${TF_WORKSPACE}" ]; then
    tfWorkspace="${TF_WORKSPACE}"
  fi
}

function configureCLICredentials {
  if [[ ! -f "${HOME}/.terraformrc" ]] && [[ "${tfCLICredentialsToken}" != "" ]]; then
    cat > ${HOME}/.terraformrc << EOF
credentials "${tfCLICredentialsHostname}" {
  token = "${tfCLICredentialsToken}"
}
EOF
  fi
}

function installTerraform {
  curl -fsL "https://github.com/tfutils/tfenv/archive/v${tfenvVersion}.tar.gz" \
    | tar -xz -C ~/

  ln -s ~/tfenv-"${tfenvVersion}"/bin/* /usr/local/bin

  REQUIRED_TF_VERSIONS=$(
    find "${tfWorkingDir}" -name .terraform-version -exec cat {} \; -exec echo \; | sort -u
  )
  for TF_VERSION in $REQUIRED_TF_VERSIONS; do
    tfenv install $TF_VERSION
  done

  if [[ "${tfVersion}" == "latest" ]]; then
    echo "Checking the latest version of Terraform"
    tfVersion=$(curl -sL https://releases.hashicorp.com/terraform/index.json | jq -r '.versions[].version' | grep -v '[-].*' | sort -rV | head -n 1)

    if [[ -z "${tfVersion}" ]]; then
      echo "Failed to fetch the latest version"
      exit 1
    fi
  fi

  tfenv install "${tfVersion}"
  tfenv use "${tfVersion}"
}

function installTerragrunt {
  if [[ "${tgVersion}" == "latest" ]]; then
    echo "Checking the latest version of Terragrunt"
    latestURL=$(curl -Ls -o /dev/null -w %{url_effective} https://github.com/gruntwork-io/terragrunt/releases/latest)
    tgVersion=${latestURL##*/}

    if [[ -z "${tgVersion}" ]]; then
      echo "Failed to fetch the latest version"
      exit 1
    fi
  fi

  url="https://github.com/gruntwork-io/terragrunt/releases/download/${tgVersion}/terragrunt_linux_amd64"

  echo "Downloading Terragrunt ${tgVersion}"
  curl -fsSL -o /tmp/terragrunt ${url}
  if [ "${?}" -ne 0 ]; then
    echo "Failed to download Terragrunt ${tgVersion}"
    exit 1
  fi
  echo "Successfully downloaded Terragrunt ${tgVersion}"

  echo "Moving Terragrunt ${tgVersion} to PATH"
  chmod +x /tmp/terragrunt
  mv /tmp/terragrunt /usr/local/bin/terragrunt
  if [ "${?}" -ne 0 ]; then
    echo "Failed to move Terragrunt ${tgVersion}"
    exit 1
  fi
  echo "Successfully moved Terragrunt ${tgVersion}"
}

function main {
  # Source the other files to gain access to their functions
  scriptDir=$(dirname ${0})
  source ${scriptDir}/terragrunt_fmt.sh
  source ${scriptDir}/terragrunt_init.sh
  source ${scriptDir}/terragrunt_validate.sh
  source ${scriptDir}/terragrunt_plan.sh
  source ${scriptDir}/terragrunt_apply.sh
  source ${scriptDir}/terragrunt_output.sh
  source ${scriptDir}/terragrunt_import.sh
  source ${scriptDir}/terragrunt_taint.sh
  source ${scriptDir}/terragrunt_destroy.sh

  parseInputs
  configureCLICredentials
  installTerraform
  cd ${GITHUB_WORKSPACE}/${tfWorkingDir}

  case "${tfSubcommand}" in
    fmt)
      installTerragrunt
      terragruntFmt ${*}
      ;;
    init)
      installTerragrunt
      terragruntInit ${*}
      ;;
    validate)
      installTerragrunt
      terragruntValidate ${*}
      ;;
    plan)
      installTerragrunt
      terragruntPlan ${*}
      ;;
    apply)
      installTerragrunt
      terragruntApply ${*}
      ;;
    output)
      installTerragrunt
      terragruntOutput ${*}
      ;;
    import)
      installTerragrunt
      terragruntImport ${*}
      ;;
    taint)
      installTerragrunt
      terragruntTaint ${*}
      ;;
    destroy)
      installTerragrunt
      terragruntDestroy ${*}
      ;;
    *)
      echo "Error: Must provide a valid value for terragrunt_subcommand"
      exit 1
      ;;
  esac
}

main "${*}"
