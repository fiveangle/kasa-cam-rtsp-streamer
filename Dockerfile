FROM alpine:3.14
RUN apk add --no-cache ffmpeg curl
COPY run.sh .
ENTRYPOINT ["/bin/sh", "run.sh"]
