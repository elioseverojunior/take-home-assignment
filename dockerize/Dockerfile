ARG APPLICATION=${APPLICATION:-dockerize}
ARG BUILD_TIME=${BUILD_TIME:-unset}
ARG COMMIT=${COMMIT:-unset}
ARG GOARCH=${GOARCH:-amd64}
ARG GOOS=${GOOS:-linux}
ARG GO_BUILDER_TAG="1.19-alpine3.16"
ARG RELEASE=${RELEASE:-unset}
ARG TAG="3.16"
ARG UPX_VERSION=${UPX_VERSION:-3.96}

FROM alpine:${TAG} AS base

ENV APPLICATION=${APPLICATION:-dockerize}
ENV GOOS=${GOOS:-linux}
ENV GOARCH=${GOARCH:-amd64}

EXPOSE 80 443 8080

ADD bash_files/. /root/.

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
 mysql-client\
 openssh\
 perl-utils\
 rsync\
 tree\
 unzip\
 vim\
 wget\
 xz\
 zip\
 && rm -rf /var/cache/apk/*;

CMD [ "/bin/bash" ]

FROM golang:${GO_BUILDER_TAG} AS builder

ENV APPLICATION=${APPLICATION:-dockerize}
ENV BUILD_TIME=${BUILD_TIME:-unset}
ENV COMMIT=${COMMIT:-unset}
ENV GOARCH=${GOARCH:-amd64}
ENV GOOS=${GOOS:-linux}
ENV RELEASE=${RELEASE:-unset}
ENV UPX_VERSION=${UPX_VERSION:-3.96}

RUN export GOOS GOARCH\
 && apk add\
 --no-cache\
 --upgrade\
 --repository https://dl-cdn.alpinelinux.org/alpine/edge/main\
 alpine-sdk\
 bash-completion\
 bash\
 curl\
 gcc\
 gettext\
 git\
 jq\
 less\
 libpq\
 libxml2-utils\
 mysql-client\
 openssh\
 openssl\
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

WORKDIR /tmp

RUN curl -Ss https://github.com/upx/upx/releases/download/v$UPX_VERSION/upx-$UPX_VERSION-amd64_linux.tar.xz -L\
 | tar -xJf- &&\
 mv upx-$UPX_VERSION-amd64_linux upx &&\
 mv /tmp/upx /usr/local/bin/ &&\
 ln -s /usr/local/bin/upx/upx /usr/bin/upx

WORKDIR /usr/src/build/

COPY . .

RUN go get github.com/pwaller/goupx\
 && go build -a -ldflags "-s -w -X version.Release=${RELEASE} -X version.Commit=${COMMIT} -X version.BuildTime=${BUILD_TIME}" -o "${APPLICATION}-${GOOS}-${GOARCH}"\
 && ls -lha "${APPLICATION}-${GOOS}-${GOARCH}"\
 && upx --brute "${APPLICATION}-${GOOS}-${GOARCH}"\
 && ls -lha "${APPLICATION}-${GOOS}-${GOARCH}"

FROM base AS final

WORKDIR /app

COPY --from=builder "/usr/src/build/${APPLICATION}-$GOOS-$GOARCH" "/app/${APPLICATION}"
COPY --from=builder "/usr/src/build/src" "/app/src"

RUN chmod +x "/app/${APPLICATION}"\
 && rm -rfv "/root/.cache"

ENTRYPOINT [ "/app/dockerize" ]
