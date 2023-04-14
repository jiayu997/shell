#!/bin/bash 
DB_HOST=192.168.0.51
DB_PORT=3306
DB_USER=root
DB_PASSWORD=password
DB_EXPIRE=7
DB_BACKUP_DIR=/backup/mysql
BASE_DIR=$(cd $(dirname $0);pwd)
BACK_LOG=$BASE_DIR/backup.log

function error_text(){	
	echo "[ ERROR ] $@" >>$BACK_LOG
}

function ok_text(){
	echo "[ OK ] $@" >>$BACK_LOG
}

function check_dir(){
	if [ ! -d $DB_BACKUP_DIR ]; then
		mkdir -p /backup/mysql
	fi
}

function check_user(){
	if [ $(id -u -n) != "root" ];then
		error_text "请使用root运行脚本"
		exit 1
	else
		ok_text "当前身份: ROOT"
	fi
}

function check_mysql(){
	# 检查服务是否起来
	if [ $(ps -aux|grep mysql|grep -v mysql-backup|grep -v grep|wc -l) -eq 0 ]; then
		error_text "MySQL服务没有启动"
        exit 1
	fi
	# 连接数据库,检查是否能正常使用
	mysql -u$DB_USER -h$DB_HOST -P$DB_PORT -p$DB_PASSWORD -e "show processlist;" &>/dev/null
	if [ $? -ne 0 ]; then
		error_text "MySQL服务异常"
        exit 1
	fi
}

function backup(){
	# 检查是否带了备份数据库的参数
	if [ $# -eq 0 ]; then
    	echo -e "[ ERROR ] 必须在脚本后边带要备份的数据库，空格分开多个数据库" >> $BACK_LOG
    	exit 1
	fi

	# 开始备份
    ok_text "时间: $(date '+%Y-%m-%d %H:%m:%S'),需要备份的数据库有: $@"
	for i in $@
	do
		if [ $(mysql -u$DB_USER -h$DB_HOST -P$DB_PORT -p$DB_PASSWORD -e "show databases"|grep -oE "^$i$"|wc -l) -ne 1 ]; then
			error_text "数据库: $i 备份失败,没有这个库" >>$BACK_LOG
		else
			mysqldump -u$DB_USER -h$DB_HOST -P$DB_PORT -p$DB_PASSWORD -B $i --master-data=2 --single-transaction|gzip>${DB_BACKUP_DIR}/${i}-$(date "+%F").sql.gz	
			if [ $? -eq 0 ];then
				ok_text "时间: $(date '+%Y-%m-%d %H:%m:%S'),数据库: $i 备份成功,备份文件存放路径为: ${DB_BACKUP_DIR}/${i}-$(date "+%F").sql.gz"
			else
				error_text "数据库: $i 备份失败" >>$BACK_LOG
			fi
		fi
	done	
}

function check_expire(){
	find  $DB_BACKUP_DIR -mtime +7 -exec rm -rf {} \;
}

function restore(){
	# 检查是否带了恢复数据库的参数
	if [ $# -eq 0 ]; then
    	echo -e "[ ERROR ] 必须在脚本后边带要恢复的数据库，空格分开多个数据库" >> $BACK_LOG
    	exit 1
	fi

	# 开始恢复
    ok_text "时间: $(date '+%Y-%m-%d %H:%m:%S'),需要恢复的备份有: $@"
	for i in $@
	do
		if [ ! -f $i ]; then
			error_text "$i 备份文件不存在,无法恢复"
		else
			if [[ "$i" == *".gz" ]]; then
				/bin/bash -c gunzip < $i | mysql -u$DB_USER -h$DB_HOST -P$DB_PORT -p$DB_PASSWORD
				if [ $? -eq 0 ]; then
					ok_text "时间: $(date '+%Y-%m-%d %H:%m:%S'),$i 备份文件恢复成功"
				else
					error_text "$i 备份文件恢复失败"
				fi
			else
				error_text "$i 文件格式不对，无法恢复"
			fi
		fi
	done	
}

function useage(){
  echo -e "\033[32m***************************************\033[0m"
  echo -e "\033[32mMySQL数据库备份与恢复管理脚本使用帮助\033[0m"
  echo -e "\033[32mUsage: \033[0m"
  echo -e "\033[32m   backup 要备份的数据库名字(空格隔开)\033[0m"
  echo -e "\033[32m   restore 要恢复的数据库文件(空格隔开)\033[0m"
  echo -e "\033[32mMySQL 脚本配置信息                       \033[0m"
  echo -e "\033[32mMySQL IP: $DB_HOST                     \033[0m"
  echo -e "\033[32mMySQL PORT: $DB_PORT                   \033[0m"
  echo -e "\033[32mMySQL USER: $DB_USER                   \033[0m"
  echo -e "\033[32mMySQL PASSWORD: $DB_PASSWORD           \033[0m"
  echo -e "\033[32mMySQL LOG: $BACK_LOG                   \033[0m"
  echo -e "\033[32mMySQL EXPIRE: ${DB_EXPIRE}day          \033[0m"
  echo -e "\033[32mMySQL BACKUP DIR: $DB_BACKUP_DIR       \033[0m"
  echo -e "\033[32m***************************************\033[0m"
}

action=$1
case $1 in
    backup)
		echo "--------------------------------------------" >>$BACK_LOG
        shift
		check_user 
		check_mysql
		check_dir
		backup $@
		check_expire
    ;;
    restore)
		echo "--------------------------------------------" >>$BACK_LOG
        shift 
		check_user
		check_mysql
		restore $@
    ;;
    *)
        useage
    ;;
esac
