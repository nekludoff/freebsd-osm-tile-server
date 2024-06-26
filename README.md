# freebsd-osm-tile-server

Shell scripts to create Open Street Map tile server on FreeBSD 14.1

You will need a fresh FreeBsd 14.1 installation with ZFS file system. I recommend a minimum 8gb ram, 8gb swap file and 100gb hdd

1. Login as Root and execute follow commands <br>

pkg upgrade -y <br>
portsnap auto <br>
pkg install -y git sudo wget nano bash<br>
cd /root <br>
git clone https://github.com/nekludoff/freebsd-osm-tile-server.git <br>

2. Run install.sh by type in command string 

cd freebsd-osm-tile-server <br>
<b>bash install.sh</b><br>

4. After the install.sh will completed, run map-test.html
5. Reboot your server
