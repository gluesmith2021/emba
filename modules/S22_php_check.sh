#!/bin/bash

# emba - EMBEDDED LINUX ANALYZER
#
# Copyright 2020-2021 Siemens Energy AG
# Copyright 2020-2021 Siemens AG
#
# emba comes with ABSOLUTELY NO WARRANTY. This is free software, and you are
# welcome to redistribute it under the terms of the GNU General Public License.
# See LICENSE file for usage of this software.
#
# emba is licensed under GPLv3
#
# Author(s): Michael Messner, Pascal Eckmann

# Description:  Checks for bugs, stylistic errors, etc. in php scripts, then it lists the found error types.

S22_php_check()
{
  module_log_init "${FUNCNAME[0]}"
  module_title "Check php scripts for syntax errors"

  S22_PHP_VULNS=0
  S22_PHP_SCRIPTS=0

  if [[ $PHP_CHECK -eq 1 ]] ; then
    mapfile -t PHP_SCRIPTS < <( find "$FIRMWARE_PATH" -xdev -type f -iname "*.php" -exec md5sum {} \; 2>/dev/null | sort -u -k1,1 | cut -d\  -f3 )
    for LINE in "${PHP_SCRIPTS[@]}" ; do
      if ( file "$LINE" | grep -q "PHP script" ) ; then
        ((S22_PHP_SCRIPTS++))
        if [[ "$THREADED" -eq 1 ]]; then
          s22_script_check &
          WAIT_PIDS_S22+=( "$!" )
        else
          s22_script_check
        fi
      fi
    done

    if [[ "$THREADED" -eq 1 ]]; then
      wait_for_pid "${WAIT_PIDS_S22[@]}"
    fi

    if [[ -f "$TMP_DIR"/S22_VULNS.tmp ]]; then
      while read -r VULNS; do
        (( S22_PHP_VULNS="$S22_PHP_VULNS"+"$VULNS" ))
      done < "$TMP_DIR"/S22_VULNS.tmp
    fi

    print_output ""
    print_output "[+] Found ""$ORANGE""$S22_PHP_VULNS"" issues""$GREEN"" in ""$ORANGE""$S22_PHP_SCRIPTS""$GREEN"" php files.""$NC""\\n"
    write_log ""
    write_log "[*] Statistics:$S22_PHP_VULNS:$S22_PHP_SCRIPTS"

  else
    print_output "[-] PHP check is disabled ... no tests performed"
  fi
  module_end_log "${FUNCNAME[0]}" "$S22_PHP_VULNS"
}

s22_script_check() {
  NAME=$(basename "$LINE" 2> /dev/null | sed -e 's/:/_/g')
  PHP_LOG="$LOG_PATH_MODULE""/php_""$NAME"".txt"
  php -l "$LINE" > "$PHP_LOG" 2>&1
  VULNS=$(grep -c "PHP Parse error" "$PHP_LOG" 2> /dev/null)
  if [[ "$VULNS" -ne 0 ]] ; then
    #check if this is common linux file:
    local COMMON_FILES_FOUND
    if [[ -f "$BASE_LINUX_FILES" ]]; then
      COMMON_FILES_FOUND="(""${RED}""common linux file: no""${GREEN}"")"
      if grep -q "^$NAME\$" "$BASE_LINUX_FILES" 2>/dev/null; then
        COMMON_FILES_FOUND="(""${CYAN}""common linux file: yes""${GREEN}"")"
      fi
    else
      COMMON_FILES_FOUND=""
    fi
    print_output "[+] Found ""$ORANGE""parsing issues""$GREEN"" in script ""$COMMON_FILES_FOUND"":""$NC"" ""$(print_path "$LINE")" "" "$PHP_LOG"
    echo "$VULNS" >> "$TMP_DIR"/S22_VULNS.tmp
  fi
}

#memory_limit            = 50M
#post_max_size           = 20M
#max_execution_time      = 60

s22_check_php_init(){
  #$(sudo ~/vendor/bin/iniscan scan --path=/etc/php/7.4/apache2/php.ini > ./logs/iniscan_output.txt)
  FILE="./logs/iniscan_output.txt"
  while IFS= read -r LINE
  do
    if (( "$LINE" == *"FAIL"* && "$LINE" == *"ERROR"*)); then
         add_recommendations LINE
         print_output "[-] ""$ORANGE""FAIL""$RED""ERROR""$WHITE""$LINE"
    elif (( "$LINE" == *"FAIL"* && "$LINE" == *"WARNING"*)); then
         add_recommendations LINE
         print_output "[-] ""$ORANGE""FAIL""$CYAN""WARNING""$WHITE""$LINE"
    elif (( "$LINE" == *"PASS"* && "$LINE" == *"WARNING"*)); then
         print_output "[-] ""$GREEN""PASS""$ORANGE""ERROR""$WHITE""$LINE"
    elif (( "$LINE" == *"PASS"* && "$LINE" == *"WARNING"*)); then
         print_output "[-] ""$GREEN""PASS""$CYAN""WARNING""$WHITE""$LINE"
    fi
    #print_output "$(orange "orange text example")"
    #print_output "$(red "red text example")"
    #print_output "$(blue "blue text example")"
    #print_output "$(cyan "cyan text example")"
    #print_output "$(green "green text example")"
    #print_output "$(magenta "magenta text example")"
  done < "$FILE"
}

add_recommendations(){
   LINE = $1
   LINE_ARR = LINE.split('|');

   if()
   #memory_limit            = 50M
#post_max_size           = 20M
#max_execution_time      = 60



}


#Must heaves
# PHP7.2+
#display_errors = Off
#allow_url_fopen         = Off
#allow_url_include       = Off
#file_uploads            = On (nur wenn benötigt)
#enable_dl               = Off
#disable_functions       = system, exec, shell_exec, passthru, phpinfo, show_source, highlight_file, popen, proc_open, fopen_with_path, dbmopen, dbase_open, putenv, move_uploaded_file, chdir, mkdir, rmdir, chmod, rename, filepro, filepro_rowcount, filepro_retrieve, posix_mkfifo
# see also: http://ir.php.net/features.safe-mode
#disable_classes         =
#session.name                     = myPHPSESSID
#session.referer_check   = /application/path
#memory_limit            = 50M
#post_max_size           = 20M
#max_execution_time      = 60
#report_memleaks         = On
#track_errors            = Off
#html_errors             = Off
