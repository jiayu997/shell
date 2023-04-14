### 说明

`该脚本实现了自动备份MySQL数据库中任意数据库，适合放在crond中运行，定时备份数据库,且在有需要的时候实现自动恢复备份。该脚本只针对库备份，无法实现对表备份`

### 配置信息

```shell
DB_HOST=192.168.0.51 				#数据库主机IP
DB_PORT=3306						#数据库端口
DB_USER=root						#以什么身份运行
DB_PASSWORD=password				#数据库密码
DB_EXPIRE=7							#自动清理一周以前的备份文件
DB_BACKUP_DIR=/backup/mysql			#备份文件保存位置
BASE_DIR=$(cd $(dirname $0);pwd) 	#脚本运行的路径
BACK_LOG=$BASE_DIR/backup.log		#备份与恢复日志保存位置
```

### 命令格式

```shell
# 备份
	bash mysql-backup.sh database-name1 database-name2 database-name3 .....
# 恢复
	bash mysql-restore.sh /the/path/backup1.sql.gz /the/path/backup2.sql.gz .....
```

