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

function error_handler
{
   echo "$BASENAME: $1"
   display_usage
   exit 1
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

  syscall_list = ""
  syscall_array_count = 0
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

    if (index(syscall_list,syscall) == 0)
    {
      syscall_list = syscall_list" "syscall
      syscall_array_count++
      syscall_array_operation[syscall_array_count] = syscall
    }

    if (syscall_count > 1)
    {
      syscall_timedelta = current_syscall_time - previous_syscall_time
    }

    for (syscall_index=1;syscall_index<=syscall_array_count;syscall_index++)
    {
      if ( syscall == syscall_array_operation[syscall_index] )
      {
        syscall_array_op_time_spent[syscall_index] = syscall_array_op_time_spent[syscall_index] + syscall_timedelta
        syscall_array_op_count[syscall_index]++
      }
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
  printf("\n")
  if ( OUTPUT_FORMAT == "csv" )
  {
    printf("syscall_operation,time_spent,count\n")
    for (syscall_index=1;syscall_index<=syscall_array_count;syscall_index++)
    {
      printf("%s%s%f%s%d\n",
        syscall_array_operation[syscall_index],
        OUTPUT_SEPARATOR,
        syscall_array_op_time_spent[syscall_index],
        OUTPUT_SEPARATOR,
        syscall_array_op_count[syscall_index])
    }
  }
  else
  {
    printf("Summary\n")
    printf("%-32s %12s %9s\n", "syscall_operation", "time_spent", "count")
    for (syscall_index=1;syscall_index<=syscall_array_count;syscall_index++)
    {
      printf("%-32s %12.9f %9d\n",
        syscall_array_operation[syscall_index],
        syscall_array_op_time_spent[syscall_index],
        syscall_array_op_count[syscall_index])
    }
    printf("\n")
  }
}'

exit 0
