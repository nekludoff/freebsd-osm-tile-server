#!/bin/sh
cd /

echo "CPUTYPE?=native" >> /etc/make.conf
echo "CFLAGS+=-O3 -funroll-loops -flto -march=native -pipe -s -DNDEBUG" >> /etc/make.conf
echo "CXXFLAGS+=-O3 -funroll-loops -flto -march=native -pipe -s -DNDEBUG" >> /etc/make.conf
echo "COPTFLAGS+=-O3 -funroll-loops -flto -march=native -pipe -s -DNDEBUG" >> /etc/make.conf

echo "DEFAULT_VERSIONS+=llvm=15" >> /etc/make.conf
echo "DEFAULT_VERSIONS+=php=8.1" >> /etc/make.conf
echo "DEFAULT_VERSIONS+=ssl=openssl" >> /etc/make.conf

zfs destroy -r zroot/pgdb
zfs create -o mountpoint=/pgdb zroot/pgdb
zfs create -o mountpoint=/pgdb/data zroot/pgdb/data
cd /pgdb/data
mkdir 16
zfs set recordsize=32k zroot/pgdb/data
zfs create -o mountpoint=/pgdb/wal zroot/pgdb/wal
cd /pgdb/wal
mkdir 16
zfs set recordsize=64k zroot/pgdb/wal
zfs set compression=lz4 zroot/pgdb
zfs set atime=off zroot/pgdb
zfs set xattr=sa zroot/pgdb
zfs set logbias=latency zroot/pgdb
zfs set redundant_metadata=most zroot/pgdb

pkg install -y git sudo wget npm nano
pkg install -y llvm15 lua54 
pkg install -y mc nano bash apache24 boost-all cairo ceph14 cmake coreutils curl freetype2 glib gmake harfbuzz icu iniparser libjpeg-turbo libmemcached png proj python39 sqlite3 tiff webp zlib-ng bzip
pkg install -y png tiff proj icu freetype2 cairomm pkgconf libtool libltdl
ln -s /usr/local/bin/python3.9 /usr/local/bin/python
ln -s /usr/local/bin/python3.9 /usr/local/bin/python3

cd /root
git clone https://github.com/nekludoff/freebsd-osm-tile-server.git
cd freebsd-osm-tile-server/Postgresql-16

pkg install -y postgresql16-client-16.0.pkg
pkg install -y py39-psycopg-c-3.1.10.pkg
pkg install -y py39-psycopg-3.1.10.pkg
pkg install -y py39-psycopg2-2.9.7.pkg
pkg install -y py39-psycopg2cffi-2.9.0.pkg
pkg install -y postgresql16-contrib-16.0.pkg
pkg install -y sfcgal-1.4.1_4.pkg
pkg install -y gdal-3.7.2.pkg
pkg install -y osm2pgsql-1.9.2.pkg
pkg install -y postgresql16-server-16.0.pkg
pkg install -y postgis33-3.3.4.pkg
chown -R postgres:postgres /pgdb

sysrc postgresql_enable="YES"
cp -f postgresql /usr/local/etc/rc.d/postgresql
chmod 755 /usr/local/etc/rc.d/postgresql
/usr/local/etc/rc.d/postgresql initdb
mv -f /pgdb/data/16pg_wal /pgdb/wal/16
ln -s /pgdb/wal/16/pg_wal /pgdb/data/16/pg_wal
cp -f pg_hba.conf /pgdb/data/16/pg_hba.conf
cp -f postgresql.conf /pgdb/data/16/postgresql.conf
service postgresql start

su - postgres -c "createuser _renderd"
su - postgres -c "createdb -E UTF8 -O _renderd gis"
psql -U postgres -d gis -c "CREATE EXTENSION postgis;"
psql -U postgres -d gis -c "CREATE EXTENSION hstore;"
psql -U postgres -d gis -c "ALTER TABLE geometry_columns OWNER TO _renderd;"
psql -U postgres -d gis -c "ALTER TABLE spatial_ref_sys OWNER TO _renderd;"
cd /

mkdir home
mkdir /home/_renderd
pw groupadd _renderd
pw useradd _renderd -g _renderd -s /usr/local/bin/bash
chown -R _renderd:_renderd /home/_renderd
mkdir /home/_renderd/src
cd /home/_renderd/src
git clone https://github.com/gravitystorm/openstreetmap-carto
cd /home/_renderd/src/openstreetmap-carto
npm install -g carto
carto -v
carto project.mml > mapnik.xml
mkdir /home/_renderd/data
cd /home/_renderd/data
wget http://download.geofabrik.de/russia/central-fed-district-latest.osm.pbf
chmod o+rx /home/_renderd
chown -R _renderd:_renderd /home/_renderd

sudo -u _renderd osm2pgsql -d gis --create --slim  -G --hstore --tag-transform-script /home/_renderd/src/openstreetmap-carto/openstreetmap-carto.lua -C 2500 --number-processes 4 -S /home/_renderd/src/openstreetmap-carto/openstreetmap-carto.style /home/_renderd/data/central-fed-district-latest.osm.pbf

cd /home/_renderd/src/openstreetmap-carto/
sudo -u _renderd psql -d gis -f indexes.sql

cd /home/_renderd/src/openstreetmap-carto/
mkdir data
sudo chown _renderd data
sudo -u _renderd scripts/get-external-data.py

cd /home/_renderd/src/openstreetmap-carto/
scripts/get-fonts.sh
mkdir /usr/share/fonts
cp -r /home/_renderd/src/openstreetmap-carto/fonts/* /usr/share/fonts

cd /root
git clone --recursive  https://github.com/openstreetmap/mod_tile.git
cd mod_tile
mkdir mapnik-src
cd mapnik-src

curl --location --silent https://github.com/mapnik/mapnik/releases/download/v3.1.0/mapnik-v3.1.0.tar.bz2 | tar --extract --bzip2 --strip-components=1 --file=-
curl --location --silent https://github.com/mapnik/mapnik/commit/8944e81367d2b3b91a41e24116e1813c01491e5d.patch | patch -F3 -Np1
curl --location --silent https://github.com/mapnik/mapnik/commit/83779b7b6bdd229740b1b5e12a4a8fe27114cb7d.patch | patch -F3 -Np1
curl --location --silent https://github.com/mapnik/mapnik/commit/7f0daee8b37d8cf6eff32529b1762ffd5104f3f3.patch | patch -F3 -Np1

setenv JOBS 4
setenv PYTHON python3.9
sh configure \
            CPP_TESTS=False \
            DEMO=False \
            FAST=True \
            HB_INCLUDES=/usr/local/include/harfbuzz \
            HB_LIBS=/usr/local/lib \
            ICU_INCLUDES=/usr/local/include \
            ICU_LIBS=/usr/local/lib \
            OPTIMIZATION=3 && \
          gmake PYTHON=${PYTHON} && \
          gmake install PYTHON=${PYTHON}

mkdir /usr/include/iniparser

ln -s /usr/include/iniparser.h /usr/include/iniparser/iniparser.h

cd ..
cmake -S . -B build -DCMAKE_LIBRARY_PATH=/usr/local/lib -DENABLE_TESTS=1
cmake --build build
ctest --test-dir build
cmake --install build
cd /

zfs destroy -r zroot/mod_tile
zfs create -o mountpoint=/mod_tile zroot/mod_tile
zfs set recordsize=1m zroot/mod_tile
chown -R _renderd:_renderd /mod_tile

mkdir /usr/local/etc/renderd
chown -R _renderd:_renderd /usr/local/etc/renderd
mkdir /var/run/renderd
chown -R _renderd:_renderd /var/run/renderd

sysrc apache24_enable="YES"
sysrc renderd_enable="YES"

cp -f /root/freebsd-osm-tile-server/conf/apache24/httpd.conf /usr/local/etc/apache24/httpd.conf
cp -f /root/freebsd-osm-tile-server/conf/apache24/renderd.conf /usr/local/etc/apache24/Includes/renderd.conf
chown -R www:www /usr/local/etc/apache24

cp -f /root/freebsd-osm-tile-server/conf/renderd/renderd /usr/local/etc/rc.d/renderd
chmod 755 /usr/local/etc/rc.d/renderd
cp -f /root/freebsd-osm-tile-server/conf/renderd/renderd.conf /usr/local/etc/renderd/renderd.conf
chown -R _renderd:_renderd /usr/local/etc/renderd

service renderd start
service apache24 start
service renderd restart
service apache24 restart
