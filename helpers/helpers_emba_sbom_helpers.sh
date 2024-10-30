#!/bin/bash -p

# EMBA - EMBEDDED LINUX ANALYZER
#
# Copyright 2024-2024 Siemens Energy AG
#
# EMBA comes with ABSOLUTELY NO WARRANTY. This is free software, and you are
# welcome to redistribute it under the terms of the GNU General Public License.
# See LICENSE file for usage of this software.
#
# EMBA is licensed under GPLv3
# SPDX-License-Identifier: GPL-3.0-only
#
# Author(s): Michael Messner

# Description: Helper functions for SBOM building
#

# first: build the properaties path array
# This can be used for the binary path (souce_path) and for paths extracted from a
# package like deb or rpm (path). Additionally, it is commonly used for the architecture
# and further meta data like the version identifier
# parameter: array with all the properties in the form
#   "path:the_path_to_log"
#   "other_propertie:the_property_to_log"
# returns global array PROPERTIES_JSON_ARR
build_sbom_json_properties_arr() {
  local lPROPERTIES_ARRAY_INIT_ARR=("$@")

  local lPROPERTIES_ELEMENT_ID=""
  local lPROPERTIES_ELEMENT=""
  # PROPERTIES_JSON_ARR is used in the caller
  export PROPERTIES_JSON_ARR=()
  local lPROPERTIES_ELEMENT_1=""
  local lPROPERTIES_ELEMENT_2=""
  local lINIT_ELEMENT=""

  for lPROPERTIES_ELEMENT_ID in "${!lPROPERTIES_ARRAY_INIT_ARR[@]}"; do
    lPROPERTIES_ELEMENT="${lPROPERTIES_ARRAY_INIT_ARR["${lPROPERTIES_ELEMENT_ID}"]}"
    # lPROPERTIES_ELEMENT_1 -> path, source or something else
    lPROPERTIES_ELEMENT_1=$(echo "${lPROPERTIES_ELEMENT}" | cut -d ':' -f1)
    # lPROPERTIES_ELEMENT_2 -> the real value
    lPROPERTIES_ELEMENT_2=$(echo "${lPROPERTIES_ELEMENT}" | cut -d ':' -f2-)
    # jo is looking for a file if our entry starts with : -> lets pseudo escape it for jo
    if [[ "${lPROPERTIES_ELEMENT_2:0:1}" == ":" ]]; then
      lPROPERTIES_ELEMENT_2='\'"${lPROPERTIES_ELEMENT_2}"
    fi

    # default value
    lINIT_ELEMENT="EMBA:sbom"
    # dedicated rules -> path -> location
    [[ "${lPROPERTIES_ELEMENT_1}" == "path" ]] && lINIT_ELEMENT="EMBA:sbom:location"
    [[ "${lPROPERTIES_ELEMENT_1}" == "source_path" ]] && lINIT_ELEMENT="EMBA:sbom:source_location"

    local lPROPERTIES_ARRAY_TMP=()
    lPROPERTIES_ARRAY_TMP+=("name=${lINIT_ELEMENT}:$((lPROPERTIES_ELEMENT_ID+1)):${lPROPERTIES_ELEMENT_1}")
    [[ "${lPROPERTIES_ELEMENT_2}" == "NA" ]] && continue
    lPROPERTIES_ARRAY_TMP+=("value=${lPROPERTIES_ELEMENT_2}")
    PROPERTIES_JSON_ARR+=( "$(jo "${lPROPERTIES_ARRAY_TMP[@]}")")
  done
  # lPROPERTIES_PATH_JSON=$(jo -p -a "${lPROPERTIES_PATH_ARR_TMP[@]}")
}

# 2nd: build the checksum array
# We currently build md5, sha256 and sha512
# parameter: binary/file to check
# returns global array HASHES_ARR
build_sbom_json_hashes_arr() {
  local lBINARY="${1:-}"

  local lMD5_CHECKSUM=""
  local lSHA256_CHECKSUM=""
  local lSHA512_CHECKSUM=""
  # HASHES_ARR is used in the caller
  export HASHES_ARR=()

  # hashes of the source file that is currently tested:
  lMD5_CHECKSUM="$(md5sum "${lBINARY}" | awk '{print $1}')"
  lSHA256_CHECKSUM="$(sha256sum "${lBINARY}" | awk '{print $1}')"
  lSHA512_CHECKSUM="$(sha512sum "${lBINARY}" | awk '{print $1}')"

  # temp array with only one set of hash values
  local lHASHES_ARRAY_INIT=("alg=MD5")
  lHASHES_ARRAY_INIT+=("content=${lMD5_CHECKSUM}")
  HASHES_ARR+=( "$(jo "${lHASHES_ARRAY_INIT[@]}")" )

  lHASHES_ARRAY_INIT=("alg=SHA-256")
  lHASHES_ARRAY_INIT+=("content=${lSHA256_CHECKSUM}")
  HASHES_ARR+=( "$(jo "${lHASHES_ARRAY_INIT[@]}")" )

  lHASHES_ARRAY_INIT=("alg=SHA-512")
  lHASHES_ARRAY_INIT+=("content=${lSHA512_CHECKSUM}")
  HASHES_ARR+=( "$(jo "${lHASHES_ARRAY_INIT[@]}")" )

  # lhashes=$(jo -p -a "${HASHES_ARR[@]}")
}

# 3rd: build and store the component sbom as json
# paramters: multiple
# return: nothing -> writes json to SBOM directory
build_sbom_json_component_arr() {
  local lPACKAGING_SYSTEM="${1:-}"
  local lAPP_TYPE="${2:-}"
  local lAPP_NAME="${3:-}"
  local lAPP_VERS="${4:-}"
  local lAPP_MAINT="${5:-}"
  local lAPP_LIC="${6:-}"
  local lCPE_IDENTIFIER="${7:-}"
  local lPURL_IDENTIFIER="${8:-}"
  local lAPP_DESC="${9:-}"
  # we need the bom-ref in the caller to include it in our EMBA csv log for further references
  export SBOM_COMP_BOM_REF=""
  SBOM_COMP_BOM_REF="$(uuidgen)"

  if [[ -n "${lAPP_MAINT}" ]] && { [[ "${lAPP_MAINT}" == "NA" ]] || [[ "${lAPP_MAINT}" == "-" ]]; }; then
    lAPP_MAINT=""
  fi
  [[ -n "${lAPP_MAINT}" ]] && lAPP_MAINT=$(translate_vendor "${lAPP_MAINT}")

  if [[ -n "${lAPP_VERS}" ]] && [[ "${lAPP_VERS}" == "NA" ]]; then
    lAPP_VERS=""
  fi
  if [[ -n "${lCPE_IDENTIFIER}" ]] && [[ "${lCPE_IDENTIFIER}" == "NA" ]]; then
    lCPE_IDENTIFIER=""
  fi
  if [[ -n "${lPURL_IDENTIFIER}" ]] && [[ "${lPURL_IDENTIFIER}" == "NA" ]]; then
    lPURL_IDENTIFIER=""
  fi

  local lAPP_DESC_NEW="EMBA SBOM-group: ${lPACKAGING_SYSTEM} - name: ${lAPP_NAME}"
  if [[ -n "${lAPP_VERS}" ]] && [[ "${lAPP_VERS}" != "NA" ]]; then
    lAPP_DESC_NEW+=" - version: ${lAPP_VERS}"
  fi
  if [[ -n "${lAPP_DESC}" ]] && [[ "${lAPP_DESC}" != "NA" ]]; then
    lAPP_DESC_NEW+=" - description: ${lAPP_DESC}"
  fi

  local lCOMPONENT_ARR=()

  lCOMPONENT_ARR+=( "type=${lAPP_TYPE}" )
  lCOMPONENT_ARR+=( "name=${lAPP_NAME:-NA}" )
  lCOMPONENT_ARR+=( "-s" "version=${lAPP_VERS}" )
  lCOMPONENT_ARR+=( "author=${lAPP_MAINT}" )
  lCOMPONENT_ARR+=( "group=${lPACKAGING_SYSTEM}" )
  lCOMPONENT_ARR+=( "bom-ref=${SBOM_COMP_BOM_REF}" )
  if [[ -n "${lAPP_LIC}" ]] && [[ ! "${lAPP_LIC}" == "NA" ]]; then
    lCOMPONENT_ARR+=( "license=$(jo name="${lAPP_LIC}")" )
  fi
  lCOMPONENT_ARR+=( "cpe=${lCPE_IDENTIFIER}" )
  lCOMPONENT_ARR+=( "purl=${lPURL_IDENTIFIER}" )
  lCOMPONENT_ARR+=( "properties=$(jo -a "${PROPERTIES_JSON_ARR[@]}")" )
  if [[ "${#HASHES_ARR[@]}" -gt 0 ]]; then
    lCOMPONENT_ARR+=( "hashes=$(jo -a "${HASHES_ARR[@]}")" )
  fi
  lCOMPONENT_ARR+=( "description=${lAPP_DESC_NEW//\ /%SPACE%}" )

  if [[ ! -d "${SBOM_LOG_PATH}" ]]; then
    mkdir "${SBOM_LOG_PATH}"
  fi

  # if ! check_for_duplicates "${lAPP_NAME}"; then
    jo -n -- "${lCOMPONENT_ARR[@]}" > "${SBOM_LOG_PATH}/${lPACKAGING_SYSTEM}_${lAPP_NAME}_${SBOM_COMP_BOM_REF:-NA}.json"
  # else
  #   print_output "[-] Possible duplicate found for ${lAPP_NAME}" "no_log"
  # fi

  # we can unset it here again
  unset HASHES_ARR
  unset PROPERTIES_PATH_JSON_ARR
}

check_for_duplicates() {
  local lAPP_NAME="${1:-}"
  # local lDUPLICATE_FILES=()
  # check if we already have a result in our sbom
  # mapfile -t lDUPLICATE_FILES < <(grep -i -l "${lAPP_NAME}" "${SBOM_LOG_PATH%\/}/"*)
  print_output "[-] Duplicate check for ${lAPP_NAME} not available" "no_log"
}

# translate known vendors from short variant to the long variant:
#   dlink -> D'Link
#   kernel -> kernel.org
translate_vendor() {
  local lAPP_MAINT="${1:-}"
  local lAPP_MAINT_NEW=""

  if [[ -f "${CONFIG_DIR}"/vendor_list.cfg ]]; then
    lAPP_MAINT_NEW="$(grep "^${lAPP_MAINT};" "${CONFIG_DIR}"/vendor_list.cfg | cut -d ';' -f2- || true)"
    lAPP_MAINT_NEW="${lAPP_MAINT_NEW//\"}"
  fi

  [[ -z "${lAPP_MAINT_NEW}" ]] && lAPP_MAINT_NEW="${lAPP_MAINT}"
  echo "${lAPP_MAINT_NEW}"
}
