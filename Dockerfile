FROM debian:bullseye-slim

# Install required packages
RUN apt-get update && apt-get install -y \
    firefox-esr \
    xvfb \
    ffmpeg \
    dbus \
    fontconfig \
    xauth \
    libx11-xcb1 \
    libxcb1 \
    libxcomposite1 \
    libxcursor1 \
    libxdamage1 \
    libxfixes3 \
    libxi6 \
    libxrandr2 \
    libxrender1 \
    libxss1 \
    libxtst6 \
    x11-xserver-utils \
    bash \
    && rm -rf /var/lib/apt/lists/*

# Create a non-root user
RUN useradd -m -d /home/firefox firefox

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
