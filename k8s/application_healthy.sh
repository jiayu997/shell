#!/bin/bash

# admin:pms-apigateway-5966447d5d-fsrh7:172.20.0.119
pod_list=`kubectl get pods --all-namespaces -o wide | awk 'NR>1{print $1,$2,$7}' OFS=":"`
service_list=(
"admin:deployment:xgkschj-ams:8080"
)
function app_healthz(){
        for i in ${service_list[@]}
        do
                if [ "$(echo $i | awk -F: '{print $2}')"  == "deployment" ]; then
                        local app_namespace=$(echo $i | awk -F: '{print $1}')
                        local app_name=$(echo $i | awk -F: '{print $3}')
                        local healthz_port=$(echo $i | awk -F: '{print $4}')
                        local pod_name=($(echo "$pod_list" | grep -E "^$app_namespace:$app_name-[0-9a-zA-Z]{1,}-[0-9a-zA-Z]{1,}:" | awk -F: '{print $2}'))
                        local pod_ip=($(echo "$pod_list" | grep -E "^$app_namespace:$app_name-[0-9a-zA-Z]{1,}-[0-9a-zA-Z]{1,}:" | awk -F: '{print $3}'))
                        printf "\033[33m##########################命名空间：%-5s 应用名称：%-15s \033[0m\n" $app_namespace $app_name
                        if [ ${#pod_name[@]} -eq 0 ]; then
                                printf "\033[41;37m应用不存在实例\033[0m\n"
                                printf "\033[33m######################################################################################\033[0m\n\n"
                                continue
                        fi
                        for j in ${!pod_name[@]};do
                                if [ "$app_name" == "xgkschj-ams" ]; then
                                        if curl -s -I -L --connect-timeout 3 --max-time 3 ${pod_ip[$j]}:$healthz_port/introspect?access_token=123 | grep -E "200|302" &>/dev/null; then
                                                printf "\033[32m%-30s %-16s 健康检查成功\033[0m\n" ${pod_name[$j]} ${pod_ip[$j]}
                                                continue
                                        else
                                                printf "\033[41;37m%-30s %-16s 健康检查失败\033[0m\n" ${pod_name[$j]} ${pod_ip[$j]}
                                                continue
                                        fi
                                fi
                                if curl -s -I --connect-timeout 3 --max-time 3 ${pod_ip[$j]}:$healthz_port/gaokao_anon/v1/system/health/redisHealth | grep -E "200|302" &>/dev/null; then
                                        printf "\033[32m%-30s %-16s Redis健康检查成功\033[0m" ${pod_name[$j]} ${pod_ip[$j]}
                                else
                                        printf "\033[41;37m%-30s %-16s Redis健康检查失败\033[0m" ${pod_name[$j]} ${pod_ip[$j]}
                                fi
                                if curl -s -I --connect-timeout 3 --max-time 3 ${pod_ip[$j]}:$healthz_port/gaokao_anon/v1/system/health/ywdbHealth | grep -E "200|302" &>/dev/null; then
                                        printf "\033[32m 数据库健康检查成功\033[0m\n"
                                else
                                        printf "\033[41;37m 数据库健康检查失败\033[0m\n"
                                fi
                        done
                        printf "\033[33m######################################################################################\033[0m\n\n"
                fi
        done
}

function app_log_check(){
        keyword=$1
        for i in ${service_list[@]}
        do
                if [ "$(echo $i | awk -F: '{print $2}')"  == "deployment" ]; then
                        local app_namespace=$(echo $i | awk -F: '{print $1}')
                        local app_name=$(echo $i | awk -F: '{print $3}')
                        local pod_name=($(echo "$pod_list" | grep -E "^$app_namespace:$app_name-[0-9a-zA-Z]{1,}-[0-9a-zA-Z]{1,}:" | awk -F: '{print $2}'))
                        printf "\033[33m##########################命名空间：%-5s 应用名称：%-15s \033[0m\n" $app_namespace $app_name
                        if [ ${#pod_name[@]} -eq 0 ]; then
                                printf "\033[41;37m应用不存在实例\033[0m\n"
                                printf "\033[33m######################################################################################\033[0m\n\n"
                                continue
                        fi
                        for j in ${!pod_name[@]}; do
                               pod_log=$(kubectl logs ${pod_name[$j]} -n $app_namespace --since=10m)
                               if [[ -z "$pod_log" ]]; then
                                        printf "\033[32m%s应用10分钟内未发现-\"${keyword}\"关键字日志\033[0m\n" ${pod_name[$j]}
                                        continue
                               fi
                               if echo "$pod_log" | tac |grep -i -q "$keyword" ; then
                                        printf "\033[41;37m%s应用10分钟内发现\"${keyword}\"关键字日志\033[0m\n" ${pod_name}
                                        echo "$pod_log" | grep -i -A 5 -m 3 "$keyword"
                               else
                                        printf "\033[32m%s应用10分钟内未发现-\"${keyword}\"关键字日志\033[0m\n" ${pod_name[$j]}
                               fi
                        done
                fi
        done
}

function usage(){
        printf "\033[32m 查询应用日志:     bash $0 -l \"Caused by\"\033[0m\n"
        printf "\033[32m 查询应用日志:     bash $0 -l \"其他关键字\" \033[0m\n"
        printf "\033[32m 检查应用健康状态:  bash $0 -c \033[0m\n"
}

while getopts "l:c" opt; do
        case "$opt" in
                'l')
                        keyword="$OPTARG"
                        app_log_check "$keyword"
                ;;
                'c')
                        app_healthz
                ;;
                ?)
			usage
                        exit 1
                ;;
	esac
done
#shift $((OPTIND-1))
