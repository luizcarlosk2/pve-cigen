# pve-cigen

pve-cigen (Proxmox VE Cloud Init Generator) is a script to create VM's based with distro images of generic cloud.

## Installation

just clone this repository, change the permission execution of pve-cigen file.

```bash
Just git clone and change the pve-cigen permission
```

## Usage

```
Usage: ./pve-cigen.sh [OPTIONS]
	OPTIONS:
	-n VM Name*
	-v VMID number. Must be an VMID not used in PVE*
	-b Bridge ID (default vmbr0)
	-c Number of CPUs (default = 1)
	-m Memory Size (MB) (default=256MB)
	-l Balloon - Min Memory Size (in MB)
	-s Aditional Disk size (in GB)*
	-p Path where the cloud-image is loccated
	-q Cloud IMG filename*
	-d Description of VM
	-i IP Address and CIDR (A.B.C.D/CIDR) (default = dhcp)
	-g Gateway Address
	-o DNS Address
	-w Domain
	-k ssh public key
	-u username (not recomended)
	-a password (not recomended)
	-F Force to remove VM with same VMID
	-S Start VM after creation
	-T Convert to template
	(*) = Mandatory Settings
```

## Contributing

Pull requests are welcome. For major changes, please open an issue first
to discuss what you would like to change.

Please make sure to update tests as appropriate.

## License

[MIT](https://choosealicense.com/licenses/mit/)
