# Usage: printStatus <function> <message>
function printStatus {
  local TMP_NAME="${1}"
  local TMP_TIME="`date '+%y/%m/%d %H:%M:%S'`"
  shift

  if [ -f "${CUBIESTRAP_LOG_FILE}" ]; then
    printf "[${TMP_TIME} %.15s] %s\n" "${TMP_NAME}" "$@" >> ${CUBIESTRAP_LOG_FILE}
  fi

  printf "[${TMP_TIME} %.15s] %s\n" "${TMP_NAME}" "$@"

}