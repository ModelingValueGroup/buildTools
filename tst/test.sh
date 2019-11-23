#!/usr/bin/env bash

##### make tmp dir
tmp=./tmp
rm -rf $tmp
mkdir $tmp
cd $tmp

##### read in the local secrets
. ~/secrets.sh

##### read all scripts
for f in ../src/*.sh; do
  . "$f"
done

downloadArtifactQuick

echo ok