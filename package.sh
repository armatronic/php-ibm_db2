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

# What package versions are we using?
# For 7.1 use the old versions: for 7.4 use newer
phpver=`php -v | head -n1 | awk '{print $2}' | cut -d'.' -f1-2`;
if [ $phpver == '7.4' | $phpver == '8.0' ]; then
  # TODO upload newer ibm_db2 for PHP drivers to repo.schoolbox.com.au
  # The drivers are currently publicly available at:
  # https://pecl.php.net/package/ibm_db2
  ibmdb2ver='2.1.5';

  # TODO upload newer DB2 ODBC CLI drivers to repo.schoolbox.com.au
  # (I think the most recent version is 11.5.4, as that is the most recent version
  #  available in the IBM Data Server Driver Package, as found on
  #  https://epwt-www.mybluemix.net/software/support/trial/cst/programwebsite.wss?siteId=853)
  # (There is an older driver 11.1.4.4 currently publicly available at:
  #  https://public.dhe.ibm.com/ibmdl/export/pub/software/data/db2/drivers/odbc_cli/)
  db2odbcver='11.5.4';

  # TODO consider using this script to build PDO_IBM package
  # (not installable via `pecl install pdo_ibm`: may be compiled from source,
  #  downloadable from https://pecl.php.net/package/PDO_IBM)
  pdoibmver='1.4.2';
else
  echo "Build and package script only supports PHP 7.4 and 8.0";
  exit 1;
fi


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
wget https://repo.schoolbox.com.au/ibm_data_server_driver_for_odbc_cli_linuxx64_v$db2odbcver.tar.gz;
if [ $? -ne 0 ];
then
	echo "Tarball download failed: ibm_data_server_driver_for_odbc_cli_linuxx64_v$db2odbcver.tar.gz";
	exit 1;
fi
if [ -f ibm_data_server_driver_for_odbc_cli_linuxx64_v$db2odbcver.tar.gz ];
then
	tar xzvf ibm_data_server_driver_for_odbc_cli_linuxx64_v$db2odbcver.tar.gz -C /opt;
else
	echo "Missing ibm_data_server_driver_for_odbc_cli_linuxx64_v$db2odbcver.tar.gz"
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

cp -v /usr/lib/php/$zendapi/ibm_db2.so  php$phpver-ibmdb2-$ibmdb2ver/;
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
