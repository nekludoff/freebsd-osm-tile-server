# freebsd-osm-tile-server

Shell scripts to create Open Street Map tile server on freebsd 13.2

You will need a fresh FreeBsd 13.2 installation with ZFS file system. I recommend a minimum 8gb ram, 8gb swap file and 100gb hdd

1. Login as Root and execute follow commands <br>

pkg upgrade -y <br>
portsnap auto <br>
pkg install -y git sudo wget <br>

2. Run install.sh by type in command string <b>sh install.sh</b>
3. After the install.sh will completed, run map-test.html
4. Reboot your server
