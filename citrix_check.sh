#!/bin/bash
# shellcheck disable=SC2016 shell=bash

function print_help {
  SCRIPT="citrix_check.sh"

  echo "$SCRIPT version 0.1.1 by Taneli Kaivola / Nixu"
  echo
  echo '```'
  echo "Usage: $SCRIPT [options] -t TARGET"
  echo "    TARGET is a mounted vmdk with filesystems mounted in flash/ and var/"
  echo
  echo "general options:"
  echo "    -x              print everything the script does"
  echo "execution options:"
  echo "    --no-triage     do not run triage"
  echo "    --no-config     do not run config checks"
  echo "    --no-forensics  do not run forensics checks"
  echo "    -l or --live    run tests in live system (excludes some noisy bash logs)"
  echo "    -a or --all     run very slow checks"
  echo "path options:"
  echo "    -no-var         skip running tests on var"
  echo "    -no-flash       skip running tests on flash"
  echo "    -var=path       set relative path to be user for var"
  echo "    -flash=path     set relative path to be user for flash"
  echo '```'
  echo
  echo "Full example for running a check (most of this requires root):"
  echo
  echo '```'
  echo "qemu-nbd -r -c /dev/nbd1 netscaler.vmdk"
  echo "mkdir -p target/{flash,var}"
  echo "mount -t ufs -o ro,ufstype=ufs2 /dev/nbd1p1 target/flash"
  echo "mount -t ufs -o ro,ufstype=ufs2 /dev/nbd1p8 target/var"
  echo "./citrix_check.sh -t target | tee report.md"
  echo "pandoc -f markdown -o report.html report.md"
  echo "umount target/flash"
  echo "umount target/var"
  echo "qemu-nbd -d /dev/nbd1"
  echo "rmdir target/{flash,var}"
  echo '```'
  echo
}

function check_live_files {
  echo "### List all the files modified after 2020-01-10"
  echo
  echo '```'
  find / -newermt "2020-01-10" -not -path "/proc/*" -type f -print0 | xargs -0 /bin/ls -ltr
  echo '```'
  echo
}

function check_live_portal_scripts {
  echo "### Calculate MD5 files netscaler portal scripts (/netscaler/portal/scripts/)"
  echo
  echo '```'
  md5 /netscaler/portal/scripts/*
  echo '```'
  echo
}

function check_live_config_syslog {
  echo "### List syslog configuration in /etc/newsyslog.conf"
  echo
  echo '```'
  cat /etc/newsyslog.conf
  echo '```'
  echo
}

function check_live_connections {
  echo "### List connected sockets to external hosts"
  echo
  echo '```'
  sockstat -c -4 | awk '{ if (substr($7,1,8) != "127.0.0.") print $0}'
  echo '```'
  echo
  echo "### List connected sockets to localhost"
  echo
  echo '```'
  sockstat -c -4 | awk '{ if (substr($7,1,8) == "127.0.0.") print $0}'
  echo '```'
  echo
}

function check_live_processes {
  echo "### List running processes"
  echo
  echo '```'
  ps auxd
  echo '```'
  echo
}

function check_config_ssl {
  if [ -z "$PATH_FLASH" ]; then return; fi

  echo "### Checking SSL certificates"
  echo
  cd "${PATH_FLASH}/nsconfig/ssl"
  echo '```'
  for f in *.crt; do
    if [ -f "${f//.crt}.key" ]; then
      echo "$ openssl x509 -in \"$f\" -noout -text | grep -E \"Validity|Subject:|Subject Alternative Name:\" -A 2"
      openssl x509 -in "$f" -noout -text | grep -E "Validity|Subject:|Subject Alternative Name:" -A 2
    fi
  done
  for f in *.cert; do
    if [ -f "${f//.cert}.key" ]; then
      echo "$ openssl x509 -in \"$f\" -noout -text | grep -E \"Validity|Subject:|Subject Alternative Name:\" -A 2"
      openssl x509 -in "$f" -noout -text | grep -E "Validity|Subject:|Subject Alternative Name:" -A 2
    fi
  done
  for f in *.pem; do
    if [ -f "${f//.pem}.key" ]; then
      echo "$ openssl x509 -in \"$f\" -noout -text | grep -E \"Validity|Subject:|Subject Alternative Name:\" -A 2"
      openssl x509 -in "$f" -noout -text | grep -E "Validity|Subject:|Subject Alternative Name:" -A 2
    fi
  done
  echo '```'
  echo
}

function check_triage_crontabs {
  if [ -z "$PATH_VAR" ]; then return; fi

  echo "### Checking crontab files"
  echo
  cd "${PATH_VAR}/cron/tabs/"

  echo "#### List of all crontab files"
  echo
  echo '```'
  ls -la
  echo '```'
  echo
  for f in *; do
    if [ -e "$f" ]; then
      echo "#### Finding: Crontab for user $f found"
      echo
      echo '```'
      cat "$f"
      echo '```'
      echo
    fi
  done
}

function check_nshttp_profile_ids {
  if [ -z "$PATH_VAR" ]; then return; fi

  echo "### Checking nshttp_profile_ids"
  echo
  cd "${PATH_VAR}"

  echo "#### List of all files in nshttp_profile_ids"
  echo 
  echo '```'
  ls -lart ./run/nshttp_profile_ids/
  echo '```'

  echo "#### List of IOCs in nshttp_profile_ids"
  echo 
  echo "All of the following sections should be empty."
  echo
  echo '```'
  grep -aHir '`' ./run/nshttp_profile_ids/ | xxd
  echo '```'
  echo
  echo '```'
  grep -aHir template.new ./run/nshttp_profile_ids/ | xxd
  echo '```'
  echo
  echo '```'
  grep -aHir '&#91;&#37;' ./run/nshttp_profile_ids/ | xxd
  echo '```'
  echo
  echo '```'
  grep -aHir '../..' ./run/nshttp_profile_ids/ | xxd
  echo '```'
  echo
}

function check_httpaccess_logs {
  if [ -z "$PATH_VAR" ]; then return; fi

  echo "### Checking httpaccess_logs"
  echo
  cd "${PATH_VAR}"

  echo "All of the following subsections should be empty."
  echo

  echo "#### GET requests on .xml files"
  echo '```'
  grep -HiE -B 1 'GET.*\.xml HTTP/1\.1\" 200' log/httpaccess.log log/httpaccess.log.*[0-9] 2>/dev/null
  zgrep -HiE -B 1 'GET.*\.xml HTTP/1\.1\" 200' log/httpaccess.log.*.gz 2>/dev/null
  echo '```'
  echo

  echo "#### GET requests on .xml files"
  echo '```'
  grep -HiE -B 1 '(GET|POST).*\.pl HTTP/1\.1\" 200' log/httpaccess.log log/httpaccess.log.*[0-9] 2>/dev/null
  zgrep -HiE -B 1 '(GET|POST).*\.pl HTTP/1\.1\" 200' log/httpaccess.log.*.gz 2>/dev/null
  echo '```'
  echo

  echo "#### GET or POST requests to Perl files"
  echo '```'
  grep -HiE '(GET|POST).*\.pl HTTP/1\.1\" 200' log/httpaccess.log log/httpaccess.log.*[0-9] 2>/dev/null
  zgrep -HiE '(GET|POST).*\.pl HTTP/1\.1\" 200' log/httpaccess.log.*.gz 2>/dev/null
  echo '```'
  echo

  echo "#### Execution of php files"
  echo '```'
  grep -HiE '(support|shared|n_top|vpn|themes).+\.php HTTP/1\.1\" 200' log/httpaccess.log log/httpaccess.log.*[0-9] 2>/dev/null
  zgrep -HiE '(support|shared|n_top|vpn|themes).+\.php HTTP/1\.1\" 200' log/httpaccess.log.*.gz 2>/dev/null
  echo '```'
  echo

  echo "#### Miscellanious indicators"
  echo '```'
  grep -HiE 'newbm\.pl|127\.0\.0\.2|smb\.conf' log/httpaccess.log log/httpaccess.log.*[0-9] 2>/dev/null
  zgrep -HiE 'newbm\.pl|127\.0\.0\.2|smb\.conf' log/httpaccess.log.*.gz 2>/dev/null
  echo '```'
  echo
}

function check_shell_logs {
  if [ -z "$PATH_VAR" ]; then return; fi

  echo "### Checking check_shell_logs"
  echo

  cd "${PATH_VAR}"

  echo "#### Checking for commands ran by nobody"
  echo
  echo "The following section should be empty. "
  echo

  echo '```'
  grep -Hi 'nobody' log/bash.log log/bash.log*[0-9] 2>/dev/null
  zgrep -Hi 'nobody' log/bash.log.*.gz 2>/dev/null
  grep -Hi 'nobody' log/sh.log log/sh.log*[0-9] 2>/dev/null
  zgrep -Hi 'nobody' log/sh.log.*.gz 2>/dev/null
  echo '```'
  echo

  echo "#### Checking for commands ran from console"
  echo
  if [ "$RUN_LIVE" == "NO" ]; then
  echo "Skipped because this is a live system."
  else
  echo "The following section contains commands ran from the console."
  echo
  echo '```'
  grep -Hi '/dev/pts/' log/bash.log log/bash.log*[0-9] 2>/dev/null
  zgrep -Hi '/dev/pts/' log/bash.log.*.gz 2>/dev/null
  grep -Hi '/dev/pts/' log/sh.log log/sh.log*[0-9] 2>/dev/null
  zgrep -Hi '/dev/pts/' log/sh.log.*.gz 2>/dev/null
  echo '```'
  fi
  echo
}

function check_forensics_iocs {
  echo "### Checking known IOCs from all *.gz-files on disk"
  echo
  echo '```'
  find . -type f -name \*.gz -exec zgrep -E -aHi "138\.68\.14\.63|95\.179\.163\.186|185\.178\.45\.221|159\.69\.37\.196|d3SY1erQ|2zds3h2T|8xNac8At|UrJnnijX" '{}' \;
  echo '```'
  echo
}

function check_new_files {
  echo "### List new files since 2020-01-10"
  echo
  echo '```'
  find . -newermt "2020-01-10" -not -path "/proc/*" -type f -print0 | xargs -0 /bin/ls -ltr
  echo '```'
  echo
}

function print_header {
  echo "# Automated Netscaler report for $TARGET"
  echo
  echo "## citrix_check.sh configuration"
  echo
  echo "- PATH: $(pwd -P)"
  echo "- TARGET: ${TARGET}"
  echo "- PATH_VAR: ${PATH_VAR}"
  echo "- PATH_FLASH: ${PATH_FLASH}"
  echo "- RUN_TRIAGE: ${RUN_TRIAGE}"
  echo "- RUN_CONFIG: ${RUN_CONFIG}"
  echo "- RUN_FORENSICS: ${RUN_FORENSICS}"
  echo "- RUN_SLOW: ${RUN_SLOW}"
  echo "- RUN_LIVE: ${RUN_SLOW}"
  echo
}

RUN_TRIAGE=YES
RUN_CONFIG=YES
RUN_FORENSICS=YES
RUN_SLOW=NO
RUN_LIVE=NO

PATH_VAR="./var/"
PATH_FLASH="./flash/"

while [[ $# -gt 0 ]]
do
key="$1"

case $key in
    -t|--target)
      TARGET="$2"
      shift
      shift
    ;;
    --no-triage)
      RUN_TRIAGE=NO
      shift
    ;;
    --no-config)
      RUN_CONFIG=NO
      shift
    ;;
    --no-forensics)
      RUN_FORENSICS=NO
      shift
    ;;
    -l|--live)
      RUN_LIVE=YES
      shift
    ;;
    -a|--all|--slow)
      RUN_SLOW=YES
      shift
    ;;
    --no-var)
      PATH_VAR=""
      shift
    ;;
    --no-flash)
      PATH_FLASH=""
      shift
      shift
    ;;
    --flash)
      PATH_FLASH="$2"
      shift
      shift
    ;;
    --var)
      PATH_FLASH="$2"
      shift
      shift
    ;;
    -x)
      set -x
      shift
    ;;
    --help)
      HELP=YES
      shift
    ;;
esac
done

#set -x
set -e
if [ -z "$TARGET" ] || ! [ -d "$TARGET" ] || [ -n "$HELP" ]; then
  print_help
  exit
fi

print_header

cd "$TARGET"  

if [ "$RUN_LIVE" == "YES" ]; then
  echo "## Live collection"
  echo
  (check_live_live_processes || echo "Test execution failed")
  (check_live_files || echo "Test execution failed")
  (check_live_portal_scripts || echo "Test execution failed")
  (check_live_config_syslog || echo "Test execution failed")
  (check_live_connections || echo "Test execution failed")

fi

if [ "$RUN_TRIAGE" == "YES" ]; then
  echo "## Triage"
  echo
  (check_triage_crontabs || echo "Test execution failed")
  (check_shell_logs || echo  "Test execution failed")
  (check_nshttp_profile_ids || echo "Test execution failed")
fi

if [ "$RUN_CONFIG" == "YES" ]; then
  echo "## Config file checks"
  echo
  (check_config_ssl || echo "Test execution failed")
fi

if [ "$RUN_FORENSICS" == "YES" ]; then
  echo "## Forensics"
  echo
  (check_new_files || echo "Test execution failed")
fi

if [ "$RUN_SLOW" == "YES" ]; then
  echo "## Forensics (slow checks)"
  echo
  (check_forensics_iocs || echo "Test execution failed")
fi
