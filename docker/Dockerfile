FROM sociomantic/dlang
# Temporary : remove next command block after tango 1.3 is propagates to stable
RUN export RELEASE=`lsb_release -sc`; \
	echo "deb https://sociomantic:tz7CTx4XncI81dJVd8f9PvVCw@ci.sociomantic.com/ubuntu/devel $RELEASE-devel main" | tee /etc/apt/sources.list.d/sociomantic-devel.list; \
	wget -O /etc/apt/trusted.gpg.d/sociomantic-devel.gpg https://sociomantic:tz7CTx4XncI81dJVd8f9PvVCw@ci.sociomantic.com/ubuntu/devel/keyring.gpg; \
	apt-get update && apt-get install -y \
		libtango1-dmd-dev \
		libtango1-headers
RUN apt-get update && apt-get install -y \
	libglib2.0-dev \
	libpcre3-dev \
	libxml2-dev \
	libxslt-dev \
	libebtree6-dev \
	libtokyocabinet-dev \
	liblzo2-dev \
	libreadline-dev \
	libbz2-dev \
	zlib1g-dev \
	libssl-dev
