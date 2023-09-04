# FROM --platform=linux/amd64 ruby:3.0.5-alpine3.15 AS builder
ARG PLATFORM=arm64
ARG RUBY_BASE_IMAGE=ruby:3.0.5-alpine3.15
ARG GO_VERSION=go1.19.3
ARG GO_BIN_TAR=go1.19.3.linux-amd64

FROM --platform=$PLATFORM $RUBY_BASE_IMAGE AS ruby_builder

# ----------------------------------------------------------------------------------------
# Build the ruby app
ARG BUNDLER_CONFIG_ARGS="set clean 'true' set no-cache 'true' set system 'true' set without 'development test coverage'"
ENV APP_HOME=/usr/src/metasploit-framework
ENV TOOLS_HOME=/usr/src/tools
ENV BUNDLE_IGNORE_MESSAGES="true"
ENV GO_VERSION=$GO_VERSION
WORKDIR $APP_HOME

COPY Gemfile* metasploit-framework.gemspec Rakefile $APP_HOME/
COPY lib/metasploit/framework/version.rb $APP_HOME/lib/metasploit/framework/version.rb
COPY lib/metasploit/framework/rails_version_constraint.rb $APP_HOME/lib/metasploit/framework/rails_version_constraint.rb
COPY lib/msf/util/helper.rb $APP_HOME/lib/msf/util/helper.rb

RUN apk add --no-cache \
      autoconf \
      bash \
      bison \
      build-base \
      curl \
      ruby-dev \
      openssl-dev \
      readline-dev \
      sqlite-dev \
      postgresql-dev \
      libpcap-dev \
      libxml2-dev \
      libxslt-dev \
      yaml-dev \
      zlib-dev \
      ncurses-dev \
      git \
      go
# Try adding missing nmap deps from the nmap Dockerfile ...
RUN apk add --update --no-cache \
    ca-certificates \
    libpcap \
    libgcc libstdc++ \
    libssl3 \
  && update-ca-certificates

RUN echo "gem: --no-document" > /etc/gemrc \
    && gem update --system \
    && bundle update --bundler \
    && bundle config $BUNDLER_ARGS
RUN bundle install --jobs=8 \
    # temp fix for https://github.com/bundler/bundler/issues/6680
    && rm -rf /usr/local/bundle/cache \
    # needed so non root users can read content of the bundle
    && chmod -R a+r /usr/local/bundle

# ----------------------------------------------------------------------------------------
# Install go
# Why do we do this from source??
ENV GO111MODULE=off

#RUN tar -C $TOOLS_HOME -xzf go1.20.6.linux-amd64.tar.gz
RUN mkdir -p $TOOLS_HOME && \
    cd $TOOLS_HOME && \
    curl -O https://dl.google.com/go/go1.19.3.linux-amd64.tar.gz && \
    tar -C $TOOLS_HOME -xzf go1.19.3.linux-amd64.tar.gz

# RUN mkdir -p $TOOLS_HOME/bin && \
#     cd $TOOLS_HOME/bin && \
#     curl -O https://dl.google.com/go/go1.19.3.src.tar.gz && \
#     tar -zxf go1.19.3.src.tar.gz && \
#     rm go1.19.3.src.tar.gz

# # This fails ... can we just install the bins?
# RUN cd bin/go/src && \
#     ./make.bash


# ----------------------------------------------------------------------------------------
FROM --platform=$PLATFORM $RUBY_BASE_IMAGE
# ----------------------------------------------------------------------------------------

ENV APP_HOME=/usr/src/metasploit-framework
ENV TOOLS_HOME=/usr/src/tools
ENV NMAP_PRIVILEGED=""
ENV METASPLOIT_GROUP=metasploit

# used for the copy command
RUN addgroup -S $METASPLOIT_GROUP


#RUN apk add --no-cache bash sqlite-libs nmap nmap-scripts nmap-nselibs \
#    postgresql-libs python2 python3 py3-pip ncurses libcap su-exec alpine-sdk \
#    python2-dev openssl-dev nasm mingw-w64-gcc

RUN apk add --no-cache bash sqlite-libs nmap nmap-scripts nmap-nselibs \
    postgresql-libs python2 python3 py3-pip ncurses libcap su-exec alpine-sdk \
    python2-dev openssl-dev nasm

RUN apk add python3-dev
RUN apk add gcompat

RUN /usr/sbin/setcap cap_net_raw,cap_net_bind_service=+eip $(which ruby)
RUN /usr/sbin/setcap cap_net_raw,cap_net_bind_service=+eip $(which nmap)

COPY --from=ruby_builder /usr/local/bundle /usr/local/bundle
RUN chown -R root:metasploit /usr/local/bundle
COPY . $APP_HOME/
COPY --from=ruby_builder $TOOLS_HOME $TOOLS_HOME
RUN chown -R root:metasploit $APP_HOME/
RUN chmod 664 $APP_HOME/Gemfile.lock
RUN gem update --system
RUN cp -f $APP_HOME/docker/database.yml $APP_HOME/config/database.yml

# Install pip as well as impacket and requests
RUN pip3 install --upgrade pip
RUN pip3 install impacket
RUN pip3 install requests

ENV GOPATH=$TOOLS_HOME/go
ENV GOROOT=$TOOLS_HOME/bin/go
ENV PATH=${PATH}:${GOPATH}/bin:${GOROOT}/bin

WORKDIR $APP_HOME
RUN git config --global --add safe.directory /usr/src/metasploit-framework

# we need this entrypoint to dynamically create a user
# matching the hosts UID and GID so we can mount something
# from the users home directory. If the IDs don't match
# it results in access denied errors.
ENTRYPOINT ["docker/entrypoint.sh"]

CMD ["./msfconsole", "-r", "docker/msfconsole.rc", "-y", "$APP_HOME/config/database.yml"]
