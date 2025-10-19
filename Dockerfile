###############
# BUILD STAGE #
###############

FROM debian:stable AS builder
ENV DEBIAN_FRONTEND=noninteractive

# Build dependencies
RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y \
        git make cmake gcc g++ wget \
        libperl-dev libmodule-build-perl libtest-simple-perl \
        zlib1g zlib1g-dev \
        texinfo \
        ncurses-dev

# Build user and directories
RUN useradd -ms /bin/bash user
USER user
WORKDIR /home/user/src

# Binkd clone and build
RUN git clone https://github.com/pgul/binkd.git --depth 1 binkd && \
    cd binkd && \
    cp mkfls/unix/* . && \
    ./configure --with-perl --with-af-force && \
    make

# Husky clone
RUN mkdir husky && \
    cd husky && \
    wget https://raw.githubusercontent.com/huskyproject/huskybse/master/script/init_build && \
    chmod 0755 init_build && \
    ./init_build -d $(pwd)

# Husky configuration
COPY husky/huskymak.cfg husky/

# Husky build
RUN cd husky && \
    ./build.sh

# RNtrack clone and build
RUN git clone https://github.com/vasilyevmax/rntrack.git --depth 1 rntrack && \
    cd rntrack/MakeFiles/linux && \
    make PREFIX=/usr/local CONFIG=/ftn/etc/rntrack.conf

# GoldEd-Plus clone
RUN git clone https://github.com/golded-plus/golded-plus.git --depth 1 golded-plus

# GoldEd-Plus configuration
COPY golded/mygolded.h golded-plus/golded3/

# GoldEd-Plus build
RUN cd golded-plus && \
    mkdir build && \
    cd build && \
    cmake -DCMAKE_BUILD_TYPE:STRING=Release .. && \
    make

#
# Installation
#
USER root

# Binkd
RUN cd binkd && \
    make install

# Husky
RUN cd husky && \
    make -j install

# RNtrack
RUN cd rntrack/MakeFiles/linux && \
    make PREFIX=/usr/local CONFIG=/ftn/etc/rntrack.conf install

# GoldEd-Plus
RUN cd golded-plus/build && \
    make install

##################
# ASSEMBLY STAGE #
##################

FROM debian:stable
ENV DEBIAN_FRONTEND=noninteractive

# Runtime dependencies
COPY debian/non-free.sources /etc/apt/sources.list.d/
RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y \
        libperl5.40 libncurses6 \
        cron supervisor openssh-server \
        zip unzip rar \
        locales logrotate && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Copy build result and files
COPY --from=builder /usr/local/ /usr/local/
COPY --chmod=0700 entrypoint/ftn-entrypoint.sh /usr/local/sbin/
RUN install -m 0700 -d /etc/ftn-entrypoint.d
COPY supervisor/ /etc/supervisor/
COPY logrotate/* /etc/logrotate.d/
COPY --chmod=0755 binutils/* /usr/local/bin/

# Generate locales
COPY debian/locale.gen /etc/
RUN locale-gen

# User to run services
RUN useradd -d /ftn -ms /bin/bash ftn
USER ftn
WORKDIR /ftn

# Startup
USER root
WORKDIR /
ENTRYPOINT [ "/usr/local/sbin/ftn-entrypoint.sh" ]
CMD ["/usr/bin/supervisord", "-n", "-c", "/etc/supervisor/supervisord.conf"]

# Cron jobs
COPY cron/crontab-ftn /
RUN crontab -u ftn /crontab-ftn && \
    rm /crontab-ftn

# Exposed resources
VOLUME /ftn
EXPOSE 22/tcp
EXPOSE 24554/tcp
