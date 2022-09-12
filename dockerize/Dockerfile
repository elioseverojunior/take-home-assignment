ARG APPLICATION=${APPLICATION:-dockerize}
ARG GOARCH=""
ARG GOOS=""
ARG TAG="3.16"
ARG TAG_GO_BUILDER="1.19-alpine3.16"

FROM golang:${TAG_GO_BUILDER} AS builder

ARG UPX_VERSION=${UPX_VERSION:-3.96}
ARG GOOS=${GOOS:-linux}
ARG GOARCH=${GOARCH:-amd64}
ARG APPLICATION=${APPLICATION:-dockerize}

ENV APPLICATION=${APPLICATION:-dockerize}
ENV UPX_VERSION=${UPX_VERSION:-3.96}
ENV GOOS=${GOOS:-linux}
ENV GOARCH=${GOARCH:-amd64}

RUN export GOOS GOARCH\
 && apk add\
 --no-cache\
 --upgrade\
 --repository https://dl-cdn.alpinelinux.org/alpine/edge/main\
 alpine-sdk\
 libpq\
 gettext\
 tree\
 curl\
 less\
 unzip zip rsync\
 openssl gcc\
 bash\
 bash-doc\
 bash-completion\
 perl-utils git vim\
 curl wget jq openssh libxml2-utils xz\
 mysql-client\
 && rm -rf /var/cache/apk/*

CMD [ "/bin/bash" ]

WORKDIR /tmp

RUN curl -Ss https://github.com/upx/upx/releases/download/v$UPX_VERSION/upx-$UPX_VERSION-amd64_linux.tar.xz -L\
 | tar -xJf- &&\
 mv upx-$UPX_VERSION-amd64_linux upx &&\
 mv /tmp/upx /usr/local/bin/ &&\
 ln -s /usr/local/bin/upx/upx /usr/bin/upx

WORKDIR /usr/src/build/

COPY . .

RUN go get github.com/pwaller/goupx\
 && go build -a -ldflags '-s -w' -o "${APPLICATION}-${GOOS}-${GOARCH}"\
 && ls -lha "${APPLICATION}-${GOOS}-${GOARCH}"\
 && upx --brute "${APPLICATION}-${GOOS}-${GOARCH}"\
 && ls -lha "${APPLICATION}-${GOOS}-${GOARCH}"

FROM alpine:${TAG}

ENV APPLICATION=${APPLICATION:-dockerize}
ENV GOOS=${GOOS:-linux}
ENV GOARCH=${GOARCH:-amd64}

EXPOSE 80 8080 443

COPY bash_files/. /root/.

RUN apk add\
 --no-cache\
 --upgrade\
 --repository https://dl-cdn.alpinelinux.org/alpine/edge/main\
 bash-completion\
 bash\
 curl\
 jq\
 less\
 libxml2-utils\
 openssh\
 perl-utils\
 rsync\
 tree\
 unzip\
 vim\
 wget\
 xz\
 zip\
 && rm -rf /var/cache/apk/*

CMD [ "/bin/bash" ]

WORKDIR /app

COPY --from=builder "/usr/src/build/${APPLICATION}-$GOOS-$GOARCH" "/app/${APPLICATION}"
COPY --from=builder "/usr/src/build/src" "/app/src"

RUN chmod +x "/app/${APPLICATION}"\
 && rm -rfv "/root/.cache"

ENTRYPOINT [ "/app/dockerize" ]
