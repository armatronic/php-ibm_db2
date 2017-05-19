#!/bin/bash
initialdir=`pwd`;

echo "Build and package php-ibm_db2";

echo "operating in dir: `pwd`";

echo "Creating artifact directory";
mkdir -vp $initialdir/package-artifacts;

distrocodename=`cat /etc/lsb-release | grep DISTRIB_CODENAME | cut -d'=' -f2`;
if [ "$distrocodename" == "trusty" ];
then
	echo "Running on Ubuntu 14.04 Trusty";
	echo "Installing newer build toolchain";
	apt-get update;
	apt-get -y install software-properties-common python-software-properties;
	add-apt-repository ppa:ubuntu-toolchain-r/test -y;
	apt-get update;
	export CPPFLAGS="-DSIZEOF_LONG_INT=8";
	apt-get -y install gcc-5 g++-5 libgss3;
	if [ $? -ne 0 ];
	then
		echo "unable to installed updated toolchain";
		exit 1;
	fi
	update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-5 60 --slave /usr/bin/g++ g++ /usr/bin/g++-5;
fi

ibmdb2ver='1.9.9';

echo "Downloading ibm_db2 for php";
cd $initialdir;
wget https://repo.schoolbox.com.au/ibm_db2-$ibmdb2ver.tgz;
if [ $? -ne 0 ];
then
	echo "Tarball download failed: ibm_db2-$ibmdb2ver.tgz";
	exit 1;
fi
if [ -f ibm_db2-$ibmdb2ver.tgz ];
then
	tar xzvf ibm_db2-$ibmdb2ver.tgz -C /opt;
else
	echo "Missing ibm_db2-$ibmdb2ver.tgz"
	exit 1;
fi

echo "Downloading ibm_odbc_cli";
cd $initialdir;
mkdir -vp /opt/ibm;
wget https://repo.schoolbox.com.au/ibm_data_server_driver_for_odbc_cli_linuxx64_v11.1.tar.gz;
if [ $? -ne 0 ];
then
	echo "Tarball download failed: ibm_data_server_driver_for_odbc_cli_linuxx64_v11.1.tar.gz";
	exit 1;
fi
if [ -f ibm_data_server_driver_for_odbc_cli_linuxx64_v11.1.tar.gz ];
then
	tar xzvf ibm_data_server_driver_for_odbc_cli_linuxx64_v11.1.tar.gz -C /opt;
else
	echo "Missing ibm_data_server_driver_for_odbc_cli_linuxx64_v11.1.tar.gz"
	ls -lR;
	exit 1;
fi
mv -v /opt/clidriver /opt/ibm/sqllib;

echo "Exporting environment variables";
export IBM_DB_HOME=/opt/ibm/sqllib;
export IBM_DB_DIR=/opt/ibm/sqllib;
export IBM_DB_LIB=/opt/ibm/sqllib/lib;
echo "IBM_DB_HOME: $IBM_DB_HOME";
echo "IBM_DB_DIR: $IBM_DB_DIR";
echo "IBM_DB_LIB: $IBM_DB_LIB";

echo "Compiling driver from source";
cd /opt/ibm_db2-$ibmdb2ver;

phpver=`php -v | head -n1 | awk '{print $2}' | cut -d'.' -f1-2`;
echo "For php version: $phpver";

echo "phpize";
phpize=`phpize`;
echo "$phpize";

zendapi=`echo "$phpize" | grep 'Zend Module Api No:' | cut -d':' -f2 | awk '{print $1}'`;
echo "Zend API: $zendapi";

echo "configure php-ibm_db2";
./configure -with-IBM_DB2=/opt/ibm/sqllib;

echo "make php-ibm_db2";
make;

echo "make install php-ibm_db2";
make install;

echo "modules"
ls -lR modules;

phpibmdb2dir=`pwd`;

# Create directories for completing the build
builddir="$initialdir/build-dir-`date -I`";
rm -fR $builddir;
mkdir -vp $builddir;
cd $builddir;

cleanver=`echo "$ibmdb2ver" | cut -d'-' -f1`;
ibmdb2ver="$cleanver";

mkdir php$phpver-ibmdb2-$ibmdb2ver;

cp -v $phpibmdb2dir/ibm_db2/modules/*.so  php$phpver-ibmdb2-$ibmdb2ver/;
cp -v $initialdir/php-ibm_db2-package/extra/* php$phpver-ibmdb2-$ibmdb2ver/;
cp -vR /opt/ibm/sqllib php$phpver-ibmdb2-$ibmdb2ver/;
tar czvf php$phpver-ibmdb2_$ibmdb2ver.orig.tar.gz php$phpver-ibmdb2-$ibmdb2ver;

cp -vfR $initialdir/php-ibm_db2-package/debian php$phpver-ibmdb2-$ibmdb2ver/;

cd php$phpver-ibmdb2-$ibmdb2ver;

mv -v debian/phpX.Y-ibmdb2.install debian/php$phpver-ibmdb2.install;
mv -v debian/phpX.Y-ibmdb2.links debian/php$phpver-ibmdb2.links;
sed -i "s/X\.Y/$phpver/g" debian/*;
sed -i "s/YYYYMMDD/$zendapi/g" debian/*;
sed -i "s/DISTROCODENAME/$distrocodename/g" debian/*;
sed -i "s/IBM_DB2VER/$ibmdb2ver/g" debian/*;
# Build!
debuild -i -I -us -uc;
if [ $? -ne 0 ];
then
        echo "Build failed";
        exit 1;
fi

echo "Copy deb files to package-artifacts";
cp -vf ../*.deb $initialdir/package-artifacts;

echo "Artifact List: `readlink -f $initialdir/package-artifacts/`";
ls -lhR $initialdir/package-artifacts/;

echo "Creating package tarball";
cd $initialdir;
tar czvf php$phpver-ibm_db2-package.tar.gz package-artifacts;
if [ $? -ne 0 ];
then
        echo "Unable to tarball packages";
        exit 1;
fi

cp -v php$phpver-ibm_db2-package.tar.gz $initialdir/package-artifacts/;
