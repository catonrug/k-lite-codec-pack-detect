#!/bin/sh

#this code is tested un fresh 2015-11-21-raspbian-jessie-lite Raspberry Pi image
#by default this script should be located in two subdirecotries under the home

#sudo apt-get update -y && sudo apt-get upgrade -y
#sudo apt-get install git -y
#mkdir -p /home/pi/detect && cd /home/pi/detect
#git clone https://github.com/catonrug/k-lite-codec-pack-detect.git && cd k-lite-codec-pack-detect && chmod +x check.sh && ./check.sh

#check if script is located in /home direcotry
pwd | grep "^/home/" > /dev/null
if [ $? -ne 0 ]; then
  echo script must be located in /home direcotry
  return
fi

#it is highly recommended to place this directory in another directory
deep=$(pwd | sed "s/\//\n/g" | grep -v "^$" | wc -l)
if [ $deep -lt 4 ]; then
  echo please place this script in deeper directory
  return
fi

#set application name based on directory name
#this will be used for future temp directory, database name, google upload config, archiving
appname=$(pwd | sed "s/^.*\///g")

#set temp directory in variable based on application name
tmp=$(echo ../tmp/$appname)

#create temp directory
if [ ! -d "$tmp" ]; then
  mkdir -p "$tmp"
fi

#check if database directory has prepared 
if [ ! -d "../db" ]; then
  mkdir -p "../db"
fi

#set database variable
db=$(echo ../db/$appname.db)

#if database file do not exist then create one
if [ ! -f "$db" ]; then
  touch "$db"
fi

#check if google drive config directory has been made
#if the config file exists then use it to upload file in google drive
#if no config file is in the directory there no upload will happen
if [ ! -d "../gd" ]; then
  mkdir -p "../gd"
fi

if [ -f ~/uploader_credentials.txt ]; then
sed "s/folder = test/folder = `echo $appname`/" ../uploader.cfg > ../gd/$appname.cfg
else
echo google upload will not be used cause ~/uploader_credentials.txt do not exist
fi

#create a new array [linklist] with internet links inside and add one extra line
linklist=$(cat <<EOF
http://www.codecguide.com/download_k-lite_codec_pack_basic.htm
http://www.codecguide.com/download_k-lite_codec_pack_standard.htm
http://www.codecguide.com/download_k-lite_codec_pack_full.htm
http://www.codecguide.com/download_k-lite_codec_pack_mega.htm
extra line
EOF
)

printf %s "$linklist" | while IFS= read -r onelink
do {

#find torrent file on page
torrent=$( \
wget -qO- $onelink | \
sed "s/\d034\|\d039\|<\|>/\n/g" | \
grep "\.torrent" | \
head -1 | \
sed "s/^/http:\/\/www.codecguide.com\//")

#find one damn direct link which is located just inside the torrent file
url=$( \
wget -qO- $torrent | \
sed "s/http/\nhttp/g;s/\.exe/\.exe\n/g" | \
grep -a "^http.*\.exe")

filename=$( \
echo $url | \
sed "s/^.*\///g")

echo Trying to get:
echo $url
size=$(curl -o /dev/null -s -w %{size_download} $url)
if [ $size -gt 99999 ]; then

wget $url -O $tmp/$filename -q
echo

echo creating sha1 checksum of file..
sha1=$(sha1sum $tmp/$filename | sed "s/\s.*//g")
echo

#check if this file is already in database
grep "$sha1" $db > /dev/null
if [ $? -ne 0 ]
#if sha1 sum do not exist in database then this is new version
then
echo new version detected!
echo

echo creating md5 checksum of file..
md5=$(md5sum $tmp/$filename | sed "s/\s.*//g")
echo

#lets put all signs about this file into the database
echo "$md5">> $db
echo "$sha1">> $db
			
echo searching exact version number
version=$(pestr $tmp/$filename | grep -m1 -A1 "ProductVersion" | grep -v "ProductVersion")
echo $version
echo

#create unique filename for google upload
newfilename=$(echo $filename | sed "s/\.exe/_`echo $version`\.exe/")
mv $tmp/$filename $tmp/$newfilename

#if google drive config exists then upload and delete file:
if [ -f "../gd/$appname.cfg" ]
then
echo Uploading $newfilename to Google Drive..
echo Make sure you have created \"$appname\" directory inside it!
../uploader.py "../gd/$appname.cfg" "$tmp/$newfilename"
echo
fi

#lets send emails to all people in "posting" file
emails=$(cat ../posting | sed '$aend of file')
printf %s "$emails" | while IFS= read -r onemail
do {
python ../send-email.py "$onemail" "$filename $version" "$newfilename 
$md5
$sha1
https://drive.google.com/drive/folders/0B_3uBwg3RcdVMlJFWkxIN0Vvckk "
} done
echo

#end of database check
fi

else
echo file url not reachable in torrent file
echo
#end of file size check
fi

} done

#clean and remove whole temp direcotry
rm $tmp -rf > /dev/null
