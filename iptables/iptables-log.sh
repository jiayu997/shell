#!/bin/bash
######################################################################
################ author: qujiayu98@163.com      ######################
#### 1. the script just used to analyse iptables filter sequence
#### 2. plese don't used in production
################################## end ################################

set -e
set -u

# get current iptables rule
iptables_save=$(iptables-save | grep -E "^\-|^\*")
new_iptables_save=""

while IFS=$"\n" read -r rule ; do
	if [[ $rule =~ ^\* ]]; then
		table=$(awk -F'*' '{print $2}' <<< $rule)
		new_iptables_save+="$rule\n"
		continue
	fi
	if [[ $rule =~ ^: ]]; then
		new_iptables_save+="$rule\n"
		continue
	fi
	#chain=$(awk '{print $2}' <<< $rule)
	#expression=$(echo "$rule" | sed -r "s@(.*)-j(.*)@\1-j -m limit --limit-burst 1 --limit 1/second -j LOG --log-prefix \"$table|$chain\" --log-level debug@g")
	#new_iptables_save+="$expression\n$rule\n"
done <<< "${iptables_save[@]}"

echo -e "${new_iptables_save}"
#iptables-restore <<< $(echo -e "${new_iptables_save}")
