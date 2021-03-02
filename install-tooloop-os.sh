#!/bin/bash

# Say hi
echo "-------------------------------------------------------------------------"
echo "Tooloop OS"
echo "-------------------------------------------------------------------------"
echo " "

# get the path to the script
SCRIPT_PATH="`dirname \"$0\"`"                  # relative
SCRIPT_PATH="`( cd \"$SCRIPT_PATH\" && pwd )`"  # absolutized and normalized
if [ -z "$SCRIPT_PATH" ] ; then
  # error; for some reason, the path is not accessible
  # to the script (e.g. permissions re-evaled after suid)
  exit 1  # fail
fi

# exit if we’re not root
if [ $EUID != 0 ]; then
  echo "This script must be run as root."
  exit $exit_code
    exit 1
fi


# ------------------------------------------------------------------------------
# Update
# ------------------------------------------------------------------------------
echo " "
echo "-------------------------------------------------------------------------"
echo "1/3 --- Updating system"
echo "-------------------------------------------------------------------------"
echo " "

# Updating system first
apt update -y
apt dist-upgrade -y


# ------------------------------------------------------------------------------
# Packages
# ------------------------------------------------------------------------------
echo " "
echo "-------------------------------------------------------------------------"
echo "2/3 --- Installing base packages"
echo "-------------------------------------------------------------------------"
echo " "

# Install base packages
apt install -y --no-install-recommends \
  xorg \
  x11-xserver-utils \
  openbox \
  obmenu \
  obconf \
  chromium-browser \
  ssh \
  x11vnc \
  pulseaudio \
  pavucontrol \
  unclutter \
  hsetroot \
  scrot \
  git \
  zip \
  unzip \
  make \
  gcc \
  curl \
  htop \
  vainfo \
  augeas-doc \
  augeas-lenses \
  augeas-tools \
  bash-completion \
  nano \
  psmisc \
  pcregrep

# ------------------------------------------------------------------------------
# Config
# ------------------------------------------------------------------------------
echo " "
echo "-------------------------------------------------------------------------"
echo "3/3 --- Configuring system"
echo "-------------------------------------------------------------------------"
echo " "

# Allow shutdown commands without password and add tooloop scripts path to sudo
cat >/etc/sudoers.d/tooloop <<EOF
# find and autocomplete tooloop scripts using sudo
Defaults  secure_path="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/snap/bin:/opt/tooloop/scripts"
# make an alias for x11vnc start and stop commands
Cmnd_Alias VNC_CMNDS = /bin/systemctl start x11vnc, /bin/systemctl stop x11vnc
# allow these commands without using a password
tooloop     ALL=(ALL) NOPASSWD: /sbin/poweroff, /sbin/reboot, /sbin/shutdown, VNC_CMNDS
EOF

# Auto login
mkdir -p /etc/systemd/system/getty\@tty1.service.d
cat >/etc/systemd/system/getty\@tty1.service.d/autologin.conf <<EOF
[Service]
ExecStart=
ExecStart=/sbin/agetty --skip-login --noissue --autologin "tooloop" %I
EOF

# Create the /assets folder sctructure
mkdir -p /assets/addons
mkdir -p /assets/data
mkdir -p /assets/logs
mkdir -p /assets/presentation
mkdir -p /assets/screenshots


# Silent boot
augtool<<EOF
set /files/etc/default/grub/GRUB_DEFAULT 0
set /files/etc/default/grub/GRUB_TIMEOUT 0
set /files/etc/default/grub/GRUB_CMDLINE_LINUX_DEFAULT \""console=tty12 quiet loglevel=3 rd.systemd.show_status=false rd.udev.log-priority=3\""
save
EOF

update-grub2

# Nice SSH banner
augtool<<EOF
set /files/etc/ssh/sshd_config/Banner /etc/issue.net
save
EOF

cat >/etc/issue.net <<EOF




     |                         |
   --|--     _____     _____   |       _____     _____     _____
     |      /     \   /     \  |      /     \   /     \   /     \\
     |     |       | |       | |     |       | |       | |       |
     |     |       | |       | |     |       | |       | |       |
      \___  \____ /   \____ /   \___  \____ /   \____ /  |  ____/
                                                         |
                  Tooloop OS 0.9 alpha  |  Ubuntu 18.04  |


Hint: There's a bunch of convenient aliases starting with tooloop-...
E.g. tooloop-presentation-stop, tooloop-settings

-------------------------------------------------------------------------

EOF

# Get rid of the last login message
touch /home/tooloop/.hushlogin
chown tooloop:tooloop /home/tooloop/.hushlogin

# Hide verbose kernel messages
cat >/etc/sysctl.d/20-quiet-printk.conf <<EOF
kernel.printk = 3 3 3 3
EOF

# Disable wait-online service to prevent the system from waiting forever on a 
# network connection. This will disable the following services:
# open-iscsi.service cloud-final.service cloud-config.service iscsid.service
# https://askubuntu.com/questions/972215/a-start-job-is-running-for-wait-for-network-to-be-configured-ubuntu-server-17-1
systemctl disable systemd-networkd-wait-online.service
systemctl mask systemd-networkd-wait-online.service

# Copy bash config
cp "$SCRIPT_PATH"/files/bashrc /home/tooloop/.bashrc
chown tooloop:tooloop /home/tooloop/.bashrc

# Copy Openbox theme
cp -R "$SCRIPT_PATH"/files/openbox-theme/* /usr/share/themes/

# Copy Openbox config
mkdir -p /home/tooloop/.config
mkdir -p /home/tooloop/.config/openbox
cp -R "$SCRIPT_PATH"/files/openbox-config/* /home/tooloop/.config/openbox/

# Copy Openbox menu icons
mkdir -p /home/tooloop/.config/openbox-menu-icons
cp -R "$SCRIPT_PATH"/files/openbox-menu-icons/* /home/tooloop/.config/openbox-menu-icons/

# Copy start- and stop-presentation scripts
cp "$SCRIPT_PATH"/files/start-presentation.sh /assets/presentation/
cp "$SCRIPT_PATH"/files/stop-presentation.sh /assets/presentation/

# Copy Clear Sans font
cp -R "$SCRIPT_PATH"/include/clearsans /usr/share/fonts/truetype

# Copy scripts
mkdir -p /opt/tooloop
cp -R "$SCRIPT_PATH"/files/scripts /opt/tooloop
chmod +x /opt/tooloop/scripts/*

# Get settings server
# TODO: remove branch when merging
git clone --single-branch --branch appcenter https://github.com/vollstock/Tooloop-Settings-Server.git /opt/tooloop/settings-server

# Install dependencies
/bin/bash /opt/tooloop/settings-server/install-dependencies.sh

# Create a systemd service for settings server
mkdir -p /usr/lib/systemd/system/
cat > /usr/lib/systemd/system/tooloop-settings-server.service <<EOF
[Unit]
Description=Tooloop settings server
After=network.target

[Service]
Environment=DISPLAY=:0
Environment=XAUTHORITY=/home/tooloop/.Xauthority
ExecStart=/usr/bin/python /opt/tooloop/settings-server/tooloop-settings-server.py
Restart=always

[Install]
WantedBy=graphical.target
EOF

# Enable and start the service
systemctl enable tooloop-settings-server
systemctl start tooloop-settings-server

# Create a systemd target for Xorg
# info here: https://superuser.com/a/1128905
mkdir -p /usr/lib/systemd/user
cat > /usr/lib/systemd/user/xsession.target <<EOF
[Unit]
Description=XSession
BindsTo=graphical-session.target
EOF

# Create a systemd service for the VNC server
cat > /usr/lib/systemd/user/x11vnc.service <<EOF
[Unit]
Description=x11vnc screen sharing service

[Service]
Environment=DISPLAY=:0
Environment=XAUTHORITY=/home/tooloop/.Xauthority
Type=simple
ExecStart=/bin/sh -c '/usr/bin/x11vnc -shared -forever -passwd tooloop'
Restart=on-success
SuccessExitStatus=3

[Install]
WantedBy=xsession.target
EOF

# Create a cronjob to take a screenshot every minute
(crontab -u tooloop -l ; echo "* * * * * env DISPLAY=:0.0 /opt/tooloop/scripts/tooloop-screenshot") | crontab -u tooloop -

# Create a cronjob to clean up screenshots every day at 00:00
(crontab -u tooloop -l ; echo "0 0 * * * /opt/tooloop/scripts/tooloop-screenshots-clean") | crontab -u tooloop -

# make Enttec USB DMX devices accessable to the tooloop user
usermod -aG tty tooloop
usermod -aG dialout tooloop
cat > /etc/udev/rules.d/75-permissions-enttec.rules <<EOF
SUBSYSTEM=="usb", ACTION=="add|change", ATTRS{idVendor}=="0403", ATTRS{idProduct}=="6001", "MODE="0666"
EOF

# Create local deb repository
mkdir -p /assets/packages/media/
mkdir -p /assets/packages/conf/
cat > /assets/packages/conf/distributions <<EOF
Origin: Tooloop_Local_repo
Label: Tooloop_Local_Repo
Codename: bionic
Architectures: i386 amd64
Components: main
Description: Local repository for Tooloop presentations and addons
EOF

# Add to apt source list
echo "deb [allow-insecure=yes] file:/assets/packages ./" | tee -a /etc/apt/sources.list

# Stop apt from removing empty folders when uninstalling stuff
touch /assets/data/.keep
touch /assets/presentation/.keep
touch /opt/tooloop/settings-server/installed_app/.keep

# Get bundled packages
# TODO: download release from github
# For now:
git clone https://github.com/Tooloop/Tooloop-Packages.git /home/tooloop/Tooloop-Packages
cd /home/tooloop/Tooloop-Packages
./build.sh

# Chown things to the tooloop user
chown -R tooloop:tooloop /assets/
chown -R tooloop:tooloop /home/tooloop/
chown -R tooloop:tooloop /opt/tooloop/


echo " "
echo "-------------------------------------------------------------------------"
echo "Done."
echo "-------------------------------------------------------------------------"
echo " "

sleep 1

echo "We will reboot now into your Tooloop OS installation."
echo "Enjoy ;-)"

sleep 5

reboot