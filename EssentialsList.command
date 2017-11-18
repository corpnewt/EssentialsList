#!/bin/bash

efiMountPoint=

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd)"

# Turn on case-insensitive matching
shopt -s nocasematch
# turn on extended globbing
shopt -s extglob

bootName=""
bootMount=""
bootIdent=""
bootDisk=""
bootPart=""

driveName=""
driveMount=""
driveIdent=""
driveDisk=""
drivePart=""

efiName=""
efiMount=""
efiIdent=""
efiDisk=""
efiPart=""

desktopPath="~/Desktop"
lEPath="/Library/Extensions"
sLEPath="/System/Library/Extensions"

folderPrefix="EssentialsList-"

getConfig="1"

getD64UEFI="1"

getACPI="1"

getLoaded="1"

getNALoaded="1"


function resetVars () {
    bootName=""
    bootMount=""
    bootIdent=""
    bootDisk=""
    bootPart=""

    driveName=""
    driveMount=""
    driveIdent=""
    driveDisk=""
    drivePart=""
    
    efiName=""
    efiMount=""
    efiIdent=""
    efiDisk=""
    efiPart=""
}

function setDrive () {
	driveName="$( getDiskName "$1" )"
	driveMount="$( getDiskMountPoint "$1" )"
	driveIdent="$( getDiskIdentifier "$1" )"
	driveDisk="$( getDiskNumber "$1" )"
	drivePart="$( getPartitionNumber "$1" )"
    
    if [[ "$driveName" == "" ]]; then
        driveName="Untitled"
    fi
}

function setEFI () {
    efiName="$( getDiskName "$1" )"
	efiMount="$( getDiskMountPoint "$1" )"
	efiIdent="$( getDiskIdentifier "$1" )"
	efiDisk="$( getDiskNumber "$1" )"
	efiPart="$( getPartitionNumber "$1" )"
    
    if [[ "$efiName" == "" ]]; then
        efiName="Untitled"
    fi
}

function setBoot () {
    bootName="$( getDiskName "$1" )"
	bootMount="$( getDiskMountPoint "$1" )"
	bootIdent="$( getDiskIdentifier "$1" )"
	bootDisk="$( getDiskNumber "$1" )"
    bootPart="$( getPartitionNumber "$1" )"
    
    if [[ "$bootName" == "" ]]; then
        bootName="Untitled"
    fi
}

function customQuit () {
	clear
	echo \#\#\# EssentialsList \#\#\#
	echo by CorpNewt
	echo 
	echo Thanks for testing it out, for bugs/comments/complaints
	echo send me a message on Reddit, or check out my GitHub:
	echo 
	echo www.reddit.com/u/corpnewt
	echo www.github.com/corpnewt
	echo 
	echo Have a nice day/night!
	echo 
	echo 
	shopt -u extglob
	shopt -u nocasematch
	exit $?
}

function displayWarning () {
	clear
	echo \#\#\# WARNING \#\#\#
	echo 
	echo This script is provided with NO WARRANTY whatsoever.
	echo I am not responsible for ANY problems or issues you
	echo may encounter, or any damages as a result of running
	echo this script.
	echo 
	echo To ACCEPT this warning and FULL RESPONSIBILITY for
	echo using this script, press [enter].
	echo 
	read -p "To REFUSE, close this script."
    setBoot "/"
	mainMenu
}

function mainMenu () {
    tStamp="$( getTimestamp )"
    
    destFolder="$desktopPath/$folderPrefix$tStamp"
    destFolderName="$folderPrefix$tStamp"
    
    resetVars
    clear
    echo \#\#\# EssentialsList - CorpNewt \#\#\#
    echo
    echo Select drive containing your EFI:
    echo 
    
    driveList="$( cd /Volumes/; ls -1 | grep "^[^.]" )"
    unset driveArray
    IFS=$'\n' read -rd '' -a driveArray <<<"$driveList"
    
    #driveCount="${#driveArray[@]}"
    driveCount=0
    driveIndex=0
    
    for aDrive in "${driveArray[@]}"
    do
        (( driveCount++ ))
        echo "$driveCount". "$aDrive"
    done
    
    driveIndex=$(( driveCount-1 ))
    
    #ls /volumes/
    echo 
    echo 
    read drive
    
    if [[ "$drive" == "" ]]; then
        #drive="/"
        mainMenu
    fi
    
    #Notice - must have the single brackets or this
    #won't accurately tell if $drive is a number.
    if [ "$drive" -eq "$drive" ] 2>/dev/null; then
        #We have a number - check if it's in the array
        if [  "$drive" -le "$driveCount" ] && [  "$drive" -gt "0" ]; then
            drive="${driveArray[ (( $drive-1 )) ]}"
        else
            echo Index "$drive" out of range, checking for drive name...
        fi
    fi
    
    if [[ "$( isDisk "$drive" )" != "0" ]]; then
        if [[ "$( volumeName "$drive" )" ]]; then
			# We have a valid disk
			drive="$( volumeName "$drive" )"
			#setDisk "$drive"
		else
			# No disk available there
			echo \""$drive"\" is not a valid disk name, identifier
			echo or mount point.
			echo 
			read -p "Press [enter] to return to drive selection..."
			mainMenu
		fi
    fi
    
    setDrive "$drive"

    ###########################
    # Drive Selected ##########
    ###########################
    
    # Strip trailing slash
    driveMount="$( removeTrailingSlash "$driveMount" )"
    
    # Check our destination path
    if [[ ! "$( checkPath "$destFolder" )" == "0" ]]; then
        clear
        echo \#\#\# EssentialsList - CorpNewt \#\#\#
        echo
        echo There was an error creating \""$destFolder"\".
        echo
        exit
    fi
    
    clear
    echo \#\#\# EssentialsList - CorpNewt \#\#\#
    echo
    echo Checking for \""$driveMount$lEPath"\"...
    
    # List lEPath if it exists
    if [[ -d "$driveMount$lEPath" ]]; then
        #Yay!  It exists - let's list it:
        echo ...Found! - Listing to \""$destFolder/LE-Kexts.txt"\"...
        lEList="$( cd "$driveMount$lEPath"; ls -1 | grep "^[^.]" )"
        echo "$lEList" > "$destFolder/LE-Kexts.txt"
    else
        echo ...Not Found!
    fi
    
    echo
    echo Checking for \""$driveMount$sLEPath"\"...
    
    # List sLEPath if it exists
    if [[ -d "$driveMount$sLEPath" ]]; then
        #Yay!  It exists - let's list it:
        echo ...Found! - Listing to \""$destFolder/SLE-Kexts.txt"\"...
        sLEList="$( cd "$driveMount$sLEPath"; ls -1 | grep "^[^.]" )"
        echo "$sLEList" > "$destFolder/SLE-Kexts.txt"
    else
        echo ...Not Found!
    fi

    # List all loaded kexts
    if [[ "$getLoaded" == "1" ]]; then
        # We want em - let's get em
        echo
        echo Getting all loaded kexts! - Listing to \""$destFolder/KextStat.txt"\"...
        kList="$( kextstat )"
        echo "$kList" > "$destFolder/KextStat.txt"
    fi

    # List loaded non-Apple kexts
    if [[ "$getNALoaded" == "1" ]]; then
        # We want em - let's get em
        echo
        echo Getting loaded non-Apple kexts! - Listing to \""$destFolder/KextStat-non-Apple.txt"\"...
        ksList="$( kextstat | grep -iv com.apple )"
        echo "$ksList" > "$destFolder/KextStat-non-Apple.txt"
    fi
    
    # Check if we're on the boot drive or not
    if [[ ! "$bootMount" == "$driveMount" ]]; then
        # We're not on our boot drive - grab those too
        echo
        echo Checking for \""$bootMount$lEPath"\"...
    
        # List lEPath if it exists
        if [[ -d "$bootMount$lEPath" ]]; then
            #Yay!  It exists - let's list it:
            echo ...Found! - Listing to \""$destFolder/Boot-LE-Kexts.txt"\"...
            lEList="$( cd "$bootMount$lEPath"; ls -1 | grep "^[^.]" )"
            echo "$lEList" > "$destFolder/Boot-LE-Kexts.txt"
        else
            echo ...Not Found!
        fi
    
        echo
        echo Checking for \""$bootMount$sLEPath"\"...
    
        # List sLEPath if it exists
        if [[ -d "$bootMount$sLEPath" ]]; then
            #Yay!  It exists - let's list it:
            echo ...Found! - Listing to \""$destFolder/Boot-SLE-Kexts.txt"\"...
            sLEList="$( cd "$bootMount$sLEPath"; ls -1 | grep "^[^.]" )"
            echo "$sLEList" > "$destFolder/Boot-SLE-Kexts.txt"
        else
            echo ...Not Found!
        fi
    fi
    
    echo
    echo Checking for \""$driveMount/EFI/CLOVER/kexts"\"...
    
    # Check for EFI folder on root of drive
    
    hasEFIFolder="$( checkEFIFolder "$driveMount" )"
    
    if [[ "$hasEFIFolder" == "1" ]]; then
        
        if [[ -d "$driveMount/EFI/CLOVER/kexts" ]]; then
            echo ...Found! - Iterating contents...
            iterateEFI "$driveMount/EFI/CLOVER/kexts" "$destFolder" "EFIF-"
        else
            echo ...Not Found!
        fi
        
        if [[ "$getConfig" == "1" ]]; then
            echo
            echo Checking for \""$driveMount/EFI/CLOVER/config.plist"\"...
            if [[ -e "$driveMount/EFI/CLOVER/config.plist" ]]; then
                echo ...Found! - Copying to \""$destFolder/EFIF-config.plist"\"...
                cp "$driveMount/EFI/CLOVER/config.plist" "$destFolder/EFIF-config.plist"
            else
                echo ...Not Found!
            fi
        fi
        
        if [[ "$getD64UEFI" == "1" ]]; then
            echo
            echo Checking for \""$driveMount/EFI/drivers64UEFI"\"...
                if [[ -d "$driveMount/EFI/CLOVER/drivers64UEFI" ]]; then
                    echo ...Found! - Listing to \""$destFolder/EFIF-drivers64UEFI.txt"\"...
                    d64UEFIFList="$( cd "$driveMount/EFI/CLOVER/drivers64UEFI"; ls -1 | grep "^[^.]" )"
                    echo "$d64UEFIFList" > "$destFolder/EFIF-drivers64UEFI.txt"
            else
                echo ...Not Found!
            fi
        fi

        if [[ "$getACPI" == "1" ]]; then
            echo
            echo ...Checking for \""$driveMount/EFI/ACPI/patched"\"...
                if [[ -d "$driveMount/EFI/CLOVER/ACPI/patched" ]]; then
                    echo ...Found! - Listing to \""$destFolder/EFIF-ACPI-Patched.txt"\"...
                    acpiList="$( cd "$driveMount/EFI/CLOVER/ACPI/Patched"; ls -1 | grep "^[^.]" )"
                    echo "$acpiList" > "$destFolder/EFIF-ACPI-Patched.txt"
            else
                echo ...Not Found!
            fi
        fi
        
    else
        echo ...Not Found!
    fi
    
    echo
    echo Checking for EFI partition...
    
    hasEFIPartition="$( getEFIIdentifier "$driveIdent" )"
    
    needToUnmount="0"
    
    if [[ ! "$hasEFIPartition" == "" ]]; then
        # Check if we have an EFI partition - and mount it
        setEFI "$hasEFIPartition"
        
        echo ...Found! - Checking mount status...
        
        if [[ "$efiMount" == "" ]]; then
            echo ...Mounting...
            needToUnmount="1"
            diskutil mount "$hasEFIPartition" &>/dev/null
            setEFI "$efiIdent"
        fi
        efiMount="$( removeTrailingSlash "$efiMount" )"
        # Iterate
        echo
        echo Checking for \""$efiMount/EFI/CLOVER/kexts"\"...
        if [[ -d "$efiMount/EFI/CLOVER/kexts" ]]; then
            echo ...Found! - Iterating contents...
            iterateEFI "$efiMount/EFI/CLOVER/kexts" "$destFolder" "EFI-"
        fi
        
        if [[ "$getConfig" == "1" ]]; then
            echo
            echo Checking for \""$efiMount/EFI/CLOVER/config.plist"\"...
            if [[ -e "$efiMount/EFI/CLOVER/config.plist" ]]; then
                echo ...Found! - Copying to \""$destFolder/EFI-config.plist"\"...
                cp "$efiMount/EFI/CLOVER/config.plist" "$destFolder/EFI-config.plist"
            else
                echo ...Not Found!
            fi
        fi
        
        if [[ "$getD64UEFI" == "1" ]]; then
            echo
            echo ...Checking for \""$efiMount/EFI/drivers64UEFI"\"...
                if [[ -d "$efiMount/EFI/CLOVER/drivers64UEFI" ]]; then
                    echo ...Found! - Listing to \""$destFolder/EFI-drivers64UEFI.txt"\"...
                    d64UEFIList="$( cd "$efiMount/EFI/CLOVER/drivers64UEFI"; ls -1 | grep "^[^.]" )"
                    echo "$d64UEFIList" > "$destFolder/EFI-drivers64UEFI.txt"
            else
                echo ...Not Found!
            fi
        fi
        
        if [[ "$getACPI" == "1" ]]; then
            echo
            echo ...Checking for \""$efiMount/EFI/ACPI/patched"\"...
                if [[ -d "$efiMount/EFI/CLOVER/ACPI/patched" ]]; then
                    echo ...Found! - Listing to \""$destFolder/EFI-ACPI-Patched.txt"\"...
                    acpiList="$( cd "$efiMount/EFI/CLOVER/ACPI/Patched"; ls -1 | grep "^[^.]" )"
                    echo "$acpiList" > "$destFolder/EFI-ACPI-Patched.txt"
            else
                echo ...Not Found!
            fi
        fi

        # Unmount EFI if it was unmounted before
        if [[ "$needToUnmount" == "1" ]]; then
            echo
            echo Unmounting \""$efiMount"\"...
            diskutil unmount "$efiIdent"
        fi
    else
        echo ...Not Found!
    fi
    
    # Grab diskutil list info
    echo
    echo Grabbing diskutil list...
    diskInfo="$( diskutil list )"
    echo ...Copying to \""$destFolder/DiskUtil-Info.txt"\"...
    echo "$diskInfo" > "$destFolder/DiskUtil-Info.txt"
    
    echo
    echo Grabbing system version...
    sysVers="$( system_profiler SPSoftwareDataType )"
    echo ...Copying to \""$destFolder/SysVersion-Info.txt"\"...
    echo "$sysVers" > "$destFolder/SysVersion-Info.txt"

    # Zip up the resulting file on the desktop
    
    clear
    echo \#\#\# EssentialsList - CorpNewt \#\#\#
    echo
    echo Successfully populated \""$destFolder"\"!
    echo
    echo Would you like to zip this folder up?  \(y/n\):
    echo This will delete the original folder when done.
    echo 
    echo 
    read toZip
    
    if [[ "$toZip" == "" ]]; then 
        toZip="y"
    fi 
    
    if [[ "$toZip" == "y" ]]; then
        clear
        echo \#\#\# EssentialsList - CorpNewt \#\#\#
        echo
        echo Zipping \""$destFolder"\"...
        cd "$desktopPath"
        zip -r "$destFolderName.zip" "$destFolderName"
        cd "$DIR"
        echo
        echo Removing folder...
        rm -Rf "$destFolder"
    fi
    
    
    echo
    echo Done.
    echo
    sleep 3
    customQuit

}

function iterateEFI () {
    # Takes a folder - iterates through it, listing the contents
    # of each directory to var2 - a supplied directory
    
    local __sourceFolder="$( removeTrailingSlash "$1" )"
    local __destFolder="$( removeTrailingSlash "$2" )"
    local __prefix="$3"
    local __list="$( cd "$__sourceFolder"; ls -1 )"
    local __array=""
    local __folderList=""
    
    unset __array
    IFS=$'\n' read -rd '' -a __array <<<"$__list"
    
    local __testcount="${#__array[@]}"
    
    if [ "$__testcount" -gt "0" ]; then
        for item in "${__array[@]}"
        do
            # List the contents of each folder to its own
            # text file
            __folderList=""
            if [[ -d "$__sourceFolder/$item" ]]; then
                # We got a directory - dump the contents:
                __folderList="$( cd "$__sourceFolder/$item"; ls -1 | grep "^[^.]" )"
                
                # Check for empty folders by checking string length gtr 0
                if [[ ! "${#__folderList}" == "0" ]]; then
                    echo "$__folderList" > "$__destFolder/$__prefix$item.txt"
                fi
            fi
        done
    fi

}

function checkPath () {

    if [[ ! -e "$1" ]]; then
        mkdir "$1"
        echo "$?"
    else
        echo "0"
    fi

}

function checkEFIFolder () {
    local __vol=$1
	if [[ -d "$__vol/EFI" ]]; then
        echo 1
    else
        echo 0
    fi
}

function getTimestamp () {
    date +%Y%m%d_%H%M%S%Z
}

function expandRelativePath () {
    #Expand tilde in path if relative
    local __startPath="$1"
    __startPath="${__startPath/#\~/$HOME}"
    echo $__startPath
}

function removeTrailingSlash () {
    echo ""${1%/}""
}


###################################################
###               Disk Functions                ###
###################################################


function isDisk () {
	# This function checks our passed variable
	# to see if it is a disk
	# Accepts mount point, diskXsX and an empty variable
	# If empty, defaults to "/"
	local __disk=$1
	if [[ "$__disk" == "" ]]; then
		__disk="/"
	fi
	# Here we run diskutil info on our __disk and see what the
	# exit code is.  If it's "0", we're good.
	diskutil info "$__disk" &>/dev/null
	# Return the diskutil exit code
	echo $?
}

function volumeName () {
	# This is a last-resort function to check if maybe
	# Just the name of a volume was passed.
	local __disk=$1
	if [[ ! -d "$__disk" ]]; then
		if [ -d "/volumes/$__disk" ]; then
			#It was just volume name
			echo "/Volumes/$__disk"
		fi
	else
		echo "$__disk"
	fi
}

function getDiskMounted () {
	local __disk=$1
	# If variable is empty, set it to "/"
	if [[ "$__disk" == "" ]]; then
		__disk="/"
	fi
	# Output the "Volume Name" of __disk
	echo "$( diskutil info "$__disk" | grep 'Mounted' | cut -d : -f 2 | sed 's/^ *//g' | sed 's/ *$//g' )"
}

function getDiskName () {
	local __disk=$1
	# If variable is empty, set it to "/"
	if [[ "$__disk" == "" ]]; then
		__disk="/"
	fi
	# Output the "Volume Name" of __disk
	echo "$( diskutil info "$__disk" | grep 'Volume Name' | cut -d : -f 2 | sed 's/^ *//g' | sed 's/ *$//g' )"
}

function getDiskMountPoint () {
	local __disk=$1
	# If variable is empty, set it to "/"
	if [[ "$__disk" == "" ]]; then
		__disk="/"
	fi
	# Output the "Mount Point" of __disk
	echo "$( diskutil info "$__disk" | grep 'Mount Point' | cut -d : -f 2 | sed 's/^ *//g' | sed 's/ *$//g' )"
}

function getDiskIdentifier () {
	local __disk=$1
	# If variable is empty, set it to "/"
	if [[ "$__disk" == "" ]]; then
		__disk="/"
	fi
	# Output the "Mount Point" of __disk
	echo "$( diskutil info "$__disk" | grep 'Device Identifier' | cut -d : -f 2 | sed 's/^ *//g' | sed 's/ *$//g' )"
}

function getDiskNumbers () {
	local __disk=$1
	# If variable is empty, set it to "/"
	if [[ "$__disk" == "" ]]; then
		__disk="/"
	fi
	# Output the "Device Identifier" of __disk
	# If our disk is "disk0s1", it would output "0s1"
	echo "$( getDiskIdentifier "$__disk" | cut -d k -f 2 )"
}

function getDiskNumber () {
	local __disk=$1
	# If variable is empty, set it to "/"
	if [[ "$__disk" == "" ]]; then
		__disk="/"
	fi
	# Get __disk identifier numbers
	local __diskNumbers="$( getDiskNumbers "$__disk" )"
	# return the first number
	echo "$( echo "$__diskNumbers" | cut -d s -f 1 )"
}

function getPartitionNumber () {
	local __disk=$1
	# If variable is empty, set it to "/"
	if [[ "$__disk" == "" ]]; then
		__disk="/"
	fi
	# Get __disk identifier numbers
	local __diskNumbers="$( getDiskNumbers "$__disk" )"
	# return the second number
	echo "$( echo "$__diskNumbers" | cut -d s -f 2 )"	
}

function getPartitionType () {
	local __disk=$1
	# If variable is empty, set it to "/"
	if [[ "$__disk" == "" ]]; then
		__disk="/"
	fi
	# Output the "Volume Name" of __disk
	echo "$( diskutil info "$__disk" | grep 'Partition Type' | cut -d : -f 2 | sed 's/^ *//g' | sed 's/ *$//g' )"
}

function getEFIIdentifier () {
	local __disk="$1"
	# If variable is empty, set it to "/"
	if [[ "$__disk" == "" ]]; then
		__disk="/"
	fi

	# Check if we are on an APFS volume
	local __tempNum="$( getDiskNumber "$__disk" )"
	local __apfsDisk="$( getPhysicalStore "disk$__tempNum" )"
	if [[ "$__apfsDisk" != "" ]]; then
		__disk="$__apfsDisk"
	fi

	local __diskName="$( getDiskName "$__disk" )"
	local __diskNum="$( getDiskNumber "$__disk" )"

	# Output the "Device Identifier" for the EFI partition of __disk
	endOfDisk="0"
	i=1
	while [[ "$endOfDisk" == "0" ]]; do
		# Iterate through all partitions of the disk, and return those that
		# are EFI
		local __currentDisk=disk"$__diskNum"s"$i"
		# Check if it's a valid disk, and if not, exit the loop
		if [[ "$( isDisk "$__currentDisk" )" != "0" ]]; then
			endOfDisk="true"
			continue
		fi

		local __currentDiskType="$( getPartitionType "$__currentDisk" )"

		if [ "$__currentDiskType" == "EFI" ]; then
			echo "$( getDiskIdentifier "$__currentDisk" )"
		fi
		i="$( expr $i + 1 )"
	done
}

function getPhysicalStore () {
	# Helper function to get the physical disk for apfs volume
	local __disk="$1"
	local __diskName="$( getDiskName "$__disk" )"
	local __diskNum="$( getDiskNumber "$__disk" )"
	# If variable is empty, set it to "/"
	if [[ "$__disk" == "" ]]; then
		__disk="/"
	fi
	# Output the physical store disk, if any
	__tempDisk="$( diskutil apfs list "$__disk" 2>/dev/null | grep 'APFS Physical Store Disk' | cut -d : -f 2 | sed 's/^ *//g' | sed 's/ *$//g' )"
	__finalDisk=""
	if [[ "$__tempDisk" != "" ]]; then
		__tempDiskNumber="$( getDiskNumber "$__tempDisk" )"
		__finalDisk="disk$__tempDiskNumber"
	fi
	echo $__finalDisk
}

###################################################
###             End Disk Functions              ###
###################################################

#Initialization

resetVars
desktopPath="$( expandRelativePath "$desktopPath" )"
lEPath="$( expandRelativePath "$lEPath" )"
sLEPath="$( expandRelativePath "$sLEPath" )"

displayWarning
