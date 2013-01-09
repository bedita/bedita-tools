#!/bin/sh

# define usage function
usage(){
	echo "Usage: $0 name [branch] [base-path] [unix-group-name]\n\n"
	echo "  name: instance name (mandatory)\n"
	echo "  branch: git branch for BEdita (default master)\n"
	echo "  base-path: base path fore new instance, will be created in base path/name (default /home/bedita3)\n"
	echo "  unix-group-name: unix group name for permission on instance (default bedita)\n"
	exit 1
}

# args, at least 1 argument
if [ $# -eq 0 ]
then
	usage
fi

BE_INSTANCE=$1

# defaults
BE_DIR="/home/bedita3"
BE_GROUP="bedita"
BE_BRANCH="master"

if [ $# -gt 1 ]
then
    BE_BRANCH=$2
	echo "Creating instance from branch $BE_BRANCH\n"
fi

if [ $# -gt 2 ]
then
    BE_DIR=$3
	echo "Using $BE_DIR as base path\n"
fi

if [ $# -gt 3 ]
then
    BE_GROUP=$3
	echo "Using $BE_GROUP as unix group name\n"
fi

# too many args
if [ $# -gt 4 ]
then
    echo "Too many arguments.\nThis script accepts four arguments\n"
	usage
fi

BEFRONT_DIR="frontends"
BE_REPO="https://github.com/bedita/bedita.git"

DIR="$BE_DIR/$BE_INSTANCE"

stat=1 # exit status (da resettare a zero prima di uscire senza errori)
trap 'exitOK;' 0
trap 'exitKO;' 1 2 15
exitOK() {
	d=`date '+%F %R'`
	exit $stat
}
exitKO() {
	d=`date '+%F %R'`
	# segnala l'errore
	echo "$d Process stopped, instance $BE_INSTANCE created partially."
	echo "Please manually remove folder."
	exit $stat
}

# get current user
USER=`eval whoami`

echo "\n\nExecuting: sudo mkdir $DIR"
sudo mkdir $DIR

echo "Executing: sudo chown $USER:$BE_GROUP $DIR"
sudo chown $USER:$BE_GROUP $DIR 

echo "Executing: sudo chmod g+w $DIR"
sudo chmod g+w $DIR

echo "Executing: sudo chmod g+s $DIR"
sudo chmod g+s $DIR
cd $DIR

echo "\nExecuting: git clone -b $BE_BRANCH $BE_REPO . [insert auth info if needed]"
git clone -b $BE_BRANCH $BE_REPO .

echo "\nExecuting: mkdir $DIR/$BEFRONT_DIR"
mkdir $DIR/$BEFRONT_DIR

echo "Executing: mkdir $DIR/apache"
mkdir $DIR/apache
echo "Executing: touch $DIR/apache/$BE_INSTANCE"
touch $DIR/apache/$BE_INSTANCE

echo "Executing: mkdir $DIR/addons"
mkdir $DIR/addons
echo "Executing: mkdir $DIR/modules"
mkdir $DIR/modules

echo "Releasing .sample files in $DIR/bedita-app/config"
cd $DIR/bedita-app/config
cp core.php.sample core.php
cp database.php.sample database.php


echo "---------------------------------------------------"
echo "Instance $BE_INSTANCE created"
echo "---------------------------------------------------"
echo "\n\nNow symlink your apache vhost config file:\n"
echo "  ln -s $DIR/apache/$BE_INSTANCE /etc/apache2/sites-enabled/"
echo "\n\nThen reload apache and use BEdita web wizard to finish setup"

