#!/bin/bash
# Config Swift.
# jingshao_AT_cnic_DOT_cn May 2. 2013
# last edit May 19. 2013

. ./build_swift_cfg.sh

for zone in ${ZONES[@]};do
	eval nodes=\${$zone[@]}
	for node in ${nodes[@]}
	do
		echo "stoping swift on nodes@"${node}
		sshpass -p ${PASS_ROOT} ssh -o StrictHostKeyChecking=no root@${node} swift-init all stop 1>/dev/null 2>&1
	done
done

temp=${ZONES}
eval op_host=\${$temp}
echo "Op host: "${op_host}

echo "Remove the old swift"
sshpass -p ${PASS_ROOT} ssh -o StrictHostKeyChecking=no root@${op_host} rm -r -f -v ${CONF_DIR}/*.builder
sshpass -p ${PASS_ROOT} ssh -o StrictHostKeyChecking=no root@${op_host} rm -r -f -v ${CONF_DIR}/*.ring.gz

echo "Create new rings"
sshpass -p ${PASS_ROOT} ssh -o StrictHostKeyChecking=no root@${op_host} swift-ring-builder ${CONF_DIR}/account.builder create ${PARTITION_SIZE_POWER} ${REPLICAS} ${HOURS}
sshpass -p ${PASS_ROOT} ssh -o StrictHostKeyChecking=no root@${op_host} swift-ring-builder ${CONF_DIR}/container.builder create ${PARTITION_SIZE_POWER} ${REPLICAS} ${HOURS}
sshpass -p ${PASS_ROOT} ssh -o StrictHostKeyChecking=no root@${op_host} swift-ring-builder ${CONF_DIR}/object.builder create ${PARTITION_SIZE_POWER} ${REPLICAS} ${HOURS}

echo "Create new zones and add devices"
zoneidx=1
for zone in ${ZONES[@]};do
	eval nodes=\${$zone[@]}
	for node in ${nodes[@]};do
		devidx=0
		for device in ${DEVICES[@]};do
			sshpass -p ${PASS_ROOT} ssh -o StrictHostKeyChecking=no root@${op_host} swift-ring-builder ${CONF_DIR}/object.builder add z${zoneidx}-${node}:6010/${device} ${DEVICES_WEIGHTS#[devidx]}
			sshpass -p ${PASS_ROOT} ssh -o StrictHostKeyChecking=no root@${op_host} swift-ring-builder ${CONF_DIR}/container.builder add z${zoneidx}-${node}:6011/${device} ${DEVICES_WEIGHTS[devidx]}
			sshpass -p ${PASS_ROOT} ssh -o StrictHostKeyChecking=no root@${op_host} swift-ring-builder ${CONF_DIR}/account.builder add z${zoneidx}-${node}:6012/${device} ${DEVICES_WEIGHTS[devidx]}
			devidx=$[devidx+1]
		done
	done
	zoneidx=$[zoneidx+1]
done

echo "Rebalance"
sshpass -p ${PASS_ROOT} ssh -o StrictHostKeyChecking=no root@${op_host} swift-ring-builder ${CONF_DIR}/object.builder rebalance
sshpass -p ${PASS_ROOT} ssh -o StrictHostKeyChecking=no root@${op_host} swift-ring-builder ${CONF_DIR}/container.builder rebalance
sshpass -p ${PASS_ROOT} ssh -o StrictHostKeyChecking=no root@${op_host} swift-ring-builder ${CONF_DIR}/account.builder rebalance

echo "Copy the ring file to other nodes"

mkdir /tmp/tmp_scpfile
sshpass -p ${PASS_ROOT} scp -o StrictHostKeyChecking=no ${op_host}:/${CONF_DIR}/*.builder ${op_host}:/${CONF_DIR}/*.ring.gz /tmp/tmp_scpfile
sshpass -p ${PASS_ROOT} scp -o StrictHostKeyChecking=no ${op_host}:/${CONF_DIR}/proxy-server.conf /tmp/tmp_scpfile/proxy-server.conf
sleep 5
sed -i "/auth_host/a\signing_dir = ${CONF_DIR}" /tmp/tmp_scpfile/proxy-server.conf
sed -i "/auth_host/c\auth_host = ${AUTH_HOST}" /tmp/tmp_scpfile/proxy-server.conf
sed -i "/auth_uri/c\auth_uri = http://${AUTH_HOST}:5000/" /tmp/tmp_scpfile/proxy-server.conf
sleep 3

for zone in ${ZONES[@]};do
	eval nodes=\${$zone[@]}
	for node in ${nodes[@]}
	do
		sshpass -p ${PASS_ROOT} scp -o StrictHostKeyChecking=no /tmp/tmp_scpfile/* ${node}:/${CONF_DIR}/
	done
done

rm -rf /tmp/tmp_scpfile

swift_service_id=`sshpass -p ${PASS_ROOT} ssh -o StrictHostKeyChecking=no root@${AUTH_HOST} keystone --os-username admin --os_password ${PASS_AUTH} --os_tenant_name admin --os_auth_url http://${AUTH_HOST}:5000/v2.0 service-list | grep object-store | awk '{print $2}'`

endpoint_id=`sshpass -p ${PASS_ROOT} ssh -o StrictHostKeyChecking=no root@${AUTH_HOST} keystone --os-username admin --os_password ${PASS_AUTH} --os_tenant_name admin --os_auth_url http://${AUTH_HOST}:5000/v2.0 endpoint-list | grep ${swift_service_id} | awk '{print $2}'`

echo "Create new endpoint"
sshpass -p ${PASS_ROOT} ssh -o StrictHostKeyChecking=no root@${AUTH_HOST} keystone --os-username admin --os_password ${PASS_AUTH} --os_tenant_name admin --os_auth_url http://${AUTH_HOST}:5000/v2.0 endpoint-create --region RegionOne --service-id=${swift_service_id} --publicurl="http://${HAPROXY_HOST}:8080/v1/AUTH_\$\(tenant_id\)s" --adminurl=http://${HAPROXY_HOST}:8080 --internalurl="http://${HAPROXY_HOST}:8080/v1/AUTH_\$\(tenant_id\)s"

echo "Delete old endpoint"
sshpass -p ${PASS_ROOT} ssh -o StrictHostKeyChecking=no root@${AUTH_HOST} keystone --os-username admin --os_password ${PASS_AUTH} --os_tenant_name admin --os_auth_url http://${AUTH_HOST}:5000/v2.0 endpoint-delete ${endpoint_id}

echo "Starting swift on all nodes"
for zone in ${ZONES[@]};do
	eval nodes=\${$zone[@]}
	for node in ${nodes[@]}
	do
		echo "Starting swift@"${node}
		sshpass -p ${PASS_ROOT} ssh -o StrictHostKeyChecking=no root@${node} swift-init all restart 1>/dev/null 2>&1
		sleep 5
	done
done

echo "Config swift done"
