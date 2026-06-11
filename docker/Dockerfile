# This file is written for my specific use case, change it accordingly to your tastes and needs
FROM osrf/ros:noetic-desktop-full

ENV DEBIAN_FRONTEND=noninteractive

ARG UNAME=user
ARG UID=1000
ARG GID=1000
RUN groupadd -g ${GID} -o ${UNAME}
RUN useradd -m -u ${UID} -g ${GID} -o -s /bin/bash ${UNAME}
RUN usermod -aG sudo ${UNAME}
RUN echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers
USER ${UNAME}

ENV USER=${UNAME}
ENV HOME=/home/${UNAME}
USER ${UNAME}
ENV ROS_WS=/home/${UNAME}/ros_ws
RUN mkdir -p ${ROS_WS}/src

SHELL ["/bin/bash", "-c"]

RUN echo ". /opt/ros/noetic/setup.bash" >> ~/.bashrc 

WORKDIR /home/${UNAME}
RUN sudo apt-get update && sudo apt-get install -y git
RUN git clone https://github.com/PX4/PX4-Autopilot.git --recursive \
    && bash ./PX4-Autopilot/Tools/setup/ubuntu.sh --no-nuttx --no-sim-tools
WORKDIR /home/${UNAME}/PX4-Autopilot/
RUN make px4_sitl

WORKDIR /home/${UNAME}
RUN curl -L https://d176tv9ibo4jno.cloudfront.net/latest/QGroundControl-x86_64.AppImage \
    -o QGroundControl-x86_64.AppImage
RUN chmod +x QGroundControl-x86_64.AppImage \
    && ./QGroundControl-x86_64.AppImage --appimage-extract \
    && rm QGroundControl-x86_64.AppImage \
    && chmod +x squashfs-root/AppRun \
    && sudo ln -s /home/${UNAME}/squashfs-root/AppRun /usr/local/bin/qgc

COPY docker/requirements.txt /tmp/requirements.txt
RUN sudo apt-get update && sudo apt-get install -y $(cat /tmp/requirements.txt)

WORKDIR /tmp
RUN wget https://raw.githubusercontent.com/mavlink/mavros/master/mavros/scripts/install_geographiclib_datasets.sh \
    && sudo chmod +x ./install_geographiclib_datasets.sh \
    && sudo bash ./install_geographiclib_datasets.sh \
    && rm install_geographiclib_datasets.sh

# ENV ROS_HOSTNAME=localhost
# ENV ROS_MASTER_URI=http://localhost:11311

RUN sudo usermod -a -G dialout ${UNAME} 
WORKDIR /home/${UNAME}
ENV DISABLE_ROS1_EOL_WARNINGS=1

COPY docker/ros_entrypoint.sh /ros_entrypoint.sh
ENTRYPOINT ["/ros_entrypoint.sh"]
CMD ["bash"]
