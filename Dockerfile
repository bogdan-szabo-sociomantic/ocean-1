FROM sociomantic/d1lang
RUN apt-get update && apt-get install -y \
	libglib2.0-dev \
	libpcre3-dev \
	libxml2-dev \
	libxslt-dev \
	libebtree6-dev \
	libtokyocabinet-dev \
	liblzo2-dev \
	libreadline-dev