# EssentialsList
A small python script that creates a timestamped zip on your Desktop that containing troubleshooting info

***

## To install:

Do the following one line at a time in Terminal:

    git clone https://github.com/corpnewt/EssentialsList
    cd EssentialsList
    chmod +x EssentialsList.command
    
Then run with either `./Run.command` or by double-clicking *Run.command*

***

## What it gets:

The script can be customized (with more features coming in the future hopefully), but the defaults grab the following:

* Version of BOOTX64.efi and CLOVERX64.efi
* config.plist (as well as verifying structure)
* Kext lists and versions from the 10.xx and Other folders
* SSDT/DSDT from ACPI -> origin and patched
* drivers32/64(UEFI) list
* debug.log
* preboot.log
* bdmesg
* kextstat
* kextcache (both raw and cleaned versions)
* List of kexts and versions from /Library/Extensions and /System/Library/Extensions
* sysctl machdep.cpu/xcpm
* patchmatic dump
* pmset -g and assertions
* diskutil list
* Mount points
* IOReg
* General overview of the Clover installs/system

It also auto-finds the booted Clover install by parsing bdmesg - but will prompt the user if not found.

It can auto-mount EFI partitions, and will remember the state and return it when completed.

It saves the output to a timestamped zip on the Desktop with the format `EssentialsList-[timestam].zip`

***

## Thanks To:

* Slice, apianti, vit9696, Download Fritz, Zenith432, STLVNUB, JrCs,cecekpawon, Needy, cvad, Rehabman, philip_petev, ErmaC and the rest of the Clover crew for Clover and bdmesg
* RehabMan for patchmatic
* Apple for making it so damn hard to resolve apfs and core storage volumes to their respective EFI partitions...
