FROM alpine:3.19.3

RUN apk update && \
    apk add --no-cache \
    vim \
    chromium \
    xvfb \
    ffmpeg \
    bash

WORKDIR /app

COPY entrypoint.sh .

CMD ["bash", "entrypoint.sh"]
