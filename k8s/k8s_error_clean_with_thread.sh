#!/bin/bash
# 最大并发线程数
MAX_THREAD=30

# 最大异常pod数，超过这个数其控制器副本数量将会被设置为0
MAX_ERROR_PODS_NUM=5

# admin:alertmanager-c2-monitor-kube-prometheus-alertmanager-0:Running:22
POD_LIST=$(kubectl get pods --all-namespaces | grep -v "Running" | awk -v OFS=: 'NR>1{print $1,$2,$4,$5}')

# 日志
function logger(){
  TIMESTAMP=$(date +'%Y-%m-%d %H:%M:%S')
  case "$1" in
    debug)  # 浅蓝
      echo -e "\033[36m[ DEBUG ]\033[0m $2"
      ;;
    info)   # 绿色
      echo -e "\033[32m[ INFO ]\033[0m $2"
      ;;
    warn)   # 黄色
      echo -e "\033[33m[ WARN ]\033[0m $2"
      ;;
    error)  # 红色
      echo -e "\033[31m[ ERROR ]\033[0m $2"
      ;;
    *)
      ;;
  esac
}

# 初始化管道
function init_fd(){
  # 创建有名管道
  [ -e /tmp/$$ ] || mkfifo /tmp/$$

  #创建文件描述符，以可读（<）可写（>）的方式关联管道文件,文件描述符10拥有有名管道文件的所有特性
  exec 10<>/tmp/$$
  
  # 文件描述符关联后拥有管道的所有特性，删除管道
  rm -rf /tmp/$$

  # 初始化,往管道里面放xx个令牌,用于模拟最大并发
  for i in `seq 1 $MAX_THREAD` ; do
    echo "key" >&10
  done
}

# 关闭管道
function close_fd(){
  exec 10<&-
  exec 10>&-
}

# 将异常的pod副本deployment控制器副本设置为0
function scale_deployment_to_zero(){
  # admin:c2-ama
  DEPLOYMENT_LIST=$(kubectl get deployment --all-namespaces | awk -v OFS=: 'NR>1{print $1,$2}')

  # 遍历deploy
  for i in ${DEPLOYMENT_LIST[@]}; do
    # 取出令牌
    read -u10
    {
      local deploymentNamespace=$(echo $i | awk -F: '{print $1}')
      local deploymentName=$(echo $i | awk -F: '{print $2}')
      # 不能用for去遍历处理，时间复杂度是O(n),在异常情况下CPU会炸
      local errorCount=$(echo "${POD_LIST[@]}" | grep -E "^$deploymentNamespace:$deploymentName-[0-9a-zA-Z]{1,}-[0-9a-zA-Z]{1,}:" | wc -l)

      # 对异常pod数>=xx的，deployment副本设置为0
      if [[ $errorCount -gt $MAX_ERROR_PODS_NUM ]]; then
          echo "namespace: $deploymentNamespace  deployment: $deploymentName errorCount $errorCount"
         #kubectl scale deployment $deploymentName --replicas=0 -n $deploymentNamespace &>/dev/null \
         #&& logger info "namespace: $deploymentNamespace  deployment: $deploymentName errorCount $errorCount scale to 0 sucess" \
         #|| logger error "namespace: $deploymentNamespace  deployment: $deploymentName errorCount $errorCount scale to 0 failed"
      fi
      echo "key" >&10
    }&
  done
  logger info "wait for exit"
  # 等待子进程退出
  wait
}

# 将异常的pod副本statefulset控制器副本设置0
function scale_statefulset_to_zero(){
  # admin:c2-harbor-harbor-database
  STS_LIST=$(kubectl get sts --all-namespaces | awk -v OFS=: 'NR>1{print $1,$2}')

  # 遍历sts
  for i in ${STS_LIST[@]}; do
    # 取出令牌
    read -u10
    {
      local stsNamespace=$(echo $i | awk -F: '{print $1}')
      local stsName=$(echo $i | awk -F: '{print $2}')
      # 不能用for去遍历处理，时间复杂度是O(n),在异常情况下CPU会炸
      local errorCount=$(echo "${POD_LIST[@]}" | grep -E "^$stsNamespace:$stsName-[0-9]{1,}:" | wc -l)
      if [[ $errorCount -gt $MAX_ERROR_PODS_NUM ]]; then
        echo "namespace: $stsNamespace statefulset: $stsName errorCount $errorCount" 
        #kubectl scale statefulset $stsName --replicas=0 -n $stsNamespace &>/dev/null \
        #&& logger info "namespace: $stsNamespace  deployment: $stsName errorCount: $errorCount scale to 0 sucess" \
        #|| logger error "namespace: $stsNamespace  deployment: $stsName errorCount $errorCount scale to 0 failed"
      fi
      echo "key" >&10
    }&
  done
  logger info "wait for exit"
  # 等待子进程退出
  wait
}

# 删除集群异常pod
function delete_pod(){
  # 清理pod
  for i in ${POD_LIST[@]}; do
    # 取出令牌
    read -u10
    {
      local podNameSpace=$(echo $i | awk -F: '{print $1}')
      local podName=$(echo $i | awk -F: '{print $2}')
      logger info "namespace: $podNameSpace  pod: $podName will be delete" 
      kubectl delete pods $podName -n $podNameSpace &>/dev/null --force --grace-period=0 \
      && logger info "namespace: $podNameSpace  pod: $podName delete sucess" \
      || logger error "namespace: $podNameSpace  pod: $podName delete failed"
      echo "key" >&10
    }&
  done
  logger info "wait for exit"
  # 等待子进程退出
  wait
}

# 初始化管道
init_fd

# 删除异常pod
delete_pod

# 将异常deployment副本数设置为0
scale_deployment_to_zero

# 将异常sts
scale_statefulset_to_zero

# 关闭管道
close_fd
