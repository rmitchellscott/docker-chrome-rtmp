FROM alpine:3.21

# Install required packages
RUN apk add --no-cache \
    firefox \
    xvfb \
    ffmpeg \
    dbus \
    dbus-x11 \
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
    mesa-dri-gallium \
    msttcorefonts-installer \
    && \
    # Install Microsoft fonts
    update-ms-fonts && \
    fc-cache -f && \
    # Create necessary directories with proper permissions
    mkdir -p /tmp/.X11-unix && \
    chmod 1777 /tmp/.X11-unix && \
    mkdir -p /var/run/dbus && \
    # Disable Firefox telemetry and reporting
    mkdir -p /usr/lib/firefox/distribution && \
    echo '{"policies": {"DisableTelemetry": true, "DisableFirefoxStudies": true}}' > /usr/lib/firefox/distribution/policies.json

# Create a non-root user and add to video group for better graphics support
RUN adduser -D -h /home/firefox firefox && \
    addgroup firefox video

# Set up the script
COPY stream.sh /stream.sh
RUN chmod +x /stream.sh && \
    chown firefox:firefox /stream.sh

# Set environment defaults
ENV SCREEN_WIDTH=1920 \
    SCREEN_HEIGHT=1080 \
    FFMPEG_PRESET=veryfast \
    HOME=/home/firefox \
    DISPLAY=:99 \
    DBUS_SESSION_BUS_ADDRESS=/dev/null \
    MOZ_LOG="" \
    MOZ_LOG_FILE=/dev/null

# Switch to non-root user
USER firefox
WORKDIR /home/firefox

# Run the stream script
ENTRYPOINT ["/stream.sh"]
