#!/bin/bash
# Config HAproxy tool for Swift.
# jingshao_AT_cnic_DOT_cn May 2. 2013

. ./build_swift_cfg.sh

if [ -z "${HAPROXY_HOST}" ]
then
	echo "No HAProxy host"
else
	echo "HAProxy host: "${HAPROXY_HOST}

	is_Exist=`sshpass -p ${PASS_ROOT} ssh -o StrictHostKeyChecking=no root@${HAPROXY_HOST} dpkg -l | grep haproxy`

	if [ -z "${is_Exist}" ]
	then
		echo "Installing HAProxy"
		sshpass -p ${PASS_ROOT} ssh -o StrictHostKeyChecking=no root@${HAPROXY_HOST} apt-get -y --force-yes install haproxy
	fi
	
cat > /var/test_haproxy.cfg << _wrtend_
global
        log 127.0.0.1   local0
	log 127.0.0.1   local1 notice
	maxconn 4096
        user haproxy
	group haproxy
	daemon

defaults
	log     global
	mode    http
        option  httplog
	option  dontlognull
	retries 3
	option redispatch
	maxconn 2000
	contimeout      5000
	clitimeout      50000
	srvtimeout      50000

listen 	admin_stat
	bind 0.0.0.0:8888
	mode	http
	stats 	refresh	30s
	stats uri /haproxy_stats
	stats realm Haproxy\ Statistics
	stats auth admin:admin
	stats hide-version

listen	swift	0.0.0.0:8081
	mode	http
	option	httplog
	balance	source
	maxconn 20000
_wrtend_

	for zone in ${ZONES[@]};do
		eval nodes=\${$zone[@]}
		for node in ${nodes[@]}
		do
			echo "	server swift_${node} ${node}:8080 maxconn 5000" >> /var/test_haproxy.cfg
		done
	done

	sshpass -p ${PASS_ROOT} scp -o StrictHostKeyChecking=no /var/test_haproxy.cfg ${HAPROXY_HOST}:${HAPROXY_CONF_DIR}/haproxy.cfg
	sshpass -p ${PASS_ROOT} ssh -o StrictHostKeyChecking=no root@${HAPROXY_HOST} haproxy -f ${HAPROXY_CONF_DIR}/haproxy.cfg

	swift_service_id=`sshpass -p ${PASS_ROOT} ssh -o StrictHostKeyChecking=no root@${AUTH_HOST} keystone --os-username admin --os_password ${PASS_AUTH} --os_tenant_name admin --os_auth_url http://${AUTH_HOST}:5000/v2.0 service-list | grep object-store | awk '{print $2}'`

	endpoint_id=`sshpass -p ${PASS_ROOT} ssh -o StrictHostKeyChecking=no root@${AUTH_HOST} keystone --os-username admin --os_password ${PASS_AUTH} --os_tenant_name admin --os_auth_url http://${AUTH_HOST}:5000/v2.0 endpoint-list | grep ${swift_service_id} | awk '{print $2}'`

	echo "swift service id: "${swift_service_id}", endpoint id: "${endpoint_id}

	echo "Add new endpoint for HAProxy"
	sshpass -p ${PASS_ROOT} ssh -o StrictHostKeyChecking=no root@${AUTH_HOST} keystone --os-username admin --os_password ${PASS_AUTH} --os_tenant_name admin --os_auth_url http://${AUTH_HOST}:5000/v2.0 endpoint-create --region RegionOne --service-id=${swift_service_id} --publicurl="http://${HAPROXY_HOST}:8081/v1/AUTH_\$\(tenant_id\)s" --adminurl=http://${HAPROXY_HOST}:8081 --internalurl="http://${HAPROXY_HOST}:8081/v1/AUTH_\$\(tenant_id\)s"

	echo "Delete old endpoint"
	sshpass -p ${PASS_ROOT} ssh -o StrictHostKeyChecking=no root@${AUTH_HOST} keystone --os-username admin --os_password ${PASS_AUTH} --os_tenant_name admin --os_auth_url http://${AUTH_HOST}:5000/v2.0 endpoint-delete ${endpoint_id}
	
	rm -rf /var/test_haproxy.cfg

	echo "Config HAProxy done"
	echo "The statistics page is http://${HAPROXY_HOST}:8888/haproxy_stats"
        echo "admin/admin"
fi

