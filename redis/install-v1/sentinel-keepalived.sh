<<!
 **********************************************************
 * Author        : jiayu997
 * Email         : qujiayu98@163.com
 * Last modified : 2021-05-05 06:24
 * Filename      : sentinel-keepalived.sh
 * Description   : redis-sentinel automatic deployment script
 * *******************************************************
!
#!/bin/bash
action=$1
BASE_DIR=$(cd $(dirname $0);pwd)
IS_YUM=1

function error_text(){	
	echo -e "[\033[31m ERROR \033[0m] $1"
}

function ok_text(){
	echo -e "[\033[32m OK \033[0m] $1"
}

function init_security(){
	systemctl disable firewalld --now &>/dev/null && systemctl disable NetworkManager --now &> /dev/null &&sed -i 's#SELINUX=enforcing#SELINUX=disabled#g' /etc/sysconfig/selinux && sed -i 's#SELINUX=enforcing#SELINUX=disabled#g' /etc/selinux/config && if [ $(getenforce) == "Enforcing" ]; then setenforce 0; fi
	if [ $? -eq 0 ]; then
		ok_text "firewalld,networkmanager,selinux have been disabled"
	else
		error_text "firewalld networkmanager,selinux disable error"
		exit 1
	fi
}

function check_user(){
	# 检查当前身份是否为root
	if [ $(id -u -n) != "root" ]; then
		error_text "Please run this script by root"
		exit 1
	else 
		init_security
	fi
}

function check_config(){
	# 检查是否存在配置文件
	if [ ! -f $BASE_DIR/config.txt ]; then
		error_text "Not found config.txt,please cp config-example.txt config.txt"
		exit 1
	else
		source $BASE_DIR/config.txt
		ok_text "config.txt check ok"
	fi
}

function check_os(){
	# 检查当前操作系统
	if [ -f /etc/redhat-release ]; then
		osVersion=$(cat /etc/redhat-release|grep -oE '[0-9]+\.[0-9]'|awk -F '.' '{print $1}')
		if [ $osVersion == "7" ]; then
			if [ $(uname -m) != "x86_64" ]; then
				error_text "Please run this script in Centos7 64"
				exit 1
			else 
				ok_text "os check ok"
			fi
		else
			error_text "Please run this script in Centos7 64"
			exit 1
		fi
	else
		error_text "Please run this script in Centos7 64"
		exit 1
	fi
	
}

function check_network(){
	ping -c 2 -i 0.5 -W 1 114.114.114.114 &>/dev/null && curl -I -k -L -s -w "%{http_code}\n" -o /dev/null https://mirrors.aliyun.com &>/dev/null
	if [ $? -ne 0 ]; then
		error_text "this machine cannot connect to the internet,will use offline installation"
		IS_YUM=0
	else
		ok_text "network check ok"
	fi
}

function check_yum(){
	# 更新系统yum源
	if [ ! -f /etc/yum.repos.d/CentOS-Base.repo -o ! -f /etc/yum.repos.d/epel.repo ]; then
		curl -o /etc/yum.repos.d/CentOS-Base.repo https://mirrors.aliyun.com/repo/Centos-7.repo &>/dev/null && curl -o /etc/yum.repos.d/epel.repo http://mirrors.aliyun.com/repo/epel-7.repo &>/dev/null
		if [ $? -ne 0 ]; then
			error_text "yum update error,will use offline installation"
			IS_YUM=0
		else
			ok_text "yum update ok"	
		fi
	else
		ok_text "yum already exist,don't need to update"
	fi
}

function check_interface(){
	# 检查网口是否存在
	if [ ! -d /sys/class/net/$INTERFACE ]; then
		error_text "Please use correct interface"
		exit 1
	else
		ok_text "interface check ok"
	fi	
}


function check_vip(){
	# 检查VIP是否被使用
	ping -c 2 -i 0.5 -W 1 $VIP &>/dev/null
	if [ $? -eq 0 ]; then
		error_text "This IP has been already used by others Please change VIP"
		exit 1
	else	
		ok_text "vip check ok"
	fi
}


function install_netstat(){
	if [ ! -f $BASE_DIR/package/net-tools/net-tools-2.0-0.25.20131004git.el7.x86_64.rpm ]; then
		error_text "net-tools rpm package is not exist,please download again"
	else
		rpm -ivh $BASE_DIR/package/net-tools/net-tools-2.0-0.25.20131004git.el7.x86_64.rpm &>/dev/null
		if [ $? -eq 0 ]; then
			ok_text "net-tools rpm package install ok"
		else
			error_text "net-tools rpm package install error"
			exit 1
		fi
	fi
}

function check_port(){
	# 使用的端口检查
	if [ $(rpm -qa|grep net-tools|wc -l) -ne 1 ]; then
		if [ $IS_YUM -eq 1 ]; then
			yum -y install net-tools &>/dev/null
			if [ $? -eq 0 ]; then
				ok_text "net-tools install ok"
			else
				error_text "yum install net-tools error"
				IS_YUM=0
				install_netstat
			fi
		else
			install_netstat
		fi
	else
		ok_text "net-tools has been installed"
	fi

	if [ $(netstat -tunlp|grep -oE ':$REDIS_PORT'|grep -v grep|wc -l) -eq 0 ]; then
		ok_text "redis port check ok"
	else
		error_text "redis port has already been used,please change another port"
		exit 1
	fi
	if [ $(netstat -tunlp|grep -oE ':$SENTINEL_PORT'|grep -v grep|wc -l) -eq 0 ]; then
		ok_text "sentinel port check ok"
	else
		error_text "sentinel port has already been used,please change another port"
		exit 1
	fi
}

function pre_install(){
	check_user
	check_config
	check_os
	check_interface
	check_vip
	if [ $IS_YUM -eq 1 ]; then
		check_network
	fi
	if [ $IS_YUM -eq 1 ]; then
		check_yum
	fi
	check_port
}

function config(){
	source $BASE_DIR/config.txt #其他函数source的，只能在该函数中生效
	# 备份redis配置文件
	if [ ! -f /etc/redis.conf.bak ]; then
		cp /etc/redis.conf /etc/redis.conf.bak
	fi
	if [ ! -f /etc/sentinel.conf.bak ]; then
		cp /etc/redis-sentinel.conf /etc/redis-sentinel.conf.bak
	fi
	
	# 备份keepalived配置文件
	if [ ! -f /etc/keepalived/keepalived.conf.bak ]; then
		cp /etc/keepalived/keepalived.conf /etc/keepalived/keepalived.conf.bak
	fi

	# 配置redis配置文件(根据需求自行添加)
	sed -i "s@bind.*@bind 0.0.0.0@g" /etc/redis.conf	
	sed -i "s@protected-mode yes@protected-mode no@g" /etc/redis.conf
	sed -i "s@daemonize no@daemonize yes@g" /etc/redis.conf
	sed -i "s@timeout 0@timeout 5@g" /etc/redis.conf
	sed -i "s@# repl-timeout 60@repl-timeout 60@g" /etc/redis.conf
	sed -i "s@# repl-ping-replica-period 10@repl-ping-replica-period 10@g" /etc/redis.conf
	sed -i "s@# requirepass foobared@requirepass $REDIS_PASSWORD@g" /etc/redis.conf
	sed -i "s@# masterauth <master-password>@masterauth $REDIS_PASSWORD@g" /etc/redis.conf
	if [ $REDIS_PORT -ne 6379 ]; then
		sed -i "s@port 6379@port $REDIS_PORT@g" /etc/redis.conf
		sed -i "s@^pidfile .*@pidfile /var/run/redis_$REDIS_PORT.pid@g" /etc/redis.conf
	fi
	if [ $(hostname -I|grep $MASTER_HOST|grep -v grep|wc -l) -eq 0 ]; then
		sed -i "s@# replicaof <masterip> <masterport>@replicaof $MASTER_HOST $REDIS_PORT@g" /etc/redis.conf
	fi
	ok_text "redis config ok"

	# 配置sentinel配置文件
	sed -i "s@# protected-mode no@protected-mode no@g" /etc/redis-sentinel.conf
	sed -i "s@daemonize no@daemonize yes@g" /etc/redis-sentinel.conf
	sed -i "s@port 26379@port $SENTINEL_PORT@g" /etc/redis-sentinel.conf
   	sed -i "s@sentinel monitor mymaster 127.0.0.1 6379 2@sentinel monitor $SENTINEL_NAME $MASTER_HOST $REDIS_PORT $SENTINEL_QUORUM@g" /etc/redis-sentinel.conf
	sed -i "s@sentinel parallel-syncs mymaster 1@sentinel parallel-syncs $SENTINEL_NAME $SENTINEL_NUMREPLICAS@g" /etc/redis-sentinel.conf
	sed -i "s@# sentinel auth-pass mymaster MySUPER--secret-0123passw0rd@sentinel auth-pass $SENTINEL_NAME $REDIS_PASSWORD@g" /etc/redis-sentinel.conf
	ok_text "sentinel config ok"

	# 配置keepalived配置文件,前边不能有空格，否则会有问题,且不能写成cat <<EOF>file这种格式
	cat >/etc/keepalived/keepalived.conf<<EOF
! Configuration File for keepalived
global_defs {
   router_id LVS_DEVEL
   script_user root
   enable_script_security
   vrrp_skip_check_adv_addr
   vrrp_strict
   vrrp_garp_interval 0
   vrrp_gna_interval 0
}
vrrp_script sentinel_check {
    script "/etc/keepalived/sentinel-check.sh 127.0.0.1 $REDIS_PORT $REDIS_PASSWORD"
    interval 2
    weight 10
    fall 3
    rise 1
}
vrrp_instance VI_1 {
    state BACKUP 
    interface ens33
    virtual_router_id 51
    priority 100
    advert_int 2
    authentication {
        auth_type PASS
        auth_pass 1111
    }
    virtual_ipaddress {
        192.168.0.55/24
    }
    track_script {
        sentinel_check
    }
}
EOF

	# EOF如果不加双引号，会执行里面的命令
	cat >/etc/keepalived/sentinel-check.sh<<"EOF"
#!/bin/bash 
if [ -z "$(redis-cli -h $1 -p $2 -a $3 info|grep role:master)" ]; then
	exit 1 
else 
	exit 0 
fi 
EOF
#	echo -e '#!/bin/bash\nif [ -z "$(redis-cli -h $1 -p $2 -a $3 info|grep role:master)" ]; then\n\texit 1\nelse\n\texit 0\nfi' >/tmp/test ,if用了-z,需要加字符串
	#chmod 644 /etc/keepalived/*   #配置文件只能是644,否则报错
	chmod a+x /etc/keepalived/sentinel-check.sh
	chmod 755 /etc/redis.conf   # yum安装的redis,在systemd文件中指定了以redis用户运行
	chmod 755 /etc/redis-sentinel.conf
	ok_text "redis,sentinel,keepalived config is ok"
	ok_text "redis,sentinel,keepalived have been configured"
	echo -ne "[\033[32m Please Run:\033[0m]"
	echo -ne "\033[33m./sentinel-keepalived.sh start redis-sentinel \033[0m\n"
}

function yum_install(){
	# 检查源(redis-5),这里加个逻辑判断 #rpm -qa|grep epel-release && rpm -qa|grep ius-release
	if [ $IS_YUM -eq 1 ]; then
		yum install -y https://repo.ius.io/ius-release-el7.rpm https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm &>/dev/null
		if [ $? -ne 0 ]; then
			error_text "yum source update error"
			exit 1
		else
			ok_text "yum source update ok"
		fi
	fi	

	# 安装redis
	if [ $(rpm -qa|grep redis|grep -v grep|wc -l) -eq 0 ]; then
		yum install -y redis5 &>/dev/null
		if [ $? -ne 0 ]; then
			error_text "redis install error"
			exit 1
		else
			ok_text "redis install ok"
		fi
	else
		if [ $(rpm -qa|grep redis|grep -oE "^redis5-[0-9]"|awk -F '-' '{print $2}') -eq 5 ]; then
			ok_text "redis havs already been installed"
		else
			error_text "redis version is not compatible"
			exit 1
		fi
	fi

	# 安装keepalived
	if [ $(rpm -qa|grep keepalived|grep -v grep|wc -l) -eq 0 ]; then
		yum -y install keepalived &>/dev/null
		if [ $? -eq 0 ]; then
			ok_text "keepalived install ok"
		else 
			error_text "keepalived install error"
			eixt 1
		fi
	else
		ok_text "keepalived has already been installed"
	fi
	
	# 安装后配置配置文件
	config
}

function rpm_install(){
	# 安装keepalived依赖包
	if [ $(rpm -qa|grep keepalived|wc -l) -eq 0 ]; then
		if [ ! -d $BASE_DIR/package/keepalived ]; then
			error_text "keepalived package is not exist"
			exit 1
		else
			if [ $(ls $BASE_DIR/package/keepalived|wc -l) -ne 32 ]; then
				error_text "incorrect number of keepalived packets"
				exit 1
			fi
		fi		
		yum -y localinstall $BASE_DIR/package/keepalived/* --disablerepo=\* --skip-broken &>/dev/null
		keepalived -h &>/dev/null
		if [ $? -eq 0 ]; then
			ok_text  "keepalived install ok"
		else
			error_text "keepalived install error,please install keepalived manually before run this shell"
			exit 1
		fi
	else
		ok_text "keepalived has been installed"
	fi	

	# 安装redis5
	if [ $(rpm -qa|grep redis5|wc -l) -eq 0 ]; then
		if [ ! -f $BASE_DIR/package/redis/redis5-5.0.9-1.el7.ius.x86_64.rpm ]; then
			error_text "redis5 package is not exist"
			exit 1
		fi
		rpm -ivh $BASE_DIR/package/redis/redis5-5.0.9-1.el7.ius.x86_64.rpm &>/dev/null
		if [ $? -eq 0 ]; then
			ok_text "redis 5 install ok"
		else
			error_text "redis5 install error,please install redis5 manually before run this shell"
			exit 1
		fi
	else
		ok_text "redis5 has been installed"
	fi
	
	# 修改配置文件
	config
}


function install(){
	while :
	do
		echo -ne "[\033[32m Check \033[0m] The default is yum installation, Do you want to switch to offline installation [Y/N] "
		read -n1 answer
		echo 
		case $answer in
			Y|y)
				IS_YUM=0
				break
			;;
			N|n)
				IS_YUM=1
				break
			;;
			*)
				error_text "please input correct choice"
			;;
		esac
	done
	pre_install
	if [ $IS_YUM -eq 1 ]; then
		yum_install
	else
		rpm_install
	fi
}

function stop(){
	systemctl stop keepalived >/dev/null && systemctl stop redis >/dev/null && systemctl stop redis-sentinel >/dev/null
	if [ $? -eq 0 ]; then
		ok_text "keepalived,redis,redis-sentinel have been stoped"
	else
		error_text "keepalived,redis,redis-sentinel stop fail"
		exit 1
	fi
}	

function start(){
	# 启动redis
	if [ -z "$(systemctl status redis|grep running)" ]; then 
		systemctl start redis &>/dev/null
		if [ $? -eq 0 ]; then
			ok_text "redis start ok"
		else
			error_text "redis start error"
			eixt 1
		fi
	else
		ok_text "redis has already been running,don't need to start"
	fi

	#启动redis-sentinel
	if [ -z "$(systemctl status redis-sentinel|grep running)" ]; then
		systemctl start redis-sentinel &>/dev/null
		if [ $? -eq 0 ]; then
			ok_text "redis-sentinel start ok"
		else
			error_text "redis-sentinel start error"
			exit 1
		fi
	else
		ok_text "redis-sentinel has already been running,don't need to start"
	fi
	
	# 启动keepalived
	if [ -z "$(systemctl status keepalived|grep running)" ]; then
		systemctl start keepalived &>/dev/null
		if [ $? -eq 0 ]; then
			ok_text "keepalived start ok"
		else
			error_text "keepalived start error"
			exit 1
		fi
	else
		ok_text "keepalived has already been running,don't need to start"	
	fi	
}

function uninstall(){
	stop
	yum remove keepalived redis5
	rm -rf /etc/keepalived/keepalived.conf
	rm -rf /etc/redis.conf
	rm -rf /etc/redis-sentinel.conf
}

function reset(){
	uninstall
	install	
}

function status(){
	source $BASE_DIR/config.txt 
	# 检查redis运行情况
	echo -ne "Redis Service       "
	redis-cli -h 127.0.0.1 -p $REDIS_PORT -a $REDIS_PASSWORD info &>/dev/null 
	if [ $? -ne 0 ]; then
    	echo -e "[\033[31m ERROR \033[0m]"
  	else
		echo -e "[\033[32m OK \033[0m]"
	fi
	
	# 检查sentinel运行情况
	echo -ne "Sentinel Service    "
	redis-cli -h 127.0.0.1 -p $SENTINEL_PORT -a $REDIS_PASSWORD info &>/dev/null 
	if [ $? -ne 0 ]; then
    	echo -e "[\033[31m ERROR \033[0m]"
	else
    	echo -e "[\033[32m OK \033[0m]"
	fi

	# 检查keepalived运行情况
	echo -ne "Keepalived Service  "
	systemctl status keepalived|grep running &>/dev/null #如果grep到了,会返回0,如果没grep到，会返回非0	
	if [ $? -eq 0 ]; then
		echo -e "[\033[32m OK \033[0m]"
	else
		echo -e "[\033[31m ERROR \033[0m]"
	fi

	# redis角色情况
	echo -ne "Sedis Role          "
	if [ -z "$(hostname -I | grep $VIP)" ]; then
    	echo -e "[\033[32m role: slave \033[0m]"
	else
    	echo -e "[\033[32m role: master \033[0m]"
	fi
}

function restart(){
	stop
	start
}

function useage() {
  echo -e "\033[32m***************************\033[0m"
  echo -e "\033[32m--Redis哨兵高可用部署脚本--\033[0m"
  echo "Usage: "
  echo "  install [COMMAND] ..."
  echo "  install --help"
  echo "Commands: "
  echo "  install      安装 Redis"
  echo "  start        启动 Redis"
  echo "  stop         停止 Redis"
  echo "  status       检查 Redis"
  echo "  restart      重启 Redis"
  echo "  uninstall    卸载 Redis"
  echo "  reset        重置 Redis"
  echo -e "\033[32m***************************\033[0m"
}

function main() {
	case $action in
		install)
			install
		;;
		uninstall)
			uninstall
		;;
		start)
			start
		;;
		stop)
			stop
		;;
		restart)
			restart
		;;
		reset)
			reset
		;;
		status)
			status
		;;
		-h)
			useage
		;;
		--help)
			useage
		;;
		*)
			useage
		;;
	esac
}
main
