#!/bin/bash

sudo yum update –y
sudo yum upgrade
sudo amazon-linux-extras install java-openjdk11 -y
sudo adduser --system --no-create-home --group --disabled-login sonarqube
sudo mkdir /opt/sonarqube
sudo wget https://binaries.sonarsource.com/Distribution/sonarqube/sonarqube-9.4.0.54424.zip
sudo chown -R sonarqube:sonarqube /opt/sonarqube
cd /opt/sonarqube/sonarqube-9.4.0.54424/bin/linux-x86-64
sudo sh sonar.sh start
