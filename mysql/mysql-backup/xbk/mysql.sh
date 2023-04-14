#!/bin/bash
DB_HOST=localhost
DB_PORT=3306
DB_USER=root
DB_PASSWORD=password
DB_EXPIRE=7
DB_BACKUP_DIR=/backup/mysql
BASE_DIR=$(cd $(dirname $0);pwd)
BACK_LOG=$DB_BACKUP_DIR/backup.log

function error_text(){
    echo "[ ERROR ] $@" >> $BACK_LOG
}

function ok_text(){
    echo "[ OK ] $@" >> $BACK_LOG
}

function check_user(){
	if [ $(id -u -n) != "root" ]; then
		error_text "当前身份:$(id -u -n)"	
		exit 1
	else
		ok_text "当前身份:$(id -u -n)"
	fi
}

function check_service(){
	#检查数据库服务是否起来
	if [ $(systemctl status mysqld.service|grep running|wc -l) -ne 1 ]; then
		systemctl start mysqld.service
		if [ $? -ne 0 ]; then
			ok_text "时间：$(date '+%Y-%m-%d %H:%m:%S') MySQL服务正常"
		else
			error_text "时间：$(date '+%Y-%m-%d %H:%m:%S') MySQL服务启动失败"
			exit 1
		fi
	else
		ok_text "时间：$(date '+%Y-%m-%d %H:%m:%S') MySQL服务正常"
	fi
	#检查数据库是否能正常使用
	mysql -u$DB_USER -h$DB_HOST -P$DB_PORT -p$DB_PASSWORD -e 'show processlist' &>/dev/null
	if [ $? -eq 0 ]; then	
		ok_text "时间：$(date '+%Y-%m-%d %H:%m:%S') MySQL连接正常"
	else
		error_text "时间：$(date '+%Y-%m-%d %H:%m:%S') MySQL连接失败"
		exit 1
	fi
}

function check_package(){
	if [ ! -d $BASE_DIR/package ]; then
		error_text "时间：$(date '+%Y-%m-%d %H:%m:%S') XBK相关包缺少，请重新下载"
		exit 1
	fi
	if [ $(ls $BASE_DIR/package | wc -l) -ne 15 ]; then
		error_text "时间：$(date '+%Y-%m-%d %H:%m:%S') XBK相关包缺少，请重新下载"
		exit 1
	else
		ok_text "时间：$(date '+%Y-%m-%d %H:%m:%S') XBK本地安装包完整"
	fi
}

function check_xbk(){
	if [ $(rpm -qa | grep percona-xtrabackup | wc -l) -eq 1 ]; then
		ok_text "时间：$(date '+%Y-%m-%d %H:%m:%S') XBK已经安装"
	else
		yum -y localinstall $BASE_DIR/package/*
		if [ $? -eq 0 ]; then
			ok_text "时间：$(date '+%Y-%m-%d %H:%m:%S') XBK已经安装"
		else
			error_text "时间：$(date '+%Y-%m-%d %H:%m:%S') XBK安装失败"
			exit 1
		fi
	fi
}

function del_full(){
	# 如果之前的全备大于7天，应当删除再重新备份,之所以加6是因为full本身算一天
	if [ $(find $DB_BACKUP_DIR -maxdepth 1 -mindepth 1 -type d -mtime +6 | grep full | wc -l) -ne 0 ]; then
		find $DB_BACKUP_DIR -maxdepth 1 -mindepth 1 -type d -mtime +6 -exec rm -rf {} \;
		if [ $? -eq 0 ]; then
			ok_text "时间：$(date '+%Y-%m-%d %H:%m:%S') full备份被成功清理"
		else
			error_text "时间：$(date '+%Y-%m-%d %H:%m:%S') full备份清理失败" 
		fi
		return 1
	else
		# 没有超过七天的备份
		return 0
	fi
}

function db_full(){
	# 判断是否为第一次全备
	if [ ! -d $DB_BACKUP_DIR/full ]; then
		innobackupex --user=$DB_USER --password=$DB_PASSWORD --no-timestamp $DB_BACKUP_DIR/full &>/dev/null
		if [ $? -ne 0 ]; then
			error_text "时间：$(date '+%Y-%m-%d %H:%m:%S') XBK全备失败"
			exit 1
		else
			ok_text "时间：$(date '+%Y-%m-%d %H:%m:%S') XBK全备成功"
			exit 1 #不让后边db_incre执行
		fi
	else
		# 如果有full,则判断是否存在时间大于7天
		del_full
		# 存在大于7天的备份，清理后重新备份
		if [ $? -eq 1 ]; then
			innobackupex --user=$DB_USER --password=$DB_PASSWORD --no-timestamp $DB_BACKUP_DIR/full &>/dev/null
			if [ $? -ne 0 ]; then
				error_text "时间：$(date '+%Y-%m-%d %H:%m:%S') XBK全备失败"
				exit 1
			else
				ok_text "时间：$(date '+%Y-%m-%d %H:%m:%S') XBK全备成功"
				exit 1
			fi
		fi
	fi
}

function db_incre(){
	# 先判断是否存在incre备份，如果有再判断时候存在大于7天的备份，然后再备份新的增量备份
	if [ $(ls $DB_BACKUP_DIR | grep incre | wc -l) -eq 0 ]; then
		# 第一次增量备份
		innobackupex --user=$DB_USER --password=$DB_PASSWORD --no-timestamp --incremental --incremental-basedir=$DB_BACKUP_DIR/full $DB_BACKUP_DIR/incre1 &>/dev/null
		if [ $? -ne 0 ]; then
				error_text "时间：$(date '+%Y-%m-%d %H:%m:%S') XBK第1次增量备份失败"
				rm -rf $DB_BACKUP_DIR/incre1 &>/dev/null
				exit 1
			else
				ok_text "时间：$(date '+%Y-%m-%d %H:%m:%S') XBK第1次增量备份成功"
		fi
	else
		# 存在incre备份：①:大于7天了，替换 ②:没有大于7天的,创建新的
		if [ $(find $DB_BACKUP_DIR -mindepth 1 -maxdepth 1 -type d -ctime +6 -name "incre*" | wc -l) -eq 0 ]; then #没有大于7天的，则增加incre
			local num=`expr $(ls $DB_BACKUP_DIR | grep incre | awk -F"incre" 'END{print $2}')`
			local tmp=$(( $num+1 ))
			innobackupex --user=$DB_USER --password=$DB_PASSWORD --no-timestamp --incremental --incremental-basedir=$DB_BACKUP_DIR/incre$num $DB_BACKUP_DIR/incre$tmp &>/dev/null
			if [ $? -ne 0 ]; then
				error_text "时间：$(date '+%Y-%m-%d %H:%m:%S') XBK第${tmp}次增量备份失败"
				rm -rf $DB_BACKUP_DIR/incre$num &>/dev/null
				exit 1
			else
				ok_text "时间：$(date '+%Y-%m-%d %H:%m:%S') XBK第${tmp}次增量备份成功"
			fi
		else
			# 存在大于7天的，替换该备份
			local num=$(find $DB_BACKUP_DIR -mindepth 1 -maxdepth 1 -type d -ctime +6 -name "incre*" | awk -F"incre" '{print $2}')
			if [ $num -eq 1 ]; then
				rm -rf $DB_BACKUP_DIR/incre1 &>/dev/null
				innobackupex --user=$DB_USER --password=$DB_PASSWORD --no-timestamp --incremental --incremental-basedir=$DB_BACKUP_DIR/full $DB_BACKUP_DIR/incre1 &>/dev/null
				if [ $? -ne 0 ]; then
					error_text "时间：$(date '+%Y-%m-%d %H:%m:%S') XBK第${num}次增量备份失败"
					exit 1
				else
					ok_text "时间：$(date '+%Y-%m-%d %H:%m:%S') XBK第${num}次增量备份成功"
				fi
			else
				local tmp=$(( $num-1 ))
				rm -rf $DB_BACKUP_DIR/incre$num &>/dev/null
				innobackupex --user=$DB_USER --password=$DB_PASSWORD --no-timestamp --incremental --incremental-basedir=$DB_BACKUP_DIR/incre$tmp $DB_BACKUP_DIR/incre$num &>/dev/null
				if [ $? -ne 0 ]; then
					error_text "时间：$(date '+%Y-%m-%d %H:%m:%S') XBK第${num}次增量备份失败"
					exit 1
				else
					ok_text "时间：$(date '+%Y-%m-%d %H:%m:%S') XBK第${num}次增量备份成功"
				fi
			fi
		fi
	fi
}

# 名字：full,incre1,incre2,incre3,incre4
function db_backup(){
	db_full
	db_incre
}

function useage(){
        echo -e "\033[32m*******************************************************\033[0m"
        echo -e "\033[31m该脚本用于:MySQL XBK全备+增量备份                     \033[0m"
        echo -e "\033[32mUsage:                                                 \033[0m"
        echo -e "\033[32m    bash mysql.sh backup                              \033[0m"
        echo -e "\033[32mMySQL 脚本配置信息                                     \033[0m"
        echo -e "\033[32mMySQL IP: $DB_HOST                                     \033[0m"
        echo -e "\033[32mMySQL PORT: $DB_PORT                                   \033[0m"
        echo -e "\033[32mMySQL USER: $DB_USER                                   \033[0m"
        echo -e "\033[32mMySQL PASSWORD: $DB_PASSWORD                           \033[0m"
        echo -e "\033[32mMySQL LOG: $BACK_LOG                                   \033[0m"
        echo -e "\033[32mMySQL EXPIRE: ${DB_EXPIRE}day                          \033[0m"
        echo -e "\033[32mMySQL BACKUP DIR: $DB_BACKUP_DIR                       \033[0m"
        echo -e "\033[32m*******************************************************\033[0m"
}

case $1 in
	backup)
		useage
		check_user
		check_service
		check_package
		check_xbk
		db_backup
	;;
	*)
		useage
	;;
esac
