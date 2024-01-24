#/bin/sh
scp -r "Ube.sc" "root@192.168.7.2:/usr/share/SuperCollider/Extensions/Ube.sc"
~/Documents/Github/Bela/scripts/build_project.sh . --force -c "-H -6 --disable-led 1"