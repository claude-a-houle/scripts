#!/bin/bash

PARAMS=$*
HELP=0
BASENAME=`basename $0`
ERROR_MESSAGE=""
TIME_DELTA_THRESHOLD=2
OUTPUT_FORMAT="raw"
SUMMARY="Y"
STRACE_FILENAME=""

display_usage ()
{
   echo "\
Usage: $BASENAME -f <strace_filename> [--timedelta] [--csv] [-v|--verbose] [--no-summary] [-h|--help]

   -f            strace filename
   --timedelta   time delta threshold from previous syscall seconds (DEFAULT: 2 seconds ; optional)
   --csv         output in CSV format (DEFAULT: raw ; optional)
   -v|--verbose  verbose output (DEFAULT: non-verbose ; optional)
   --no-summary  (DEFAULT: on ; optional)

   -h|--help     display this help and exit (optional)
"
}

function error_handler
{
   echo "$BASENAME: $1"
   display_usage
   exit 1
}

################################################################################
### Process Input Parms
################################################################################
while [ "$1" != "" ]
do
   case $1 in
      "-f")           shift; STRACE_FILENAME="$1"; shift;;
      "--timedelta")  shift; TIME_DELTA_THRESHOLD="$1"; shift;;
      "--csv")        shift; OUTPUT_FORMAT="csv";;
      "--no-summary") shift; SUMMARY="N" ; VERBOSE="Y" ;;
      "-h")           shift; HELP=1              ;;
      "--help")       shift; HELP=1          ;;
      "-v")           shift; VERBOSE="Y"         ;;
      "--verbose")    shift; VERBOSE="Y"         ;;
         *)           shift; ERROR_MESSAGE="Invalid Parameter -- $PARAMS";;
   esac
done

if [ "$ERROR_MESSAGE" != "" ]; then
   error_handler "$ERROR_MESSAGE"
fi

if [ $HELP != 0 ]; then
   display_usage
   exit 0
fi

if [[ "$STRACE_FILENAME" == "" ]]; then
  error_handler "missing something ? (eg. -f parm should be input file"
fi

################################################################################
### Meat and potatoes of processing the strace file 
################################################################################
FIRST_STRACE_TS=$(awk '!/resuming|resume/{print $2}' "$STRACE_FILENAME" | head -1)
LAST_STRACE_TS=$(awk '!/resuming|resume/{print $2}' "$STRACE_FILENAME" | tail -1)

cat "$STRACE_FILENAME" | \
awk 'BEGIN{
  STRACE_FILENAME = "'"$STRACE_FILENAME"'"
  VERBOSE = "'"$VERBOSE"'"
  SUMMARY = "'"$SUMMARY"'"
  TIME_DELTA_THRESHOLD = "'"$TIME_DELTA_THRESHOLD"'"
  TIME_DELTA_THRESHOLD = TIME_DELTA_THRESHOLD + 0
  OUTPUT_FORMAT = "'"$OUTPUT_FORMAT"'"
  OUTPUT_SEPARATOR = " "
  if ( OUTPUT_FORMAT == "csv" ) { OUTPUT_SEPARATOR = "," }
  FIRST_STRACE_TS = "'"$FIRST_STRACE_TS"'"
  LAST_STRACE_TS = "'"$LAST_STRACE_TS"'"

  syscall_count = 0
  syscall_timedelta = 0
  previous_syscall_time = 0

  syscall_list = ""
  syscall_array_count = 0
}
{
  potential_syscall = ""
  line = $0
  split($2,a,".")
  ts = strftime("%Y-%m-%d-%H.%M.%S", a[1])"."a[2]
  
  if (match($3,/\(/))
  {
    split($3,c,"(")
    potential_syscall = c[1]
  }
  else
  {
    if (match($3,/<.../))
    {
      potential_syscall = $4
    }
  }

  # Match on syscall starting with alphabetic char
  if(match(potential_syscall,/^[A-Za-z]+$/))
  {
    syscall = potential_syscall
    syscall_count++
    current_syscall_time = $2

    # start building array of syscall op, count, and time spent
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

    # Using verbose just spits out everything...duh
    if ( VERBOSE == "Y" )
    {
      # pretty color for syscall_timedelta if you need that to stand out
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
      # pretty color for syscall_timedelta, but a shorter list than using verbose
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
  if (SUMMARY == "Y")
  {
    printf("\n")
    if ( OUTPUT_FORMAT == "csv" )
    {
      # Summary in CSV (less info, but easier to copy/paste into s/s of course)
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
      # Summary in txt format
      split(FIRST_STRACE_TS,a,".")
      strace_start = strftime("%Y-%m-%d-%H.%M.%S", a[1])"."a[2]
      split(LAST_STRACE_TS,a,".")
      strace_end = strftime("%Y-%m-%d-%H.%M.%S", a[1])"."a[2]
      strace_elapse = LAST_STRACE_TS - FIRST_STRACE_TS
      printf("Summary\n")
      printf("strace file:   %s\n", STRACE_FILENAME)
      printf("strace start:  %s\n", strace_start)
      printf("strace end:    %s\n", strace_end)
      printf("strace elapse: %-12.6f\n", strace_elapse)
      printf("\n")
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
  }
}'

exit 0
