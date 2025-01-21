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
Xvfb :99 -screen 0 "${SCREEN_WIDTH}"x"${SCREEN_HEIGHT}"x24 &
export DISPLAY=:99

# Browser time
chromium --no-first-run --kiosk --no-sandbox --window-size="${SCREEN_WIDTH}","${SCREEN_HEIGHT}" --window-position=0,0 --enable-features=OverlayScrollbar --autoplay-policy=no-user-gesture-required "$WEB_URL" &

# Use ffmpeg to capture the display and stream it to an RTMP server
if [ -z "$ICE_URL" ]; then
  # ICE_URL is not set, use video with silence
  ffmpeg -f x11grab -s "${SCREEN_WIDTH}"x"${SCREEN_HEIGHT}" -draw_mouse 0 -i :99.0 \
      -f lavfi -i anullsrc=channel_layout=stereo:sample_rate=44100 \
      -c:v libx264 -preset "${FFMPEG_PRESET:-veryfast}" -maxrate 3000k -bufsize 6000k -pix_fmt yuv420p \
      -c:a aac -b:a 128k -ac 2 \
      -f flv "$RTMP_URL"
else
  # ICE_URL is set, use both video and audio
  ffmpeg -f x11grab -s "${SCREEN_WIDTH}"x"${SCREEN_HEIGHT}" -draw_mouse 0 -i :99.0 \
      -i "$ICE_URL" \
      -c:v libx264 -preset "${FFMPEG_PRESET:-veryfast}" -maxrate 3000k -bufsize 6000k -pix_fmt yuv420p \
      -c:a aac -b:a 128k -ac 2 \
      -f flv "$RTMP_URL"
fi
