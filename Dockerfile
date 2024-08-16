FROM debian:latest
RUN apt-get update && apt-get install -y vim chromium xvfb ffmpeg
WORKDIR /app
COPY entrypoint.sh .
CMD ["bash", "entrypoint.sh"]
