#!/bin/sh
#set -x

# set some variables
. ./setVars.sh

abort()
{
    if [ "$?" = "0" ]
    then
        return
    else
      echo >&2 '
      ***************
      *** ABORTED ***
      ***************
      '
      echo "An error occurred on line $1. Exiting..." >&2
      exit 1
    fi
}

summary()
{
  echo_msg "Current Services in CF_SPACE"
  cf services
}

echo_msg()
{
  echo ""
  echo "************** ${1} **************"
}

create_single_service()
{
  line="$@"
  SI=`echo "$line" | cut -d " " -f 3`
  EXISTS=`cf services | grep ${SI} | wc -l | xargs`
  if [ $EXISTS -eq 0 ]
  then
    if [[ $line == *"p-config-server"*  &&  ! -z "$GITHUB_URI" ]]
    then
      #echo "This is config server"
      #Annoying hack because of quotes, single quotes etc ....
      cf create-service $line -c ''\{\"git\":\{\"uri\":\""${GITHUB_URI}"\",\"label\":\"master\"\}\}''
    else
      cf create-service $line
    fi
    scs_service_created=1
  else
    echo_msg "${SI} already exists"
  fi
}

create_all_services()
{
  scs_service_created=0

  file="./PCFServices.list"
  while IFS= read -r line 
  do
    create_single_service "$line" 
  done < "$file"
  echo_msg "Services created, bear in mind Spring Cloud Services need about a minute to fully initialise."

  if [ $scs_service_created -eq 1 ]
  then
    # Sleep for service registry
    max=18
  for ((i=1; i<=$max; ++i )) ; do
     echo "Pausing to allow Spring Cloud Services to Initialise.....$i/$max"
     sleep 5
    done
  fi
}

main()
{
# Work out the CF_TARGET
  CF_TARGET=`cf target | grep "API" | cut -d" " -f5| xargs`
  # Disable PWS because of SCS Tile
  PWS=`echo $CF_TARGET | grep "run.pivotal.io" | wc -l`
  if [ $PWS -ne 0 ]
  then
    echo_msg "This won't run on PWS, please use another environment"
    exit 1
  fi

  create_all_services
  summary

  #echo_msg "Services ready, now please configure the ConfigServer service before proceeding, use Apps Manager to point it to the right Github Repoi, e.g. https://github.com/pivotal-bank/cf-SpringBootTrader-config.git"
}

trap 'abort $LINENO' 0
SECONDS=0
SCRIPTNAME=`basename "$0"`

main

echo "Executed $SCRIPTNAME in $SECONDS seconds."
exit 0
