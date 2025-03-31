#!/bin/bash

major_version=7       # eg. 7 or 8 or 9 work...10-beta, not so much...yet
minor_max_version=9   # eg. for 7.9, just use 9. For 8.10, use 10, etc... I'll make this easier later

for minor_version in $(seq 0 $minor_max_version) ; do
   echo "RHEL $major_version.$minor_version)"
   curl -sk "https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/${major_version}/html-single/${major_version}.${minor_version}_release_notes/index" -o - | html2text > rhel_${major_version}.${minor_version}_release_notes.txt
done

exit 0
