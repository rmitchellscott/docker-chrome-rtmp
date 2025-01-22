FROM alpine:3.21

# Install required packages
RUN apk add --no-cache \
    firefox \
    xvfb \
    ffmpeg \
    dbus \
    fontconfig \
    xauth \
    libx11 \
    libxcb \
    libxcomposite \
    libxcursor \
    libxdamage \
    libxfixes \
    libxi \
    libxrandr \
    libxrender \
    libxext \
    libxtst \
    xrandr \
    xset \
    bash \
    mesa-dri-gallium

# Create a non-root user
RUN adduser -D -h /home/firefox firefox

# Set up the script
COPY stream.sh /stream.sh
RUN chmod +x /stream.sh

# Set environment defaults
ENV SCREEN_WIDTH=1920 \
    SCREEN_HEIGHT=1080 \
    FFMPEG_PRESET=veryfast \
    HOME=/home/firefox

# Set up proper permissions
RUN chown -R firefox:firefox /home/firefox

# Switch to non-root user
USER firefox
WORKDIR /home/firefox

# Run the stream script
ENTRYPOINT ["/stream.sh"]
