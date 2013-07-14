#!/bin/sh
# chkconfig: 345 99 10
# description: Oracle auto start-stop script.
#
# Set ORA_HOME to be equivalent to the $ORACLE_HOME
# from which you wish to execute dbstart and dbshut;
#
# Set ORA_OWNER to the user id of the owner of the 
# Oracle database in ORA_HOME.

ORA_HOME=/u01/app/oracle/product/11.2.0/dbhome_1
ORA_OWNER=oracle
ORACLE_UNQNAME=orcl

if [ ! -f $ORA_HOME/bin/dbstart ]
then
    echo "Oracle startup: cannot start"
    exit
fi

case "$1" in
    'start')
        # Start the Oracle databases:
        # The following command assumes that the oracle login 
        # will not prompt the user for any values
        su - $ORA_OWNER -c "$ORA_HOME/bin/lsnrctl start"
        su - $ORA_OWNER -c "$ORA_HOME/bin/dbstart $ORA_HOME"
        su - $ORA_OWNER -c "export ORACLE_SID=$ORACLE_UNQNAME; export ORACLE_UNQNAME=$ORACLE_UNQNAME; $ORA_HOME/bin/emctl start dbconsole"
        touch /var/lock/subsys/dbora
        ;;
    'stop')
        # Stop the Oracle databases:
        # The following command assumes that the oracle login 
        # will not prompt the user for any values
        su - $ORA_OWNER -c "export ORACLE_SID=$ORACLE_UNQNAME; export ORACLE_UNQNAME=$ORACLE_UNQNAME; $ORA_HOME/bin/emctl stop dbconsole"
        su - $ORA_OWNER -c "$ORA_HOME/bin/dbshut $ORA_HOME"
        su - $ORA_OWNER -c "$ORA_HOME/bin/lsnrctl stop"
        rm -f /var/lock/subsys/dbora
        ;;
    'restart')
        $0 stop
        $0 start
        ;;
    status)
        if [ -x /var/lock/subsys/dbora ]; then
            echo "Running"
            exit 0
        else
            echo "Not running"
            exit 1
        fi
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status}"
        exit 1
esac
