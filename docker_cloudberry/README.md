# Cloudberry

This is the docker contianer for starting a Cloudberry 7 cluster.
https://docs.vmware.com/en/VMware-Greenplum/7/greenplum-database/landing-index.html

Note: After the creation of a cluster, it is required to initialize the cluster using the functions in `$GPHOME/entrypoint.sh`.

## Quick Start

To start a GPDB single node cluster, try the command below, or refer to the `example/gpdb-single-node/docker-compose.yml`

```bash
docker run -d \
  -p 15432:5432  -p 10022:22 \
  -v /data/database/gpdb:/data/gpdb \
  -h gpdb-cdw \
  --name gpdb-cdw \
  docker.io/qpod0dev/greenplum

# to change the password for gpadmin db user, enter the container and execute the command below.
psql -d postgres -c "ALTER ROLE gpadmin WITH PASSWORD 'gpadmin';"
```

## Multi-node cluster on a single machine

Please refer to the file `example/gpdb-single-vm/docker-compose.yml`.
Note: it is neded to create folders `primary1` and `primary2` for segment nodes in `/data/database/greenplum`:

```bash
mkdir -pv /data/database/greenplum/primary1
mkdir -pv /data/database/greenplum/primary2
```

## Debug

```bash
# to build the docker image
docker build -t qpod0dev/greenplum --build-arg "BASE_NAMESPACE=qpod" .

docker run -it \
  -p 15432:5432  -p 10022:22 \
  -v /data/database/gpdb:/data/gpdb \
  -h gpdb-cdw \
  --name gpdb-cdw \
  docker.io/qpod0dev/greenplum \
  bash

/bin/bash -c ${GPHOME}/entrypoint.sh
```
