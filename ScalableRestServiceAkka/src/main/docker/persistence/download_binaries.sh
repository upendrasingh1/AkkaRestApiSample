#!/usr/bin/env bash
USER=upendra.singh@tallysolutions.com
PASS=Sonu17481

wget --user=$USER --password=$PASS http://downloads.datastax.com/enterprise/dse-5.0.3-bin.tar.gz

wget --user=$USER --password=$PASS http://debian.datastax.com/enterprise/pool/datastax-agent_6.0.3_all.deb

wget --user=$USER --password=$PASS http://downloads.datastax.com/enterprise/opscenter-6.0.3.tar.gz

#ln -s /home/centos/binaries/opscenter-6.0.3.tar.gz opscenter.tar.gz
#ln -s /home/centos/binaries/dse-5.0.3-bin.tar.gz dse-bin.tar.gz
#ln -s /home/centos/binaries/datastax-agent_6.0.3_all.deb datastax-agent_all.deb