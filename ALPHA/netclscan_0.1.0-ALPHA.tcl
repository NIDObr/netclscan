#!/usr/bin/env tclsh

#-------------------------------------------------------------------------------------
# author: NidoBr
# e-mail: < coqecoisa@gmail.com >
# github: < https://github.com/NIDObr >
# Version: 0.1.0-ALPHA (experimental) 
# info:
#	Simple tool to display active network connections on IPV4 and IPV6 protocols 
#	Uses as base the files of the directory "/proc/net/*" 
#-------------------------------------------------------------------------------------

#--------------------------------------MODULES

# depends on the libtcl package 
package require dns
#set config_dns [ dns::configure -nameserver teste ]

#-------------------------------------FUNCTIONS

# convert hexadecimal (little-endian) to decimal
proc hex_to_dec { hex_string } {
	# converts hexadecimal to decimal using "expr 0x" 
	set dec1 [ expr 0x[ string range $hex_string 6 7 ] ]
	set dec2 [ expr 0x[ string range $hex_string 4 5 ] ]
	set dec3 [ expr 0x[ string range $hex_string 2 3 ] ]
	set dec4 [ expr 0x[ string range $hex_string 0 1 ] ]
	set dec_ip "$dec1.$dec2.$dec3.$dec4"
	# IP
	return $dec_ip
}
proc file_analyze { net_file } {
	gets $net_file
	while { ! [ eof "$net_file" ] } {
		set linha [ gets $net_file ]
		if { $linha == "" } {
			break
		} elseif { [ lindex $linha 0 ] == "sl" } {
			set linha [ gets $net_file ]
			set ::flag_proto "udp:"
		}
		# IP:PORTA DE ORIGEM
		set hex_orig [ lindex $linha 1 ]
		set ip_local [ hex_to_dec [ string range $hex_orig 0 7 ] ]
		set porta_local [ expr 0x[ string range $hex_orig 9 12 ] ]
		# IP:PORTA DE DESTINO
		set hex_dest [ lindex $linha 2 ]
		set ip_dest [ hex_to_dec [ string range $hex_dest 0 7 ] ]
		set porta_dest  [ expr 0x[ string range $hex_dest 9 12 ] ]
		set estado [ lindex $linha 3 ]
		if { $porta_dest == 53 && $::skip == 0 } {
			display_info $ip_local $porta_local $ip_dest $porta_dest $estado
			set ::skip 1
			puts aqui
		} else {
			display_info $ip_local $porta_local $ip_dest $porta_dest $estado
		}
	}
}
proc display_info { ip_l porta_l ip_d porta_d estado } {
	if { $::init == 0 } {
		puts "netclscan $::versao		$::time_data\n\nProto	IP local				ip remoto				estado\n"
		set ::init 1
	}
	switch $estado {
		0A { set stat "escuta" }
		01 { set stat "estabelecido" }
		06 { set stat "espera" }
		07 { set stat "" }
	}
	set host_l $ip_l
	set host_d $ip_d
	if { $::flag_dns == "on" } {
		set dns_ld [ dns::resolve $ip_l]
		set name_l [ dns::name $dns_ld ]
		set dns_ld [ dns::resolve $ip_d ]
		set name_d [ dns::name $dns_ld ]
		if { $name_l != "" } {
			set host_l [ lindex $name_l 0 ]
		}
		if { $name_d != "" } {
			set host_d [ lindex $name_d 0 ]
		}
	}
	if { [ string first ":" "$ip_l:$porta_l" ] < 11 } {
		set tabl "	"
	} else {
		set tabl ""
	}
	if { [ string first ":" "$ip_d:$porta_d" ] < 11 } {
		set tabd "	"
	} else {
		set tabd ""
	}
	puts "$::flag_proto	$host_l:$porta_l	$tabl		$host_d:$porta_d	$tabd		$stat"

}

#-------------------------------------MAIN

set ::init 0
set ::cont_local 0
set ::flag_dns "on"
set ::skip 0
global flag_proto
set ::time_data [ clock format [ clock seconds ] -format {%d/%m/%y %H:%M} ]
set ::versao "0.1.0-ALPHA"

if { $argv == "" } {
	puts "netclscan: Mostra as conexões de rede\n\n	netclscan \[opções\]\n	\nOpções:\n	-u Lista as conexões UDP\n	-t Lista as conexões TCP\n	-a Lista as conexoẽs UDP e TCP"
	exit
}
switch -regexp $argv {
	(\-[atu])h$ {
		set ::flag_dns "on"
	}
	(\-h[atu]$) {
		set ::flag_dns "on"
	}
}
switch $argv {
	-t {
		set ::flag_proto "tcp:"
		set net_file [ open /proc/net/tcp r ]
		file_analyze $net_file
	}
	-u {
		set ::flag_proto "udp:"
		set net_file [ open /proc/net/udp r ]
		file_analyze $net_file
	}
	-a {
		set ::flag_proto "tcp:"
		set tmp_time [ clock format [ clock seconds ] -format {%d%m%y_%H%M%S} ]
		set tcp_file [ open /proc/net/tcp r ]
		set udp_file [ open /proc/net/udp r ]
		file delete -force /tmp/netclscan_*
		set tmp_file [ open /tmp/netclscan_$tmp_time a+ ]
		while { ! [ eof $tcp_file ] } {
			set linha [ gets $tcp_file ]
			if { $linha == "" } {
				break
			}
			puts $tmp_file $linha
		}
		puts $tmp_file [ read $udp_file ]
		close $tcp_file
		close $udp_file
		close $tmp_file
		set net_file [ open /tmp/netclscan_$tmp_time r ]
		file_analyze $net_file
		file delete -force /tmp/netclscan_$tmp_time
	}
	default {
		puts "ERRO! < $argv > not parameter"
		exit 1
	}
}

close $net_file
