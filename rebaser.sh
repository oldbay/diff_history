#!/bin/bash

FILE=$1
REPLACEWITH="fixup"
MASK="old"

position=0

if [ -f $FILE ]
then
    OUTPUT=$FILE.tmp
    echo "" > $OUTPUT
    cat $FILE | while read line
    do
        if [[ "$line" == *$MASK ]];then
            let position+=1
            if [ $position -gt 1 ];then
                echo ${line/pick/$REPLACEWITH} >> $OUTPUT
            else
                echo $line >> $OUTPUT
            fi
        else
            echo $line >> $OUTPUT
        fi
    done
    cat $OUTPUT >./OUTPUT.tmp
    cat $OUTPUT > $FILE
fi
