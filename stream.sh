#!/bin/bash

# Store PIDs for cleanup
XVFB_PID=""
FIREFOX_PID=""
FFMPEG_PID=""

cleanup() {
    echo "Cleaning up processes..."
    
    # Kill Firefox if running
    if [ ! -z "$FIREFOX_PID" ] && kill -0 $FIREFOX_PID 2>/dev/null; then
        echo "Stopping Firefox (PID: $FIREFOX_PID)"
        kill -TERM $FIREFOX_PID 2>/dev/null || kill -KILL $FIREFOX_PID 2>/dev/null
    fi

    # Kill FFmpeg if running
    if [ ! -z "$FFMPEG_PID" ] && kill -0 $FFMPEG_PID 2>/dev/null; then
        echo "Stopping FFmpeg (PID: $FFMPEG_PID)"
        kill -TERM $FFMPEG_PID 2>/dev/null || kill -KILL $FFMPEG_PID 2>/dev/null
    fi

    # Kill Xvfb if running
    if [ ! -z "$XVFB_PID" ] && kill -0 $XVFB_PID 2>/dev/null; then
        echo "Stopping Xvfb (PID: $XVFB_PID)"
        kill -TERM $XVFB_PID 2>/dev/null || kill -KILL $XVFB_PID 2>/dev/null
    fi

    echo "Cleanup complete"
    exit 0
}

# Set up signal handling
trap cleanup INT TERM

# Error checking
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
XVFB_PID=$!
export DISPLAY=:99

echo "Starting Xvfb (PID: $XVFB_PID)..."
sleep 3

# Create Firefox profile with required settings
PROFILE_DIR=$(mktemp -d)
cat > "$PROFILE_DIR/user.js" << EOF
user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);
user_pref("full-screen-api.allow-trusted-requests-only", false);
user_pref("full-screen-api.warning.timeout", 0);
user_pref("browser.sessionstore.resume_from_crash", false);
user_pref("browser.shell.checkDefaultBrowser", false);
user_pref("browser.tabs.warnOnClose", false);
user_pref("browser.fullscreen.autohide", false);
EOF

# Create CSS for fullscreen
mkdir -p "$PROFILE_DIR/chrome"
cat > "$PROFILE_DIR/chrome/userChrome.css" << EOF
#navigator-toolbox { visibility: collapse !important; }
browser { margin-top: 0 !important; }
EOF

echo "Starting Firefox..."
# Start Firefox with fullscreen parameters
firefox --profile "$PROFILE_DIR" \
    --new-instance \
    --width "${SCREEN_WIDTH}" \
    --height "${SCREEN_HEIGHT}" \
    --no-remote \
    --private-window "${WEB_URL}" \
    --kiosk &
FIREFOX_PID=$!

echo "Firefox started (PID: $FIREFOX_PID)"
echo "Waiting for Firefox to load..."
sleep 10

echo "Starting FFmpeg capture..."
# Use ffmpeg to capture the display and stream it
if [ -z "$ICE_URL" ]; then
    # ICE_URL is not set, use video with silence
    ffmpeg -hide_banner -loglevel info \
        -f x11grab -framerate 30 -s "${SCREEN_WIDTH}"x"${SCREEN_HEIGHT}" -draw_mouse 0 -i :99.0 \
        -f lavfi -i anullsrc=channel_layout=stereo:sample_rate=44100 \
        -c:v libx264 -preset "${FFMPEG_PRESET:-veryfast}" -maxrate 3000k -bufsize 6000k -pix_fmt yuv420p \
        -c:a aac -b:a 128k -ac 2 \
        -f flv "$RTMP_URL" &
else
    # ICE_URL is set, use both video and audio
    ffmpeg -hide_banner -loglevel info \
        -f x11grab -framerate 30 -s "${SCREEN_WIDTH}"x"${SCREEN_HEIGHT}" -draw_mouse 0 -i :99.0 \
        -i "$ICE_URL" \
        -c:v libx264 -preset "${FFMPEG_PRESET:-veryfast}" -maxrate 3000k -bufsize 6000k -pix_fmt yuv420p \
        -c:a aac -b:a 128k -ac 2 \
        -f flv "$RTMP_URL" &
fi
FFMPEG_PID=$!

echo "FFmpeg started (PID: $FFMPEG_PID)"

# Monitor child processes
while kill -0 $XVFB_PID && kill -0 $FIREFOX_PID && kill -0 $FFMPEG_PID 2>/dev/null; do
    sleep 1
done

# If we get here, something died. Clean up and exit
echo "A process has died, initiating cleanup..."
cleanup
