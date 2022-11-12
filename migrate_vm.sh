#!/bin/bash

# Backup VM, shutdown VM. Copy VM backup to new host, copy virtual hard drive to new host. Start VM on new host.

vm=$1
curr=$2
new_host=$3
bak="/tmp/${vm}-$(date +%d%b%Y).xml"
imgd="/var/lib/libvirt/images"

usage() {
	echo ""
	echo ""
	echo -e "\t Requires at least 3 arguments."
	echo -e "\t $0 <vm name> <old hostname> <new hostname>"
	echo ""
	echo ""
}
if [[ $# -ne 3 ]]; then
	usage
	exit 1
fi

# Check if VM exists on old host
check=$(ssh "${curr}" virsh list --name | grep "${vm}")
list=$(ssh "${curr}" virsh list --name)
#check="ls"
if [[ "${check}" ]]; then
	echo ""
	echo "I'm going to shutdown "${vm}" on "${curr}", make a backup of "${vm}" on "${curr}", and then copy that backup to "${new_host}"."
	echo "Then I'm going to copy the hard drive for "${vm}" from "${curr}" to "${new_host}"."
	echo "And finally, I'm going to start "${vm}" on "${new_host}"."
	echo ""
	echo "The above actions will be taken. Press CTRL+c now to cancel."
	for i in {5..0}
	do
		echo -n "."
		sleep 1
	done
	echo ""
	for i in {5..3}
	do
		echo "You have $i half-seconds remaining to cancel."
		sleep 0.5
	done
	for i in {2..0}
	do
		echo "You have $i slow-second(s) remaining."
		sleep 2.5
	done
	echo "Godspeed Will Robinson."
	echo "Shutting down "${vm}" and making backup."
	# ssh "${curr}" " virsh dumpxml "${vm}" "
	ssh "${curr}" " virsh shutdown "${vm}" && until virsh domstate "${vm}" | grep shut; do echo "Waiting for shutdown to complete." ; sleep 5 ; done "
	ssh "${curr}" " virsh dumpxml "${vm}" > "${bak}" "
	ssh "${curr}" " ls -lh "${bak}" "
	
	# Copy backup
	echo "Backup complete. Copying to "${new_host}"."
	echo ""
	scp "${curr}":"${bak}" "${new_host}":"${bak}"

	# Copy hard drive
	echo "Copying hard drive image from "${curr}" to "${new_host}". "
	for i in $(ssh "${curr}" " virsh domblklist "${vm}" | grep qcow2 | cut -d' ' -f9 ")
	do
		echo "Copying: "
		echo "${i}"
		imgf="$( echo "${i}" | cut -d/ -f6 )"
#		if [[ $(ssh "${new_host}" [ ! -e "${imgd}"/"${imgf}" ]) ]]; then
			#rsync -avz --progress "${curr}":"${i}" "${new_host}":"${imgd}"/"${imgf}"
			scp "${curr}":"${i}" "${new_host}":"${imgd}"/"${imgf}"
#		fi
		echo "New image location is: ${imgd}/${imgf}" 
		ssh ${new_host} sed -i "s#file=\'.*.qcow2\'#file=\'${imgd}/${imgf}\'#" "${bak}"
		scp "${new_host}":"${bak}" "${bak}"
		sed -i "s+<cpu mode=.*+<cpu mode='host-passthrough' check='none'>+" "${bak}"
		brdg=$(ssh "${new_host}" "ifconfig | grep ^br | cut -d':' -f1")
		sed -i "s+<source bridge=.*+<source bridge='"${brdg}"'/>+" "${bak}"
		scp "${bak}" "${new_host}":"${bak}"
		#ssh ${new_host} sed -i \"s+<cpu mode=.*+<cpu mode='host-passthrough' check='none'>+\" "${bak}"
	done

	# Import and start VM on new host
	ssh "${new_host}" " virsh define --file "${bak}" && virsh start "${vm}" "
	echo " "${vm}" should now be active on "${new_host}". "
	ssh "${new_host}" " virsh list "
else
	usage
	echo -e "\t "${vm}" doesn't appear to exist on "${curr}""
	echo -e "\t These are your choices:"
	echo -e "\t "${list}" "
	echo ""
	exit 1
fi

exit $?
