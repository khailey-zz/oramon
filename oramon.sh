#!/bin/bash 
#
# Copyright (c) 2011 by Delphix.
# All rights reserved.
#
# Ronald Rood 2013-01-30 support for MacosX
#

UN=delphix
PW=delphix
HOST=172.16.100.102
SID=tba1
PORT=1521
RUN_TIME=43200     # total run time, 12 hours default 43200
RUN_TIME=86400     # total run time, 24 hours default 86400
RUN_TIME=864000    # total run time, 10 days  default 864000
RUN_TIME=-1        #  run continuously

    DEBUG=${DEBUG:-0}            # 1 output debug, 2 include SQLplus output

function usage
{
       echo "Usage: $(basename $0) [username] [password] [host] [sid] <port=1521> <runtime=3600>"
       exit
}

[[ $# -lt 4 ]] && usage

[[ $# -gt 0 ]] && UN=$1
[[ $# -gt 1 ]] && PW=$2
[[ $# -gt 2 ]] && HOST=$3
[[ $# -gt 3 ]] && SID=$4
[[ $# -gt 4 ]] && PORT=${5:-1521}
[[ $# -gt 5 ]] && RUN_TIME=${6:-3600}


    TARGET=${HOST}:${SID}

function pipesetup {
    MACHINE=`uname -a | awk '{print $1}'`
    case $MACHINE  in
    Linux)
            MKNOD=/bin/mknod
            ;;
    AIX)
            MKNOD=/usr/sbin/mknod
            ;;
    SunOS)
            MKNOD=/etc/mknod
            ;;
    HP-UX)
            MKNOD=mknod
            ;;
    Darwin)
            MKNOD=""
            ;;
    *)
            MKNOD=mknod
            ;;
    esac
    SUF=.dat
    OUTPUT=${LOG}/${TARGET}_connect.log
    CLEANUP=${CLEAN}/${TARGET}_cleanup.sh
    SQLTESTOUT=${TMP}/${TARGET}_collect.out
    OPEN=${TMP}/${TARGET}_collect.open
    PIPE=${TMP}/${TARGET}_collect.pipe
    rm $OPEN $PIPE > /dev/null 2>&1
    touch  $OPEN

    if [ -z "${MKNOD}" ]
    then
      cmd="mkfifo ${PIPE}"
    else
      cmd="$MKNOD $PIPE p"
    fi

    eval $cmd
    tail -f $OPEN >> $PIPE &
    OPENID="$!"
  # run SQLPLUS silent unless DEBUG is 2 or higher
       SILENT=""
    if [[ $DEBUG -lt 2 ]]; then
       SILENT="-s"
    fi
  # SID
    CONNECT="$UN/$PW@(DESCRIPTION= (ADDRESS_LIST= (ADDRESS= (PROTOCOL=TCP) (HOST=$HOST) (PORT=$PORT))) (CONNECT_DATA= (SERVER=DEDICATED) (SID=$SID)))"
  # SERVICE_ID
  # CONNECT="$UN/$PW@(DESCRIPTION= (ADDRESS_LIST= (ADDRESS= (PROTOCOL=TCP) (HOST=$HOST) (PORT=$PORT))) (CONNECT_DATA= (SERVER=DEDICATED) (SERVICE_NAME=$SID)))"
  # cmd="sqlplus $SILENT \"$CONNECT\" < $PIPE &"
    cmd="sqlplus $SILENT \"$CONNECT\" < $PIPE > /dev/null &"
    echo "$cmd" >> ${OUTPUT}
    eval $cmd
    SQLID="$!"
    echo "kill -9 $SQLID" >> $CLEANUP
    echo "kill -9 $OPENID" >> $CLEANUP
       
}


    # SLEEP is the sleep time between collection loops
    # loop only collects every 60 seconds
    # concerned that simpy sleeping 60 would introduce drift
    # thus sleep X seconds ( X < 60) , check for minute change
    # if minute change then collect
    # the smaller X is the closer to the minute collections will take place
    # but the smaller X is the more CPU the script uses
    # sleep of 0.1 was about 1.5% of a core of cpu
    # sleeping 1 was less than 1%
    # sleeping 5 was around 0.1% except during the collect
    # sleep has to be less than .5 for every second for manual ASH collection to work
    # currenlty script collects ASH from v$active_session_history instead of manual

    SLEEP=5


    #MON_HOME=${MON_HOME:-"/var/delphix/server/log/MONITOR"} 
    MON_HOME=${MON_HOME:-"/tmp/MONITOR"} 
    LOG=${LOG:-"$MON_HOME/log"}
    TMP=${TMP:-"/tmp/MONITOR/tmp"}
    CLEAN=${CLEAN:-"$MON_HOME/clean"}
    #[[ ! -d "$MON_HOME" ]] && mkdir $MON_HOME >/dev/null 2>&1
    #[[ ! -d "$LOG" ]] && mkdir $LOG >/dev/null 2>&1
    #[[ ! -d "$TMP" ]] && mkdir $TMP >/dev/null 2>&1
    #[[ ! -d "$CLEAN" ]] && mkdir $CLEAN >/dev/null 2>&1
    [[ ! -d "$MON_HOME" ]] && mkdir $MON_HOME 
    [[ ! -d "$LOG" ]] && mkdir $LOG 
    [[ ! -d "$TMP" ]] && mkdir $TMP 
    [[ ! -d "$CLEAN" ]] && mkdir $CLEAN 
    CURR_DATE=$(date "+%u_%H" ) 
    OUTPUT=${LOG}/${TARGET}_vdbmon.log
    echo "" > $OUTPUT
    SQLTESTOUT=${TMP}/vdbmon_${TARGET}_collect.tmp
    rm $SQLTESTOUT > /dev/null 2>&1
    EXIT=${CLEAN}/${TARGET}_collect.end
    CLEANUP=${CLEAN}/${TARGET}_cleanup.sh
    echo "" > $CLEANUP

    pipesetup

    SUF=.dat
    RUN_TIME=-1        #  run continuously

    trap "echo $CLEANUP;sh $CLEANUP >> $OUTPUT 2>&1 ;exit" 0 3 5 9 15
    echo "echo 'cleanup: exiting ...' " >> $CLEANUP

    # list of data to collect, each represents a different SQL query

    type=${type:-"none"}
    if [[ $type == "ash" ]]; then
      COLLECT_LIST=""     
      FAST_SAMPLE="ash"  
      #SLEEP=.5
      SLEEP=5
      ASH_SLEEP=5
    else
      COLLECT_LIST="avgreadsz avgreadms avgwritesz avgwritems throughput aas wts systat ash "     
      COLLECT_LIST=""     
      FAST_SAMPLE="iolatency"  
      ASH_SLEEP=5
      SLEEP=5
    fi

  # exit if removed
    touch $EXIT

  # printout setup
    for i in 1; do
    echo
    echo "RUN_TIME=$RUN_TIME" 
    echo "COLLECT_LIST=$COLLECT_LIST" 
    echo "FAST_SAMPLE=$FAST_SAMPLE"
    echo "TARGET=$TARGET" 
    echo "DEBUG=$DEBUG" 
    echo
    done 
    #>>$OUTPUT
    #cat $OUTPUT


#   /******************************/
#   *                             *
#   * BEGIN FUNCTION DEFINITIONS  *
#   *                             *
#   /******************************/
#

function logoutput
{
    echo $1
    echo "$1" >> $OUTPUT
}

function debug 
{
if [[ $DEBUG -ge 1 ]]; then
   #   echo "   ** beg debug **"
   var=$*
   nvar=$#
   if test x"$1" = xvar; then
     shift
     let nvar=nvar-1
     while (( $nvar > 0 ))
     do
        eval val='$'{$1} 1>&2
        echo "       :$1:$val:"  1>&2
        shift
        let nvar=nvar-1
     done
   else
     while (( $nvar > 0 ))
     do
        echo "       :$1:"  1>&2
        shift
        let nvar=nvar-1
     done
   fi
   #   echo "   ** end debug **"
fi
}                         

function check_exit 
{
        if [[  ! -f $EXIT ]]; then
           logoutput "exit file removed, exiting at $(date)" 
           #sqlexit
           sleep 1
           cat $CLEANUP >> $OUTPUT
           sh $CLEANUP  > /dev/null 2>&1
           logoutput "check_exit: exiting ..."
           exit
        fi
}

function sqloutput  
{
    cat << EOF >>$PIPE &
       set pagesize 0
       set feedback off
       spool $SQLTESTOUT
       select 1 from dual;
       spool off
EOF
}

function testconnect 
{
     CONNECTED=0
     rm $SQLTESTOUT 2>/dev/null
     if [[ $CONNECTED -eq 0 ]]; then
        limit=60
     else
        limit=60
     fi
     sqloutput
     sleep 1
     count=0
     #if [[ -f $SQLTESTOUT ]]; then
       grep '^ *1'  $SQLTESTOUT >/dev/null  2>&1
       found=$?
     #fi
     debug "before while"
     while [[ $count -lt $limit && $found -gt 0 ]]; do
        debug "found $found"
        debug "loop#   $count limit $limit "

        echo "Trying to connect" >> $OUTPUT
        #sleep $SLEEP
        sleep .5
        count=$(expr $count + 1)
        check_exit

        if [[ -f $SQLTESTOUT ]]; then
          grep '^ *1'  $SQLTESTOUT >/dev/null  2>&1
          found=$?
        else 
          debug  "sql output file: $SQLTESTOUT, not found"
        fi
     done
     debug "after while"
     #echo "count# $count limit $limit " 
     if [[ $count -ge $limit ]]; then
       echo "output from sqlplus: " >> $OUTPUT
       if [[ -f $SQLTESTOUT ]]; then
          cat $SQLTESTOUT
          cat $SQLTESTOUT >>$OUTPUT
       else
          logoutput "sqlplus output file: $SQLTESTOUT, not found" 
          logoutput "check user name and password for sqlplus"
          logoutput "try 'export DEBUG=1' and rerun"
       fi
       logoutput "vdbmon.sh : timeout waiting connection to sqlplus" 
       eval $CMD
       cat $CLEANUP >>$OUTPUT
       sh $CLEANUP
       #sqlexit
       logoutput "test_connect: exiting ..."
       exit
       CONNECTED=0
     else
       CONNECTED=1
       touch $OUTPUT
     fi
}

function sqlexit  
{
   for i in 1; do
      echo "exit"
      echo "vdbmon:exit" >> $OUTPUT
      echo ""
      echo -e "\004"
   done >>$PIPE
}


function iolatency  
{
#select  nullif((round(decode(seqct,0,0,seqtm/seqct),2)),0  ) seq_ms, 
     cat << EOF
     spool  ${TMP}/vdbmon_${TARGET}_iolatency.tmp

select  
        round(seqtm/nullif(seqct,0),2) seq_ms,
        round(seqct/nullif(delta,0),2) seq_ct,
        round(lfpwtm/nullif(lfpwct,0),2) lfpw_ms,
        round(lfpwct/nullif(delta,0),2) lfpw_ct,
        round(scattm/nullif(scatct,0),2) seq_ms,
        round(scatct/nullif(delta,0),0) scat_ct,
        round(dprtm/nullif(dprct,0),2) dpr_ms,
        round(dprct/nullif(delta,0),2) dpr_ct,
        round(dprttm/nullif(dprtct,0),2) dprt_ms,
        round(dprtct/nullif(delta,0),2) dprt_ct,
        round(dpwttm/nullif(dpwtct,0),2) dpwt_ms,
        round(dpwtct/nullif(delta,0),2) dpwt_ct,
        'XXX',
        prevsec,delta
        , prevseq_ct,prevseq_tm  
        , prevscat_ct, prevscat_tm 
        , prevlfpw_tm,prevlfpw_ct
        , prevdpr_ct, prevdpr_tm
        , prevdprt_ct, prevdprt_tm
        , prevdpw_ct, prevdpw_tm
        , prevdpwt_ct, prevdpwt_tm
        --seqtm seq_tm,
        --scattm scat_tm,
from
(select 
       sum(decode(event,'db file sequential read', round(time_waited_micro/1000) -  &prevseq_tm_var,0)) seqtm,
       sum(decode(event,'db file scattered read',  round(time_waited_micro/1000) - &prevscat_tm_var,0)) scattm,
       sum(decode(event,'log file parallel write',  round(time_waited_micro/1000) - &prevlfpw_tm_var,0)) lfpwtm,
       sum(decode(event,'db file sequential read', round(time_waited_micro/1000) ,0)) prevseq_tm,
       sum(decode(event,'db file scattered read',  round(time_waited_micro/1000) ,0)) prevscat_tm,
       sum(decode(event,'log file parallel write',  round(time_waited_micro/1000) ,0)) prevlfpw_tm,
       sum(decode(event,'db file sequential read', total_waits - &prevseq_ct_var,0)) seqct,
       sum(decode(event,'db file scattered read',  total_waits - &prevscat_ct_var,0)) scatct,
       sum(decode(event,'log file parallel write',  total_waits - &prevlfpw_ct_var,0)) lfpwct,
       sum(decode(event,'db file sequential read', total_waits ,0)) prevseq_ct,
       sum(decode(event,'db file scattered read',  total_waits ,0)) prevscat_ct,
       sum(decode(event,'log file parallel write',  total_waits ,0)) prevlfpw_ct,
       sum(decode(event,'direct path read',  round(time_waited_micro/1000) - &prevdpr_tm_var,0)) dprtm,
       sum(decode(event,'direct path read',  round(time_waited_micro/1000) ,0)) prevdpr_tm,
       sum(decode(event,'direct path read',  total_waits - &prevdpr_ct_var,0)) dprct,
       sum(decode(event,'direct path read',  total_waits ,0)) prevdpr_ct,
       sum(decode(event,'direct path write',  round(time_waited_micro/1000) - &prevdpw_tm_var,0)) dpwtm,
       sum(decode(event,'direct path write',  round(time_waited_micro/1000) ,0)) prevdpw_tm,
       sum(decode(event,'direct path write',  total_waits - &prevdpw_ct_var,0)) dpwct,
       sum(decode(event,'direct path write',  total_waits ,0)) prevdpw_ct,
       sum(decode(event,'direct path write temp',  round(time_waited_micro/1000) - &prevdpwt_tm_var,0)) dpwttm,
       sum(decode(event,'direct path write temp',  round(time_waited_micro/1000) ,0)) prevdpwt_tm,
       sum(decode(event,'direct path write temp',  total_waits - &prevdpwt_ct_var,0)) dpwtct,
       sum(decode(event,'direct path write temp',  total_waits ,0)) prevdpwt_ct,
       sum(decode(event,'direct path read temp',  round(time_waited_micro/1000) - &prevdprt_tm_var,0)) dprttm,
       sum(decode(event,'direct path read temp',  round(time_waited_micro/1000) ,0)) prevdprt_tm,
       sum(decode(event,'direct path read temp',  total_waits - &prevdprt_ct_var,0)) dprtct,
       sum(decode(event,'direct path read temp',  total_waits ,0)) prevdprt_ct,
       to_char(sysdate,'SSSSS')-&prevsec_var delta,
       to_char(sysdate,'SSSSS') prevsec
from 
     v\$system_event
where
     event in ('db file sequential read',
               'db file scattered read',
               'direct path read temp',
               'direct path write temp',
               'direct path read',
               'direct path write',
               'log file parallel write')
)
;

     spool off
EOF
}

# wait times - count, total time
function wts  
{
     cat << EOF
     spool  ${TMP}/vdbmon_${TARGET}_wts.tmp
     Select 'waitstat'       ||','|| 
            total_waits      ||','|| 
            time_waited_micro||','|| 
            replace(event,' ','_')
     from v\$system_event
      where event in  (
          'db file sequential read',     -- single
          'db file parallel read',       -- multi 2-128 ?
          'db file scattered read',      -- multi 2-128 blocks ?
          'direct path read',            -- multi 1-128 blocks (8K-1M)
          'direct path write',           
          'direct path write temp',      
          'direct path read temp',       -- multi 1-128 ?? smaller
          'control file sequential read',-- multi 1-64 (blocks?)
          'log file sequential read',    -- multi 512 bytes - 4M
          'log file sync',               -- write
          'log file parallel write'      -- write
           ) ;
     spool off
EOF
}

# reads, blocks, time
function systat  
{
     cat << EOF
     spool  ${TMP}/vdbmon_${TARGET}_systat.tmp
     Select 'systat'  ||','|| 
            replace(name,' ','_') ||','|| 
             value   ||','|| 
	     stat_id    
       from v\$sysstat fs 
       where stat_id in (
          789768877,  -- physical read IO requests            
          3343375620, -- physical read total IO requests
          523531786,  -- physical read bytes                     
          2572010804, -- physical read total bytes
          2007302071, -- physical read total multi block requests
          2263124246, -- physical reads
          4171507801, -- physical reads cache
          2589616721, -- physical reads direct
          789768877 , -- physical read IO requests
          2663793346, -- physical reads direct temporary tablespace
          2564935310  -- physical reads direct (lob)
       );
     spool off
EOF
}

function aas  
{
     cat << EOF
     spool  ${TMP}/vdbmon_${TARGET}_aas.tmp
with AASSTAT as (
           select
                 decode(n.wait_class,'User I/O','User I/O',
                                     'Commit','Commit',
                                     'Wait')                               CLASS,
                 sum(round(m.time_waited/m.INTSIZE_CSEC,3))                AAS
           from  v\$waitclassmetric  m,
                 v\$system_wait_class n
           where m.wait_class_id=n.wait_class_id
             and n.wait_class != 'Idle'
           group by  decode(n.wait_class,'User I/O','User I/O', 'Commit','Commit', 'Wait')
          union
             select 'CPU_ORA_CONSUMED'                                     CLASS,
                    round(value/100,3)                                     AAS
             from v\$sysmetric
             where metric_name='CPU Usage Per Sec'
               and group_id=2
          union
            select 'CPU_OS'                                                CLASS ,
                    round((prcnt.busy*parameter.cpu_count)/100,3)          AAS
            from
              ( select value busy from v\$sysmetric where metric_name='Host CPU Utilization (%)' and group_id=2 ) prcnt,
              ( select value cpu_count from v\$parameter where name='cpu_count' )  parameter
          union
             select
               'CPU_ORA_DEMAND'                                            CLASS,
               nvl(round( sum(decode(session_state,'ON CPU',1,0))/60,2),0) AAS
             from v\$active_session_history ash
             where SAMPLE_TIME > sysdate - (60/(24*60*60))
)
select
       decode(sign(CPU_OS-CPU_ORA_CONSUMED), -1, 0, (CPU_OS - CPU_ORA_CONSUMED )) ||','||
       CPU_ORA_CONSUMED ||','||
       decode(sign(CPU_ORA_DEMAND-CPU_ORA_CONSUMED), -1, 0, (CPU_ORA_DEMAND - CPU_ORA_CONSUMED )) ||','||
       COMMIT||','||
       READIO||','||
       WAIT
from (
select
       sum(decode(CLASS,'CPU_ORA_CONSUMED',AAS,0)) CPU_ORA_CONSUMED,
       sum(decode(CLASS,'CPU_ORA_DEMAND'  ,AAS,0)) CPU_ORA_DEMAND,
       sum(decode(CLASS,'CPU_OS'          ,AAS,0)) CPU_OS,
       sum(decode(CLASS,'Commit'          ,AAS,0)) COMMIT,
       sum(decode(CLASS,'User I/O'        ,AAS,0)) READIO,
       sum(decode(CLASS,'Wait'            ,AAS,0)) WAIT
from AASSTAT);
     spool off
EOF
}


#  
function throughput  
{
     #  read_kb/s, write_kb/s, read_kb_total/s, write_kb_total/s
     cat << EOF
     spool  ${TMP}/vdbmon_${TARGET}_throughput.tmp
     select   
         round((sum(decode(metric_name, 'Physical Read Bytes Per Sec' , value,0)))/1024,0) ||','||
         round((sum(decode(metric_name, 'Physical Write Bytes Per Sec' , value,0 )))/1024,0)  ||','||
         round((sum(decode(metric_name, 'Physical Read Total Bytes Per Sec' , value,0)))/1024,0) ||','||
         round((sum(decode(metric_name, 'Physical Write Total Bytes Per Sec' , value,0 )))/1024,0) ||','||
         round((sum(decode(metric_name, 'Physical Write Total IO Requests Per Sec', value,0 ))),1) ||','||
         round((sum(decode(metric_name, 'Physical Read Total IO Requests Per Sec' , value,0 ))),1)
     from     v\$sysmetric
     where    metric_name in (
                    'Physical Read Total Bytes Per Sec' ,
                    'Physical Read Bytes Per Sec' , 
                    'Physical Write Bytes Per Sec' ,
                    'Physical Write Total Bytes Per Sec' ,
                    'Physical Write Total IO Requests Per Sec',
                    'Physical Read Total IO Requests Per Sec'
                    )
       and group_id=2;
     spool off
EOF
}


function avgwritems   
{
     cat << EOF
     spool  ${TMP}/vdbmon_${TARGET}_avgwritems.tmp
     select 
       m.wait_count  ||','||
       10*m.time_waited ||','||
       nvl(round(10*m.time_waited/nullif(m.wait_count,0),3) ,0)
     from v\$eventmetric m,
          v\$event_name n
     where m.event_id=n.event_id
       and n.name in ( 'log file parallel write');
     spool off
EOF
}


#  
function avgwritesz  
{
     # redo_KB/s, redo_writes/s , avg_redo_KB 
     cat << EOF
     spool  ${TMP}/vdbmon_${TARGET}_avgwritesz.tmp
     select
         round(sum(decode(metric_name,'Redo Generated Per Sec',value,0))/1024) ||','||
         round(sum(decode(metric_name,'Redo Writes Per Sec',value,0)),2) ||','||
         nvl(round(sum(decode(metric_name,'Redo Generated Per Sec',value,0)) /
         nullif(sum(decode(metric_name,'Redo Writes Per Sec',value,0)),0)/1024,0),0)
     from     v\$sysmetric
     where    metric_name in  (
                           'Redo Writes Per Sec',
                           'Redo Generated Per Sec'
         )
      and     group_id=2;
     spool off
EOF
}

function avgreadsz  
{
     #  read_KB/s, reads/s, avg_read_KB
     cat << EOF
     spool  ${TMP}/vdbmon_${TARGET}_avgreadsz.tmp
        select 
          round(sum(decode(metric_name,'Physical Read Total Bytes Per Sec',value,0))/1024,2)  ||','||
          round(sum(decode(metric_name,'Physical Read Total IO Requests Per Sec',value,0)),2)  ||','||           
          round((nvl(sum(decode(metric_name,'Physical Read Total Bytes Per Sec',value))/
            nullif(sum(decode(metric_name,'Physical Read Total IO Requests Per Sec',value,0)),0),0))/1024 ,2)||','||
          round(sum(decode(metric_name,'Physical Read Bytes Per Sec',value,0))/1024,2)  ||','||
          round(sum(decode(metric_name,'Physical Read IO Requests Per Sec',value,0)),2)  ||','||           
          round((nvl(sum(decode(metric_name,'Physical Read Bytes Per Sec',value))/
            nullif(sum(decode(metric_name,'Physical Read IO Requests Per Sec',value,0)),0),0))/1024 ,2)
        from v\$sysmetric 
        where group_id = 2    -- 60 deltas, not the 15 second
        ;
     spool off
EOF
}
#           nvl(sum(decode(metric_name,'Physical Reads Per Sec',value))/

function avgreadms  
{
     cat << EOF
     spool  ${TMP}/vdbmon_${TARGET}_avgreadms.tmp
            select 
                   wait_count    ||','||
                   10*time_waited  ||','||
                   round(10*time_waited/nullif(wait_count,0),2) avg_read_ms
            from   v\$waitclassmetric  m
                   where wait_class_id= 1740759767 --  User I/O
            ;
     spool off
EOF
}

function ash
{
     cat << EOF
     spool  ${TMP}/vdbmon_${TARGET}_ash.tmp
     Select
       (cast(ash.SAMPLE_TIME as date)-to_date('01-JAN-1970','DD-MON-YYYY'))*(86400) ||','||
       ash.sample_id               ||','||
       ash.session_id              ||'_'|| session_serial# ||','||
       decode(ash.session_type,'BACKGROUND',substr(program,-5,4),u.username)  ||','||
       ash.sql_id                  ||','||
       ash.sql_plan_hash_value     ||','||
       ash.session_type            ||','||
       decode(session_state,'ON CPU','CPU',replace(ash.event,' ','_') ) ||','||
       decode(session_state,'ON CPU','CPU',replace(ash.wait_class,' ','_') )
     from v\$active_session_history ash, 
          all_users u
     where
        sample_time > sysdate - $ASH_SLEEP/(24*60*60) and
        u.user_id=ash.user_id
     order by ash.sample_id
     ;
     spool off
EOF
}


function ash_manual
{
     cat << EOF
     spool  ${TMP}/vdbmon_${TARGET}_ash.tmp
      select
      (cast(sysdate as date)-to_date('01-JAN-1970','DD-MON-YYYY'))*(86400) ||','||
         1  ||','||
         concat(s.sid,concat('_',s.serial#))  ||','||
         decode(type,'BACKGROUND',substr(program,-5,4),u.username)  ||','||
         s.sql_id ||','||
      --  sql_plan_hash_value is not in v$session but in x$ksusea KSUSESPH
         s.SQL_CHILD_NUMBER ||','||
         s.type ||','||
       decode(s.WAIT_TIME,0,replace(s.event,' ','_') , 'ON CPU') ||','||
       decode(s.WAIT_TIME,0,replace(s.wait_class,' ','_') , 'CPU' )
      from
             v\$session s,
             all_users u
      where
        u.user_id=s.user# and
        s.sid != ( select distinct sid from v\$mystat  where rownum < 2 ) and
            (  ( s.wait_time != 0  and  /* on CPU  */ s.status='ACTIVE'  /* ACTIVE */)
                 or
               s.wait_class  != 'Idle'
            )
   union all
      select
        (cast(sysdate as date)-to_date('01-JAN-1970','DD-MON-YYYY'))*(86400) ||','||
         null  ||','||
         0  ||','||
         null  ||','||
         null  ||','||
         null  ||','||
         null  ||','||
         null  ||','||
         null
      from dual
      where not exists ( select  1 from
             v\$session s
      where
        s.sid != ( select distinct sid from v\$mystat  where rownum < 2 ) and
            (  ( s.wait_time != 0  and  /* on CPU  */ s.status='ACTIVE'  /* ACTIVE */)
                 or
               s.wait_class  != 'Idle'
            )
       )
     ;
     spool off
EOF
}

function last_update
{
     #spool  $LAST_UPDATE
     cat << EOF
     spool  ${TMP}/vdbmon_${TARGET}_last_update.tmp
      select
      (cast(sysdate as date)-to_date('01-JAN-1970','DD-MON-YYYY'))*(86400) ||','||
      to_char(sysdate,'YYYY-MON-DD HH24:MI:SS')
      from
       dual
     ;
     spool off
EOF
}
function ash_new
{
     cat << EOF
     spool  ${TMP}/vdbmon_${TARGET}_ash.tmp
      select
      (cast(sysdate as date)-to_date('01-JAN-1970','DD-MON-YYYY'))*(86400) ||','||
         SAMPLE_ID  ||','||
         concat(s.session_id,concat('_',s.session_serial#))  ||','||
         decode(session_type,'BACKGROUND',substr(program,-5,4),u.username)  ||','||
         s.sql_id ||','||
      --  sql_plan_hash_value is not in v$session but in x$ksusea KSUSESPH
         s.SQL_CHILD_NUMBER ||','||
         s.session_type ||','||
         decode(s.SESSION_STATE,'WAITING',replace(s.event,' ','_') , 'ON CPU') ||','||
         decode(s.SESSION_STATE,'WAITING',replace(s.wait_class,' ','_') , 'CPU' )
      from
             v$active_session_history s,
             all_users u
     ;
     spool off
EOF
}



function setup_sql 
{
  cat << EOF
  set echo on
  set pause off
  set linesize 2500
  set verify off
  set feedback off
  set heading off
  set pagesize 0
  set trims on
  set trim on
  column start_day    new_value start_day 
  select  to_char(sysdate,'J')     start_day  from dual;
  column pt           new_value pt
  column seq          new_value seq
  column elapsed      new_value elapsed     
  column timer        new_value timer       
  column event for a25


        column seq_ms for 9999.99
        column seq_ct for 9999.99
        column lfpw_ms for 9999.99
        column lfpw_ct for 9999.99
        column seq_ms for 9999.99
        column scat_ct for 9999.99
        column dpr_ms for 9999.99
        column dpr_ct for 9999.99
        column dprt_ms for 9999.99
        column dprt_ct for 9999.99

   column prevdprt_ct new_value prevdprt_ct_var
   column prevdprt_tm new_value prevdprt_tm_var
   column prevdpwt_ct new_value prevdpwt_ct_var
   column prevdpwt_tm new_value prevdpwt_tm_var
   column prevdpr_ct new_value prevdpr_ct_var
   column prevdpr_tm new_value prevdpr_tm_var
   column prevdpw_ct new_value prevdpw_ct_var
   column prevdpw_tm new_value prevdpw_tm_var

   column prevseq_ct new_value prevseq_ct_var
   column prevseq_tm new_value prevseq_tm_var

   column prevscat_ct new_value prevscat_ct_var
   column prevscat_tm new_value prevscat_tm_var

   column prevlfpw_ct new_value prevlfpw_ct_var
   column prevlfpw_tm new_value prevlfpw_tm_var

   column prevsec new_value prevsec_var

   select 0 prevsec from dual;
   select 0 prevseq_tm from dual;
   select 0 prevseq_ct from dual;
   select 0 prevscat_ct from dual;
   select 0 prevscat_tm from dual;
   select 0 prevlfpw_ct from dual;
   select 0 prevlfpw_tm from dual;

   select 0 prevdprt_ct from dual;
   select 0 prevdprt_tm from dual;
   select 0 prevdpwt_ct from dual;
   select 0 prevdpwt_tm from dual;
   select 0 prevdpr_ct from dual;
   select 0 prevdpr_tm from dual;
   select 0 prevdpw_ct from dual;
   select 0 prevdpw_tm from dual;

  set echo off
EOF
}

#  alter session set sql_trace=false;
#  REM drop sequence orastat;
#  REM create sequence orastat;


#  END FUNCTION DEFINITIONS  

#  BEGIN MAIN LOOP          

  CONNECTED=0
  testconnect

  logoutput "Connected, starting collect at $(date)" 
  logoutput "starting stats collecting " 
   #
   # collect stats once a minute
   # every second see if the minute had changed
   # every second check EXIT file exists
   # if EXIT file has been deleted, then exit
   # 
   # change the directory day of the week 1-7
   # day of the week 1-7
   # 
     # variable to track how long collection has run in case script should exit after X amount
     SLEPTED=0
     debug var SLEPTED SAMPLE_RATE

     last_sec=0  
     last_min=0  
     LAST_DATE=$(date "+%u")  
     midnight=1
 
# BEGIN COLLECT LOOP
    if [[ $CONNECTED -eq 1 ]]; then
     check_exit
     setup_sql >>$PIPE
     while [[  ( $SLEPTED -lt $RUN_TIME ||  $RUN_TIME -eq -1 )  && ( -f $EXIT ) ]]; do
      # date = 1-7, day of the week
        CURR_DATE=$(date "+%u")  
        mkdir ${MON_HOME}/${CURR_DATE} >/dev/null 2>&1

        # clean up local, currently done by perfmon.sh
        if [ $LAST_DATE -ne $CURR_DATE ]; then
         #  echo $CURR_DATE >$MON_HOME/current_data.out
         #  mkdir ${MON_HOME}/${CURR_DATE} >/dev/null 2>&1
         #  rm ${MON_HOME}/${CURR_DATE}/*.dat  >/dev/null 2>&1
         #  LAST_DATE=$CURR_DATE
            midnight=1;
        fi

        curr_sec=$(date "+%H%M%S" | sed -e 's/^0*//' )
        curr_min=$(date "+%H%M" | sed -e 's/^0*//' )  
        # force to 0 incase they are empty after above sed
        curr_sec=$(expr $curr_sec + 0);
        curr_min=$(expr $curr_min + 0);
        
      # if [[ $curr_min -gt  $last_min ||  $curr_min -eq 0 ]]; then
        if [[ $curr_min -gt  $last_min ||  $midnight -eq 1 ]]; then
            #echo "     single block            logfile write         multi block          direct read         direct read temp ";
            #echo "        ms      IOP/s         ms      IOP/s        ms       IOP/s        ms       IOP/s        ms       IOP/s";
            echo "   single block       logfile write       multi block      direct read   direct read temp    direct write temp"
            echo "   ms      IOP/s        ms    IOP/s       ms    IOP/s       ms    IOP/s       ms    IOP/s         ms     IOP/s"
   #                   10.96          2       1.44          3      24.93          0
          debug "COLLECTION: last_min $last_min curr_min $curr_min "
            last_min=$curr_min
            for i in $COLLECT_LIST; do
               ${i} >>$PIPE
            done
            last_update >> $PIPE
            testconnect
            for i in  $COLLECT_LIST; do
              # prepend each line with the current time hour concat minute ie 0-2359
              cat ${TMP}/vdbmon_${TARGET}_${i}.tmp  | sed -e "s/^/$last_min,/" >>${MON_HOME}/${CURR_DATE}/${TARGET}:${i}$SUF
            done
            #cat ${TMP}/vdbmon_${TARGET}_last_update.tmp  | sed -e "s/^/$last_min,/" >> ${LAST_UPDATE}
            check_exit
        fi
   
       # this section is only used if collecting ASH
       if [ $curr_sec -gt  $last_sec -o $midnight -eq 1 ]; then
            debug "FAST: last_sec $last_sec curr_sec $curr_sec "
            let last_sec=$curr_sec+$ASH_SLEEP
            for i in $FAST_SAMPLE; do
               ${i} >> $PIPE
            done
            testconnect
            for i in  $FAST_SAMPLE; do
              # prepend each line with the current time 0-235959
              cat ${TMP}/vdbmon_${TARGET}_${i}.tmp  | sed -e 's/XXX.*//' 
              cat ${TMP}/vdbmon_${TARGET}_${i}.tmp  | sed -e "s/^/$last_sec,/" >>${MON_HOME}/${CURR_DATE}/${TARGET}:${i}$SUF
            done
       fi

       midnight=0;

       sleep $SLEEP 
       debug "sleeping 1"
       #debug "sleeping $SAMPLE_RATE"
     done
   fi
 # END COLLECT LOOP

 # CLEANUP
   logoutput "run time expired, exiting at " 
   logdate=`date +'%Y-%m-%d %H:%M:%S'`
   logoutput $logdate  
   # sqlexit
   logoutput "catting cleaning up: $CLEANUP"
   cat $CLEANUP
   logoutput "running cleaning up: $CLEANUP"
   logoutput "exiting ..."
   sh $CLEANUP 
   sleep 1
   logoutput "exited "

