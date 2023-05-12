#!/bin/bash
base_dir=$(cd $(dirname ${BASH_SOURCE[0]}) &>/dev/null && pwd)


function get_harbor_info_v2(){
    local project_list=()
    local page_all=5
    local page_size=100
    if [ -f $base_dir/harbor_image_list ]; then
        rm -rf $base_dir/harbor_image_list
    fi
    for ((i=1;i<=$page_all;i++))
    do
        # 获取当前所有project name
        project_list=($(curl -s -k -u $harbor_user:$harbor_password  -H "Content-Type: application/json" -X GET  "https://$harbor_ip:$harbor_port/api/v2.0/projects?page=$i&page_size=$page_size" | jq | awk '/"name": /' | awk -F'"' '{print $4}') ${project_list[@]})
    done
    for i in ${project_list[@]}
    do
        local image_name_list=()
        for ((j=1;j<=$page_all;j++))
        do
            # 获取项目下所有的镜像名称
            image_name_list=($(curl -s -k -u $harbor_user:$harbor_password -H "Content-Type: application/json" -X GET "https://$harbor_ip:$harbor_port/api/v2.0/projects/$i/repositories?page=$j&page_size=$page_size" | jq | awk '/"name": /' | awk -F '"' '{print $4}') ${image_name_list[@]})
        done
        for j in ${image_name_list[@]}
        do
            local image_tags=()
            for ((l=1;l<=$page_all;l++))
            do
                # 获取镜像名称下所有的tags
                image_tags=($(curl -s -k -u $harbor_user:$harbor_password  -H "Content-Type: application/json" -X GET  "https://$harbor_ip:$harbor_port/api/v2.0/projects/$i/repositories/${j#*/}/artifacts?page=$l&page_size=$page_size"  | jq | awk '/"name": /' | awk -F '"' '{print $4}') ${image_tags[@]})
            done
            for k in ${image_tags[@]}
            do
                echo "获得镜像坐标：$harbor_ip:$harbor_port/$j:$k"
                echo "$harbor_ip:$harbor_port/$j:$k" >> $base_dir/harbor_image_list
            done
        done
    done
}

function get_harbor_info_v1(){
    local page_all=5
    local page_size=100
    local project_list=()
    if [ -f $base_dir/harbor_image_list ]; then
        rm -rf $base_dir/harbor_image_list
    fi
    # 获取所有项目列表和项目ID，格式为：44:lzzh 37:test
    for  ((i=1;i<=$page_all;i++))
    do
        local project_id=($(curl -s -k -X GET -u $harbor_user:$harbor_password -H 'Accept: application/json' "https://$harbor_ip:$harbor_port/api/projects?page=$i&page_size=$page_size" | jq | awk '/"project_id"/' | grep -oE "[0-9]{1,}"))
        local project_name=($(curl -s -k -X GET -u $harbor_user:$harbor_password -H 'Accept: application/json' "https://$harbor_ip:$harbor_port/api/projects?page=$i&page_size=$page_size" | jq | awk '/"name"/' | awk -F '"' '{print $4}'))
        local tmp=()
        for i in ${!project_id[@]}
        do
            tmp[$i]="${project_id[$i]}:${project_name[$i]}"
        done
        project_list=(${tmp[@]} ${project_list[@]})
    done
    for i in ${project_list[@]}
    do
        local image_name_list=()
        for ((j=1;j<=$page_all;j++))
        do
            local project_id=`echo "$i" | awk -F":" '{print $1}'`
            # 存在这种镜像：harbor_ip:harbor_port/qszjjzh/cptactionhank/atlassian-confluence:v2,需注意,但无需单独做处理
            # 获取镜像列表，qszjjzh/cptactionhank/atlassian-confluence:v2，qszjjzh/trade
            image_name_list=($(curl -s -k -X GET -u $harbor_user:$harbor_password -H 'Accept: application/json' "https://$harbor_ip:$harbor_port/api/repositories?project_id=$project_id&page=$j&page_size=$page_size" | jq | awk '/"name": /' | awk -F '"' '{print $4}') ${image_name_list[@]})
        done
        for j in ${image_name_list[@]}
        do
            local image_tags=()
            # 参考链接：https://$harbor_ip:$harbor_port/api/repositories/qszjjzh/ehn/tags
            image_tags=($(curl -s -k -X GET -u $harbor_user:$harbor_password -H 'Accept: application/json' "https://$harbor_ip:$harbor_port/api/repositories/$j/tags" | jq | awk '/"name": /' | awk -F '"' '{print $4}') ${image_tags[@]})
            for k in ${image_tags[@]}
            do
                echo "获得镜像坐标：$harbor_ip:$harbor_port/$j:$k"
                echo "$harbor_ip:$harbor_port/$j:$k" >> $base_dir/harbor_image_list
            done
        done
    done
}

function harbor_version(){
    # v2
    if curl -I --connect-timeout 1 --max-time 1 -s -k -X GET -u $1:$2 -H "Content-Type: application/json" "https://$3:$4/api/v2.0/projects" | grep 200 &>/dev/null ; then
        return 2
    fi
    # v1
    if curl -I --connect-timeout 1 --max-time 1 -s -k -X GET -u $1:$2 -H 'Accept: application/json' "https://$3:$4/api/projects" | grep 200 &>/dev/null ; then
        return 1
    fi
    echo "获取harbor版本信息失败"
    exit 1
}

function backup_harbor(){
    if [ ! -d $base_dir/harbor-backup ]; then
        mkdir -p $base_dir/harbor-backup
    fi
    if [ ! -f $base_dir/harbor_image_list ]; then
        echo "本地未存在镜像坐标文件，请先运行1，获取镜像坐标文件"
        exit 1
    fi
    # 172.17.80.96:443/qszjjzh/cptactionhank/atlassian-confluence:7.4.0 由于存在这种命名不规范镜像，这里采用正则处理,并丢弃部分
    for i in `cat harbor_image_list`
    do
        local image_name=`echo ${i##*/} | awk -F':' '{print $1}'`
        local image_tags=`echo ${i##*/} | awk -F':' '{print $2}'`
        local project_name=`echo $i | awk -F'/' '{print $2}'`
        local date=`date "+%m-%d-%H-%M"` #格式：07-10-18-45
        ## 防止未拉取下来也执行备份
        docker pull $i && docker save $i > $base_dir/harbor-backup/${date}-$[$(date +%s%N)/1000000]-$project_name-$image_name-$image_tags
        # 取消rmi 动作
        #docker rmi $i
    done
}

# v1版新建项目都是私有的，这里不做处理了
function create_project(){
    if [ "$1" == "2" ]; then
        curl -u "$3:$4" -X POST -k -H "Content-Type: application/json" "https://$5:$6/api/v2.0/projects" -d '{"project_name": '"\"$2\""',"public": true}' &>/dev/null
    fi
    if [ "$1" == "1" ]; then
        curl -u "$3:$4" -X POST -k -H "Content-Type: application/json" "https://$5:$6/api/projects" -d '{"project_name": '"\"$2\"}" &>/dev/null
    fi
    if [ $? -eq 0 ]; then
        echo "项目：$2 创建成功!"
    else
        echo "项目：$2 创建失败!"
        exit 1
    fi
}

function backup_restore(){
    if [ ! -d $base_dir/harbor-backup ]; then
        echo "未发现备份文件夹"
        exit 1
    fi
    for i in $base_dir/harbor-backup/*
    do
        docker load -i $i
    done
}

function push_new_harbor(){
    if [ ! -f $base_dir/harbor_image_list ]; then
        echo "本地未存在镜像坐标文件，请先运行1，获取镜像坐标文件"
        exit 1
    fi
    echo "下面开始根据获取的镜像坐标文件将镜像推送到新harbor,请填写正确信息"
    read -p "请输入新harbor ip:  " new_harbor_ip
    read -p "请输入新harbor port:  " new_harbor_port
    read -p "请输入新harbor username:  " new_harbor_username
    read -p "请输入新harbor password:  " new_harbor_password
    if ! docker login -u $new_harbor_username -p $new_harbor_password $new_harbor_ip:$new_harbor_port &>/dev/null ; then
        echo "docker login 失败，请先解决该问题"
        exit 1
    fi
    harbor_version $new_harbor_username $new_harbor_password $new_harbor_ip $new_harbor_port
    harbor_api=$?
    # 获取所有project_name
    local project_list=$(cat harbor_image_list | awk -F/ '{print $2}' | uniq)
    # 创建project,全部公开
    for i in ${project_list[@]}
    do
        create_project $harbor_api $i $new_harbor_username $new_harbor_password $new_harbor_ip $new_harbor_port
    done
   # 开始拉取镜像，并推送到新harbor节点
    for i in `cat harbor_image_list`
    do
        docker pull $i
        docker tag $i $new_harbor_ip:$new_harbor_port/${i#*/}
        docker push $new_harbor_ip:$new_harbor_port/${i#*/}
#  不做删除动作
#        docker rmi $i
#        docker rmi $new_harbor_ip:$new_harbor_port/${i#*/}
    done
}

function local_push_harbor(){
    #  NF != 3的坐标，都不推送到harbor， 不规范的镜像这里都不做处理了
    # grafana/grafana:8.5.1  这种坐标全部推送到harbor_ip:harbor_port/admin下面去
    # local two_image_list=($(docker image ls | awk 'NR>1 {print $1,$2}' OFS=':' | awk -F'/' 'NF==2'))
    # kong:2.8.1 这种坐标全部推送到harbor_ip:harbor_port/admin下面去
    # local one_image_list=($(docker image ls | awk 'NR>1 {print $1,$2}' OFS=':' | awk -F'/' 'NF==2'))

    # 完整坐标,不规范的镜像不会推送到harbor
    local full_image_list=($(docker image ls | awk 'NR>1 {print $1,$2}' OFS=':' | awk -F'/' 'NF>=3'))
    # project name
    local project_name=($(docker image ls | awk 'NR>1 {print $1,$2}' OFS=':' | awk -F'/' 'NF>=3' | awk -F'/' '{print $2}' | sort | uniq))
    echo "下面开始将本地镜像推送到harbor,请填写正确信息"
    read -p "请输入harbor ip:  " new_harbor_ip
    read -p "请输入harbor port:  " new_harbor_port
    read -p "请输入harbor username:  " new_harbor_username
    read -p "请输入harbor password:  " new_harbor_password
    if ! docker login -u $new_harbor_username -p $new_harbor_password $new_harbor_ip:$new_harbor_port &>/dev/null ; then
        echo "docker login 失败，请先解决该问题"
        exit 1
    fi
    harbor_version $new_harbor_username $new_harbor_password $new_harbor_ip $new_harbor_port
    harbor_api=$?
    # 创建project 
    for i in ${project_name[@]}
    do
        create_project $harbor_api $i $new_harbor_username $new_harbor_password $new_harbor_ip $new_harbor_port
    done
    # 将本地镜像推送到harbor
    for i in ${full_image_list[@]}
    do
        docker tag $i $new_harbor_ip:$new_harbor_port/${i#*/}
        docker push $new_harbor_ip:$new_harbor_port/${i#*/}
    done
}

function useage(){
    echo "bash shell_name [1|2|3|4]"
    echo "1. harbor所有镜像坐标(保存到$base_dir/harbor_image_list)"
    echo "2. harbor(旧)镜像备份到本地$base_dir/harbor-backup"
    echo "3. harbor(旧)镜像恢复(本地加载之前备份的镜像)"
    echo "4. harbor(旧)镜像推送到harbor(新)-(适合新老harbor同时存在)"
    echo "5. 本机镜像推送到harbor"
}

function get_image_cordinate(){
    read -p "请输入harbor ip:  " harbor_ip
    read -p "请输入harbor port:  " harbor_port
    read -p "请输入harbor username:  " harbor_user
    read -p "请输入harbor password:  " harbor_password
    harbor_version $harbor_user $harbor_password $harbor_ip $harbor_port  # username password harbor_ip harbor_port
    if [ $? -eq 2 ]; then
        get_harbor_info_v2
    elif [ $? -eq 1 ]; then
        get_harbor_info_v1
    fi
}

if ! command -v jq &>/dev/null ; then
    if ! rpm -ivh $base_dir/packages/{jq-1.6-2,oniguruma-6.8.2-2}.el7.x86_64.rpm &>/dev/null ; then
        echo "jq 安装失败，无法运行脚本"
        exit 1
    fi
fi

if ! command -v curl &>/dev/null; then
    echo "curl 命令未安装，请手动安装"
    exit 1
fi

if ! command -v docker &>/dev/null; then
    echo "未安装docker，无法运行脚本"
    exit 1
fi

if [ -f $base_dir/harbor_image_list ]; then
    read -p "检测到本地已存在镜像坐标文件，是否删除Y/N: " choice
    if [[ "$choice" =~ Y|y ]]; then
        rm -rf $base_dir/harbor_image_list
    fi
fi

case $1 in
    "get_image_cordinate")
        get_image_cordinate
    ;;
    "backup_harbor")
        backup_harbor
    ;;
    "backup_restore")
        backup_restore
    ;;
    "push_new_harbor")
        push_new_harbor
    ;;
    "local_push_harbor")
        local_push_harbor
    ;;
    *)
        useage
    ;;
esac