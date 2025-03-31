#!/bin/bash

for i in $(seq 7 9); do \
  /bin/ls -1 rhel_${i}*_release_notes.txt | sort -t'.' -k2n
done | \
while read fn ; do
  cat $fn | \
  awk 'BEGIN{
    IGNORECASE=1
    fn = "'"$fn"'"
    gsub(/rhel_/,"",fn)
    gsub(/_release_notes/,"",fn)
    gsub(/\.txt$/,"",fn)
    chapter = ""
    section = ""
  }
  /## Chapter/{chapter = $0 ; gsub(/## /,"",chapter)}
  /### [0-9]/{section = $0 ; gsub(/### /,"",section)}
  /\*\*.*sssd/{
    found_it = $0
    gsub(/\*\*/,"",found_it)
    printf("RHEL %s | %s | %s | %s\n", fn, chapter, section, found_it) 
  }'
done

exit 0

# Todo:
# - use args to pass search criteria instead of hard-coded /\*\*.*sssd/
# - combine get_release_notes.sh into this script, store in a "cache" of some sort
# - collect/refresh release notes if/when necessary
# - csv, json, and yaml output would be nice...eventually
# - convert all into python
