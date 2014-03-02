# Module for managing tor relays / bridges and exits
# Jan Weiher, 2011, jan@buksy.de
# BSD-License.

class tor::install {
	package { ['tor', 'tor-geoipdb']:
		ensure 	=> latest,
		require => File[tor_sources_list],
	}

	file { "tor_sources_list":
		path 	=> "/etc/apt/sources.list.d/tor_sources.list",
		content => template("tor/tor_sources_list.erb"),
		ensure 	=> present,
		require => Exec["add_tor_apt_key"],
		mode 	=> 0444,
		owner 	=> root,
	}
	
	exec { 
	"apt_updates":
		command 	=> "/usr/bin/apt-get update",
		subscribe 	=> File[tor_sources_list],
		refreshonly => true;
	"add_tor_apt_key":
		path		=> "/usr/bin:/usr/sbin:/sbin:/bin",
		command		=> "gpg --keyserver keys.gnupg.net --recv 886DDD89 && gpg --export A3C4F0F979CAA22CDBA8F512EE8CBC9E886DDD89 | apt-key add -",
		unless 		=> "apt-key list | grep 886DDD89",
	}	
}

class tor::bridge {
	include tor::install
	$tor_mode = 'bridge'
	include tor::config
}	

class tor::relay {
	include tor::install
	$tor_mode = 'relay'
	include tor::config
}

class tor::config inherits tor::defaults {
	file { 
	"tor_torrc":
		path 	=> "/etc/torrc.d/10-torrc",
		content => template("tor/torrc.erb"),
		mode 	=> 0444,
		owner 	=> root,
		notify => Exec[generate_tor_torrc],
		ensure 	=> file;
	"/etc/torrc.d":
		ensure 	=> directory,
		mode	=> 0755,
		owner 	=> root,
		group 	=> root;
	}
	
	exec {
		"generate_tor_torrc":
			path => "/usr/bin:/bin",
			command => "cat /etc/torrc.d/* > /etc/tor/torrc",
			refreshonly => true,
	}
	
	@@file { 'tor-myfamily':
		path	=> "/etc/torrc.d/20-myfamily-$fqdn",
		content	=> inline_template("# $fqdn\nMyFamily \$$tor_fingerprint\n"),
		notify => Exec[generate_tor_torrc],
		tag => "tor_myfamily",
	}
	
	File <<| tag == 'tor_myfamily' |>> 
	
	service { "tor":
		ensure 		=> running,
		require 	=> Exec[generate_tor_torrc],
		subscribe 	=> Exec[generate_tor_torrc],
		hasrestart 	=> true,
		hasstatus 	=> true,
	}
}

class tor::disabled {
	package{["tor", "tor-geoipdb"]:
		ensure 	=> absent,
		require => Service["tor"];
	}
	
	service { "tor":
		ensure => stopped,
	}
	
	file {
		"etc_tor_remove":
			path 	=> "/etc/torrc.d",
			ensure 	=> absent,
			recurse => true,
			force 	=> true,
			require => Package["tor"];
		"torsocksconf":
			path	=> "/etc/torsocks.conf",
			ensure 	=> absent;
		"var_lib_tor_remove":
			path 	=> "/var/lib/tor",
			ensure 	=> absent,
			force 	=> true,
			require => Package["tor"],
			recurse => true;
		"var_log_tor_remove":
			path 	=> "/var/log/tor",
			ensure 	=> absent,
			force 	=> true,
			require => Package["tor"],
			recurse => true;
		"tor_apt_sources_remove":
			path 	=> "/etc/apt/sources.list.d/tor_sources.list",
			require => Package["tor"],
			ensure	=> absent;
	}
	exec { "remove apt key":
		command => "apt-key del 886DDD89",
		path => "/usr/bin:/usr/sbin:/bin:/sbin",
		onlyif => "apt-key list | grep 886DDD89",
		require => File["tor_apt_sources_remove"];
	}
}

class tor::defaults {
	# Reasonable defaults go here
	# Default to bridge mode, so that an admin with a working 
	# Puppet setup can include the tor module and start a large 
	# amount of bridges
	if ! $tor_mode {
		$tor_mode = "bridge"
	}
	
	if ! $tor_orport {
		$tor_orport = "443"
	}
	
	if ! $tor_contactinfo {
		$tor_contactinfo = "Random puppet-tor User"
	}
	
	if ! $tor_nickname {	
		# default to hostname instead of 'Unnamed'
		#$tor_nickname = "Unnamed"
		$tor_nickname = $::hostname
	}
	
	if ! $tor_relaybandwidthrate {
		$tor_relaybandwidthrate = "50 Kbytes"
	}
	
	if ! $tor_relaybandwidthburst {
		$tor_relaybandwidthburst = "60 Kbytes"
	}
	if ! $tor_exitpolicy {
		# Defaults to reduced exit policy
		# https://trac.torproject.org/projects/tor/wiki/doc/ReducedExitPolicy
		$tor_exitpolicy = [
			'accept *:20-23',     # FTP, SSH, telnet
			'accept *:43',        # WHOIS
			'accept *:53',        # DNS
			'accept *:79-81',     # finger, HTTP
			'accept *:88',        # kerberos
			'accept *:110',       # POP3
			'accept *:143',       # IMAP
			'accept *:194',       # IRC
			'accept *:220',       # IMAP3
			'accept *:443',       # HTTPS
			'accept *:464',       # kpasswd
			'accept *:531',       # IRC/AIM
			'accept *:543-544',   # Kerberos
			'accept *:563',       # NNTP over SSL
			'accept *:706',       # SILC
			'accept *:749',       # kerberos 
			'accept *:873',       # rsync
			'accept *:902-904',   # VMware
			'accept *:981',       # Remote HTTPS management for firewall
			'accept *:989-995',   # FTP over SSL, Netnews Administration System, telnets, IMAP over SSL, ircs, POP3 over SSL
			'accept *:1194',      # OpenVPN
			'accept *:1220',      # QT Server Admin
			'accept *:1293',      # PKT-KRB-IPSec
			'accept *:1500',      # VLSI License Manager
			'accept *:1533',      # Sametime
			'accept *:1677',      # GroupWise
			'accept *:1723',      # PPTP
			'accept *:1863',      # MSNP
			'accept *:2082',      # Infowave Mobility Server
			'accept *:2083',      # Secure Radius Service (radsec)
			'accept *:2086-2087', # GNUnet, ELI
			'accept *:2095-2096', # NBX
			'accept *:2102-2104', # Zephyr
			'accept *:3128',      # SQUID
			'accept *:3389',      # MS WBT
			'accept *:3690',      # SVN
			'accept *:4321',      # RWHOIS
			'accept *:4643',      # Virtuozzo
			'accept *:5050',      # MMCC
			'accept *:5190',      # ICQ
			'accept *:5222-5223', # XMPP, XMPP over SSL
			'accept *:5228',      # Android Market
			'accept *:5900',      # VNC
			'accept *:6660-6669', # IRC
			'accept *:6679',      # IRC SSL  
			'accept *:6697',      # IRC SSL  
			'accept *:8000',      # iRDMI
			'accept *:8008',      # HTTP alternate
			'accept *:8074',      # Gadu-Gadu
			'accept *:8080',      # HTTP Proxies
			'accept *:8087-8088', # Simplify Media SPP Protocol, Radan HTTP
			'accept *:8443',      # PCsync HTTPS
			'accept *:8888',      # HTTP Proxies, NewsEDGE
			'accept *:9418',      # git
			'accept *:9999',      # distinct
			'accept *:10000',     # Network Data Management Protocol
			'accept *:19294',     # Google Voice TCP
			'accept *:19638',     # Ensim control panel
			'reject *:*',
		]
	}
}
