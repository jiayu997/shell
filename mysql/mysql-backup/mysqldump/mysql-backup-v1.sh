#!/bin/bash
DB_HOST=192.168.0.51
DB_PORT=3306
DB_USER=root
DB_PASSWORD=password
DB_EXPIRE=7
DB_BACKUP=$@
DB_BACKUP_DIR=/backup/mysql
BASE_DIR=$(cd $(dirname $0);pwd)
BACK_LOG=$BASE_DIR/backup.log

function error_text(){	
	echo "[ ERROR ] $1" >>$BACK_LOG
}

function ok_text(){
	echo "[ OK ] $1" >>$BACK_LOG
}

function check_dir(){
	if [ ! -d $DB_BACKUP_DIR ]; then
		mkdir -p /backup/mysql
	fi
}

function check_user(){
	if [ $(id -u -n) != "root" ];then
		error_text "请使用root运行脚本"
		error_text "数据库: ${DB_BACKUP} 备份失败"
		exit 1
	else
		ok_text "当前身份: ROOT"
	fi
}

function check_mysql(){
	# 检查服务是否起来
	if [ $(ps -aux|grep mysql|grep -v mysql-backup|grep -v grep|wc -l) -eq 0 ]; then
		error_text "MySQL服务没有启动"
		error_text "数据库: ${DB_BACKUP} 备份失败"
        exit 1
	else
		ok_text "MySQL服务已启动"
	fi
	# 连接数据库,检查是否能正常使用
	mysql -u$DB_USER -h$DB_HOST -P$DB_PORT -p$DB_PASSWORD -e "show processlist;" &>/dev/null
	if [ $? -ne 0 ]; then
		error_text "MySQL服务异常"
		error_text "数据库: ${DB_BACKUP} 备份失败"
        exit 1
	else
		ok_text "MySQL服务正常运行,下面开始备份数据库"
	fi
}

function backup(){
    ok_text "时间: $(date '+%Y-%m-%d %H:%m:%S'),需要备份的数据库有: ${DB_BACKUP}"
	for i in ${DB_BACKUP}
	do
		if [ $(mysql -u$DB_USER -h$DB_HOST -P$DB_PORT -p$DB_PASSWORD -e "show databases"|grep -oE "^$i$"|wc -l) -ne 1 ]; then
			error_text "数据库: $i 备份失败,没有这个库" >>$BACK_LOG
			continue
		else
			mysqldump -u$DB_USER -h$DB_HOST -P$DB_PORT -p$DB_PASSWORD -B $i -R -E --triggers --master-data=2 --single-transaction|gzip>${DB_BACKUP_DIR}/${i}-$(date "+%F").sql.gz &>/dev/null	
			if [ $? -eq 0 ];then
				ok_text "时间: $(date '+%Y-%m-%d %H:%m:%S'),数据库: $i 备份成功,备份文件存放路径为: ${DB_BACKUP_DIR}/${i}-$(date "+%F").sql.gz"
			else
				error_text "数据库: $i 备份失败" >>$BACK_LOG
				continue
			fi
		fi
	done	
}

function main(){
	check_user
    check_mysql
	check_dir
	backup
}
echo "--------------------------------------------" >>$BACK_LOG
if [ $# -eq 0 ]; then
	echo -e "[ ERROR ] 必须在脚本后边带要备份的数据库，空格分开多个数据库" >> $BACK_LOG
	exit 1
fi
main
