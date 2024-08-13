FROM debian:latest
RUN apt-get update && apt-get install -y vim pulseaudio chromium xvfb ffmpeg
RUN adduser root pulse-access
WORKDIR /app
COPY entrypoint.sh .
CMD ["bash", "entrypoint.sh"]
