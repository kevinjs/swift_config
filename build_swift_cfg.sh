#/bin/bash
#PROXY_NODES="localhost"
#STORAGE_NODES="localhost"

CONF_DIR=/etc/swift
PASS_STACK=csdb123cnic

zone1=(192.168.138.212)
zone2=(192.168.138.213)
zone3=(192.168.138.214)
#zone4=(192.168.138.217)
ZONES=(zone1 zone2 zone3)
NODES=(192.168.138.212 192.168.138.213 192.168.138.214)

PARTITION_SIZE_POWER=18
REPLICAS=3
HOURS=1

DEVICES=(sdb1)
DEVICES_WEIGHTS=(100)



#the end of include_swift_batch.sh
