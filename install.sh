#!/bin/sh
cd /

echo "CPUTYPE?=native" >> /etc/make.conf
echo "CFLAGS+=-O3 -funroll-loops -flto -march=native -pipe -s -DNDEBUG" >> /etc/make.conf
echo "CXXFLAGS+=-O3 -funroll-loops -flto -march=native -pipe -s -DNDEBUG" >> /etc/make.conf
echo "COPTFLAGS+=-O3 -funroll-loops -flto -march=native -pipe -s -DNDEBUG" >> /etc/make.conf

echo "DEFAULT_VERSIONS+=llvm=16" >> /etc/make.conf
echo "DEFAULT_VERSIONS+=php=8.3" >> /etc/make.conf
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
zfs set compression=lz4 zroot/pgdb
zfs set atime=off zroot/pgdb
zfs set xattr=sa zroot/pgdb
zfs set logbias=latency zroot/pgdb
zfs set redundant_metadata=most zroot/pgdb
zfs set recordsize=64k zroot/pgdb/wal
zfs set compression=off zroot/pgdb/wal

pkg install -y git sudo wget npm nano
pkg install -y llvm16 lua54 openssl
pkg install -y mc nano bash apache24 boost-all cairo 
pkg install -y cmake coreutils curl freetype2 glib gmake harfbuzz icu iniparser 
pkg install -y libjpeg-turbo libmemcached python39 sqlite3 tiff webp zlib-ng bzip2
pkg install -y py311-pyyaml
pkg install -y py311-requests
pkg install -y png tiff jpeg proj cairomm pkgconf libtool libltdl
pkg install -y py311-boost-libs py311-cairo
ln -s /usr/local/bin/python3.11 /usr/local/bin/python
ln -s /usr/local/bin/python3.11 /usr/local/bin/python3

cd /root

pkg delete -y proj
pkg delete -y sfcgal
pkg delete -y gdal
pkg delete -y postgresql15-client
pkg delete -y postgresql16-client

git clone https://github.com/nekludoff/freebsd-osm-tile-server.git
cd freebsd-osm-tile-server/Postgresql-16

pkg install -y postgresql16-client-16.4.pkg
pkg install -y sfcgal-2.0.0.pkg
pkg install -y gdal-3.9.2_2.pkg
pkg install -y py311-psycopg-c-3.1.20.pkg
pkg install -y py311-psycopg-3.1.20.pkg
pkg install -y py311-psycopg2-2.9.9_1.pkg
pkg install -y py311-psycopg2cffi-2.9.0.pkg
pkg install -y postgresql16-contrib-16.4.pkg
pkg install -y osm2pgsql-2.0.0.pkg
pkg install -y postgresql16-server-16.4.pkg
pkg install -y postgis34-3.4.3.pkg
chown -R postgres:postgres /pgdb

sysrc postgresql_enable="YES"
cp -f postgresql /usr/local/etc/rc.d/postgresql
chmod 755 /usr/local/etc/rc.d/postgresql
/usr/local/etc/rc.d/postgresql initdb
mv -f /pgdb/data/16/pg_wal /pgdb/wal/16
ln -s /pgdb/wal/16/pg_wal /pgdb/data/16/pg_wal
cp -f pg_hba.conf /pgdb/data/16/pg_hba.conf
cp -f postgresql.conf /pgdb/data/16/postgresql.conf
service postgresql start

su - postgres -c "createuser _renderd"
su - postgres -c "createdb -E UTF8 -O _renderd gis"
psql -U postgres -d gis -c "ALTER USER _renderd WITH SUPERUSER";
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
psql -U postgres -d gis -c "ALTER USER _renderd WITH SUPERUSER";
sudo -u _renderd scripts/get-external-data.py

cd /home/_renderd/src/openstreetmap-carto/
scripts/get-fonts.sh
mkdir /usr/share/fonts
cp -r /home/_renderd/src/openstreetmap-carto/fonts/* /usr/share/fonts

cd /root
git clone --recursive https://github.com/mapnik/mapnik.git
cd mapnik

export JOBS=4
export PYTHON=python3.11

bash configure \
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

cp -r -f /root/mapnik/deps/mapbox/protozero/include/protozero /usr/local/include/
cp -r -f /root/mapnik/deps/mapbox/variant/include/mapbox /usr/local/include/
cp -r -f /root/mapnik/deps/mapbox/polylabel/include/mapbox /usr/local/include/
cp -r -f /root/mapnik/deps/mapbox/geometry/include/mapbox /usr/local/include/

cd /root
git clone --recursive  https://github.com/openstreetmap/mod_tile.git
cd mod_tile


mkdir /usr/include/iniparser

ln -s /usr/include/iniparser.h /usr/include/iniparser/iniparser.h

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

touch /mod_tile/planet-import-complete

service renderd start
service apache24 start
service renderd restart
service apache24 restart
