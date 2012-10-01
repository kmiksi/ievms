Overview
========

Microsoft provides virtual machine disk images to facilitate website testing 
in multiple versions of IE, regardless of the host operating system. 
Unfortunately, setting these virtual machines up without Microsoft's VirtualPC
can be extremely difficult. The ievms scripts aim to facilitate that process using
VirtualBox on Linux or OS X. With a single command, you can have IE6, IE7, IE8
and IE9 running in separate virtual machines.

Thanks to Greg "xdissent" Thornton (https://github.com/xdissent) for starting this project.


Requirements
============

* VirtualBox (http://virtualbox.org)
* Axel OR Curl OR Wget
* p7zip-rar OR wine OR unrar (download unrar locally) for rar
* p7zip OR cabextract OR wine for IE6 cab
* mkisofs (Linux) OR hdiutil (OS X) for IE6 drivers
* Patience


Installation
============

1. Install VirtualBox.

2. Download ievms.sh and run:

   * Install IE versions 6, 7, 8 and 9.

         bash ievms.sh

   * Install specific IE versions (IE7 and IE9 only for example):

         IEVMS_VERSIONS="7 9" bash ievms.sh

   * Install on specific location (disk space issues):

         INSTALL_PATH="/media/DiscHasSpace/ievms" bash ievms.sh

3. Launch Virtual Box.

4. Choose ievms image from Virtual Box.

5. Install VirtualBox Guest Additions (pre-mounted as CD image in the VM).

6. **IE6 only** - Install network adapter drivers by opening the ``drivers`` CD image in the VM.

.. note:: The IE6 network drivers *must* be installed upon first boot, or an
   activation loop will prevent subsequent logins forever. If this happens, 
   restoring to the ``clean`` snapshot will reset the activation lock.

The VHD archives are massive and can take hours or tens of minutes to 
download, depending on the speed of your internet connection. You might want
to start the install and then go catch a movie, or maybe dinner, or both. 

Once available and started in VirtualBox, the password for ALL VMs is "Password1".


Recovering from a failed installation
-------------------------------------

Each version is installed into a subdirectory of ``~/.ievms/vhd/``. If the installation fails
for any reason (corrupted download, for instance), delete the version-specific subdirectory
and rerun the install.

If nothing else, you can delete ``~/.ievms`` and rerun the install.


Specifying the install path
---------------------------

To specify where the VMs are installed, use the INSTALL_PATH variable:

    INSTALL_PATH="/Path/to/.ievms" bash ievms.sh


Features
========

Clean Snapshot
    A snapshot is automatically taken upon install, allowing rollback to the
    pristine virtual environment configuration. Anything can go wrong in 
    Windows and rather than having to worry about maintaining a stable VM,
    you can simply revert to the ``clean`` snapshot to reset your VM to the
    initial state.

    The VMs provided by Microsoft will not pass the Windows Genuine Advantage
    and cannot be activated. Unfortunately for us, that means our VMs will
    lock us out after 30 days of unactivated use. By reverting to the 
    ``clean`` snapshot the countdown to the activation apocalypse is reset,
    effectively allowing your VM to work indefinitely.


Support Axel, Wget or Curl
    If you have ``axel`` download accelerator on your system, it will be used!
    Otherwise, the script will look for ``wget`` or ``curl`` commands to perform downloads and resumes.


Resuming Downloads
    If one of the comically large files fails to download, the downloader
    command used will automatically attempt to resume where it left off.
    Thanks to a ``.part`` suffix, the downloads can be easily identifyed and resumed.


License
=======

None. (To quote Morrissey, "take it, it's yours")
