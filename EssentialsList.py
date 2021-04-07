#!/usr/bin/env python
from Scripts import *
import os, sys, tempfile, datetime, shutil, time, plistlib, json

try:
    basestring  # Python 2
    unicode
except NameError:
    basestring = str  # Python 3
    unicode = str

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
        if sys.version_info >= (3,0) and isinstance(text, str):
            text = text.encode("utf-8","ignore")
        with open(filepath, "wb") as f:
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
        boot_manager = bdmesg.get_bootloader_uuid()
        mounts = self.d.get_disks_and_partitions_dict()
        disks = list(mounts)
        i = 0
        for d in disks:
            i += 1
            print("{}. {}:".format(i, d))
            parts = mounts[d]["partitions"]
            part_list = []
            for p in parts:
                p_text = "        - {}".format(p["name"])
                if p["disk_uuid"] == boot_manager:
                    p_text += " *"
                part_list.append(p_text)
            if len(part_list):
                print("\n".join(part_list))
        print(" ")
        print("Q. Quit")
        print(" ")
        print("(* denotes the booted EFI)")
        menu = self.u.grab("Pick the drive containing your EFI:  ")
        if not len(menu):
            return self.get_efi()
        if menu.lower() == "q":
            self.u.custom_quit()
        try: disk = disks[int(menu)-1]
        except: disk = menu
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
            # Auto-get the Boot Manager location
            efi_uuid = bdmesg.get_bootloader_uuid()
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
                efi_path = os.path.join(efi_mount_point, "EFI", "OC")
                if os.path.exists(efi_path):
                    print("Got OC install at {} ({})".format(efi_path, clover_drive))
                    path_list.append({ "disk" : clover_drive, "path" : efi_path })
        # Check for Clover locally
        if os.path.exists("/EFI/CLOVER"):
            print("Got Legacy Clover install at /EFI/CLOVER ({})".format(boot_drive))
            path_list.append({ "disk" : boot_drive, "path" : "/EFI/CLOVER" })
        # Check for OC locally
        if os.path.exists("/EFI/OC"):
            print("Got Legacy OC install at /EFI/OC ({})".format(boot_drive))
            path_list.append({ "disk" : boot_drive, "path" : "/EFI/OC" })
        
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
            self.u.grab("No CLOVER or OC installs found!", timeout=5)
            return

        # print(" ")

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
            c_text = "Found 1 Boot Manager Install" if len(over_text) == 1 else "Found {} Boot Manager Installs".format(len(over_text))
            over += "#{}#\n".format(c_text.center(self.width-2))
            over += "#{}#\n".format(" "*(self.width-2))
            over += "{}\n\n".format("#"*self.width)
            over += "\n\n".join(over_text)

        # Write to file
        self.write_text(over, os.path.join(temp, "- Overview -.txt"))

    def get_stripped_config(self, config_path, hide_serial):
        # First try to load as a plist
        try:
            with open(config_path,"rb") as f:
                plist.load(f)
            opened = "{} Structure - OK!".format(os.path.basename(config_path))
        except Exception as e:
            opened = "{} Structure - BROKEN! ({})".format(os.path.basename(config_path),e)
        with open(config_path,"rb") as f:
                raw_plist = f.read()
        # Ensure is string
        if sys.version_info >= (3, 0) and isinstance(raw_plist,bytes):
            raw_plist = raw_plist.decode("utf-8","ignore")
        # Walk the plist and hide serials if needed
        if hide_serial:
            prime_list = ["<key>{}</key>".format(x) for x in ("mlb","rom","systemserialnumber","systemuuid","serialnumber","boardserialnumber","smuuid","customuuid")]
            raw_plist = raw_plist.replace("\r","")
            primed = False
            plist_data = []
            for line in raw_plist.split("\n"):
                if primed:
                    primed = False
                    try:
                        hidden = line.split(">")[1].split("</")[0]
                        line = line.replace(hidden,"-".join(["0"*len(x) for x in hidden.split("-")]))
                    except:
                        pass
                if any(x in line.lower() for x in prime_list):
                    primed = True
                plist_data.append(line)
            raw_plist = "\n".join(plist_data)
        return (opened,raw_plist)

    def file_exists(self, file_path):
        return os.path.exists(file_path) and not os.path.isdir(file_path)
        
    def process_efi(self, path_list, folder):
        # Iterate through the paths and grab all the Clover-type info
        over_view = []
        for path in path_list:
            disk = path["disk"]
            name = self.d.get_volume_name(disk)
            t    = time.time()
            p    = path["path"]
            is_clover = os.path.exists(os.path.join(p,"CLOVERX64.efi"))
            acpi_path = os.path.join(p,"ACPI","patched") if is_clover else os.path.join(p,"ACPI")
            output_text = []
            print("Getting {} info from {}...".format("Clover" if is_clover else "OC", p))
            output_text.append("{} info from {}:".format("Clover" if is_clover else "OC", p))
            p_folder = os.path.join(folder,"{} - ({} - {})".format(name, disk, "CLOVER" if is_clover else "OC"))
            os.mkdir(p_folder)
            
            b = os.path.join(os.path.normpath(os.path.join(p, os.pardir)), "BOOT", "BOOTX64.efi")
            if is_clover:
                # Check the Clover and Boot versions
                c = os.path.join(p, "CLOVERX64.efi")
                if os.path.exists(c): output_text.append("CLOVERX64.efi - Clover Version "+self.get_clover_version(c))
                else: output_text.append("CLOVERX64.efi - Clover Version Not Found!")
                if os.path.exists(b): output_text.append("BOOTX64.efi   - Clover Version "+self.get_clover_version(b))
                else: output_text.append("BOOTX64.efi   - Clover Version Not Found!")
            # Look for our config.plist
            if self.file_exists(os.path.join(p, "config.plist")):
                config_path = os.path.join(p_folder,"config.plist")
                shutil.copy(os.path.join(p, "config.plist"), config_path)
                status,plist_data = self.get_stripped_config(config_path,self.h_serial)
                output_text.append(status)
                if len(plist_data): self.write_text(plist_data, config_path) # Contents updated, save them
            else:
                output_text.append("config.plist NOT Found!")
            # Let's walk any ACPI directories we need
            if os.path.exists(acpi_path):
                output_text.append(acpi_path[len(p)+1:]) # Strip the header out
                d = os.path.join(p_folder, "ACPI")
                t = time.time()
                acpi_files = [x for x in sorted(os.listdir(acpi_path)) if not x.startswith(".") and not os.path.isdir(os.path.join(acpi_path,x))]
                if not len(acpi_files): output_text.append(" - None")
                else:
                    for x in acpi_files:
                        output_text.append(" - "+x)
                        if not os.path.exists(d):
                            os.mkdir(d)
                        shutil.copy(os.path.join(acpi_path, x), os.path.join(d, x))
            # Walk any efi drivers folders we have and list the contents
            drivers = ["Drivers"] if not is_clover else ["drivers/UEFI","drivers/BIOS","drivers64","drivers32","drivers64UEFI","drivers32UEFI","UEFIDrivers","BiosDrivers"]
            for driver in drivers:
                d_path = os.path.join(p,driver)
                if os.path.exists(d_path) and os.path.isdir(d_path):
                    output_text.append(driver)
                    efi_files = [x for x in sorted(os.listdir(d_path)) if not x.startswith(".") and not os.path.isdir(os.path.join(d_path,x))]
                    for x in efi_files:
                        output_text.append(" - "+x)
            # List all kexts and their versions
            k_dir = os.path.join(p,"Kexts")
            if os.path.exists(k_dir):
                output_text.append("Kexts")
                for path, subdirs, files in os.walk(k_dir):
                    for name in subdirs:
                        if name.startswith(".") or not name.lower().endswith(".kext"): continue
                        output_text.append(" - {} - {}".format(
                            os.path.basename(path)+" -> "+name if os.path.basename(path).startswith(("10.","Other")) else name,
                            self.get_kext_version(os.path.join(path, name))))
            if is_clover:
                # Check for debug, preboot, and origin
                origin_path = os.path.join(p,"ACPI","origin")
                if os.path.exists(origin_path):
                    output_text.append(origin_path[len(p)+1:]) # Strip the header out
                    d = os.path.join(p_folder, "ACPI-origin")
                    t = time.time()
                    acpi_files = [x for x in sorted(os.listdir(origin_path)) if not x.startswith(".") and not os.path.isdir(os.path.join(origin_path,x)) and t - os.path.getmtime(os.path.join(origin_path,x)) <= 3600]
                    if not len(acpi_files): output_text.append(" - None")
                    else:
                        for x in acpi_files:
                            output_text.append(" - "+x)
                            if not os.path.exists(d):
                                os.mkdir(d)
                            shutil.copy(os.path.join(origin_path, x), os.path.join(d, x))
                d_path = os.path.join(p,"misc","debug.log")
                p_path = os.path.join(p,"misc","preboot.log")
                if self.file_exists(d_path):
                    if t - os.path.getmtime(d_path) <= 3600:
                        shutil.copy(d_path, os.path.join(p_folder, "debug.log"))
                        output_text.append("Located debug.log!")
                if self.file_exists(p_path):
                    if t - os.path.getmtime(p_path) <= 3600:
                        shutil.copy(p_path, os.path.join(p_folder, "preboot.log"))
                        output_text.append("Located preboot.log!")
            over_view.append("\n".join(output_text))
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
                # Check for "file:///some/path/somekext.kext/
                if not "file://" in line:
                    continue
                try: k = line.split("file://")[1].split('/"')[0]
                except: continue
                if len(k) and not k in new_cache:
                    new_cache.append(k)
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
            with open(plist_path,"rb") as f:
                info_plist = plist.load(f)
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
                vnum = s[location:location+1].decode("utf-8")
                numtest = int(vnum)
                version += vnum
            except:
                break
            location += 1
        if not len(version):
            return "Not found!"
        return version

if __name__ == '__main__':
    e = Essentials()
    e.main()
