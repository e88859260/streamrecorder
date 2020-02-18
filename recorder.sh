#!/bin/bash
# Stream Recorder

if [ -z "$1" ] || [ -z "$2" ]; then
  echo "usage: $0 site channel_id [name] [savefolder] [logfolder] [format] [loop|once] [interval] [streamorrecord] [rtmpurl]"
  exit 1
fi

# Set the default value of parameters
SITE="${1:-youtube}"
CHANNELID="$2"
NAME="$3"
SAVEFOLDER="$4"
LOGFOLDER="$5"
FORMAT="${6:-best}"
LOOPORONCE="${7:-once}"
INTERVAL="${8:-30}"
STREAMORRECORD="${9:-record}"
RTMPURL="${10}"
AUTOBACKUP=$(grep "Autobackup" ./config/global.config|awk -F = '{print $2}')
if grep -q "Autobackup" ./config/${NAME}.config
then
  AUTOBACKUP=$(grep "Autobackup" ./config/${NAME}.config|awk -F = '{print $2}')
fi
SAVEFORMAT=$(grep "Saveformat" ./config/global.config|awk -F = '{print $2}')
if grep -q "Saveformat" ./config/${NAME}.config
then
  SAVEFORMAT=$(grep "Saveformat" ./config/${NAME}.config|awk -F = '{print $2}')
fi

# Construct full URL if only channel id given
[ "$SITE" == "youtube" ] && LIVE_URL="https://www.youtube.com/channel/$CHANNELID/live"
[ "$SITE" == "bilibili" ] && LIVE_URL="https://live.bilibili.com/$CHANNELID"
[ "$SITE" == "twitch" ] && LIVE_URL="https://www.twitch.tv/$CHANNELID"
[ "$SITE" == "twitcast" ] && LIVE_URL="https://twitcasting.tv/$CHANNELID"
[ "$SITE" == "streamlink" ] && LIVE_URL="$CHANNELID"

if grep -q "Myyoutube" ./config/${NAME}.config
then
    MYYOUTUBECHANNELID=$(grep "Myyoutube" ./config/"$NAME".config|awk -F = '{print $2}')
    if [ ! -z $MYYOUTUBECHANNELID ] 
    then
        MYYOUTUBEURL="https://www.youtube.com/channel/$MYYOUTUBECHANNELID/live"
        echo "$LIVE_URL | $(date +"%Y%m%d_%H%M%S")" >> "${SAVEFOLDER}/$MYYOUTUBECHANNELID.txt"
    else
        echo "not find Myyoutube in ${NAME}.config,please config Myyoutube"
        exit 1
    fi
else
    echo "not find Myyoutube in ${NAME}.config,please config Myyoutube"
    exit 1
fi

while true; do
  # Monitor live streams of specific channel
  while true; do
    LOG_PREFIX="$(date +'[%Y-%m-%d %H:%M:%S]') ===$SITE==="
    echo "$LOG_PREFIX Checking $LIVE_URL..."
    echo "$LOG_PREFIX Try to get current live stream of $LIVE_URL"

    #Check whether the channel is live
    if [ -n "$MYYOUTUBEURL" ] && [ $(wget -q -O- "$MYYOUTUBEURL" |grep -o '\\"isLive\\":true'|wc -l) -ge 2 ]
    then
        echo "$LOG_PREFIX skip...youtube in ${NAME}.config, channel $MYYOUTUBECHANNELID is already streaming!"

    #curl -s -N https://www.youtube.com/channel/$1/live|grep -q '\\"isLive\\":true' && break
    #wget -q -O- $LIVE_URL|grep -q '\\"isLive\\":true' && break
    else 
        [ "$SITE" == "youtube" ] && [ $(wget -q -O- "$LIVE_URL" |grep -o '\\"isLive\\":true'|wc -l) -ge 2 ] && break
        if [ "$SITE" == "bilibili" ]
        then
          wget -q -O- "https://api.live.bilibili.com/room/v1/Room/get_info?room_id=$CHANNELID&from=room"|grep -q '\"live_status\"\:1' && break
        fi
        if [ "$SITE" == "twitch" ]
        then
          TWITCHKEY=$(grep "Twitchkey" ./config/global.config|awk -F = '{print $2}')
          if [ -z "$TWITCHKEY" ]
          then
            STREAM_URL=$(streamlink --stream-url "$LIVE_URL" "$FORMAT")
            (echo "$STREAM_URL" | grep -q ".m3u8") && break
            (echo "$STREAM_URL" | grep -q ".flv") && break
            echo "$LOG_PREFIX skip...Twitchkey is empty!"
          else
            wget -q -O- --header="Client-ID: $TWITCHKEY" https://api.twitch.tv/helix/streams?user_login=$CHANNELID|grep -q \"type\":\"live\" && break
          fi
        fi
        if [ "$SITE" == "twitcast" ]
        then
          wget -q -O- "https://twitcasting.tv/streamserver.php?target=$CHANNELID&mode=client" | grep -q '"live":true' && break
        fi
        if [ "$SITE" == "streamlink" ]
        then
          STREAM_URL=$(streamlink --stream-url "$LIVE_URL" "$FORMAT")
          (echo "$STREAM_URL" | grep -q ".m3u8") && break
          (echo "$STREAM_URL" | grep -q ".flv") && break
          (echo "$STREAM_URL" | grep -q ".mp4") && break
          (echo "$STREAM_URL" | grep -q ".mpd") && break
        fi
    fi
    echo "$LOG_PREFIX The stream is not available now."
    echo "$LOG_PREFIX Retry after $INTERVAL seconds..."
    sleep $INTERVAL
  done
  #Create save folder by date
  FOLDERBYDATE="$(date +"%Y%m%d")"
  [[ ! -d "${SAVEFOLDER}${FOLDERBYDATE}" ]]&&mkdir ${SAVEFOLDER}${FOLDERBYDATE}
  #[[ ! -d "${SAVEFOLDER}${FOLDERBYDATE}/metadata" ]]&&mkdir ${SAVEFOLDER}${FOLDERBYDATE}/metadata

  #Fetch live information
  if [ "$SITE" == "youtube" ]
  then
    METADATA=$(youtube-dl --get-id --get-title --get-thumbnail --get-description \
    --no-check-certificate --no-playlist --playlist-items 1 \
    "${LIVE_URL}" 2>/dev/null)
    [ -z "$METADATA" ] && echo "$LOG_PREFIX skip...youtube metadata is empty!" && continue
    # Extract stream title
    #Title=$(echo "$METADATA" | sed -n '1p'|sed 's#[()/\\!-\$]##g')
    # Extract video id of live stream
    ID=$(echo "$METADATA" | sed -n '2p')
    # Extract stream cover url
    #COVERURL=$(echo "$METADATA" | sed -n '3p')
    COVERURL="https://i.ytimg.com/vi/${ID}/maxresdefault.jpg"
    #FNAME="youtube_${Title}_$(date +"%Y%m%d_%H%M%S")_${ID}.${SAVEFORMAT}"
    FNAME="youtube_$(date +"%Y%m%d_%H%M%S")_${ID}.${SAVEFORMAT}"
    # Also save the metadata and cover to file
    if [ "$STREAMORRECORD" != "stream" ]; then
      echo "$METADATA" > "${SAVEFOLDER}${FOLDERBYDATE}/${FNAME}.info.txt"
      wget -O "${SAVEFOLDER}${FOLDERBYDATE}/${FNAME}.jpg" "$COVERURL"
    fi
  fi
  if [ "$SITE" == "bilibili" ]
  then
    # Savetitle
    TITLE=$(you-get -i "$LIVE_URL"|sed -n '2p'|cut -c 22-|cut -d '.' -f 1|sed 's/[()/\\!-\$]//g')
    # Record using MPEG-2 TS format to avoid broken file caused by interruption
    FNAME="bil_${CHANNELID}_${TITLE}_$(date +"%Y%m%d_%H%M%S").${SAVEFORMAT}"
  fi
  if [ "$SITE" == "twitch" ] || [ "$SITE" == "streamlink" ]
  then
    METADATA=$(youtube-dl --get-id --get-title --get-description "$LIVE_URL")
    #TITLE=$(echo "$METADATA" | sed -n '3p'|sed 's/[()/\\!-\$]//g')
    ID=$(echo "$METADATA" | sed -n '2p')
    #FNAME="twitch_${ID}_${TITLE}_$(date +"%Y%m%d_%H%M%S").${SAVEFORMAT}"
    FNAME="${SITE}_$(date +"%Y%m%d_%H%M%S")_${ID}.${SAVEFORMAT}"
    [ "$STREAMORRECORD" != "stream" ] && echo "$METADATA" > "${SAVEFOLDER}${FOLDERBYDATE}/${FNAME}.info.txt"
  fi
  if [ "$SITE" == "twitcast" ]
  then
    MOVIEID=$(wget -q -O- ${LIVE_URL} | grep data-movie-id | awk -F '[=\"]+' '{print $2}')
    ID=$(echo "$CHANNELID"|sed 's/:/：/') 
    LIVEDL_FNAME="${ID}_${MOVIEID}.${SAVEFORMAT}" 
    FNAME="twitcast_$(date +"%Y%m%d_%H%M%S")_${MOVIEID}.${SAVEFORMAT}"
  fi

  # Print logs
  echo "$LOG_PREFIX Start recording, stream saved to ${SAVEFOLDER}${FOLDERBYDATE}/${FNAME}"
  [ "$SITE" == "youtube" ] || [ "$SITE" == "twitch" ] && echo "$LOG_PREFIX metadata saved to ${SAVEFOLDER}${FOLDERBYDATE}/${FNAME}.info.txt"
  [ "$SITE" == "youtube" ] && echo "$LOG_PREFIX cover saved to ${SAVEFOLDER}${FOLDERBYDATE}/${FNAME}.jpg"
  echo "$LOG_PREFIX recording log saved to ${LOGFOLDER}${FNAME}.log, streaming log saved to ${LOGFOLDER}${FNAME}.streaming.log"
  # Record using MPEG-2 TS format to avoid broken file caused by interruption
  # Start recording
  # ffmpeg -i "$M3U8_URL" -codec copy -f mpegts "savevideo/$FNAME" > "savevideo/$FNAME.log" 2>&1
  # Use streamlink "--hls-live-restart" parameter to record for HLS seeking support
  #M3U8_URL=$(streamlink --stream-url "https://www.youtube.com/watch?v=${ID}" "best")
  #ffmpeg   -i "$M3U8_URL" -codec copy   -f hls -hls_time 3600 -hls_list_size 0 "${SAVEFOLDER}${FOLDERBYDATE}/${FNAME}" > "${LOGFOLDER}${FNAME}.log" 2>&1
  if [ "$SITE" != "twitcast" ]
  then
    if [ "$STREAMORRECORD" == "both" ]
    then
      streamlink --loglevel trace "$LIVE_URL" "1080p,720p,best" --retry-streams 30 --retry-max 10 -o - | ffmpeg -re -i pipe:0 \
      -codec copy -f mpegts "${SAVEFOLDER}${FOLDERBYDATE}/${FNAME}" \
      -vcodec copy -acodec aac -strict -2 -f flv "${RTMPURL}" \
      > "${LOGFOLDER}${FNAME}.streaming.log" 2>&1
      STREAMSUCCESS=$?
    elif [ "$STREAMORRECORD" == "record" ]
    then
      streamlink --loglevel trace -o "${SAVEFOLDER}${FOLDERBYDATE}/${FNAME}" \
      "$LIVE_URL" "1080p,720p,best" --retry-streams 30 --retry-max 10 > "${LOGFOLDER}${FNAME}.log" 2>&1
    elif [ "$STREAMORRECORD" == "stream" ]
    then
      streamlink "$LIVE_URL" "1080p,720p,best" --retry-streams 30 --retry-max 10 -o - | ffmpeg -re -i pipe:0 \
      -vcodec copy -acodec aac -strict -2 -f flv "${RTMPURL}" \
      > "${LOGFOLDER}${FNAME}.streaming.log" 2>&1 
    fi
  else
    ./livedl -tcas "$CHANNELID" > "${LOGFOLDER}${FNAME}.log" 2>&1
    STREAMSUCCESS=$? 
    #move stream file to streamrecorded folder
    [ $STREAMSUCCESS -eq 0 ] && [ -f "./${LIVEDL_FNAME}" ] && mv ./$LIVEDL_FNAME $SAVEFOLDER$FOLDERBYDATE/$FNAME
  fi
  # backup stream if autobackup is on 
  sleep 5 
  if [ "$AUTOBACKUP" == "on" ] && [ "$STREAMORRECORD" != "stream" ]
  then
    if ([ "$SITE" != "twitcast" ] && [ "$STREAMORRECORD" == "record" ] && tail -n 5 "${LOGFOLDER}${FNAME}.log"|grep -q "Stream ended") || [ "X$STREAMSUCCESS" == "X0" ]
    then
      ./autobackup.sh $NAME $SITE $FOLDERBYDATE $FNAME &
    else
      echo "$LOG_PREFIX stream record fail, check ${LOGFOLDER}${FNAME}.log and ${LOGFOLDER}${FNAME}.streaming.log for detail."
    fi 
  fi  

  # Exit if we just need to record current stream
  LOG_PREFIX="$(date +"[%Y-%m-%d %H:%M:%S]") ===$SITE==="
  echo "$LOG_PREFIX Live stream recording stopped."
  [[ "$LOOPORONCE" == "once" ]] && break
done

