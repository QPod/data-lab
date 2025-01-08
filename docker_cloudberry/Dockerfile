# Distributed under the terms of the Modified BSD License.
ARG BASE_NAMESPACE
ARG BASE_IMG="base"
FROM ${BASE_NAMESPACE:+$BASE_NAMESPACE/}${BASE_IMG} AS builder

COPY rootfs /

RUN set -exu && source /opt/utils/script-utils.sh \
 && install_apt /opt/utils/install_list_cloudberry.apt \
 && apt-get -qq install -yq --no-install-recommends  gcc g++ bison flex cmake pkg-config ccache ninja-build \
 # && VER_CLOUDBERRY=$(curl -sL https://github.com/apache/cloudberry/releases.atom | grep 'releases/tag' | grep "/7." | head -1 | grep -Po '\d[\d.]+' ) \
 # && URL_CLOUDBERRY="https://github.com/apache/cloudberry/archive/refs/tags/${VER_CLOUDBERRY}.tar.gz" \
 && URL_CLOUDBERRY="https://github.com/apache/cloudberry/archive/refs/heads/main.tar.gz" \
 && echo "Downloading cloudberry src release ${VER_CLOUDBERRY:-archive} from: ${URL_CLOUDBERRY}" \
 && install_tar_gz $URL_CLOUDBERRY && mv /opt/cloudberry-* /opt/cloudberry_src \
 && cd /opt/cloudberry_src \
 && PYTHON=/opt/conda/bin/python3 ./configure --prefix=/opt/gpdb --with-perl --with-python --with-libxml --with-gssapi --with-openssl \
 && sudo make -j16 && sudo make install -j16
 
FROM ${BASE_NAMESPACE:+$BASE_NAMESPACE/}${BASE_IMG}

LABEL maintainer="haobibo@gmail.com"

COPY rootfs /
COPY --from=builder --chown=1000:1000 /opt/gpdb /opt/gpdb

ENV GPHOME="/opt/gpdb" \
    GPDATA="/data/gpdb" \
    GPUSER="gpadmin"

RUN set -x && source /opt/utils/script-utils.sh \
 && echo "source ${GPHOME}/greenplum_path.sh" >> /etc/profile \
 && useradd -u 1000 ${GPUSER} -s /bin/bash -d /home/${GPUSER} \
 && usermod -aG root ${GPUSER} \
 && echo "${GPUSER} ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers \
 && echo "${GPUSER}:${GPUSER}" | chpasswd \
 && mkdir -pv ${GPHOME}/conf ${GPDATA} /home/${GPUSER}/.ssh \
 && chown -R ${GPUSER}:${GPUSER} ${GPHOME} ${GPDATA} /home/${GPUSER} \
 && install_apt /opt/utils/install_list_greenplum.apt \
 && export PATH="${PATH}:${GPHOME}/bin" && cd ${GPHOME}/bin && ls -alh \
 && PYTHON_SITE=$(/opt/conda/bin/python3 -c 'import sys;print(list(filter(lambda s: "site" in s, sys.path))[0])') \
 && sudo ln -s ${GPHOME}/lib/python/* ${PYTHON_SITE}/ \
 && pip install -U psutil pygresql pyyaml \
 && cp ${GPHOME}/docs/cli_help/gpconfigs/gpinitsystem_config ${GPHOME}/conf/gpinitsystem_config \
 # config sshd
 && sed -i 's/PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config \
 && sed -i -r 's/^.*StrictHostKeyChecking\s+\w+/StrictHostKeyChecking no/' /etc/ssh/ssh_config \
 && sed 's@session\s*required\s*pam_loginuid.so@session optional pam_loginuid.so@g' -i /etc/pam.d/sshd \
 && mkdir -pv /run/sshd \
 && ulimit -n 65536 65536 \
 && echo "Clean up" && list_installed_packages && install__clean

USER ${GPUSER}
RUN set -x && whoami \
 && [ -e ~/.ssh/id_rsa.pub ] || ssh-keygen -t rsa -b 4096 -N "" -C GreenplumDB -f ~/.ssh/id_rsa \
 && cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys \
 && ssh-keygen -A -v \
 && chmod 600 ~/.ssh/authorized_keys \
 && chmod +x ${GPHOME}/*.sh
 
ENV PATH="$PATH:${GPHOME}/bin" \
    USER=${GPUSER} \
    LD_LIBRARY_PATH="${LD_LIBRARY_PATH}:${GPHOME}/lib" \
    COORDINATOR_DIRECTORY="${GPDATA}/coordinator" \
    COORDINATOR_DATA_DIRECTORY="${GPDATA}/coordinator/gpseg-1" \
    PGPORT=5432 \
    PGUSER=gpadmin \
    PGDATABASE=postgres

WORKDIR /home/${GPUSER}
EXPOSE 5432 22
VOLUME ["${GPDATA}", "${GPHOME}/conf"]
ENTRYPOINT ["tini", "-g", "--"]
CMD ["/bin/bash", "-c", "${GPHOME}/entrypoint.sh"]
