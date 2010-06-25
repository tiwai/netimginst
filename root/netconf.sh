#!/bin/sh

. /etc/sysconfig/network/scripts/functions 2>/dev/null
rm -f /tmp/net_device
cd /sys/class/net || exit 1
i=10

fix_net() {
    # On wireless apparently arch.suse.de is not yet available. So rather be safe than sorry
    sed -i -e 's/^search /search arch.suse.de suse.de /' /etc/resolv.conf
    return 0
}

# Nuke old configs, get list of interfaces
ifaces=""
for n in * ; do
    test -d $n/device || continue
    t=`get_iface_type $n`
    case $t in
	eth|wlan|brige|vlan|bond|tun|tap)
	    rm -f /etc/sysconfig/network/ifcfg-$n
	    ifaces="$ifaces $n"
	    ;;
    esac
done

# Clean restart
for n in $ifaces ; do
    test -d $n/device || continue
    t=`get_iface_type $n`
    case $t in
	eth|wlan|brige|vlan|bond|tun|tap)
	    echo "Resetting network connection on $n..."
	    ifdown $n
	    ifconfig $n up
	    ;;
    esac
done

# Wait to settle carrier detection on slow devices
sleep 2

# Try to connect to ethernet first
for n in $ifaces ; do
    test -d $n/wireless && continue
    echo "Test network connection on $n..."
    c="`cat $n/carrier 2>/dev/null`"
    case "x$c" in
	x0)
	    # Not connected
	    ifconfig $n down
	    ;;
	x1)
	    # Connected
	    echo "   Found carrier, configuring"
	    cp /etc/ifcfg-eth.template /etc/sysconfig/network/ifcfg-$n
	    ifup $n
	    i=0
	    while [ $i -lt 10 ] ; do
		ping -c 1 www.suse.de && fix_net && break
		sleep 1
		i=$(($i+1))
	    done
	    test $i -lt 10 && break
	    echo "   Connection failed"
	    ifdown $n
	    rm -f /etc/sysconfig/network/ifcfg-$n
	    ;;
	x)
	    # Down
	    ;;
    esac
done

if [ $i -lt 10 ] ; then
    for k in $ifaces ; do
	test "$k" = "$n" && continue
	echo "   Shutting down $k"
	ifconfig $k down
    done
    echo $n >/tmp/net_device
    exit 0
fi

# Try to connect to wlan if ethernet failed
for n in $ifaces ; do
    test -d $n/wireless || continue
    echo "Test network connection on $n..."
    # Wireless
    echo "   Found carrier, configuring"
    dialog 2>/tmp/pwd --cr-wrap --no-lines --insecure --mixedform "Enter Innerweb credentials for wireless connection on secure network 'Novell'.\nPress <Cursor-Down> to switch to password field.\n" 15 60 5 User 2 0 "" 2 15 31 30 0 Password 4 0 "" 4 15 31 30 1
    if [ $? != 0 ] ; then
	rm -f /tmp/pwd
	continue
    fi
    cp /etc/ifcfg-wlan.template /etc/sysconfig/network/ifcfg-$n
    sed -i -e "s/^WIRELESS_WPA_IDENTITY=.*/WIRELESS_WPA_IDENTITY='`head -1 /tmp/pwd`'/;s/^WIRELESS_WPA_PASSWORD=.*/WIRELESS_WPA_PASSWORD='`tail -1 /tmp/pwd`'/" /etc/sysconfig/network/ifcfg-$n
    rm -f /tmp/pwd
    ifup $n
    i=0
    while [ $i -lt 10 ] ; do
	ping -c 1 www.suse.de && fix_net && break
	sleep 1
	i=$(($i+1))
    done
    # Configuration contains password - kill it
    rm -f /etc/sysconfig/network/ifcfg-$n
    test $i -lt 10 && break
    echo "   Connection failed"
    ifdown $n
done

for k in $ifaces ; do
    test "$k" = "$n" && continue
    echo "   Shutting down $k"
    ifconfig $k down
done

if [ $i -lt 10 ] ; then
    echo $n >/tmp/net_device
    exit 0
fi

exit 1

