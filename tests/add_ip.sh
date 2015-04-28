#!/bin/sh
set -e
set -x

#CALICO="dist/calicoctl"
CALICO="python calicoctl.py"

# Set it up
docker rm -f node1 node2 etcd || true
docker run -d -p 4001:4001 --name etcd quay.io/coreos/etcd:v0.4.6
$CALICO reset || true

$CALICO node --ip=172.17.8.10
$CALICO profile add TEST_GROUP

# Add endpoints
export DOCKER_HOST=localhost:2377
while ! docker ps; do
echo "Waiting for powerstrip to come up"
  sleep 1
done

docker run -e CALICO_IP=192.168.1.1 -tid --name=node1 busybox
docker run -tid --name=node2 busybox
$CALICO container add node2 192.168.1.2 --interface=hello

$CALICO profile TEST_GROUP member add node1
$CALICO profile TEST_GROUP member add node2

# Check it works
while ! docker exec node1 ping 192.168.1.2 -c 1 -W 1; do
echo "Waiting for network to come up"
  sleep 1
done

# Add two more addresses to node1 and one more to node2
$CALICO ipv4 container node1 add 192.168.2.1
$CALICO ipv4 container node1 add 192.168.3.1

$CALICO ipv4 container node2 add 192.168.2.2 --interface=hello

docker exec node1 ping 192.168.2.2 -c 1
docker exec node2 ping 192.168.1.1 -c 1
docker exec node2 ping 192.168.2.1 -c 1
docker exec node2 ping 192.168.3.1 -c 1
$CALICO shownodes --detailed

# Now remove and check pings to the removed addresses no longer work.
$CALICO ipv4 container node1 remove 192.168.2.1
$CALICO ipv4 container node2 remove 192.168.2.2 --interface=hello
docker exec node1 ping 192.168.1.2 -c 1
docker exec node2 ping 192.168.1.1 -c 1
! docker exec node1 ping 192.168.2.2 -c 1
! docker exec node2 ping 192.168.2.1 -c 1
docker exec node2 ping 192.168.3.1 -c 1
$CALICO shownodes --detailed

echo "Tests completed successfully"