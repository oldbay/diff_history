#! /bin/bash

# comstring for daemon
# $1 - file name
# $2 - directory for pid file
# $3 - state name (start/stop/status)
# $4 - utilite for demanization (start state only)
# $5 - step daemon iteration  (start state only)

log_creator() {
    echo "CMD: Daemon FILE: $FILE MSG: $MSG" 2>&1 |logger
}

pid_clean() {
if [ -f ${D_PID_FILE} ];then
    rm $D_PID_FILE
    find $D_PID_DIR -empty -type d -delete
fi
}

pid_init() {
    if [ -f ${D_PID_FILE} ];then
        pid_test=`cat $D_PID_FILE`
        ps $pid_test|grep $0
        if [ $? -eq 0 ];then
            exit 0
        else
            pid_clean
        fi
    fi
    mkdir -p $(dirname $D_PID_FILE)
    echo $$ >$D_PID_FILE
}

daemon_start() {
    pid_init
    MSG="DAEMON_OK: Deamon start"
    log_creator
    #deamon loop
    while true
    do
        $D_UTIL -f $D_FILENAME
        sleep $D_STEP
        if [ ! -f $D_PID_FILE ];then
            break
        else
            pid_test=`cat $D_PID_FILE`
            (ps $pid_test|grep $$)||break
        fi
    done
    MSG="DAEMON_OK: Deamon stop"
    log_creator
    pid_clean
}

daemon_stop() {
    if [ -f ${D_PID_FILE} ];then
        pid_test=`cat $D_PID_FILE`
        ps $pid_test|grep $0 >/dev/null 2>&1
        if [ $? -eq 0 ];then
            pid_clean 
            echo "Send signal to daemon for stop">/dev/stdout
            exit 0
        else
            pid_clean
        fi
    fi
    echo "Daemon not start">/dev/stderr
    exit 1
}

daemon_status() {
    if [ -f ${D_PID_FILE} ];then
        pid_test=`cat $D_PID_FILE`
        ps $pid_test|grep $0 >/dev/null 2>&1
        if [ $? -eq 0 ];then
            echo "Demon work in PID $pid_test">/dev/stdout
            exit 0
        else
            pid_clean
        fi
    fi
    echo "Daemon not start">/dev/stdout
    exit 0
}

#comstring
if [ -n "$1" ];then
    D_FILENAME=$1
else
    MSG="DAEMON_ERROR: daemon filename not found"
    log_creator
    echo $MSG >/dev/stderr
    exit 1
fi

if [ -n "$2" ];then
    D_PID_DIR=$2
    D_FILE_DIR=$(dirname $(realpath $D_FILENAME))
    D_PID_FILE=${D_PID_DIR}${D_FILE_DIR}/diff_daemon.pid
else
    MSG="DAEMON_ERROR: daemon pid dir not found"
    log_creator
    echo $MSG >/dev/stderr
    exit 1
fi

if [ -n "$3" ];then
    #select state
    case "${3}" in
        start)
            if [ -n "$4" ];then
                D_UTIL=$(realpath $4)
            else
                MSG="DAEMON_ERROR: daemons utilite not found"
                log_creator
                echo $MSG >/dev/stderr
                exit 1
            fi
            if [ -n "$5" ];then
                let D_STEP=$5
            else
                MSG="DAEMON_ERROR: daemons step not found"
                log_creator
                echo $MSG >/dev/stderr
                exit 1
            fi
            daemon_start
            ;;
        stop)
            daemon_stop
            ;;
        status)
            daemon_status
            ;;
        *)
            MSG="DAEMON_ERROR: Daemon mode ${4} not found."
            log_creator
            echo $MSG >/dev/stderr
            exit 1
            ;;
    esac
else
    MSG="DAEMON_ERROR: daemon state not found"
    log_creator
    echo $MSG >/dev/stderr
    exit 1
fi

exit 0
