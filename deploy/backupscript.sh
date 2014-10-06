#!/bin/bash
# This script is supposed to run every day as cron job. It copies redis snapshot into S3,
#   if the size of the snapshot changed since the last run.
# It assumes that redis snapshot location is /var/lib/redis/dump.rdb.
# To change location of the snapshot, change redis config ro pass parameters:
#    sudo nohup redis-server --dir /var/lib/redis/ --save 300 1 >redis.out 2>&1 &
#
# Steps:
# In the AWS IAM console, create a user (with access to S3) and generate access keys. 
#   Paste them in here, see AWS_xxxxx.
# In the AWS S3 console, create a bucket (deffer-user-files) and give this user 
#   permissions to list files and save. See s3_policy.txt for example of permissions.
# Create a user, for example banana and give it access to redis snapshot file.
# Create a folder /var/lib/banana and give ownership to banana.
# Copy this script to /usr/local/bin
# Create a cron job under user banana's ownershipt, see below:
#   $sudo crontab -u banana -e
#       MAILTO=your.email@gmail.com
#       30 2,5 * * * /usr/local/bin/backupsript.sh 1> /dev/nul
#
export AWS_ACCESS_KEY_ID=
export AWS_SECRET_ACCESS_KEY=
need=false
prevfile=/var/lib/banana/dump.rdb
newfilename=dump.rdb.`date "+%Y-%m-%d"`
currentfile=/var/lib/banana/$newfilename
cp /var/lib/redis/dump.rdb $currentfile 
if [ -e $prevfile ]; then
  prevsize=$(stat -c%s $prevfile)
  currentsize=$(stat -c%s $currentfile)
  echo "Comparing sizes $prevsize and $currentsize"
  [ $prevsize -eq $currentsize ] && need=false || need=true
else
  echo "Previous file not found"
  need=true
fi
echo "Need to backup? $need"
if [ "true" == "$need" ]; then
  echo "Copying $currentfile to S3"  
  aws s3 cp "$currentfile" "s3://deffer-user-files/$newfilename" --region=ap-southeast-2
  rm -rf $prevfile
  mv $currentfile $prevfile
fi
