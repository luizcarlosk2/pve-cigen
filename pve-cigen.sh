#!/bin/bash

# Initial Parameters - Do not change it
VERSION=0.10b
FORCE=0	# Use -F to force the VM creation
START=0 # Start VM after creation
HELP=0 # Show help menu
LVMTHIN="$(cat /etc/pve/storage.cfg | grep lvmthin | cut -d ":" -f2 | sed 's/ //g')" #local-lvm

# Default path where qcow files are stored
DEFAULT_CLOUDIMG_DIR="/var/lib/vz/template/qcow/"

# Get script absolute path location
BASH_DIR=$(dirname $(readlink -f ${BASH_SOURCE:-$0}))

# Import modules to check the syntax
. "$BASH_DIR"/modules/check_syntax.sh

help(){
	# Help printout
	echo "pve-cigen Rev $VERSION"
	echo "Script created by luizcarlosk2 (https://github.com/luizcarlosk2/pve-cigen.git)"
  	echo "Usage: $0 [OPTIONS]"
	echo -e "\tOPTIONS:"
  	echo -e "\t-n VM Name*"
  	echo -e "\t-v VMID number. Must be an VMID not used in PVE*"
  	echo -e "\t-b Bridge ID (default vmbr0)"
  	echo -e "\t-c Number of CPUs (default = 1)"
  	echo -e "\t-m Memory Size (MB) (default=256MB)"
	echo -e "\t-l Balloon - Min Memory Size (in MB)"
  	echo -e "\t-s Aditional Disk size (in GB)*"
	echo -e "\t-p Path where the cloud-image is loccated"
	echo -e "\t-q Cloud IMG filename*"
	echo -e "\t-d Description of VM"
	echo -e "\t-i IP Address and CIDR (A.B.C.D/CIDR) (default = dhcp)"
	echo -e "\t-g Gateway Address"
	echo -e "\t-o DNS Address"
	echo -e "\t-w Domain"
	echo -e "\t-k ssh public key"
	echo -e "\t-u username (not recomended)"
	echo -e "\t-a password (not recomended)"
	echo -e "\t-F Force to remove VM with same VMID"
	echo -e "\t-S Start VM after creation"
	echo -e "\t-T Convert to template"
	echo -e "\t(*) = Mandatory Settings"
	echo ""
	
}

check_args_mandatory(){

	if [ "$HELP" -eq 1 ]; then
		help
		exit 0
	fi

	# Check of mandatory args
	if [ -z "$VMNAME" ] || [ -z "$VMID" ] || [ -z "$BRIDGEID" ] || [ -z "$NCPU" ] || [ -z "$MEMORY" ] || [ -z "$DISK" ] || [ -z "$IMG_FILE" ]
	then
		echo ""
		echo "Error: There are some missing parameters. Check the sintax."
		help
		exit 1
	fi
}

check_args_syntax(){
	# check the syntax of the args are correct

	# check args -p/-q
	if [  -z "$IMG_PATH" ]; then
		IMG_PATH="$DEFAULT_CLOUDIMG_DIR"
	elif [ ! -d "$IMG_PATH" ]; then
		echo "Error: The path $IMG_PATH doesn't exists." >&2
		exit 1
	fi

	# Check if IMG Path is favlid
	FULL_PATH=$(readlink -m "$IMG_PATH/$IMG_FILE")
	if [ ! -f "$FULL_PATH" ]; then
		echo "Error: The file $FULL_PATH doesn't exists." >&2
		exit 1
	fi

	# Check if File arg is a qcow2 img
	FILE_TYPE=$(qemu-img info $FULL_PATH | grep format | cut -d ":" -f2)
	if [ "$FILE_TYPE" != ' qcow2' ]; then
		echo "Error: $FULL_PATH is not a qcow2 file."  >&2
		exit 1
	fi


	# Flag template for convert to template
	if [ -z "$TEMPLATE" ]; then
		TEMPLATE=0
	else
		TEMPLATE=1
	fi

	# Check VM IP address
	if [ ! -z "$IP" ]; then
		if [ "$IP" != dhcp ]; then
			check_ipcidr "$IP"
		fi
	else
		IP=dhcp
	fi

	# Check VM Gateway IP address
	if [ ! -z "$GATEWAY" ]; then
		check_ip "$GATEWAY" GATEWAY
	fi

	# Check VM Gateway IP address
	if [ ! -z "$DNS" ]; then
		check_ip "$DNS" DNS
	fi

	# Check if SSH Key exists
	if [ ! -z "$SSHK" ]; then
		if [ ! -f "$SSHK" ]; then
			echo "$SSHK"
			echo "Error: The SSH Key file $SSHK doesn't exists." >&2
			exit 1
		fi
	fi
}

check_vmid(){
	# Check if VMID provided is in use in PVE
	check_number $VMID
	qm list --full |  awk '{print $1}' | grep "$VMID" > /dev/null
	if [ $? == 0 ]; then
   		echo "Error: VMID $VMID is in use by the VM: $(qm list --full | grep $VMID | awk '{print $2}')" >&2
		exit 1
	fi
}

check_bridge(){
	# Check if the bridge ID provided exists in PVE
	ifconfig "$BRIDGEID" > /dev/null 2>&1
		if [ $? == 1 ]; then
   		echo "Error: Bridge $BRIDGEID doesn't exists." >&2
		exit 1
	fi
}

check_NCPU(){
	# Check if number of cpus is greather then available in PVE
	check_number $NCPU
	if [ $NCPU -lt 1 ]
	then
		echo "Error: It is not possible to set Number of CPU's < 1" >&2
		exit 1
	elif [ $NCPU -gt $(nproc --all) ]
	then
		echo "Error: It is not possible to set Number of CPU's = $NCPU because the system has $(nproc --all) CPU's available."
		exit 1
	fi
}

check_MEMORY(){
	# Check if amount of memory requested is available in the PVE
	PVE_MEM_TOT=$(free -m | grep Mem | awk '{print $2}')
	check_number $MEMORY
	if [ $MEMORY -gt $PVE_MEM_TOT ]; then
		echo "Error: The requested memory ($MEMORY) is greather then system available ($PVE_MEM_TOT)" >&2
		exit 1
	fi

	if [ ! -z "$BALLOON" ]; then
		check_number $BALLOON
		if [ $BALLOON -gt $PVE_MEM_TOT ]; then
			echo "Error: The requested memory balloon ($BALLOON) is greather then system available ($PVE_MEM_TOT)" >&2
			exit 1
		elif [ $BALLOON -gt $MEMORY ]; then
			echo "Error: The requested memory balloon ($BALLOON) is greather then memory requested ($MEMORY)" >&2
			exit 1

		fi
	fi
}

create_vm(){
	if [ "$FORCE" -eq 1 ]; then
		qm list --full |  awk '{print $1}' | grep "$VMID" > /dev/null
		if [ $? -eq 0 ]; then
			echo "VM $VMID exists. -F evoked. Finishing and deleting VM."
			sleep 5
			qm stop "$VMID"
			qm destroy "$VMID" --destroy-unreferenced-disks --purge --destroy-unreferenced-disks
		fi
		sleep 5
	fi
	qm create "$VMID" -name "$VMNAME" -memory "$MEMORY" -net0 virtio,bridge="$BRIDGEID" -cores "$NCPU" -sockets 1 -cpu cputype=kvm64 -description "$DESC" -kvm 1 -numa 1
	qm importdisk "$VMID" "$FULL_PATH" "$LVMTHIN"

	if [ ! -z "$BALLOON" ]; then
		qm set "$VMID" -balloon "$BALLOON"
	fi

	qm set "$VMID" -scsihw virtio-scsi-pci -virtio0 "$LVMTHIN":vm-"$VMID"-disk-0
	qm set "$VMID" -serial0 socket
	qm set "$VMID" -boot c -bootdisk virtio0
	qm set "$VMID" -agent 1
	qm set "$VMID" -hotplug disk,network,usb,memory,cpu
	qm set "$VMID" -vcpus "$NCPU"
	qm set "$VMID" -vga qxl
	qm set "$VMID" -name "$VMNAME"
	if [ ! -z "$DESC" ]; then
		qm set "$VMID" -description "\"$DESC\""
	fi
	qm set "$VMID" -sshkey "$SSHK"
	qm set "$VMID" -ide2 "$LVMTHIN":cloudinit
	
	# Get qcow2 virtual size
	QCOWSIZE="$(echo "$(qemu-img info $FULL_PATH | grep virtual | cut -d ":" -f2 | cut -d " " -f4 | sed 's/[^0-9]*//g')/(1024^3)" | bc)"
	if [ "$QCOWSIZE" -lt  "$DISK" ]; then
		qm resize "$VMID" virtio0 "$DISK"G
	else
		echo "Warning: It is not possible to set the disk size as $DISK GB because the qcow2 disk size has $QCOWSIZE GB."
		sleep 3
	fi


	# Set Network 
	if [ "$IP" == dhcp ]; then
		qm set "$VMID" --ipconfig0 ip=dhcp
	else
		if [ ! -z "$GATEWAY" ]; then
			qm set "$VMID" --ipconfig0 ip="$IP",gw="$GATEWAY"
		else
			echo "Error: It is necessary to set a Gateway when set an IP Manuallly." >&2
			echo 1
		fi
	fi

	if [ ! -z "$DNS" ]; then
		qm set "$VMID" --nameserver "$DNS"
	fi

	if [ ! -z "$DOMAIN" ]; then
		qm set "$VMID" --searchdomain "$DOMAIN"
	fi

	

	# Set User
	if [ ! -z "$USER" ]; then
		qm set "$VMID" --ciuser "$USER"
	fi

	# Set Password
	if [ ! -z "$PSWD" ]; then
		echo "Setting Passord..."
		qm set "$VMID" --cipassword ${PSWD}
	fi

	}

check_instance(){
	RESULT=$(qm config ${VMID})
	echo ""
	if [ "$?" -eq 0 ]; then
		echo "$RESULT"
		echo "----------------------------------------------------"
		echo "Result: OK"
		echo "VM $VNAME created as VMID=$VMID in PVE"
		echo "----------------------------------------------------"
		echo "Details:"
		echo "$RESULT"
	else
		echo "Error: VM $VMNAME not created."
	fi
}


while getopts hn:v:d:b:c:m:l:s:p:q:t:i:g:k:u:a:o:w:FST flag
do
	case "${flag}" in
		h) HELP=1;;				# Show Help
		n) VMNAME=${OPTARG};;	# VM Name
		v) VMID=${OPTARG};;		# VM ID
		d) DESC=${OPTARG};;		# VM Description
		b) BRIDGEID=${OPTARG};; # Bridge
		c) NCPU=${OPTARG};;		# Number of CPUs
		m) MEMORY=${OPTARG};;	# Memory
		l) BALLOON=${OPTARG};;	# Balloon - Min Memory Size
		s) DISK=${OPTARG};;		# Disk Size
		p) IMG_PATH=${OPTARG};; # Img dir
		q) IMG_FILE=${OPTARG};; # Img Name
		t) TEMPLATE=${OPTARG};; # Convert to template
		i) IP=${OPTARG};;		# IP/CIDR
		g) GATEWAY=${OPTARG};;	# Gateway
		o) DNS=${OPTARG};;		# DNS
		w) DOMAIN=${OPTARG};;	# Domain
		u) USER=${OPTARG};;		# Username
		a) PSWD=${OPTARG};;		# Password
		F) FORCE=1;;			# Force delete VM Exists
		S) START=1;;			# Start VM
		T) TEMPLATE=1;;			# Convert VM to template
		k) SSHK=${OPTARG};;		# SSH Key

	esac
done

# Check mandatory args
check_args_mandatory

# check args syntax
check_args_syntax

# Check if VMID is in use in PVE
if [ "$FORCE" -ne 1 ]; then
	check_vmid
fi

# Check if bridge interface is defined in PVE
check_bridge

# Check if NCPU's are less than available in PVE
check_NCPU

# Check if memory is less than provided
check_MEMORY

#Execute the VM Creation
create_vm

# Convert to template or Start VM
if [ "$TEMPLATE" -eq 1 ]; then
	qm set "$VMID" --template
elif [ "$START" -eq 1 ]; then
	qm start "$VMID"
fi

check_instance
