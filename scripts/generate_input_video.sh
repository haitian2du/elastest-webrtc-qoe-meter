#!/bin/sh

##################################################################################
# DEFAULT VALUES
##################################################################################

VIDEO_SAMPLE_URL=https://archive.org/download/e-dv548_lwe08_christa_casebeer_003.ogg/e-dv548_lwe08_christa_casebeer_003.mp4
WIDTH=640
HEIGHT=480
VIDEO_DURATION=00:00:35
PADDING_DURATION_SEC=5
FPS=24
AUDIO_SAMPLE_RATE_HZ=48000
TONE_FREQUENCY_HZ=1000
AUDIO_CHANNELS_NUMBER=1
FFMPEG_LOG="-loglevel error"
TARGET_VIDEO=../test.y4m
TARGET_AUDIO=../test.wav
FONT=/usr/share/fonts/truetype/msttcorefonts/Arial.ttf
CLEANUP=true

##################################################################################
# PARSE ARGUMENTS
##################################################################################

USAGE="Usage: `basename $0` [-d=duration] [-p=padding_duration_sec] [--game] [--no_cleanup]"

for i in "$@"
do
case $i in
    --game)
    VIDEO_SAMPLE_URL=https://ia802808.us.archive.org/6/items/ForniteBattle8/fornite%20battle%202.mp4
    WIDTH=1280
    HEIGHT=720
    shift
    ;;
    -d=*|--duration=*)
    VIDEO_DURATION="${i#*=}"
    shift
    ;;
    -p=*|--padding=*)
    PADDING_DURATION_SEC="${i#*=}"
    shift
    ;;
    --no_cleanup)
    CLEANUP=false
    shift
    ;;
    *) # unknown option
    echo $USAGE
    exit 0
    ;;
esac
done

##################################################################################
# INIT
##################################################################################


# 1. Download video sample
VIDEO_SAMPLE_NAME=$(echo ${VIDEO_SAMPLE_URL##*/} | sed -e 's/%20/ /g')

if [ ! -f "$VIDEO_SAMPLE_NAME" ]; then
    echo "Content video ($VIDEO_SAMPLE_NAME) not exits ... downloading"
    wget $VIDEO_SAMPLE_URL
else
    echo "Content video ($VIDEO_SAMPLE_NAME) already exits"
fi


# 2. Cut original video
echo "Cutting original video (duration $VIDEO_DURATION)"
ffmpeg $FFMPEG_LOG -y -i "$VIDEO_SAMPLE_NAME" -ss 00:00:00 -t $VIDEO_DURATION -vf scale="$WIDTH:$HEIGHT",setsar=1:1 -r $FPS test-no-frame-number.mp4
ffmpeg $FFMPEG_LOG -y -i test-no-frame-number.mp4 -vf drawtext="fontfile=$FONT:text='\   %{frame_num}  \ ':start_number=1:x=(w-tw)/2:y=h-(2*lh)+15:fontcolor=black:fontsize=40:box=1:boxcolor=white:boxborderw=10" test-no-padding.mp4


# 3. Create padding video based on a test pattern
echo "Creating padding video ($PADDING_DURATION_SEC seconds)"
ffmpeg $FFMPEG_LOG -y -f lavfi -i testsrc=duration=$PADDING_DURATION_SEC:size="$WIDTH"x"$HEIGHT":rate=$FPS -f lavfi -i sine=frequency=$TONE_FREQUENCY_HZ:duration=$PADDING_DURATION_SEC padding.mp4


# 4. Concatenate final video
echo "Concatenating padding and content videos"
ffmpeg $FFMPEG_LOG -y -i padding.mp4 -i test-no-padding.mp4 -i padding.mp4 -filter_complex concat=n=3:v=1:a=1 test.mp4


# 5. Convert video to Y4M
echo "Converting resulting video to Y4M ($TARGET_VIDEO)"
ffmpeg $FFMPEG_LOG -y -i test.mp4 -pix_fmt yuv420p $TARGET_VIDEO


# 6. Convert audio to WAV
echo "Converting resulting audio to WAV ($TARGET_AUDIO)"
ffmpeg $FFMPEG_LOG -y -i test.mp4 -vn -acodec pcm_s16le -ar $AUDIO_SAMPLE_RATE_HZ -ac $AUDIO_CHANNELS_NUMBER $TARGET_AUDIO


# 7. Delete temporal video files
if $CLEANUP; then
    echo "Deleting temporal files"
    rm test-no-frame-number.mp4 test-no-padding.mp4 padding.mp4 test.mp4
fi
