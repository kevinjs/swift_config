#/bin/bash

. ./build_swift_cfg.sh

for node in ${NODES};do
	echo "stoping swift on nodes@"${node}
        sshpass -p ${PASS_STACK} ssh stack@${node} swift-init all stop 1>/dev/null 2>&1
done

cd $CONF_DIR
rm -r -f -v ${CONF_DIR}/*.builder
rm -r -f -v ${CONF_DIR}/*.ring.gz

echo "creating rings"
su -c "cd ${CONF_DIR};swift-ring-builder account.builder create ${PARTITION_SIZE_POWER} ${REPLICAS} ${HOURS}" stack
su -c "cd ${CONF_DIR};swift-ring-builder container.builder create ${PARTITION_SIZE_POWER} ${REPLICAS} ${HOURS}" stack
su -c "cd ${CONF_DIR};swift-ring-builder object.builder create ${PARTITION_SIZE_POWER} ${REPLICAS} ${HOURS}" stack

echo "create new zones and add devices into zones."

zoneidx=1
for zone in ${ZONES[@]}
do
	eval nodes=\${$zone[@]}
	for node in ${nodes[@]}
	do
		devidx=0
		for device in ${DEVICES[@]}
		do
			su -c "cd ${CONF_DIR};swift-ring-builder object.builder add z${zoneidx}-${node}:6010/${device} ${DEVICES_WEIGHTS[devidx]}" stack
    		su -c "cd ${CONF_DIR};swift-ring-builder container.builder add z${zoneidx}-${node}:6011/${device} ${DEVICES_WEIGHTS[devidx]}" stack
    		su -c "cd ${CONF_DIR};swift-ring-builder account.builder add z${zoneidx}-${node}:6012/${device} ${DEVICES_WEIGHTS[devidx]}" stack
			devidx=$[devidx+1]
		done
	done
	zoneidx=$[zoneidx+1]
done

echo "rebalance"
su -c "cd /etc/swift;swift-ring-builder object.builder rebalance" stack
su -c "cd /etc/swift;swift-ring-builder container.builder rebalance" stack
su -c "cd /etc/swift;swift-ring-builder account.builder rebalance" stack

echo "copy the ring file to all nodes"
for zone in ${ZONES[@]}
do
	eval nodes=\${$zone[@]}
	for node in ${nodes[@]}
	do
		su -c "scp /etc/swift/*.builder /etc/swift/*.ring.gz stack@${node}:/etc/swift/" stack
	done
done

echo "starting swift on all nodes"
for zone in ${ZONES[@]}
do
	eval nodes=\${$zone[@]}
	for node in ${nodes[@]}
	do
		echo "starting swift@"${node}
		sshpass -p ${PASS_STACK} ssh stack@${node} swift-init all restart 1>/dev/null 2>&1
		sleep 5
	done
done

