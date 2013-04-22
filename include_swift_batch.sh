#/bin/bash
#PROXY_NODES="localhost"
#STORAGE_NODES="localhost"

CONF_DIR=/etc/swift
zone1=(192.168.138.212 192.168.138.213)
zone2=(192.168.138.214 192.168.138.217)
ZONES=(zone1 zone2)
NODES=(192.168.138.212 192.168.138.213 192.168.138.214 192.168.138.217)

PARTITION_SIZE_POWER=18
REPLICAS=3
HOURS=1

DEVICES=(sdb1)
DEVICES_WEIGHTS=(100)



#the end of include_swift_batch.sh
