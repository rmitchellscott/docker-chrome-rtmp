# Some low effort error checking
if [ -z "$SCREEN_WIDTH" ] || [ -z "$SCREEN_HEIGHT" ]; then
  echo "Error: SCREEN_WIDTH and SCREEN_HEIGHT must be set."
  exit 1
fi
if [ -z "$WEB_URL" ] || [ -z "$RTMP_URL" ]; then
  echo "Error: WEB_URL and RTMP_URL must be set."
  exit 1
fi

# Configure display system
Xvfb :99 -screen 0 ${SCREEN_WIDTH}x${SCREEN_HEIGHT}x24 &
export DISPLAY=:99

# Configure audio system
rm -rf /var/run/pulse /var/lib/pulse /root/.config/pulse
pulseaudio -D --verbose --exit-idle-time=-1 --system --disallow-exit

# Browser time
chromium --kiosk --no-sandbox --window-size=${SCREEN_WIDTH},${SCREEN_HEIGHT} --window-position=0,0 --enable-features=OverlayScrollbar --autoplay-policy=no-user-gesture-required "$WEB_URL" &


# Use ffmpeg to capture the display and stream it to an RTMP server
ffmpeg -f x11grab -s ${SCREEN_WIDTH}x${SCREEN_HEIGHT} -draw_mouse 0 -i :99.0 \
    -f pulse -i default \
    -c:v libx264 -preset veryfast -maxrate 3000k -bufsize 6000k -pix_fmt yuv420p \
    -c:a aac -b:a 128k -ac 2 \
    -f flv $RTMP_URL
