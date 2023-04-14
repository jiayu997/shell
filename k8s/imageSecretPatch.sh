#!/bin/bash
#########################  auth: qujiayu98@163.com  ######################################
#########################  用于批量为deployment/statefulset/daemonset 批量生产imagePullSecret 
##################################################################################################
#deploymentList=$(kubectl get deployment --all-namespaces | awk -v OFS=: 'NR>1{print $1,$2}')
#statefulsetList=$(kubectl get statefulset --all-namespaces | awk -v OFS=: 'NR>1{print $1,$2}')
#daemonsetList=$(kubectl get daemonsets --all-namespaces | awk -v OFS=: 'NR>1{print $1,$2}')
namespace=$3
imageSecretName="c2cloud"
harbor_server="https://172.24.1.239:30008"
harbor_username="admin"
harbor_password="Kec12345"


function CreateImageSecret(){
	namespaceList=$(kubectl get namespaces | awk 'NR>1{print $1}')
	for namespace in ${namespaceList[@]}; do
		kubectl create secret docker-registry $imageSecretName -n $namespace --docker-server=$harbor_server --docker-username=$harbor_username --docker-password=$harbor_password
	done
}

function DeleteImageSecret(){
	namespaceList=$(kubectl get namespaces | awk 'NR>1{print $1}')
	for namespace in ${namespaceList[@]}; do
		kubectl delete secret $imageSecretName -n $namespace
	done
}

function AddImageSecretForDeployment(){
	local deploymentList=$(kubectl get deployment -n $namespace | awk 'NR>1{print $1}')
	for i in ${deploymentList[@]}; do
		#local namespace=${i%:*}
		#local deployment=${i#*:}
		local deployment=$i
		kubectl patch deployment $deployment -n $namespace -p '{"spec": {"template": {"spec": {"imagePullSecrets": [{"name": '"\"$imageSecretName\""'}]}}}}' &>/dev/null
		if [[ $? -ne 0 ]]; then
			echo "namespace: $namespace deployment: $deployment patch failed"
			exit 1
		else
			echo "namespace: $namespace deployment: $deployment patch ok"
		fi
	done
}

function AddImageSecretForStatefulSet(){
	local statefulsetList=$(kubectl get statefulset -n $namespace | awk 'NR>1{print $1}')
	for i in ${statefulsetList[@]}; do
		local statefulset=$i
		kubectl patch statefulset $statefulset -n $namespace -p '{"spec": {"template": {"spec": {"imagePullSecrets": [{"name": '"\"$imageSecretName\""'}]}}}}' &>/dev/null
		if [[ $? -ne 0 ]]; then
			echo "namespace: $namespace statefulset: $statefulset patch failed"
			exit 1
		else
			echo "namespace: $namespace statefulset: $statefulset patch ok"
		fi
	done
}

function AddImageSecretForDaemonset(){
	local daemonsetList=$(kubectl get daemonset -n $namespace | awk 'NR>1{print $1}')
	for i in ${daemonsetList[@]}; do
		daemonset=$i
		kubectl patch daemonset $daemonset -n $namespace -p '{"spec": {"template": {"spec": {"imagePullSecrets": [{"name": '"\"$imageSecretName\""'}]}}}}' &>/dev/null
		if [[ $? -ne 0 ]]; then
			echo "namespace: $namespace daemonset: $daemonset patch failed"
			exit 1
		else
			echo "namespace: $namespace daemonset: $daemonset patch ok"
		fi
	done
}

#kubectl get pods --all-namespaces -o json | sed 's/"imagePullSecrets": \[[^]]\+\]/"imagePullSecrets": []/g' | kubectl apply -f -
#kubectl patch deployment metrics-server -n kube-system --type json -p='[{"op": "remove", "path": "/spec/template/spec/imagePullSecrets/0"}]'
#kubectl patch deployment coredns -n kube-system -p '{"spec": {"template": {"spec": {"imagePullSecrets": null}}}}'
function DeleteImageSecretForDeployment(){
	local deploymentList=$(kubectl get deployment -n $namespace | awk 'NR>1{print $1}')
	for i in ${deploymentList[@]}; do
		local deployment=$i
		kubectl patch deployment $deployment -n $namespace -p '{"spec": {"template": {"spec": {"imagePullSecrets": null}}}}' &>/dev/null
		if [[ $? -ne 0 ]]; then
			echo "namespace: $namespace deployment: $deployment delete failed"
			exit 1
		else
			echo "namespace: $namespace deployment: $deployment delete ok"
		fi
	done
}

function DeleteImageSecretForStatefulSet(){
	local statefulsetList=$(kubectl get statefulset -n $namespace | awk 'NR>1{print $1}')
	for i in ${statefulsetList[@]}; do
		local statefulset=$i
		kubectl patch statefulset $statefulset -n $namespace -p '{"spec": {"template": {"spec": {"imagePullSecrets": null}}}}' &>/dev/null
		if [[ $? -ne 0 ]]; then
			echo "namespace: $namespace statefulset: $statefulset delete failed"
			exit 1
		else
			echo "namespace: $namespace statefulset: $statefulset delete ok"
		fi
	done
}

function DeleteImageSecretForDaemonset(){
	local daemonsetList=$(kubectl get daemonset -n $namespace | awk 'NR>1{print $1}')
	for i in ${daemonsetList[@]}; do
		daemonset=$i
		kubectl patch daemonset $daemonset -n $namespace -p '{"spec": {"template": {"spec": {"imagePullSecrets": [{"name": '"\"$imageSecretName\""'}]}}}}' &>/dev/null
		if [[ $? -ne 0 ]]; then
			echo "namespace: $namespace daemonset: $daemonset patch failed"
			exit 1
		else
			echo "namespace: $namespace daemonset: $daemonset patch ok"
		fi
	done
}

function useage(){
	echo "1. 首先创建imagesecret(事先填写harbor账号信息): ./script_name createImageSecret"
	echo "2. 添加imagepullsecret"
	echo "	deployment批量添加imagepullsecret:    ./script_name addImageSecret deployment namespace_name"
	echo "	daemonset批量添加imagepullsecret:     ./script_name addImageSecret daemonset namespace_name"
	echo "	statefulset批量添加imagepullsecret:   ./script_name addImageSecret statefulset namespace_name"
	echo "	deployment批量删除imagepullsecret:    ./script_name deleteImageSecret deployment namespace_name"
	echo "	daemonset批量删除imagepullsecret:     ./script_name deleteImageSecret daemonset namespace_name"
	echo "	statefulset批量删除imagepullsecret:   ./script_name deleteImageSecret statefulset namespace_name"
}

case $1 in
"createImageSecret")
	CreateImageSecret
;;
"deleteImageSecret")
	DeleteImageSecret
;;
"addImageSecret")
	case $2 in
	"deployment")
		AddImageSecretForDeployment
	;;
	"statefulset")
		AddImageSecretForStatefulSet
	;;
	"daemonset")
		AddImageSecretForDaemonset
	;;
	*)
		useage
	;;
	esac
;;
"deleteImageSecret")
	case $2 in
	"deployment")
		DeleteImageSecretForDeployment
	;;
	"statefulset")
		DeleteImageSecretForStatefulSet
	;;
	"daemonset")
		DeleteImageSecretForDaemonset
	;;
	*)
		useage
	;;
	esac
;;
*)
	useage
;;
esac
