#!/bin/bash
####################################### 脚本用途：用于harbor证书更替，不用修改Docker配置(增加不安全配置,完全走https认证)，不用重启Docker ################
function validate_ip(){
    IP=$1
    VALID_CHECK=$(echo $IP|awk -F. '$1<=255&&$2<=255&&$3<=255&&$4<=255{print "yes"}')
    if echo $IP|grep -E "^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$">/dev/null; then
        if [ ${VALID_CHECK:-no} == "yes" ]; then
	    return 0
        else
	    return 1
        fi
    else
	    return 1
    fi
}


read -p "请输入Harbor IP或者Harbor域名: " harbor

openssl genrsa -out ca.key 4096
openssl req -x509 -new -nodes -sha512 -days 3650  -subj "/CN=$harbor"  -key ca.key  -out ca.crt
openssl genrsa -out tls.key 4096
openssl req  -new -sha512  -subj "/CN=$harbor"  -key tls.key  -out server.csr

validate_ip $harbor

# ip类型证书
if [ $? -eq 0 ]; then
cat > v3.ext <<- EOF
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names
[alt_names]
IP.1=$harbor
EOF
else
# 域名类型证书
cat > v3.ext <<- EOF
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names
[alt_names]
DNS.1=$harbor
EOF
fi

openssl x509 -req -sha512 -days 36500 -extfile v3.ext -CA ca.crt -CAkey ca.key -CAcreateserial -in server.csr -out tls.crt

echo "########  证书生成完成，请按如下步骤替换证书 ##############"
echo "1. 如果harbor是docker-compose部署的,在harbor安装目录下的common/config/nginx/conf.d 替换证书"
echo "2. 如果harbor是helm部署的，请找到harbor-nginx的证书secret替换，命令类似：kubectl create secret generic c2-harbor-nginx -n admin --from-file=ca.crt --from-file=tls.crt --from-file=tls.key"
echo "3. 拷贝当前目录下的ca.crt到集群所有节点的/etc/docker/certs.d/harbor_ip:harbor_port/ca.crt"
