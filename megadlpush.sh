#!/bin/bash
#usage: $0 [site] filename pindaoname savefolder logfolder [stream|record] trmpurl  

SITE="${1:-megapan}"
FILENAME=$2 #"/macd/IMG_0207.mp4"
PDNAME="$3"
SAVEFOLDER="$4"
LOGFOLDER="$5" 
STREAMORRECORD="$6"
RTMPURL="${7}"
MEGATONGBUFOLDER="megatongbu"

FILEDIR=$(dirname $FILENAME)
FILE=$(basename $FILENAME)

#SAVEFOLDER=$(grep "Savefolder" ./config/global.config|awk -F = '{print $2}')
LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]")
LOG_SUFFIX=$(date +"%Y%m%d_%H%M%S")

CHECKLOGIN=$(mega-whoami)
if echo $CHECKLOGIN | grep -q "Not logged in"
then
	echo "not logged in mega , please use mega-login first !"
	exit 1
fi

CHECKFILE=$(mega-ls $FILENAME)

mega-cd "/"

if echo $CHECKFILE | grep -q "Couldn't find" 
then
	echo "mega cloud not find file : $FILENAME ,please check it! messgae: ${CHECKFILE} ,"
	exit 1
fi

if [ "$FILEDIR" == "." ]
then
	[[ ! -d "${SAVEFOLDER}${MEGATONGBUFOLDER}" ]]&&mkdir ${SAVEFOLDER}${MEGATONGBUFOLDER}
else
	MEGATONGBUFOLDER="${MEGATONGBUFOLDER}${FILEDIR}"
	[[ ! -d "${SAVEFOLDER}${MEGATONGBUFOLDER}" ]]&&mkdir -p ${SAVEFOLDER}${MEGATONGBUFOLDER}
fi

if grep -q "Myyoutube" ./config/${PDNAME}.config
then
    MYYOUTUBECHANNELID=$(grep "Myyoutube" ./config/"$PDNAME".config|awk -F = '{print $2}')
    if [ ! -z $MYYOUTUBECHANNELID ] 
    then
    	LIVE_URL="Megapan , $CHECKLOGIN , $FILENAME"
        MYYOUTUBEURL="https://www.youtube.com/channel/$MYYOUTUBECHANNELID/live"
        echo "$LIVE_URL | $(date +"%Y%m%d_%H%M%S")" >> "${SAVEFOLDER}/${PDNAME}/$MYYOUTUBECHANNELID.txt"
    else
        echo "not find Myyoutube in ${NAME}.config,please config Myyoutube"
        exit 1
    fi
else
    echo "not find Myyoutube in ${PDNAME}.config,please config Myyoutube"
    exit 1
fi

echo "$LOG_PREFIX ===MEGA-GET=== check ./${LOGFOLDER}mega-get_${FILE}_${LOG_SUFFIX}.log for detail"


if [[ ! -f ${SAVEFOLDER}${MEGATONGBUFOLDER}/$FILE ]]
then
	mega-speedlimit -d -h 19M
	mega-get "$FILENAME" "${SAVEFOLDER}${MEGATONGBUFOLDER}" > "./${LOGFOLDER}mega-get_${FILE}_${LOG_SUFFIX}.log" 2>&1 
	if ! tail -n 5 "./${LOGFOLDER}mega-get_${FILE}_${LOG_SUFFIX}.log"|grep -q "Download finished:" 
	then   
		echo "$LOG_PREFIX ===MEGA-GET=== download failed"  
		exit 1
	fi
	if [[ ! -f ${SAVEFOLDER}${MEGATONGBUFOLDER}/$FILE ]]
	then
		echo "$LOG_PREFIX ===MEGA-GET=== download file $FILENAME not find"  
		exit 1
	fi
else
	echo "find load file:${SAVEFOLDER}${MEGATONGBUFOLDER}/$FILE ,not need download" >> "./${LOGFOLDER}mega-get_${FILE}_${LOG_SUFFIX}.log" 
fi 
 
echo "$(date +"[%Y-%m-%d %H:%M:%S]") ===MEGA-GET=== download ${SAVEFOLDER}${MEGATONGBUFOLDER}/$FILE complete" 

if [ "$STREAMORRECORD" == "stream" ]; then
	FNAME="${SITE}_$(date +"%Y%m%d_%H%M%S")"
	echo "$LOG_PREFIX ===ffmpeg=== begain stream ,check ${LOGFOLDER}${FNAME}.streaming.log for detail~"; 
	sleep 5
	ffmpeg -re -i ${SAVEFOLDER}${MEGATONGBUFOLDER}/$FILE \
      -vcodec copy -acodec aac -strict -2 -f flv "${RTMPURL}" \
      > "${LOGFOLDER}${FNAME}.streaming.log" 2>&1
    sleep 5 
    echo "$(date +"[%Y-%m-%d %H:%M:%S]") ===ffmpeg=== end stream , clean file ${SAVEFOLDER}${MEGATONGBUFOLDER}/$FILE"; 
    find ${SAVEFOLDER}${MEGATONGBUFOLDER}/$FILE -type f -delete 
else
	echo "$LOG_PREFIX not need stream,over~"; 
fi



