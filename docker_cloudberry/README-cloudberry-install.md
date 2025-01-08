# Cloudberry安装文档

本文档介绍Cloudberry的安装，以目前Github上开源的最新版本为例。

Cloudberry集群为主从模式，主结点称为master结点或者coordinator结点，从结点称为segment结点。

## 准备工作（均为必须）

### 1.1 建立用户gpadmin

在每台服务器上，为Cloudberry创建新用户：gpadmin，并为该用户设置初始密码，并建立密钥：

```shell
USERNAME=gpadmin \
&& sudo useradd ${USERNAME} \
&& sudo usermod -aG root ${USERNAME} \
&& sudo echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers \
&& sudo mkdir -p /home/${USERNAME}/.ssh \
&& sudo cp /root/.bashrc /home/${USERNAME}/ \
&& sudo chown -R ${USERNAME}:${USERNAME} /home/${USERNAME} \
&& sudo passwd ${USERNAME}
```

这里以设置为 P@ssw0rd! 为例。然后切换到gpadmin用户（su gpadmin），执行下面的命令：

```shell
su gpadmin
ssh-keygen -t rsa -b 4096 -N "" -C `hostname` -f ~/.ssh/id_rsa
```

### 1.2 建立从主节点到其他结点的免密访问

在主节点上，也即第1台服务器上，授权通过ssh访问各台服务器：
建议先安装sshpass: apt-get install sshpass，然后再从第1台服务器上执行下面的命令（最后一个参数为主机名）
```sshpass -p "P@ssw0rd!" ssh-copy-id -o StrictHostKeyChecking=no gpadmin@Cloudberry-001```

### 1.3 安装依赖

在第1台服务器上安装需要的包，注意下面的步骤需要安装pip包，需根据情况设置pip源。

```shell
sudo apt-get update && sudo apt-get install -y \
    gcc g++ bison flex cmake pkg-config \
    ccache ninja-build \
    locales  curl net-tools inetutils-ping git-core \
    krb5-kdc krb5-admin-server libkrb5-dev \
    libapr1-dev libbz2-dev libcurl4-gnutls-dev libevent-dev \
    libpam-dev libperl-dev libreadline-dev libssl-dev libxerces-c-dev libxml2-dev libyaml-dev libzstd-dev   zlib1g-dev \
    openssh-client openssh-server openssl \
    python3-dev python3-pip python3-psutil python3-pygresql python3-yaml

sudo pip3 install conan
```

### 1.4 配置host文件

从第1台服务器上，配置`/etc/hosts`文件，将本集群要用到的servers的IP地址和名称，这里的Node Name不一定与服务器的主机名完全一样，只是为了方便管理。

```txt
# IP Address    Node Name
30.23.109.100   Cloudberry-001
30.23.109.101   Cloudberry-002
30.23.109.102   Cloudberry-003
```

## 2 编译安装Cloudberry

在第一台服务器上，以gpadmin用户，从Cloudberry的源代码编译安装Cloudberry到/opt/gpdb/
本例中，下载的源代码来自于Cloudberry官方代码库的master branch: https://github.com/apache/cloudberry.git
master branch编译出的版本为基于PostgreSQL 12.x的版本，且该版本可以只使用Python3。

### 2.1 准备Python依赖

如果需要单独安装Python（如miniconda），首先进行安装，例如安装到/opt/conda:

```shell
sudo bash ./Miniconda3-latest-Linux-x86_64.sh -f -b -p /opt/conda \
&& sudo chmod -R g+r /opt/conda \
&& /opt/conda/bin/pip3 install pygresql psutil \
&& echo "export PATH=/opt/conda/bin:$PATH" >> ~/.bashrc
```

### 2.2 编译Cloudberry源代码

下载解压Cloudberry源代码之后，进入源代码目录，进行编译配置（注意这里设置了prefix及PYTHON的路径）：

```shell
# Configure the project first
PYTHON=/opt/conda/bin/python3 ./configure --prefix=/opt/gpdb \
--with-perl --with-python --with-libxml --with-gssapi --with-openssl 

# Do the compile and installation
sudo make -j16 && sudo make install -j16

# Change owner of the installed directory
sudo chown -R gpadmin:gpadmin /opt/gpdb
```

### 2.3 配置Cloudberry的路径

在gpadmin用户下，执行下面的命令，使gpadmin登录后能默认找到GBDP各组件，如gpssh、gpscp等。

```shell
echo "source /opt/gpdb/greenplum_path.sh" >> ~/.bashrc
```

### 2.4 将GDPB自带的python模块软链接到Python的包目录

Cloudberry自带了一个名为`gppylib`的Python包，用来管理和控制Cloudberry。通过下面的步骤，使默认的Python能够找到该包。

```shell
PYTHON_SITE=$(python3 -c 'import sys;print(list(filter(lambda s: "site" in s, sys.path))[0])') \
 && sudo ln -s /opt/gpdb/lib/python/* ${PYTHON_SITE}/
```

### 2.5. 配置服务器列表文件

在第1台服务器上，安装Cloudberry目录文件到/opt/gpdb之后，进行下面的操作：

创建服务器ID列表文件：在/opt/gpdb/conf目录下创建下面的两个文件（hostlist和seg_host）

```txt
# hostlist
Cloudberry-001
Cloudberry-002
Cloudberry-003
```

```txt
# seg_host
Cloudberry-002
Cloudberry-003
```

### 2.6 授权服务器之间SSH互访

在第1台服务器上，通过下面的命令，来进行各主机之间的ssh访问互通，然后将编译好的Cloudberry目录复制到各个服务器上：

```bash
gpssh-exkeys -f hostlist
gpscp -f seg_host /opt/conda /opt/gpdb =:~/
```

### 2.7 配置各segment服务器

通过执行`/opt/gpdb/bin/gpssh -f /opt/gpdb/conf/hostlist`来一起操作各个服务器。

在每台服务器上，修改文件 /etc/hosts，包含各个服务器的主机名和IP地址，使各个服务器能够通过hostname互访
例如通过下面的echo命令来追加到/etc/hosts文件（参照步骤1.4）：

```shell
sudo echo "30.23.109.100  Cloudberry-001" >> /etc/hosts
```

### 2.8. 修改Linux系统配置

进行系统设置，分别修改配置文件`/etc/sysctl.conf`和`/etc/security/limits.conf`，将下面的内容替换掉原来的配置，之后执行`sysctl -p`使之生效。

将文件分发到各segment结点的命令为：`gpscp -f seg_host /etc/sysctl.conf /etc/security/limits.conf =:~/`。

连接到结点执行命令的命令为：`gpssh -f seg_host`。

```conf
# /etc/security/limits.conf

* soft nofile 524288
* hard nofile 524288
* soft nproc 131072
* hard nproc 131072
```

```conf
# /etc/sysctl.conf

kernel.shmall = 4000000000
kernel.shmmax = 500000000
kernel.shmmni = 4096
vm.overcommit_memory = 2
vm.overcommit_ratio = 95
net.ipv4.ip_local_port_range = 10000 65535 
kernel.sem = 500 2048000 200 40960
kernel.sysrq = 1
kernel.core_uses_pid = 1
kernel.msgmnb = 65536
kernel.msgmax = 65536
kernel.msgmni = 2048
net.ipv4.tcp_syncookies = 1
net.ipv4.conf.default.accept_source_route = 0
net.ipv4.tcp_max_syn_backlog = 4096
net.ipv4.conf.all.arp_filter = 1
net.core.netdev_max_backlog = 10000
net.core.rmem_max = 2097152
net.core.wmem_max = 2097152
vm.swappiness = 10
vm.zone_reclaim_mode = 0
vm.dirty_expire_centisecs = 500
vm.dirty_writeback_centisecs = 100
vm.dirty_background_ratio = 0 
vm.dirty_ratio = 0
vm.dirty_background_bytes = 1610612736
vm.dirty_bytes = 4294967296
```

## 3 准备启动Cloudberry集群

### 3.1 创建Cloudberry初始化配置文件

这里需要创建Cloudberry配置的初始化选项文件，然后配置启动选项，主要关注DATA_DIRECTORY和MIRROR_DATA_DIRECTORY两个选项。

初始化的文件模板可以通过Cloudberry自带的文件，基于此进行修改：

```shell
mkdir -pv /opt/gpdb/conf
cp /opt/gpdb/docs/cli_help/gpconfigs/gpinitsystem_config /opt/gpdb/conf/gpinitsystem_config
mkdir -pv /data/Cloudberry/coordinator
mkdir -pv /data/Cloudberry/primary1 /data/Cloudberry/primary2 /data/Cloudberry/mirror1 /data/Cloudberry/mirror2
```

注意，在下面配置文件中的目录，各个目录名都需要预先创建好。
同时也需要规划好磁盘空间，例如上面的`/data/Cloudberry`目录，将来就会用来作为数据存储空间，需要预留一定磁盘空间。

配置文件具体配置项如下：

```conf
#集群名称
ARRAY_NAME="Cloudberry"

SEG_PREFIX="gpseg"

MACHINE_LIST_FILE="/opt/gpdb/conf/seg_host"

# Master结点主机名
COORDINATOR_HOSTNAME=Cloudberry-001

#master的数据目录
COORDINATOR_DIRECTORY=/data/Cloudberry/coordinator

#指定primary segment的数据目录，网上写的是多个相同目录，多个目录表示一台机器有多个segment
declare -a DATA_DIRECTORY=(/data/Cloudberry/primary1 /data/Cloudberry/primary1 /data/Cloudberry/primary1 /data/Cloudberry/primary2 /data/Cloudberry/primary2 /data/Cloudberry/primary2)

# mirror的数据目录，和主数据一样，一个对一个，多个对多个
declare -a MIRROR_DATA_DIRECTORY=(/data/Cloudberry/mirror1 /data/Cloudberry/mirror1 /data/Cloudberry/mirror1 /data/Cloudberry/mirror2 /data/Cloudberry/mirror2 /data/Cloudberry/mirror2)
```

### 3.2 执行数据初始化

初始化数据库集群，期间需要确认配置后输入Y继续：

```shell
gpinitsystem -c gpinitsystem_config
```

### 3.3 集群基本配置

完成上述步骤之后，集群即启动完成，可以通过master结点的IP和端口进行连接。下面进行一下初始化操作：
在master结点上，进入到目录`/data/Cloudberry/coordinator/gpseg-1/`，修改配置文件`pg_hba.conf`使得客户端能连接到Cloudberry的master结点。如果需要允许任何IP访问，添加下面一行即可：

```conf
host  all  all 0.0.0.0/0 trust
```

然后执行`pg_ctl reload -D ./`

### 3.4 为Cloudberry配置用户

之后从master服务器的本地连接到集群，为gpadmin用户修改密码，之后即可从其他服务器连接访问集群。

```shell
psql -d postgres
```

```SQL
alter role gpadmin with password 'gpadmin';
```
