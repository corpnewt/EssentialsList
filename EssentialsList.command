#!/usr/bin/env python
from Scripts import *
import os, sys, tempfile, datetime, shutil, time, plistlib, json

class Essentials:
    def __init__(self, **kwargs):
        self.r = run.Run()
        self.d = disk.Disk()
        self.u = utils.Utils("Essentials List")
        self.re = reveal.Reveal()
        self.c = rebuildcache.Rebuild()
        
        self.script_folder = "Scripts"
        self.settings      = "settings.json"
        # Check for self.settings in our self.script_folder
        # And load it into kwargs if it exists - this will override
        # default settings
        settings_path = os.path.join(
            os.path.dirname(os.path.realpath(__file__)),
            self.script_folder,
            self.settings
        )
        if os.path.exists(settings_path):
            try:
                kwargs = json.load(open(settings_path))
            except:
                pass
            
        self.width = 70
        
        # Turn on the functions we want to run
        self.efi        = kwargs.get("efi", True)
        self.h_serial   = kwargs.get("hide_serial", True)
        self.overview   = kwargs.get("overview", True)
        self.auto_efi   = kwargs.get("auto_efi", True)
        self.disks      = kwargs.get("diskutil", True)
        self.nvram      = kwargs.get("nvram", True)
        self.bdmesg     = kwargs.get("bdmesg", True)
        self.ioreg      = kwargs.get("ioreg", True)
        self.sysctl     = kwargs.get("sysctl", True)
        self.get_patch  = kwargs.get("patchmatic", True)
        self.get_pmset  = kwargs.get("pmset", True)
        self.kstat      = kwargs.get("kextstat", True)
        self.cache      = kwargs.get("kextcache", True)
        self.kfold      = kwargs.get("kextfolders", True)
        self.zip        = kwargs.get("zip", True)
        # Check for forced functions
        self.force_ssdt = kwargs.get("force_ssdt", False)
        self.force_dbg  = kwargs.get("force_debug", False)
        self.force_pre  = kwargs.get("force_preboot", False)
        
        # Get the tools we need
        self.patchmatic = self.get_binary("patchmatic")

        # Set placeholders for serial and uuid
        self.serial     = ""
        self.smuuid     = ""
        return

    def write_text(self, text, filepath):
        # Helper method to write binary text to file on py3, but
        # leave the str/unicode values alone on py2
        w = "w"
        if sys.version_info >= (3,0) and isinstance(text, str):
            text = text.encode("utf-8","ignore")
            w = "wb"
        with open(filepath, w) as f:
            f.write(text)
        
    def get_binary(self, name):
        # Check the system, and local Scripts dir for the passed binary
        found = self.r.run({"args":["which", name]})[0].split("\n")[0].split("\r")[0]
        if len(found):
            # Found it on the system
            return found
        if os.path.exists(os.path.join(os.path.dirname(os.path.realpath(__file__)), name)):
            # Found it locally
            return os.path.join(os.path.dirname(os.path.realpath(__file__)), name)
        # Check the scripts folder
        if os.path.exists(os.path.join(os.path.dirname(os.path.realpath(__file__)), self.script_folder, name)):
            # Found it locally -> Scripts
            return os.path.join(os.path.dirname(os.path.realpath(__file__)), self.script_folder, name)
        # Not found
        return None

    def get_serial(self):
        # Will retrieve the serial and UUID from IOReg and return it
        # for obfuscation purposes
        if "" in [ self.serial, self.smuuid ]:
            # We don't have them - get them
            print("Locating serial for obfuscation...")
            hw = self.r.run({"args":["system_profiler", "SPHardwareDataType"]})[0].strip()
            self.serial = self.get_split(hw, 'Serial Number (system): ', '\n', "")
            self.smuuid = self.get_split(hw, 'Hardware UUID: ', '\n', "")

    def get_uuid_from_bdmesg(self):
        # Get bdmesg output - then parse for SelfDevicePath
        bd = bdmesg.bdmesg()
        if not "SelfDevicePath=" in bd:
            # Not found
            return None
        try:
            # Split to just the contents of that line
            line = bd.split("SelfDevicePath=")[1].split("\n")[0]
            # Get the HD section
            hd   = line.split("HD(")[1].split(")")[0]
            # Get the UUID
            uuid = hd.split(",")[2]
            print("Got Clover drive UUID: {}\n".format(uuid))
            return uuid
        except:
            pass
        return None

    def get_split(self, text, start, end, default=None):
        try:
            return text.split(start)[1].split(end)[0]
        except:
            return default

    def get_all_split(self, text, start, end, default=None):
        splits = []
        try:
            for x in text.split(start)[1:]:
                try:
                    splits.append(x.split(end)[0])
                except:
                    pass
        except:
            pass
        if not len(splits):
            return default
        return splits

    def get_hw_from_bdmesg(self):
        # Get bdmesg output - then parse for hardware info
        # Should include:
        # Running on: 'x' with board 'y'
        # BrandString = CPU_String
        # - GFX: Model=
        bd    = bdmesg.bdmesg()
        mobo  = self.get_split(bd, "Running on: ", "\n", "Unknown Board")
        cpu   = self.get_split(bd, "BrandString = ", "\n", "Unknown CPU")
        gpus  = self.get_all_split(bd, "- GFX: Model=", "\n", "Unknown GPU")
        if type(gpus) is list:
            gpus = "      ".join(gpus)
        return "CPU:  {}\nGPU:  {}\nMOBO: {}".format(cpu, gpus, mobo)
        
    def get_efi(self):
        self.u.head()
        print(" ")
        self.d.update()
        clover = self.get_uuid_from_bdmesg()
        mounts = self.d.get_disks_and_partitions_dict()
        disks = mounts.keys()
        i = 0
        for d in disks:
            i += 1
            print("{}. {}:".format(i, d))
            parts = mounts[d]["partitions"]
            part_list = []
            for p in parts:
                p_text = "        - {}".format(p["name"])
                if p["disk_uuid"] == clover:
                    # Got Clover
                    p_text += " *"
                part_list.append(p_text)
            if len(part_list):
                print("\n".join(part_list))
        print(" ")
        print("Q. Quit")
        print(" ")
        print("(* denotes the booted Clover)")
        menu = self.u.grab("Pick the drive containing your EFI:  ")
        if not len(menu):
            return self.get_efi()
        if menu.lower() == "q":
            self.u.custom_quit()
        try:
            disk_iden = int(menu)
            if not (disk_iden > 0 and disk_iden <= len(disks)):
                # out of range!
                self.u.grab("Invalid disk!", timeout=3)
                return self.get_efi()
            disk = disks[disk_iden-1]
        except:
            disk = menu
        iden = self.d.get_identifier(disk)
        name = self.d.get_volume_name(disk)
        if not iden:
            self.u.grab("Invalid disk!", timeout=3)
            return self.get_efi()
        # Valid disk!
        return self.d.get_efi(iden)

    def main(self):
        # Check for forced logs/files and get confirmation:
        if True in [ self.force_ssdt, self.force_dbg, self.force_pre ]:
            # We have at least one forced log - let's throw up the prompt
            while True:
                self.u.head("Required Files")
                print(" ")
                print("The following are required for this script to complete")
                print("and must be under an hour old:\n")
                if self.force_ssdt:
                    print("* ACPI -> origin SSDT/DSDT (press F4 in Clover to dump)")
                if self.force_dbg:
                    print("* boot.log (config.plist -> Boot -> Debug = True)")
                if self.force_pre:
                    print("* preboot.log (press F2 in Clover to dump)")
                print(" ")
                menu = self.u.grab("Continue? (y/n):  ")
                if not len(menu):
                    continue
                if menu.lower()[:1] == "y":
                    break
                elif menu.lower()[:1] == "n":
                    self.u.custom_quit()
        
        boot_drive   = self.d.get_identifier("/")
        clover_drive = None
        if self.auto_efi:
            # Auto-get the Clover location
            efi_uuid = self.get_uuid_from_bdmesg()
            if efi_uuid:
                # We were able to parse the UUID
                clover_drive = self.d.get_identifier(efi_uuid)
        if not clover_drive:
            # Either we don't auto-get it, or we couldn't find it
            clover_drive  = self.get_efi()
        if clover_drive == boot_drive:
            # They're the same - skip the second approach
            clover_drive = None
        efi_mount  = False
        # This will iterate through a number of processes to gather info
        # we can use for troubleshooting

        self.u.head("Gathering Info")
        print(' ')
        path_list = []
        # Now we have our folder and can run our tests
        if clover_drive:
            # Save the EFI mount state
            self.d.update()
            efi_mount = self.d.is_mounted(clover_drive)
            # Mount the EFI partition
            self.d.mount_partition(clover_drive)
            # Gather up the path where we'd expect Clover and save it
            efi_mount_point = self.d.get_mount_point(clover_drive)
            if not efi_mount_point:
                print("EFI failed to mount - skipping...")
            else:
                efi_path = os.path.join(efi_mount_point, "EFI", "CLOVER")
                if os.path.exists(efi_path):
                    print("Got Clover install at {} ({})".format(efi_path, clover_drive))
                    path_list.append({ "disk" : clover_drive, "path" : efi_path })
        # Check for Clover locally
        if os.path.exists("/EFI/CLOVER"):
            print("Got Clover install at /EFI/CLOVER ({})".format(boot_drive))
            path_list.append({ "disk" : boot_drive, "path" : "/EFI/CLOVER" })
        
        # First we create a temp directory into which we'll work
        temp = tempfile.mkdtemp()
        # Now we make a time-stamped name for that
        folder_name = "EssentialsList-{:%Y-%m-%d %H.%M.%S}".format(datetime.datetime.now())
        folder = os.path.join(temp, folder_name)
        os.mkdir(folder)

        if not len(path_list):
            if clover_drive and not efi_mount:
                print("Unmounting EFI partition...")
                self.d.unmount_partition(clover_drive)
            self.u.grab("No CLOVER installs found!", timeout=5)
            return

        print(" ")

        try:
            # Gather serial info if needed
            if self.h_serial:
                self.get_serial()
                self.h_serial = False if "" in [ self.serial, self.smuuid ] else True
            # Run all the processes needed, and gather the info
            over_text = ""
            if self.efi:
                over_text = self.process_efi(path_list, folder)
            if self.overview:
                self.process_overview(folder, over_text)
            if self.disks:
                self.process_disks(folder)
                self.process_mount_points(folder)
            if self.nvram:
                self.process_nvram(folder)
            if self.bdmesg:
                self.process_bdmesg(folder)
            if self.ioreg:
                self.process_ioreg(folder)
            if self.sysctl:
                self.process_sysctl(folder)
            if self.get_patch:
                self.process_patchmatic(folder)
            if self.get_pmset:
                self.process_pmset(folder)
            if self.kstat:
                self.process_kextstat(folder)
            if self.kfold:
                self.process_kext_folders(folder)
            if self.cache:
                self.process_cache(folder)
            if self.zip:
                self.process_zip(temp, folder_name)
            else:
                self.process_folder(temp, folder_name)
        except Exception as e:
            print("Something went wrong!")
            print(str(e))
        if clover_drive and not efi_mount:
            print("Unmounting EFI partition...")
            self.d.unmount_partition(clover_drive)
        print(" ")
        self.u.grab("Done!", timeout=5)
        shutil.rmtree(temp)
        self.u.custom_quit()

    def process_zip(self, temp, folder):
        # Zip up the folder and move it to the Desktop
        print("Zipping up {} and copying to desktop...".format(folder))
        desktop = os.path.expanduser("~/Desktop")
        fpath = os.path.join(temp, folder)
        zippath = os.path.join(desktop, folder+".zip")
        cdir = os.getcwd()
        os.chdir(temp)
        self.r.run({"args":["zip", "-r", zippath, folder]})
        os.chdir(cdir)
        if os.path.exists(zippath):
            # Found it!
            self.re.reveal(zippath, True)

    def process_folder(self, temp, folder):
        # Copies the resulting folder to the desktop
        print("Copying {} to the desktop...".format(folder))
        fpath = os.path.join(temp, folder)
        dpath = os.path.join(os.path.expanduser("~/Desktop"), folder)
        shutil.copytree(fpath, dpath)
        if os.path.exists(dpath):
            # Found it!
            self.re.reveal(dpath, True)

    def process_overview(self, temp, over_text = ""):
        # Gets an overview of the hardware, system version, and appends any over text to it
        # Dump overview
        over = "{}\n".format("#"*self.width)
        hs_name = self.r.run({"args":["sysctl", "-n", "kern.hostname"]})[0].strip()
        over += "#{}#\n".format("{}".format(hs_name).center(self.width-2))
        over += "{}\n".format("#"*self.width)
        os_name = self.r.run({"args":["sw_vers", "-productName"]})[0].strip()
        os_vers = self.r.run({"args":["sw_vers", "-productVersion"]})[0].strip()
        bd_vers = self.r.run({"args":["sw_vers", "-buildVersion"]})[0].strip()
        over += "#{}#\n".format(" "*(self.width-2))
        over += "#{}#\n".format("{} - {} ({})".format(os_name, os_vers, bd_vers).center(self.width-2))
        over += "#{}#\n".format(" "*(self.width-2))
        over += "{}\n\n\n".format("#"*self.width)

        over += "{}\n".format("#"*self.width)
        over += "#{}#\n".format("Hardware Info From System Profiler".center(self.width-2))
        over += "{}\n\n".format("#"*self.width)

        hw_name = self.r.run({"args":["system_profiler", "SPHardwareDataType"]})[0].strip()
        hw_name = "\n".join([ x.strip() for x in hw_name.split("\n")[4:] ])
        if self.h_serial:
            hw_name = hw_name.replace(self.serial, "0"*len(self.serial))
            hw_name = hw_name.replace(self.smuuid, "-".join([ "0"*len(x) for x in self.smuuid.split("-") ]))
        over += hw_name + "\n\n"

        # Get more info
        hw_info = self.get_hw_from_bdmesg()
        if len(hw_info):
            # Add hw info to the mix
            over += "{}\n".format("#"*self.width)
            over += "#{}#\n".format("Hardware Info From BDMSG".center(self.width-2))
            over += "{}\n\n".format("#"*self.width)
            over += hw_info

        if len(over_text):
            over += "\n\n"
            over += "{}\n".format("#"*self.width)
            over += "#{}#\n".format(" "*(self.width-2))
            c_text = "Found 1 Clover Install" if len(over_text) == 1 else "Found {} Clover Installs".format(len(over_text))
            over += "#{}#\n".format(c_text.center(self.width-2))
            over += "#{}#\n".format(" "*(self.width-2))
            over += "{}\n\n".format("#"*self.width)
            over += "\n\n".join(over_text)

        # Write to file
        self.write_text(over, os.path.join(temp, "- Overview -.txt"))
        
    def process_efi(self, path_list, folder):
        # Iterate through the paths and grab all the Clover-type info
        over_view = []
        for path in path_list:
            disk = path["disk"]
            name = self.d.get_volume_name(disk)
            cver = "CLOVERX64.efi - Clover Version Not Found!"
            bver = "BOOTX64.efi   - CloverVersion Not Found!"
            conf = "Not Found!"
            kext = ""
            acpi = ""
            uefi = ""
            debg = "Not Found!"
            prbt = "Not Found!"
            t    = time.time()
            p    = path["path"]
            print("Getting Clover info from {}...".format(p))
            p_folder = os.path.join(folder, "{} - ({})".format(name, disk))
            os.mkdir(p_folder)
            # Check the Clover version
            if os.path.exists(os.path.join(p, "CLOVERX64.efi")):
                cver = "CLOVERX64.efi - Clover Version " + self.get_clover_version(os.path.join(p, "CLOVERX64.efi"))
            # Check for BOOX64.efi and see if we can pull a version from that too
            b_path = os.path.join(os.path.normpath(os.path.join(p, os.pardir)), "BOOT", "BOOTX64.efi")
            if os.path.exists(b_path):
                bver = "BOOTX64.efi   - Clover Version " + self.get_clover_version(b_path)
            # Copy the config.plist over
            if os.path.exists(os.path.join(p, "config.plist")) and not os.path.isdir(os.path.join(p, "config.plist")):
                shutil.copy(os.path.join(p, "config.plist"), os.path.join(p_folder, "config.plist"))
                board_serial = None
                try:
                    plist_dict = plistlib.readPlist(os.path.join(p_folder, "config.plist"))
                    conf = "OK!"
                except Exception as e:
                    conf = "Broken!: {}".format(e)
                if self.h_serial:
                    # Rework plist data independently of formatting issues
                    plist_data = ""
                    with open(os.path.join(p_folder, "config.plist"), "r") as f:
                        s = False
                        for line in f:
                            if s == False and any(x for x in ["<key>serialnumber</key>", "<key>boardserialnumber</key>", "<key>mlb</key>", "<key>rom</key>", "<key>smuuid</key>", "<key>customuuid</key>"] if x in line.lower()):
                                plist_data += line
                                s = True
                                continue
                            if s:
                                s = False
                                hidden = self.get_split(line, "<string>", "</string>", None)
                                if hidden:
                                    line = line.replace(hidden, "-".join([ "0"*len(x) for x in hidden.split("-") ]))
                            plist_data += line
                    if len(plist_data):
                        self.write_text(plist_data, os.path.join(p_folder, "config.plist"))

            # Copy the debug.log over
            got_debug = False
            if os.path.exists(os.path.join(p, "misc", "debug.log")) and not os.path.isdir(os.path.join(p, "misc", "debug.log")):
                if t - os.path.getmtime(os.path.join(p, "misc", "debug.log")) <= 3600:
                    shutil.copy(os.path.join(p, "misc", "debug.log"), os.path.join(p_folder, "debug.log"))
                    got_debug = True
                    debg = "Found!"
            if not got_debug:
                print("NO APPLICABLE DEBUG.LOG FOUND IN MISC!")
                print("  SET CONFIG -> BOOT -> DEBUG = TRUE AND REBOOT TO DUMP")
                if self.force_dbg:
                    # Gotta stop
                    print("Requirements not met - cancelling...")
                    raise Exception('Cannot continue.  Missing debug.log.')
                    
            # Copy the preboot.log over
            got_preboot = False
            if os.path.exists(os.path.join(p, "misc", "preboot.log")) and not os.path.isdir(os.path.join(p, "misc", "preboot.log")):
                if t - os.path.getmtime(os.path.join(p, "misc", "preboot.log")) <= 3600:
                    shutil.copy(os.path.join(p, "misc", "preboot.log"), os.path.join(p_folder, "preboot.log"))
                    got_preboot = True
                    prbt = "Found!"
            if not got_preboot:
                print("NO APPLICABLE PREBOOT.LOG FOUND IN MISC!")
                print("  REBOOT AND PRESS F2 IN CLOVER TO DUMP")
                if self.force_pre:
                    # Gotta stop
                    print("Requirements not met - cancelling...")
                    raise Exception('Cannot continue.  Missing preboot.log.')

            # Check for origin SSDT/DSDT
            acpi_files = []
            if os.path.exists(os.path.join(p, "ACPI", "origin")) and os.path.isdir(os.path.join(p, "ACPI", "origin")):
                acpi += "ACPI -> Origin\n"
                f = os.path.join(p, "ACPI", "origin")
                d = os.path.join(p_folder, "ACPI-origin")
                for item in os.listdir(f):
                    if item.startswith(".") or os.path.isdir(os.path.join(f, item)):
                        continue
                    # Make sure it's not more than an hour old
                    if t - os.path.getmtime(os.path.join(f, item)) > 3600:
                        # old, skip
                        continue
                    acpi += "  {}\n".format(item)
                    acpi_files.append(item)
                    # Make sure we have a target destination
                    if not os.path.exists(d):
                        os.mkdir(d)
                    shutil.copy(os.path.join(f, item), os.path.join(d, item))
            if not len(acpi_files):
                print("NO APPLICABLE SSDT/DSDT FILES FOUND IN ACPI -> ORIGIN!")
                print("  REBOOT AND PRESS F4 IN CLOVER TO DUMP")
                if self.force_ssdt:
                    # Gotta stop
                    print("Requirements not met - cancelling...")
                    raise Exception('Cannot continue.  Missing ACPI -> origin.')
            # Check for patched SSDT/DSDT
            if os.path.exists(os.path.join(p, "ACPI", "patched")) and os.path.isdir(os.path.join(p, "ACPI", "patched")):
                acpi += "ACPI -> Patched\n"
                f = os.path.join(p, "ACPI", "patched")
                d = os.path.join(p_folder, "ACPI-patched")
                t = time.time()
                for item in sorted(os.listdir(f)):
                    if item.startswith(".") or os.path.isdir(os.path.join(f, item)):
                        continue
                    acpi += "  {}\n".format(item)
                    # Make sure we have a target destination
                    if not os.path.exists(d):
                        os.mkdir(d)
                    shutil.copy(os.path.join(f, item), os.path.join(d, item))
            if len(acpi):
                acpi = acpi[:-1]
            # Get the kexts and locations
            if os.path.exists(os.path.join(p, "kexts")) and os.path.isdir(os.path.join(p, "kexts")):
                k = os.path.join(p, "kexts")
                k_list  = os.listdir(k)
                k_list.sort(key=lambda x: (len(x), x))
                for k_dir in k_list:
                    if not os.path.isdir(os.path.join(k, k_dir)) or k_dir.startswith("."):
                        continue
                    kext += "{}\n".format(k_dir)
                    if not len(os.listdir(os.path.join(k, k_dir))):
                        continue
                    kk_dir = os.path.join(k, k_dir)
                    for k_file in sorted(os.listdir(kk_dir)):
                        if k_file.startswith(".") or not k_file.lower().endswith(".kext"):
                            continue
                        k_ver = self.get_kext_version(os.path.join(kk_dir, k_file))
                        kext += "  {} v{}\n".format(k_file, k_ver)
                if len(kext):
                    kext = kext[:-1]
                    # We actually wrote some stuff
                    self.write_text(kext, os.path.join(p_folder, "Kexts.txt"))
            # Check in the drivers32/64(UEFI) folders
            d_folders = [ x for x in os.listdir(p) if x.lower() in ["drivers32", "drivers64", "drivers32uefi", "drivers64uefi", "drivers/UEFI", "drivers/BIOS", "UEFIDrivers", "BiosDrivers"] and os.path.isdir(os.path.join(p, x)) ]
            if len(d_folders):
                for d in sorted(d_folders):
                    uefi += "{}\n".format(d)
                    if not len(os.listdir(os.path.join(p, d))):
                        continue
                    for d_p in sorted(os.listdir(os.path.join(p, d))):
                        if d_p.startswith("."):
                            continue
                        uefi += "  {}\n".format(d_p)
                if len(uefi):
                    uefi = uefi[:-1]
                    self.write_text(uefi, os.path.join(p_folder, "EFI Drivers.txt"))

            over = "{}\n".format("#"*self.width)
            over += "#{}#\n".format("{} - {} - {}".format(disk, name, p).center((self.width-2)))
            over += "{}\n\n".format("#"*self.width)
            
            over += "{}\n".format(bver)
            over += "{}\n\n".format(cver)
            over += "Config.plist Format {}\n\n".format(conf)

            over += "{}\n".format("#"*self.width)
            over += "#{}#\n".format("Logs".center((self.width-2)))
            over += "{}\n\n".format("#"*self.width)
            over += "Debug.log   - {}\nPreboot.log - {}\n\n".format(debg, prbt)

            over += "{}\n".format("#"*self.width)
            over += "#{}#\n".format("Kexts".center((self.width-2)))
            over += "{}\n\n".format("#"*self.width)
            over += "{}\n\n".format(kext)

            over += "{}\n".format("#"*self.width)
            over += "#{}#\n".format("SSDT/DSDT".center((self.width-2)))
            over += "{}\n\n".format("#"*self.width)
            over += "{}\n\n".format(acpi)

            over += "{}\n".format("#"*self.width)
            over += "#{}#\n".format("EFI Drivers".center((self.width-2)))
            over += "{}\n\n".format("#"*self.width)
            over += "{}".format(uefi)

            self.write_text(over, os.path.join(p_folder, "- Overview -.txt"))
            over_view.append(over)
        return over_view

    def process_sysctl(self, temp):
        # Dumps 'sysctl machdep.cpu' and 'sysctl machdep.xcpm'
        print("Getting sysctl cpu info...")
        cpu = self.r.run({"args" : ["sysctl", "machdep.cpu"]})[0]
        if len(cpu):
            self.write_text(cpu, os.path.join(temp, "sysctl_cpu.txt"))
        print("Getting sysctl xcpm info...")
        xcpm = self.r.run({"args" : ["sysctl", "machdep.xcpm"]})[0]
        if len(xcpm):
            self.write_text(xcpm, os.path.join(temp, "sysctl_xcpm.txt"))
                
    def process_patchmatic(self, temp):
        # Dumps ACPI patches via patchmatic
        print("Getting patchmatic dump...")
        if not self.patchmatic:
            print("Could not locate patchmatic!  Skipping...")
            return
        pmf = os.path.join(temp, "patchmatic_dump")
        if not os.path.exists(pmf):
            os.mkdir(pmf)
        cdir = os.getcwd()
        os.chdir(pmf)
        self.r.run({"args":[self.patchmatic, "-extract"]})
        os.chdir(cdir)

    def process_pmset(self, temp):
        # Dumps the output of pmset -g and pmset -g assertions to pmset.txt
        print("Getting pmset and assertions...")
        pmset = self.r.run({"args" : ["pmset", "-g"]})[0]
        pmsrt = self.r.run({"args" : ["pmset", "-g", "assertions"]})[0]
        pm_text = ""
        if len(pmset):
            pm_text += "### pmset -g ###\n\n" + pmset
        if len(pmset) and len(pmsrt):
            pm_text += "\n\n"
        if len(pmsrt):
            pm_text += "### pmset -g assertions ###\n\n" + pmsrt
        if len(pm_text):
            self.write_text(pm_text, os.path.join(temp, "pmset.txt"))

    def process_mount_points(self, temp):
        # Builds a list of mounted vols
        # disk#s# - Name - /Volumes/Name
        print("Getting mounted volumes...")
        mounts = self.d.get_mounted_volume_dicts()
        mount_string = "\n".join(sorted([ "{} - {} - {}".format(x["identifier"], x["name"], x["mount_point"]) for x in mounts ]))
        if len(mount_string):
            self.write_text(mount_string, os.path.join(temp, "mount_points.txt"))
                
    def process_disks(self, temp):
        # Pipes the output of diskutil list to a diskutil.txt file in the temp folder
        print("Getting diskutil list...")
        disk = self.r.run({"args" : ["diskutil", "list"]})[0]
        if len(disk):
            self.write_text(disk, os.path.join(temp, "diskutil.txt"))

    def process_nvram(self, temp):
        # Pipes the output of nvram to a nvram.plist file in the temp folder
        print("Getting nvram...")
        nvram = self.r.run({"args" : ["nvram", "-x", "-p"]})[0]
        if len(nvram):
            self.write_text(nvram, os.path.join(temp, "nvram.plist"))

    def process_bdmesg(self, temp):
        # Pipes the output of bdmesg to a bdmesg.txt file in the temp folder
        print("Getting bdmesg...")
        bd = bdmesg.bdmesg()
        if len(bd):
            self.write_text(bd, os.path.join(temp, "bdmesg.txt"))

    def process_ioreg(self, temp):
        print("Getting ioreg...")
        folder = os.path.join(temp, "IORegistry")
        os.mkdir(folder)
        for plane in ["IOService","CoreCapture","IO80211Plane","IOACPIPlane","IODeviceTree","IOPower","IOUSB"]:
            # Pipes the output of ioreg to a ioreg.txt file in the temp folder
            ioreg = self.r.run({"args" : ["ioreg","-l","-p",plane,"-w0"]})[0]
            if len(ioreg):
                if self.h_serial:
                    ioreg = ioreg.replace(self.serial, "0"*len(self.serial))
                    ioreg = ioreg.replace(self.smuuid, "-".join([ "0"*len(x) for x in self.smuuid.split("-") ]))
                self.write_text(ioreg, os.path.join(folder, plane+".txt"))

    def process_cache(self, temp):
        print("Rebuilding the kextcache (may take some time)...")
        # Rebuilds the cache and dumps the output
        cache = self.c.rebuild(False)
        if len(cache[1]):
            # Let's dump the raw kextcache here
            self.write_text(cache[1], os.path.join(temp, "kextcache_raw.txt"))
            # Touch it up a bit
            new_cache = []
            for line in cache[1].split("\n"):
                # Check for URL = "somekext.kext/
                if not ('URL = "' in line and "file://" in line):
                    continue
                try:
                    loc  = line.split("file://")[1].split('"')[0]
                except:
                    loc  = ""
                try:
                    kext = line.split('URL = "')[1].split("/")[0]
                except:
                    kext = ""
                k = "{}{}".format(loc, kext)
                if len(k) and not k in new_cache:
                    new_cache.append("{}{}".format(loc, kext))
            if len(new_cache):
                self.write_text("\n".join(new_cache), os.path.join(temp, "kextcache.txt"))

    def process_kextstat(self, temp):
        print("Getting kextstat...")
        # Dumps the kextstat output
        kextstat = self.r.run({"args" : ["kextstat"]})[0]
        if len(kextstat):
            self.write_text(kextstat, os.path.join(temp, "kextstat.txt"))

    def process_kext_folders(self, temp):
        if os.path.exists("/Library/Extensions/"):
            le = ""
            print("Getting kexts from /Library/Extensions...")
            k_list  = os.listdir("/Library/Extensions/")
            k_list.sort(key=lambda x: (x.lower()))
            for k in k_list:
                if k.startswith("."):
                    continue
                if k.lower().endswith(".kext"):
                    k_ver = self.get_kext_version(os.path.join("/Library/Extensions/", k))
                    le += "{} v{}\n".format(k, k_ver)
            if len(le):
                self.write_text(le, os.path.join(temp, "kext-le.txt"))
        if os.path.exists("/System/Library/Extensions/"):
            sle = ""
            print("Getting kexts from /System/Library/Extensions...")
            k_list  = os.listdir("/System/Library/Extensions/")
            k_list.sort(key=lambda x: (x.lower()))
            for k in k_list:
                if k.startswith("."):
                    continue
                if k.lower().endswith(".kext"):
                    k_ver = self.get_kext_version(os.path.join("/System/Library/Extensions/", k))
                    sle += "{} v{}\n".format(k, k_ver)
            if len(sle):
                self.write_text(sle, os.path.join(temp, "kexts-sle.txt"))

    def get_kext_version(self, path):
        if path.lower().endswith(".plist"):
            plist_path = path
        else:
            plist_path = os.path.join(path, "Contents", "Info.plist")
        if not os.path.exists(plist_path):
            return "Unknown"
        try:
            info_plist = plistlib.readPlist(plist_path)
        except:
            return "Unknown"
        return info_plist.get("CFBundleVersion", "Unknown")
        
    def get_clover_version(self, clover_path):
        # Hex for "Clover revision: "
        vers_hex = "Clover revision: ".encode("utf-8")
        vers_add = len(vers_hex)
        with open(clover_path, "rb") as f:
            s = f.read()
        location = s.find(vers_hex)
        if location == -1:
            return "Not found!"
        location += vers_add
        version = ""
        while True:
            try:
                vnum = s[location].decode("utf-8")
                numtest = int(vnum)
                version += vnum
            except:
                break
            location += 1
        if not len(version):
            return "Not found!"
        return version
        
        print("\n{}".format("#"*70))
        print("Found Clover version {}".format(version).center(70))
        print("{}\n\n".format("#"*70))

if __name__ == '__main__':
    e = Essentials()
    e.main()
