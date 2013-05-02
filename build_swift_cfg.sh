#!/bin/bash
# Configuration of Swift.
# jingshao_AT_cnic_DOT_cn May 2. 2013

CONF_DIR=/etc/swift
PASS_ROOT=cnic.cn

AUTH_HOST=192.168.64.220
PASS_AUTH=cnic.cn

HAPROXY_HOST=192.168.64.220
HAPROXY_CONF_DIR=/etc/haproxy

zone1=(192.168.64.220)
zone2=(192.168.64.221)
zone3=(192.168.64.222)
zone4=(192.168.64.223)
zone5=(192.168.64.224)
ZONES=(zone1 zone2 zone3 zone4 zone5)

PARTITION_SIZE_POWER=18
REPLICAS=3
HOURS=1

DEVICES=(sdb1)
DEVICES_WEIGHTS=(100)

