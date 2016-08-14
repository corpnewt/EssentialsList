# EssentialsList
A small script that creates a timestamped folder on your Desktop that containing kext lists

Run the script - select the drive you want to explore and the script will search the following locations:

*/Library/Extensions/*
*/System/Library/Extensions/*
*/EFI/CLOVER/kexts/* (if it exists)

It will then look for an EFI partition, mount it, and search it for:

*/Volumes/EFI/EFI/CLOVER/kexts/* (if it exists)

And list all the output from those locations into the timestamped folder on your Desktop.

It will also copy config.plists over and the contents of *drivers64UEFI* from both EFI locations.
