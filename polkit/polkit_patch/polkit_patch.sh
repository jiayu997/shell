#!/bin/bash
########################################################################################################
# @mail qujiayu98@163.com
# @author 屈家玉           
########################################################################################################
BASEDIR=$(cd $(dirname ${BASH_SOURCE[0]}); pwd)
function check_network(){
	ping -c 3 -i 1 -W 1 $1 &>/dev/null
	if [ $? -ne 0 ]; then
		echo -n "IP: $1  网络检查：Failed"
		return 1
	else
		echo -n "IP：$1  网络检查：OK"
		return 0
	fi
}
function update_polkit(){
	if [ -f $BASEDIR/polkit_patch.log ]; then
		rm -rf $BASEDIR/polkit_patch.log
	fi
	rpm -Uvh $BASEDIR/package/*.rpm --force --nodeps &>/dev/null && systemctl daemon-reload &>/dev/null && systemctl restart polkit &>/dev/null
	for i in `cat IP.CSV`
	do
		local IP=`echo $i|awk -F',' '{print $1}'`
		local PAS=`echo $i|awk -F',' '{print $2}'`
		check_network $IP
		if [ $? -eq 0 ]; then
			sshpass -p $PAS ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 root@$IP "ls /" &>/dev/null
			if [ $? -eq 0 ]; then
				echo -n "  SSH：连接正常"
				sshpass -p $PAS scp -o StrictHostKeyChecking=no -o ConnectTimeout=5 $BASEDIR/package/{polkit*,glib*}.rpm root@$IP:/tmp &>/dev/null && sshpass -p $PAS ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 root@$IP "rpm -Uvh /tmp/{polkit*,glib2*}.rpm --force --nodeps &>/dev/null && rm -rf /tmp/{polkit*,glib2*}.rpm &>/dev/null && systemctl daemon-reload &>/dev/null && systemctl restart polkit &>/dev/null"	&>/dev/null
				if [ $? -eq 0 ]; then
					echo "  polkit更新状态：OK"
					echo "IP: $IP  网络检查：OK  SSH：连接正常  polkit更新状态：OK" >> $BASEDIR/polkit_patch.log
				else
					echo "  polkit更新状态：NO"
					echo "IP: $IP  网络检查：OK  SSH：连接正常  polkit更新状态：NO" >> $BASEDIR/polkit_patch.log
				fi
			else
				echo "  SSH：无法连接  polkit更新状态：NO"		
				echo "IP: $IP  网络检查：OK  SSH：无法连接  polkit更新状态：NO" >> $BASEDIR/polkit_patch.log
			fi
		else
			echo "  SSH：无法连接  polkit更新状态：NO"
			echo "IP: $IP  网络检查：Failed  SSH：无法连接  polkit更新状态：NO" >> $BASEDIR/polkit_patch.log
		fi
	done
}
update_polkit
