#!/bin/bash
source /etc/profile 2>&1>/dev/null
#define  function
> /tmp/tomcat_status.log
Scan_tomcat(){
    _count=0
    for i in `ls /u01/ |grep tomcat |grep -`
    do
        _tomcat_list[$_count]=$i
        _count=$((${_count}+1))
    done
}

Show_usage(){
    echo -e "\033[31m
    include : ${_tomcat_list[@]}
    command : start/stop/restart/status/log
    sh /var/shell/tacmot.sh  instance  command
    or
    sh /var/shell/tacmot.sh instance restart all
    \033[0m"
    exit
}

Stop(){
    echo "Now stop $_tomcatname"
    _time1=`ps -ef|grep $_tomcatname/|grep -v grep|awk '{print $5}'`
    echo "$_tomcatname $_time1" >> /tmp/tacmot.log
    grep docBase /u01/$_tomcatname/conf/server.xml  > /dev/null  2>&1
    if [[ $? == 0 ]];then
        docBase=`grep docBase /u01/$_tomcatname/conf/server.xml|awk -F '"' '{print $4}'`
        if [ "$docBase" == "/" -o ! -n "$docBase" ];then
             _jspfile=`grep docBase /u01/$_tomcatname/conf/server.xml|awk -F '"' '{print $2}' |xargs -i find {} -name 'live.jsp*'`
        else
             _jspfile=`grep docBase /u01/$_tomcatname/conf/server.xml|awk -F '"' '{print $4}' |xargs -i find {} -name 'live.jsp*'`
        fi
    else
        _jspfile=`find /u01/$_tomcatname  -name live.jsp`
    fi
    if [[ -f ${_jspfile} ]];then
        mv ${_jspfile} ${_jspfile}.bak
    fi
    sleep $_wait
    _pidfile=`grep "CATALINA_PID=" /u01/$_tomcatname/bin/catalina.sh|awk -F'=' '{print $2}'`
    _pid=`eval cat $_pidfile`
    bash /u01/$_tomcatname/bin/shutdown.sh  |egrep "Tomcat stopped|been killed" 2>&1 > /dev/null
    if [[ $? == 0 ]];then
        echo "Tomcat stopped."
        sleep 1
    else
        kill -9 $_pid
        if [[ $? == 0 ]];then
            echo "Tomcat stopped."
        else
            echo "Tomcat is not started!"
        fi
        sleep 1
    fi
}

Start(){
    echo "Now start $_tomcatname"
    bash /u01/$_tomcatname/bin/startup.sh
    if [[ $_flag != "true" ]];then
        _sleep='true'
        Status
        _time2=`ps -ef|grep $_tomcatname/|grep -v grep|awk '{print $5}'`
        if [[ $_time1 != "" ]] && [[ $_time1 != $_time2 ]];then
            echo "$_tomcatname restart success" >> /tmp/tomcat_status.log
        else
            echo "$_tomcatname restart fail" >> /tmp/tomcat_status.log
        fi
    fi
}

Status(){
    grep docBase /u01/$_tomcatname/conf/server.xml >/dev/null  2>&1
    if [[ $? == 0 ]];then
        docBase=`grep docBase /u01/$_tomcatname/conf/server.xml|awk -F '"' '{print $4}'`
        if [ "$docBase" == "/" -o ! -n "$docBase" ];then
             _jspfile=`grep docBase /u01/$_tomcatname/conf/server.xml|awk -F '"' '{print $2}' |xargs -i find {} -name 'live.jsp*'`
        else
             _jspfile=`grep docBase /u01/$_tomcatname/conf/server.xml|awk -F '"' '{print $4}' |xargs -i find {} -name 'live.jsp*'`
        fi
    else
        _jspfile=`find /u01/$_tomcatname  -name 'live.jsp*'`
    fi
    mv $_jspfile ${_jspfile%.bak*} >/dev/null  2>&1
    [ $_sleep ] && sleep $((_wait + 5))
    _port=` grep port  /u01/$_tomcatname/conf/server.xml|grep \"|egrep "org.apache.coyote.http11.Http11AprProtocol|HTTP/1.1"|awk -F '"'  '{print $2}'|head -n1`
    _pidfile=`grep "CATALINA_PID=" /u01/$_tomcatname/bin/catalina.sh|awk -F'=' '{print $2}'`
    ls ${_jspfile%.bak*}|grep car-rest > /dev/null  2>&1
    if [[ $? == 0 ]];then
        curl -s --connect-timeout 3 http://localhost:$_port/car-rest/live.jsp | grep  true  >/dev/null  2>&1
        if [[ $? == 0 ]];then
            echo "$_tomcatname running normally !"
            [  $_sleep ] || top -bn1|egrep "`eval cat $_pidfile`|PID"
        else
            tail -n100 /u01/$_tomcatname/logs/catalina.out|egrep 'ERROR|Error|error'
            if [[ $? == 0 ]];then
                echo "$_tomcatname not running or some error occured, pleas check $_tomcatname's log!"
                exit 1
            fi
        fi
    else
        curl -s --connect-timeout 3 http://localhost:$_port/live.jsp | grep true  >/dev/null  2>&1
        if [[ $? == 0 ]];then
            echo "$_tomcatname running normally !"
            [  $_sleep ] || top -bn1|egrep "`eval cat $_pidfile`|PID"
        else
            tail -n100 /u01/$_tomcatname/logs/catalina.out|egrep 'ERROR|Error|error|Exception'|egrep -v 'DEBUG|INFO|WARN'
            if [[ $? == 0 ]];then
                echo "$_tomcatname not running or some error occured, pleas check $_tomcatname's log!"
                exit 1
            fi
        fi
    fi
}

Showlog(){
    tail -f /u01/$_tomcatname/logs/catalina.out
}

Case(){
    case $_action in
        stop)
            Stop
            ;;
        start)
            _flag="true" && Start
            ;;
        restart)
            Stop
            Start
            ;;
        status)
            Status
            ;;
        log)
            Showlog
            ;;
        *)
            Show_usage
            ;;
        esac
}

Loop(){
for((i=0;i<$_length;i++))
do
    _tomcatname=${_tomcat_list[$i]}
    if [[ ${_tomcat_list[@]} =~ $_tomcatname ]];then
        if [[ ${_action_list[@]} =~ $_action ]];then
            Case
        else
            Show_usage
        fi
    else
        Show_usage
    fi
done
}

#main script
_tomcatname=$1
Scan_tomcat
_action_list=(stop start restart status log)
_action=$2
_wait=${4:-'10'}
_flag=""
if [[ $3 == all ]];then
    if [[ $_action == restart ]];then
        _length=`ps -ef | grep $_tomcatname | grep java | egrep -v 'grep|tail\>|*.sh\>|catalina.out|*.gz' | wc -l`
        if [[ $_length == 0 ]];then
            echo -e "\033[31m$_tomcatname not running\033[0m"
        fi
        Loop
        _success_info=`grep success /tmp/tomcat_status.log`
        _fail_info=`grep fail /tmp/tomcat_status.log`
        echo -e "\033[32m$_success_info\033[0m"
        echo -e "\033[31m$_fail_info\033[0m"
    else
        _length=`ls /u01/|grep $_tomcatname | egrep -v grep | wc -l`
        Loop
    fi
else
    for i in ${_tomcat_list[@]};do
    if [[ $i =~ "$1" ]];then
        _tomcatname=$i
        break
    fi
    done
    Case
fi

