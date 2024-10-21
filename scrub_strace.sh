#!/bin/bash

PARAMS=$*
HELP=0
BASENAME=`basename $0`
ERROR_MESSAGE=""
TIME_DELTA_THRESHOLD=2
OUTPUT_FORMAT="raw"

display_usage ()
{
   echo "\
Usage: $BASENAME -f <strace_filename> [--timedelta] [--csv] [-v] [-h|--help]

   -f            strace filename
   --timedelta   time delta from previous syscall seconds (DEFAULT: 2 seconds ; optional)
   --csv         output in CSV format (DEFAULT: raw ; optional)
   -v            verbose output (DEFAULT: non-verbose ; optional)

   -h|--help     display this help and exit (optional)
"
}

while [ "$1" != "" ]
do
   case $1 in
      "-f") shift;          STRACE_FILENAME="$1"; shift;;
      "--timedelta") shift; TIME_DELTA_THRESHOLD="$1"; shift;;
      "--csv") shift;       OUTPUT_FORMAT="csv";;
      "-h") shift; HELP=1              ;;
      "--help") shift; HELP=1          ;;
      "-v") shift; VERBOSE="Y"         ;;
         *) shift; ERROR_MESSAGE="Invalid Parameter -- $PARAMS";;
   esac
done

function error_handler
{
   echo "$BASENAME: $1"
   display_usage
   exit 1
}

if [ "$ERROR_MESSAGE" != "" ]; then
   error_handler "$ERROR_MESSAGE"
fi

if [ $HELP != 0 ]; then
   display_usage
   exit 0
fi

if [[ "STRACE_FILENAME" == "" ]]; then
  echo "missing something ? (eg. -f parm should be input file"
  exit 1
fi

cat "$STRACE_FILENAME" | \
awk 'BEGIN{
  VERBOSE = "'"$VERBOSE"'"
  TIME_DELTA_THRESHOLD = "'"$TIME_DELTA_THRESHOLD"'"
  TIME_DELTA_THRESHOLD = TIME_DELTA_THRESHOLD + 0
  OUTPUT_FORMAT = "'"$OUTPUT_FORMAT"'"
  OUTPUT_SEPARATOR = " "
  if ( OUTPUT_FORMAT == "csv" ) { OUTPUT_SEPARATOR = "," }

  syscall_count = 0
  syscall_timedelta = 0
  previous_syscall_time = 0
}
!/resuming|resume/{
  line = $0
  split($2,a,".")
  ts = strftime("%Y-%m-%d-%H.%M.%S", a[1])"."a[2]
  split($3,c,"(")

  if(match(c[1],/^[A-Za-z]+$/))
  {
    syscall = c[1]
    syscall_count++
    current_syscall_time = $2
    if (syscall_count > 1)
    {
      syscall_timedelta = current_syscall_time - previous_syscall_time
    }

    if ( VERBOSE == "Y" )
    {
      if ( syscall_timedelta >= TIME_DELTA_THRESHOLD )
      {
        printf("%s%s%s%s033[1;33m%f\033[0m%s[%s]\n", 
          ts,
          OUTPUT_SEPARATOR,
          syscall,
          OUTPUT_SEPARATOR,
          syscall_timedelta,
          OUTPUT_SEPARATOR,
          line)
      }
      else
      {
        printf("%s%s%s%s%f%s[%s]\n",
          ts,
          OUTPUT_SEPARATOR,
          syscall,
          OUTPUT_SEPARATOR,
          syscall_timedelta,
          OUTPUT_SEPARATOR,
          line)
      }
    }
    else
    {
       if ( syscall_timedelta >= TIME_DELTA_THRESHOLD )
       {
         printf("%s%s%s%s\033[1;33m%f\033[0m%s[%s]\n",
           ts,
           OUTPUT_SEPARATOR,
           syscall,
           OUTPUT_SEPARATOR,
           syscall_timedelta,
           OUTPUT_SEPARATOR,
           line)
       }
    }
    previous_syscall_time = $2
  }
}
END{
  if ( OUTPUT_FORMAT == "raw" )
  {
    printf("\nSummary\n  WIP\n")
    printf("\n\n")
  }
}'

exit 0
