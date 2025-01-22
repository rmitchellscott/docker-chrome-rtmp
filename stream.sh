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
Xvfb :99 -screen 0 "${SCREEN_WIDTH}"x"${SCREEN_HEIGHT}"x24 >/dev/null 2>&1 &
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
user_pref("browser.tabs.firefox-view", false);
user_pref("browser.startup.homepage_override.mstone", "ignore");
user_pref("browser.rights.3.shown", true);
user_pref("toolkit.telemetry.reportingpolicy.firstRun", false);
user_pref("toolkit.telemetry.enabled", false);
user_pref("browser.discovery.enabled", false);
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
    --kiosk >/dev/null 2>&1 &
FIREFOX_PID=$!

echo "Firefox started (PID: $FIREFOX_PID)"
echo "Waiting for Firefox to load..."
sleep 3

# Check GPU status before starting FFmpeg
echo "Checking Intel GPU status..."
if [ -e "/dev/dri" ]; then
    echo "DRI devices found:"
    ls -l /dev/dri/
    echo "Testing GPU drivers..."
    
    # Try iHD driver first
    echo "Testing iHD driver:"
    export LIBVA_DRIVER_NAME=iHD
    vainfo
    
    if [ $? -ne 0 ]; then
        echo "iHD driver failed, trying i965 driver:"
        export LIBVA_DRIVER_NAME=i965
        vainfo
    fi
else
    echo "Warning: No /dev/dri directory found!"
fi

# Set up audio input based on ICE_URL
if [ -z "$ICE_URL" ]; then
    AUDIO_INPUT="-f lavfi -i anullsrc=channel_layout=stereo:sample_rate=44100"
else
    AUDIO_INPUT="-i $ICE_URL"
fi

echo "Starting FFmpeg capture..."
# Try QSV first, then try VAAPI with different drivers
if ! LIBVA_DRIVER_NAME=iHD ffmpeg -init_hw_device qsv=hw -v error 2>&1 | grep -q "Error"; then
    echo "Using QSV with iHD driver..."
    export LIBVA_DRIVER_NAME=iHD
    ffmpeg -v debug -stats \
        -f x11grab -framerate 30 -s "${SCREEN_WIDTH}"x"${SCREEN_HEIGHT}" -draw_mouse 0 -i :99.0 \
        ${AUDIO_INPUT} \
        -c:v h264_qsv -preset "${FFMPEG_PRESET:-veryfast}" -global_quality 23 -maxrate 3000k -bufsize 6000k -async_depth 4 \
        -c:a aac -b:a 128k -ac 2 \
        -f flv "$RTMP_URL" 2>&1 &
elif ! LIBVA_DRIVER_NAME=i965 ffmpeg -init_hw_device qsv=hw -v error 2>&1 | grep -q "Error"; then
    echo "Using QSV with i965 driver..."
    export LIBVA_DRIVER_NAME=i965
    ffmpeg -v debug -stats \
        -f x11grab -framerate 30 -s "${SCREEN_WIDTH}"x"${SCREEN_HEIGHT}" -draw_mouse 0 -i :99.0 \
        ${AUDIO_INPUT} \
        -c:v h264_qsv -preset "${FFMPEG_PRESET:-veryfast}" -global_quality 23 -maxrate 3000k -bufsize 6000k -async_depth 4 \
        -c:a aac -b:a 128k -ac 2 \
        -f flv "$RTMP_URL" 2>&1 &
else
    echo "QSV failed, falling back to VAAPI..."
    ffmpeg -v debug -stats \
        -f x11grab -framerate 30 -s "${SCREEN_WIDTH}"x"${SCREEN_HEIGHT}" -draw_mouse 0 -i :99.0 \
        ${AUDIO_INPUT} \
        -vaapi_device /dev/dri/renderD128 \
        -vf 'format=nv12,hwupload' \
        -c:v h264_vaapi -qp 23 -maxrate 3000k -bufsize 6000k \
        -c:a aac -b:a 128k -ac 2 \
        -f flv "$RTMP_URL" 2>&1 &
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
