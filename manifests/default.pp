# Defaults 
Exec { path => '/usr/bin:/bin:/usr/sbin:/sbin' }
File { owner => 0, group => 0, mode => 0644 }

# Sample
group { "puppet":
	ensure => "present",
}

file { '/etc/motd':
	content => "Welcome to your Vagrant-built virtual machine!
Managed by Puppet.\n"
}

# swap
$swap_size = 3072
exec { "create swap file":
	command => "/bin/dd if=/dev/zero of=/var/swap.$swap_size bs=1M count=$swap_size",
	creates => "/var/swap.$swap_size",
}

exec { "attach swap file":
	command => "/sbin/mkswap /var/swap.$swap_size && /sbin/swapon /var/swap.$swap_size",
	require => Exec["create swap file"],
	unless => "/sbin/swapon -s | grep /var/swap.$swap_size",
}

exec { "yum update":
    command => "yum update -y",
}

package { "oracle-rdbms-server-11gR2-preinstall":
	ensure => installed,
	require => Exec["yum update"],
}
package { "elfutils-libelf-devel":
	ensure => installed,
	require => Package["oracle-rdbms-server-11gR2-preinstall"],
}
package { "mksh":
	ensure => installed,
	require => Package["oracle-rdbms-server-11gR2-preinstall"],
}

# oracle

group { "oinstall":
	ensure => "present",
	gid    => 2001, 
	require => Package["oracle-rdbms-server-11gR2-preinstall"],
}

group { "dba": 
	ensure => "present",
	gid    => 2002, 
	require => Package["oracle-rdbms-server-11gR2-preinstall"],
}

group { "nobody": 
	ensure => "present",
	gid    => 2000, 
	require => Package["oracle-rdbms-server-11gR2-preinstall"],
}

exec {"nobody nobody group membership":
	unless => "grep -q \"nobody.*:`getent group nobody | cut -d: -f3`:\" /etc/passwd",
	command => "usermod -g nobody nobody",
	require => Group['nobody'],
}

user { "oracle":
	ensure => present,
	managehome => true,
	gid => "oinstall",
	groups => ["dba"],
	membership => minimum,
	shell => "/bin/bash",
	password => '$1$n/vrV9xw$wi.ConIiqaEC0YnLLl81J1',
	require => [Group["oinstall"], Group["dba"]]
}

file { "/home/oracle":
    ensure => "directory",
    owner  => "oracle",
    group  => "dba",
    mode   => 755,
    require => User['oracle'],
}

# http://projects.puppetlabs.com/projects/1/wiki/Puppet_Augeas#/etc/sysctl.conf
Sysctl::Conf {
	require => Augeas["/etc/sysctl.conf"]
}
sysctl::conf { 
	"kernel.sem": value =>  '250 32000 100 128';
	"kernel.shmall": value => 2097152;
	"kernel.shmmni": value => 4096;

	# Replace kernel.shmmax with the half of your memory in bytes
	# if lower than 4Gb minus 1
	# 1073741824 is 1 GigaBytes
	"kernel.shmmax": value => 1052008448;
	"net.ipv4.ip_local_port_range": value => '32768	61000';
	"net.core.rmem_default": value => 262144;
	"net.core.rmem_max": value => 4194304;
	"net.core.wmem_default": value => 262144;
	"net.core.wmem_max": value => 1048576;
	# Max value allowed, should be to avoid IO errors
	"fs.aio-max-nr": value => 1048576;
	"fs.file-max": value => 6815744 ;
	# To allow dba to allocate hugetlbfs pages
	"vm.hugetlb_shm_group": value => 2002;
}

augeas { "/etc/sysctl.conf":
	context => "/files/etc/sysctl.conf",
	changes => [
		"rm net.bridge.bridge-nf-call-ip6tables",
		"rm net.bridge.bridge-nf-call-iptables",
		"rm net.bridge.bridge-nf-call-arptables",
	]
}

# http://projects.puppetlabs.com/projects/1/wiki/Puppet_Augeas#/etc/security/limits.conf
limits::conf { 
	# Oracle
	"oracle-soft-nproc":  domain => oracle, type => soft, item => nproc,  value => 2047;
	"oracle-hard-nproc":  domain => oracle, type => hard, item => nproc,  value => 16384;
	"oracle-soft-nofile": domain => oracle, type => soft, item => nofile, value => 1024;
	"oracle-hard-nofile": domain => oracle, type => hard, item => nofile, value => 65536;
	"oracle-soft-stack":  domain => oracle, type => soft, item => stack,  value => 10240;
}

# Oracle data files
$oradirectories = ["/u01", "/u02", "/u01/app", "/u01/app/oracle", "/u02/oradata"]
file { $oradirectories:
	ensure => "directory",
    owner  => "oracle",
    group  => "oinstall",
    mode   => 775,
    require => User['oracle'],
}

file { "/etc/profile.d/vagrant_oracle.sh":
	owner => 0, group => 0, mode => 0644, 
	content => "
if [ \$USER = \"oracle\" ]; then
	umask 022
	export ORACLE_BASE=/u01/app/oracle
	export ORACLE_HOME=\$ORACLE_BASE/product/11.2.0/dbhome_1
	export ORACLE_SID=orcl
	export NLS_LANG=.AL32UTF8
	unset TNS_ADMIN
	if [ -d \"\$ORACLE_HOME/bin\" ]; then
		PATH=\"\$ORACLE_HOME/bin:\$PATH\"
	fi
fi 
"
}

file { '/usr/bin/run_as_with_x':
	mode   => 755,
	content => "#!/bin/sh

user=\$1
if [ -z \"\$user\" ]; then
 user=root
fi

displayNum=`echo \$DISPLAY | sed -e 's/^.*://' -e 's/\\.[0123456789]*//'`
echo \"Display # = \$displayNum\"
cookie=`xauth list | grep \":\$displayNum\"`
echo \"Cookie = \$cookie\"
cookiename=`echo \$cookie | sed 's/\\s*MIT-MAGIC.*$//'`
echo \"Cookie Name: \$cookiename\"
echo \"user = \$user\"
sudo su -l \$user -c \"xauth list; xauth add \$cookie; bash; xauth remove \$cookiename\"

"
}

file { "/tmp/p10098816_112020_Linux-x86-64":
	ensure => "directory",
    owner  => "oracle",
    group  => "oinstall",
    mode   => 775,
    require => [ User['oracle'], Package["elfutils-libelf-devel"], Package["mksh"] ];
}
exec {
	"oracle_disk1":
		cwd     => "/tmp/p10098816_112020_Linux-x86-64",
		command => "/usr/bin/unzip -u -o /vagrant/installers/p10098816_112020_Linux-x86-64_1of7.zip",
		require => [ File["/tmp/p10098816_112020_Linux-x86-64"] ];
	"oracle_disk2":
		cwd     => "/tmp/p10098816_112020_Linux-x86-64",
		command => "/usr/bin/unzip -u -o /vagrant/installers/p10098816_112020_Linux-x86-64_2of7.zip",
		require => [ File["/tmp/p10098816_112020_Linux-x86-64"], Exec["oracle_disk1"] ];
}

# http://www.dbspecialists.com/oracle11glinux.html
# rm -rf /u01/app/oraInventory* && rm -rf /u01/app/oracle/product/11.2.0/dbhome_*
# /tmp/p10098816_112020_Linux-x86-64/database/runInstaller -force -ignoreSysPrereqs -ignorePrereq -waitforcompletion -silent -responseFile /vagrant/db.rsp

#As a root user, execute the following script(s):#
#	1. /u01/app/oraInventory/orainstRoot.sh
#	2. /u01/app/oracle/product/11.2.0/dbhome_1/root.sh
#	3. nano /etc/oratab
#ORACLE_OWNER=oracle
#ORACLE_HOME=/u01/app/oracle/product/11.2.0/dbhome_1

# http://docs.oracle.com/cd/E11857_01/em.111/e12255/oui4_product_install.htm
exec {
	"oracle_runInstaller":
		cwd     => "/tmp/p10098816_112020_Linux-x86-64/database",
		user    => "oracle",
		command => "/tmp/p10098816_112020_Linux-x86-64/database/runInstaller -force -ignoreSysPrereqs -ignorePrereq -waitforcompletion -silent -responseFile /vagrant/db.rsp",
		timeout => 1800,
		returns => [0, 3],
		creates => "/u01/app/oraInventory",
		require => Exec["oracle_disk2"];
	"orainstRoot":
		command => "/u01/app/oraInventory/orainstRoot.sh && touch /u01/app/oraInventory/orainstRoot",
		creates => "/u01/app/oraInventory/orainstRoot",
		require => Exec["oracle_runInstaller"];
	"dbhome_1_root":
		command => "/u01/app/oracle/product/11.2.0/dbhome_1/root.sh && touch /u01/app/oraInventory/dbhome_1_root",
		creates => "/u01/app/oraInventory/dbhome_1_root",
		require => Exec["orainstRoot"];
}

file { "/etc/init.d/dbora":
	owner => 0, group => 0, mode => 0700, 
	require => Exec["dbhome_1_root"],
	source => "puppet:///modules/default/etc/init.d/dbora.sh"
}

exec {"chkconfig dbora":
	command => "/sbin/chkconfig --add dbora",
	require => File["/etc/init.d/dbora"]
}

service { "dbora": 
	ensure => "running",
	require => Exec["chkconfig dbora"]
}
