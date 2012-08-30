#!/bin/ksh
function usage
{
       echo "Usage: $(basename $0) <username> <password> <host> [sid] [port]"
       echo "  username        database username"
       echo "  username        database password"
       echo "  host            hostname or IP address"
       echo "  sid             optional database sid (default: orcl)"
       echo "  port            optional database port (default: 1521)"
       echo "  script          optional database script (defaultt: empty)"
       exit 2
}

[[ $# -lt 3 ]] && usage
[[ $# -gt 6 ]] && usage

UN=$1
PW=$2
HOST=$3
SID=orcl
PORT=1521

[[ $# -gt 3 ]] && SID=$4
[[ $# -gt 4 ]] && PORT=$5
[[ $# -gt 5 ]] && SCRIPT="@$6"


 sqlplus  "$UN/$PW@\
                  (DESCRIPTION=\
                     (ADDRESS_LIST=\
                        (ADDRESS=\
                           (PROTOCOL=TCP)\
                           (HOST=$HOST)\
                           (PORT=$PORT)))\
                     (CONNECT_DATA=\
                        (SERVER=DEDICATED)\
                        (SERVICE_NAME=$SID)))" $SCRIPT

