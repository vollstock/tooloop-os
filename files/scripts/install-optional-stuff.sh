#!/bin/bash

# Heavily borrowed from raspi-config
# https://github.com/asb/raspi-config


if [ $EUID != 0 ]; then
  echo "This script must be run using sudo"
  echo ""
  echo "usage:"
  echo "sudo "$0
  exit $exit_code
    exit 1
fi


function calc_wt_size {
  # NOTE: it's tempting to redirect stderr to /dev/null, so supress error 
  # output from tput. However in this case, tput detects neither stdout or 
  # stderr is a tty and so only gives default 80, 24 values
  WT_HEIGHT=15
  WT_WIDTH=$(tput cols)


  if [ -z "$WT_WIDTH" ] || [ "$WT_WIDTH" -lt 60 ]; then
    WT_WIDTH=80
  fi
  if [ "$WT_WIDTH" -gt 120 ]; then
    WT_WIDTH=120
  fi
  WT_MENU_HEIGHT=$(($WT_HEIGHT-7))
}


# ------------------------------------------------------------------------------
# Install functions
# ------------------------------------------------------------------------------


# AMD drivers
function install_amd_drivers {
  # Installation manual
  # https://support.amd.com/en-us/kb-articles/Pages/AMDGPU-PRO-Install.aspx
  
  # downlaod the driver
  # wget https://www2.ati.com/drivers/linux/ubuntu/amdgpu-pro-17.10-450821.tar.xz
  
  # extract it
  tar xf amdgpu-pro-17.10-450821.tar.xz

  # run the installer
  ./amdgpu-pro-17.10-450821/amdgpu-pro-install

  # move drivers in the right places
  # https://community.amd.com/message/2769317
  ln -s /opt/amdgpu-pro/lib/x86_64-linux-gnu/dri/radeonsi_drv_video.so /usr/lib/x86_64-linux-gnu/dri/amdgpu_drv_video.so
  cp /opt/amdgpu-pro/lib/x86_64-linux-gnu/vdpau/*.* /usr/lib/x86_64-linux-gnu/vdpau/

  # TODO: possibly necessary (https://forum.ubuntuusers.de/topic/amd-athlon-5350-apu-und-radeon-treiber/)
  # dpkg-reconfigure xserver-xorg
  # update-initramfs -u -k all
}



# ------------------------------------------------------------------------------
# openframeworks
# ------------------------------------------------------------------------------
function install_of {
  apt-get -y install curl
  wget http://openframeworks.cc/versions/v0.9.8/of_v0.9.8_linux64_release.tar.gz
  tar xf of_v0.9.8_linux64_release.tar.gz
  mv of_v0.9.8_linux64_release /assets/presentation/openframeworks
  /assets/presentation/openframeworks/scripts/linux/ubuntu/install_dependencies.sh
  /assets/presentation/openframeworks/scripts/linux/ubuntu/install_codecs.sh
  /assets/presentation/openframeworks/scripts/linux/compileOF.sh -j3
  chown -R tooloop:tooloop /assets/presentation/openframeworks
}



# ------------------------------------------------------------------------------
# Kivy
# ------------------------------------------------------------------------------
function install_kivy {
  add-apt-repository ppa:kivy-team/kivy
  apt-get -y install python3-kivy
  apt-get -y install python-kivy-examples
  mv /usr/share/kivy-examples /assets/presentation
  chown -R tooloop:tooloop /assets/presentation/kivy-examples
}



# ------------------------------------------------------------------------------
# GStreamer
# ------------------------------------------------------------------------------
function install_gstreamer {
  echo "Getting packages..."
  apt-get -y install mpg123 libmpg123-dev gstreamer1.0 gstreamer1.0-doc gstreamer1.0-tools  gstreamer1.0-alsa gstreamer1.0-libav gstreamer1.0-pulseaudio gstreamer1.0-plugins-base gstreamer1.0-plugins-base-doc gstreamer1.0-plugins-base-dbg gstreamer1.0-plugins-good gstreamer1.0-plugins-good-doc gstreamer1.0-plugins-good-dbg gstreamer1.0-plugins-bad gstreamer1.0-plugins-bad-doc gstreamer1.0-plugins-bad-dbg gstreamer1.0-plugins-ugly gstreamer1.0-plugins-ugly-doc gstreamer1.0-plugins-ugly-dbg gstreamer1.0-vaapi gstreamer1.0-vaapi-doc gstreamer1.0-x libgstreamer1.0-0 libgstreamer1.0-0-dbg libgstreamer1.0-dev
  apt-get -y install va-driver-all libva-glx1 libva-x11-1 vainfo vainfo
}



# ------------------------------------------------------------------------------
# Open Lighting Architecture
# ------------------------------------------------------------------------------
function install_ola {
    # install dependencies
    apt-get -y install libcppunit-dev libcppunit-1.13-0v5 uuid-dev pkg-config libncurses5-dev libtool autoconf automake g++ libmicrohttpd-dev libmicrohttpd10 protobuf-compiler libprotobuf-lite9v5 python-protobuf libprotobuf-dev libprotoc-dev zlib1g-dev bison flex make libftdi-dev libftdi1 libusb-1.0-0-dev liblo-dev libavahi-client-dev python-numpy

    # download latest tarball
    wget https://github.com/OpenLightingProject/ola/releases/download/0.10.5/ola-0.10.5.tar.gz

    # extract it
    tar -zxf ola-0.10.5.tar.gz
    cd ola-0.10.5
    autoreconf -i

    # enable python and java libs for Kivy and Processing
    ./configure --enable-python-libs --enable-java-libs

    # build it
    make -j 4
    make check
    make install
    ldconfig


    # Create a systemd service
    mkdir -p /usr/lib/systemd/system/
    cat > /usr/lib/systemd/system/olad.service <<EOF
[Unit]
Description=Open Lighting Architecture daemon
After=network.target

[Service]
User=tooloop
ExecStart=/usr/local/bin/olad
Restart=always

[Install]
WantedBy=multi-user.target
EOF

    # Enable the service
    systemctl enable olad

    # Start the service
    systemctl start olad
}



# ------------------------------------------------------------------------------
# System update
# ------------------------------------------------------------------------------
function system_update {
  apt-get update && apt-get upgrade
}





# ------------------------------------------------------------------------------
# Print menu
# ------------------------------------------------------------------------------

#get_init_sys
calc_wt_size
# WT_WIDTH=60
# WT_HEIGHT=20
# WT_MENU_HEIGHT=13
while true; do
  FUN=$(whiptail --title "Tooloop OS optional stuff" --menu "What do you want to install?" $WT_HEIGHT $WT_WIDTH $WT_MENU_HEIGHT --cancel-button Exit --ok-button Install \
    "1 openframeworks" "openframeworks C++ media framework" \
    "2 Kivy" "Kivy python NUI framework" \
    "3 GStreamer" "Gstreamer video components" \
    "4 OLA" "Open Lighting Architecture" \
    "5 AMD drivers" "Graphics drivers for FirePro series" \
    "6 Nvidia drivers" "Graphics drivers for Quadro series" \
    "7 System update" "UBUNTU system updates." \
    3>&1 1>&2 2>&3)
  RET=$?
  if [ $RET -eq 1 ]; then
    exit 0
  elif [ $RET -eq 0 ]; then
    case "$FUN" in
      1\ *) install_of ;;
      2\ *) install_kivy ;;
      3\ *) install_gstreamer ;;
      4\ *) install_ola ;;
      5\ *) install_amd_drivers ;;
      6\ *) install_nvidia_drivers ;;
      7\ *) system_update ;;
      *) whiptail --msgbox "Programmer error: unrecognized option" 20 60 1 ;;
    esac || whiptail --msgbox "There was an error running option $FUN" 20 60 1
  else
    exit 1
  fi
done
