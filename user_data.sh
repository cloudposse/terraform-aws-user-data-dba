
##############
# Install deps
##############

apt-get -y install python-pip pv mysql-client

# Install AWS Client
pip install --upgrade awscli

##
## MySQL Client Configuration
##
cat <<"__EOF__" > /root/${name}.my.cnf
[client]
database=${db_name}
user=${db_user}
password=${db_password}
host=${db_host}
__EOF__
chmod 600 /root/${name}.my.cnf

##
## Makefile for MySQL commands
##

curl https://raw.githubusercontent.com/cloudposse/mysql_fix_encoding/3.0/fix_it.sh -o /usr/local/bin/mysql_latin_utf8.sh
chmod +x /usr/local/bin/mysql_latin_utf8.sh

curl https://raw.githubusercontent.com/cloudposse/rds-snapshot-restore/1.0/rds_restore_cluster_from_snapshot.sh -o /usr/local/bin/rds_restore_cluster_from_snapshot.sh
chmod +x /usr/local/bin/rds_restore_cluster_from_snapshot.sh

cat <<"__EOF__" > /usr/local/include/Makefile.${name}.mysql
DUMP ?= /tmp/mysqldump.sql
MY_CNF := /root/${name}.my.cnf

.PNONY : ${name}\:db-import
## Import dump
${name}\:db-import:
	@pv $(DUMP) | sudo mysql --defaults-file=$(MY_CNF)
	 MY_CNF=$(MY_CNF) /usr/local/bin/mysql_latin_utf8.sh | pv | sudo mysql --defaults-file=$(MY_CNF)
__EOF__
chmod 644 /usr/local/include/Makefile.${name}.mysql

cat <<"__EOF__" > /usr/local/include/Makefile.${name}.aws_mysql
DUMP ?= /tmp/mysqldump.sql
MY_CNF := /root/${name}.my.cnf
SOURCE ?= ${default_dump_source}

.PNONY : ${name}\:db-import-from-s3
## Import dump
${name}\:db-import-from-s3:
	@pv $(DUMP) | sudo mysql --defaults-file=$(MY_CNF)
	MY_CNF=$(MY_CNF) /usr/local/bin/mysql_latin_utf8.sh | pv | sudo mysql --defaults-file=$(MY_CNF)
__EOF__
chmod 644 /usr/local/include/Makefile.${name}.aws_mysql

cat <<"__EOF__" > /usr/local/include/Makefile.${name}.rds
CLUSTER ?= ${db_cluster_name}

.PNONY : ${name}\:restore-from-snapshot
## Restore dump from snapshot. Specify SNAPSHOT_ID and DRY_RUN=false
${name}\:restore-from-snapshot:
	$(call assert-set,SNAPSHOT_ID)
	$(call assert-set,DRY_RUN)
	@DRY_RUN=$(DRY_RUN) MASTER_PASSWORD=$(shell sudo cat /root/${name}.my.cnf | grep password | cut -d'=' -f2) /usr/local/bin/rds_restore_cluster_from_snapshot.sh $(CLUSTER) $(SNAPSHOT_ID)

__EOF__
chmod 644 /usr/local/include/Makefile.${name}.rds

