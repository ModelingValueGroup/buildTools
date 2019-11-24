FROM maven:3.6.0-jdk-12-alpine

LABEL author="Tom Brus"
LABEL "com.github.actions.name"="buildTools"
LABEL "com.github.actions.description"="get buildTools"

RUN	apk add --no-cache \
  bash \
  xmlstarlet \
  jq \
  maven

COPY entrypoint.sh /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
