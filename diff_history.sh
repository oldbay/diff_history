#!/bin/bash

exit_log_creator() {
    echo "CMD: $0 FILE: $FILE MSG: $MSG" 2>&1 |logger
    case ${EXIT} in
        0)
            echo $MSG >/dev/stdout
            exit ${EXIT}
            ;;
        10)
            echo $MSG >/dev/stdout
            ;;
        11)
            echo $MSG >/dev/stderr
            ;;
        *)
            echo $MSG >/dev/stderr
            exit ${EXIT}
            ;;
    esac
}

pid_clean() {
if [ -f ${PID_FILE} ];then
    rm $PID_FILE
    find $PID_dir -empty -type d -delete
fi
}

pid_init() {
if [ -f ${PID_FILE} ];then
    pid_test=`cat $PID_FILE`
    ps $pid_test|grep $0
    if [ $? -eq 0 ];then
        exit 0
    else
        pid_clean
    fi
fi
mkdir -p $(dirname $PID_FILE)
echo $$ >$PID_FILE
}

time_test() {
    let iter_time=$(date +%s)
    let commit_time=$($GIT log -1 --pretty=format:%at)
    let diff_uptime=${iter_time}-${commit_time}
    if [ $diff_uptime -lt $min_time ]||[ $diff_uptime -gt $max_time ];then
        if [ $diff_uptime -gt $max_time ];then
            let diff_uptime_min=$diff_uptime/60
            MSG="SYS_ERROR: Тimeout '$diff_uptime_min' min is very long"
            EXIT=11
            exit_log_creator
        else
            exit 0
        fi
    fi
}

repo_init() {
    pid_init
    ($GIT status || $GIT init) &&
    $GIT add $FILE &&
    $GIT commit -m "$FILE"
    if [ $? -eq 0 ];then
        pid_clean
        MSG="GIT_OK: Create GIT repository for '$FILE' complete"
        EXIT=0
        exit_log_creator
    else
        pid_clean
        MSG="GIT_ERROR: Create GIT repository for '$FILE' failed"
        EXIT=1
        exit_log_creator
    fi
}


mode_iter() {
    time_test
    pid_init
    $GIT add $FILE &&
    $GIT commit -m "$FILE"
    if [ $? -eq 0 ];then
        pid_clean
        MSG="GIT_OK: Commit '$FILE' create"
        EXIT=0
        exit_log_creator
    else
        pid_clean
        exit 0
        exit_log_creator
    fi
}

old_mark() {
    actual_cache=$($GIT log --pretty=format:%at^%h^%s | \
                   grep $FILE | \
                   grep $old_one_timestamp | \
                   awk -F "^" '{print $2}')
    wordkdir=$pwd
    cd $FILE_DIR
    $GIT filter-branch -f --msg-filter "
    if [ \"\$GIT_COMMIT\" = \"\$(git rev-parse --verify $actual_cache)\" ]
    then
        echo $old_comit_name
    else
        sed 's/.*/\0/g'
    fi
    " -- --all
    cd $wordkdir
}

mode_rebase() {
    let num=$($GIT log --pretty=format:%s | \
              grep $FILE | \
              wc -l)
    if [ $num -gt $max_nums ];then
        let old_nums=$num-$max_nums
        old_timestamps=$($GIT log --pretty=format:%at^%h^%s | \
                        grep $FILE | \
                        awk -F "^" '{print $1}' | \
                        tail -n $old_nums)
        for old_one_timestamp in $old_timestamps
        do
            old_mark
        done
        $GIT rebase -i --root
    fi
}

log_menu() {
    let height=$max_nums+1
    let width=$(echo $FILE|wc -c)+7
    echo $width
    exec 3>&1
    select=$($DIALOG --clear --title "Time Select Menu" --no-tags \
        --menu "Select log from file '$FILE' :" 25 $width $height $allmenu 2>&1 1>&3)
    err=$?
    exec 3>&-
    #reject test
    if [ $err -ne 0 ]; then exit 1; fi
}

mode_view() {
	# test dialog type
	if [ -n "$DISPLAY" ]&&[ -f /usr/bin/Xdialog ];then
		DIALOG=${DIALOG=Xdialog}
	elif [ -f /usr/bin/dialog ];then
		DIALOG=${DIALOG=dialog}
	else
		MSG="Please install dialog"
		EXIT=1
        exit_log_creator
	fi

    # menu
    while true
    do
        $GIT log --pretty=format:%h^%s^%cI|cat 
        allmenu=""
        for string in $($GIT log --pretty=format:%h^%s^%cI|grep $FILE) 
        do
            allmenu+="$(echo $string|awk -F "^" '{print $1}') $(echo $string|awk -F "^" '{print $NF}') "
        done
        old_comit_menu=$($GIT log --pretty=format:%h^%s^%cI|grep "\^${old_comit_name}\^")
        if [ "$old_comit_menu" != "" ];then
            allmenu+="$(echo $old_comit_menu|awk -F "^" '{print $1}') $old_comit_name"
        fi

        log_menu
        
        if [ "$select" == "" ];then
            break
        else
            $GIT show $select
        fi
    done
    exit 0
}

usage() { 
    # help kommand keys
    echo "Usage: $0 -f <filename> [-m <modename: iter|rebase|view>|-d <start|stop>] -c <conf file>"
    echo "-f - filename for log history"
    echo "-m - mode: iter (iteration:DEFAULT); rebase(cut the log); view(view log history)"
    echo "-d - start/stop/status iter daemon mode (replace -m {mode})"
    echo "-c - config file"
    echo "-h help"
}

# getopts for command keys
while getopts ":f:m:d:c:h" o; do
    case "${o}" in
        f)
            f=${OPTARG}
            ;;
        m)
            m=${OPTARG}
            ;;
        d)
            d=${OPTARG}
            ;;
        c)
            c=${OPTARG}
            ;;
        h)
            usage
            exit 0
            ;;
        *)
            usage
            exit 0
            ;;
    esac
done


#read config file and init config variables
CONFIG_name=$(realpath ./diff_history.cfg)
if [ -n "$c" ];then CONFIG_name=$(realpath ${c});fi
if [ -f ${CONFIG_name} ];then
    . ${CONFIG_name}
else
    MSG="ERROR: Config File '${CONFIG_name}' not found"
    EXIT=1
    exit_log_creator
fi
# let min_time=10
let min_time=${CONFIG_OPT_min_time}*60
let max_time=${CONFIG_OPT_max_time}*60
let max_nums=${CONFIG_OPT_max_nums}
GIT_dir=$(realpath ${CONFIG_GIT_dir})
GIT_rebaser=$(realpath ${CONFIG_GIT_rebaser})
PID_dir=$(realpath ${CONFIG_SYS_pid_dir})
PID_dir=$(realpath ${CONFIG_SYS_pid_dir})
DAEMON_name=$(realpath ${CONFIG_SYS_daemon_name})
let DAEMON_step=${CONFIG_SYS_daemon_step}
old_comit_name="old"


# Dynamic variables && GIT test 
if [ -n "$f" ];then
    if [ -f "$f" ];then
        FILE=$(realpath $f)
        FILE_DIR=$(dirname $(realpath $f))
        PID_FILE=${PID_dir}${FILE_DIR}/diff_history.pid
        GIT_FILE_DIR=$GIT_dir$FILE_DIR
        mkdir -p $GIT_FILE_DIR
        if [ -d $GIT_FILE_DIR ];then
            GIT="git --git-dir=$GIT_FILE_DIR --work-tree=$FILE_DIR"
            $GIT log --oneline|grep $FILE >/dev/null 2>&1 || repo_init 
            $GIT config --local core.editor "$GIT_rebaser"
        else
            MSG="SYS_ERROR: GIT directory '$GIT_FILE_DIR' not found"
            EXIT=1
            exit_log_creator
        fi
    else
        echo "File for log {-f} not found"
        usage
        exit 0
    fi
else
    echo "Please insert filename {-f}"
    usage
    exit 0
fi


#Run mode
if [ ! -n "$d" ];then
    if [ ! -n "$m" ];then m="iter";fi
    case "${m}" in
        iter)
            mode_iter
            ;;
        rebase)
            mode_rebase
            ;;
        view)
            mode_view
            ;;
        *)
            echo "Mode ${m} not found. Please insert mode: iter or rebase or view"
            usage
            exit 0
            ;;
    esac
elif [ ! -n "$m" ];then
    case "${d}" in
        start)
            nohup $DAEMON_name $FILE $PID_dir ${d} $0 $DAEMON_step &
            ;;
        stop)
            $DAEMON_name $FILE $PID_dir ${d}
            ;;
        status)
            $DAEMON_name $FILE $PID_dir ${d}
            ;;
        *)
            echo "Daemon mode ${d} not found. Please insert daemon mode: start or stop or status"
            usage
            exit 0
            ;;
    esac
else
    echo "Please select {-m} or {-d} key only"
    usage
    exit 0
fi

exit 0
