#!/usr/bin/env bash
# Automated installation of the Microsoft IE App Compat virtual machines
# ( http://www.microsoft.com/en-us/download/details.aspx?id=11575 )
#
# see more details on https://github.com/kmiksi/ievms

# Caution is a virtue
set -o nounset
set -o errtrace
set -o errexit
set -o pipefail

log() {
    local err=$?
    printf "$*\n"
    return $err
}

warn() {
    log "\nWARNING: $*\n"
}

fail() {
    log "\nERROR: $*\n"
    exit 1
}

has() {
    # hmmm, bether than which and works on MAC...
    hash "$*" 2>&-
}

ievms_home="${INSTALL_PATH:-$HOME/.ievms}"
create_home() {
    mkdir -p "$ievms_home"
    cd "$ievms_home"
}

system=`uname -sm`
check_system() {
    # Check for supported system
    case "$system" in
        Darwin*|Linux*) ;;
        *) fail "Sorry, $system is not supported." ;;
    esac
}

check_virtualbox() {
    log "Checking for VirtualBox"
    #if only lowercase vboxmanage is provided (ose)
    if ! has VBoxManage
    then
        if has vboxmanage
        then
            alias VBoxManage=vboxmanage
        else
            fail "VirtualBox is not installed! (http://virtualbox.org)"
        fi
    fi
}

check_extpack() {
    log "Checking for Oracle VM VirtualBox Extension Pack"
    if ! VBoxManage list extpacks | grep "Oracle VM VirtualBox Extension Pack"
    then
        version=`VBoxManage -v` # 4.1.12_Ubuntur77245
        ext_version="${version/r/-}" # 4.1.12_Ubuntu-77245
        ext_version="${ext_version//[_A-Za-z]/}" # 4.1.12-77245
        short_version="${version/r*/}" # 4.1.12_Ubuntu
        short_version="${short_version/_*/}" # 4.1.12
        archive="Oracle_VM_VirtualBox_Extension_Pack-$ext_version.vbox-extpack"
        url="http://download.virtualbox.org/virtualbox/$short_version/$archive"

        if [[ ! -f "$archive" ]]
        then
            log "Downloading Oracle VM VirtualBox Extension Pack from $url to $ievms_home/$archive"
            if _dw "$url" "$archive"
            then
                log "Downloaded"
            else
                warn "Failed to download $url to $ievms_home/$archive, error code ($?)"
                return $?
            fi
        fi

        log "Installing Oracle VM VirtualBox Extension Pack from $ievms_home/$archive"
        if VBoxManage extpack install "$archive"
        then
            log "Installed"
        else
            warn "Failed to install Oracle VM VirtualBox Extension Pack from $ievms_home/$archive, error code ($?)"
            return $?
        fi
    fi
}

# _dw URL [OUTPUT]
# _dw URL "" [PARTS]
_dw() {
    local url="$1" out="${2:-}" parts="${3:-}"
    if [[ "$parts" ]]
    then
        #if has curl
        #then
        #    curl -L -O "$url{${parts// /,}}"
        #else
            for part in $parts
            do
                _dw "$url$part" ||
                    return $?
            done
        #fi
        return $?
    fi

    [[ "$out" ]] || out="${url##*'/'}"
    if [[ -f "$out" ]]
    then
        log "File '$out' already downloaded in '$PWD'"
        return 0
    fi

    if has axel
    then
        axel -a -n10 "$url" -o "$out".part
    elif has wget
    then
        wget -c "$url" -O "$out".part
    elif has curl
    then
        curl -C - -L "$url" -o "$out".part
    fi
    # axel iterprets break (CTRL+C) as a "pause" and return 0
    if [[ "$?" = "0" ]] && [[ ! -f "$out".part.st ]]
    then
        mv -v "$out".part "$out"
    else
        return 1
    fi
}
# _downloaded URL [PARTS]
_downloaded() {
    if [[ "${2:-}" ]]
    then
        for part in $2
        do
            part="$1$part"
            [[ -f "${part##*'/'}" ]] || return $?
        done
    else
        [[ -f "${1##*'/'}" ]]
    fi
}

# Download and unpack latest version of unrar from rarlab
install_unrar() {
    case "$system" in
        Darwin*)  download_unrar rarosx ;;
        Linux*64) download_unrar rarlinux-x64 ;;
        Linux*)   download_unrar rarlinux ;;
    esac
}
download_unrar() {
    #wrar winrar-x64 rarlinux rarlinux-x64 rarbsd rarosx
    version="$1"
    log "Getting $version from rarlab.com downloads page"

    mkdir -p "$ievms_home/rar"
    _dw "http://www.rarlab.com/download.htm" "$ievms_home/rar/rar.html"
    url=`grep "$version" "$ievms_home/rar/rar.html" | head -1 |
        sed "s/^.*<a href=\"\(\/rar\/$version.*\)\".*$/http:\/\/www.rarlab.com\1/"`
    archive="rar.tgz"

    log "Downloading unrar from $url to $ievms_home/$archive"
    _dw "$url" "$archive" ||
        fail "Failed to download $url to $ievms_home/$archive, error code ($?)"

    tar zxf "$archive" -C "$ievms_home/" --no-same-owner ||
        fail "Failed to extract $ievms_home/$archive to $ievms_home/," \
            "tar command returned error code $?"

    has unrar || fail "Could not find unrar in $ievms_home/rar/"
}

PATH="$PATH:$ievms_home/rar"
check_unpack_rar() {
    log "Checking for rar extractor (IE7 and above)"
    has_7zrar || has unrar || has wine || install_unrar || install_7zrar
}
_unpack_rar() {
    if has unrar
    then
        unrar e "$*"
    elif has_7zrar
    then
        7z x "$*"
    elif has wine
    then
        _wine "$*" -d'E:\\' -s -s1 -s2
    fi
    return $?
}

has_7zrar() {
    has 7z && test -f "$ievms_home/p7zip/bin/Codecs/Rar29.so" \
                -o -f "/usr/lib/p7zip/Codecs/Rar29.so"
}
install_7zrar() {
    case "$system" in
        #TODO: compile for osx and x64??
        Darwin*) return 1 ;;
        Linux*64) return 1 ;; #OK, x86 binary run on Ubuntu 12.04, but...
        Linux*)
            log "Checking for downloaded p7zip at $ievms_home/p7zip"
            if ! has_7zrar
            then
                version="9.20.1"
                file="p7zip_${version}_x86_linux_bin.tar.bz2"
                url="http://sf.net/projects/p7zip/files/p7zip/$version/$file"
                cd "$ievms_home/"
                log "Downloading p7zip from $url to $ievms_home/"
                _dw "$url" "$file" ||
                    warn "Failed to download $url to $ievms_home/, error code ($?)" &&
                    return 2
                log "Extracting p7zip from $file to $ievms_home/"
                tar jxf "$file" -C "$ievms_home/" --no-same-owner ||
                    fail "Failed to extract $file to $ievms_home/," \
                        "tar command returned error code $?" &&
                    return 3
                mv "p7zip_$version" "p7zip"
            fi
            has_7zrar &&
                log "p7zip with rar support available! :D"
            ;;
    esac
}
install_cabextract() {
    case $kernel in
        Darwin) download_cabextract ;;
        Linux) fail "Linux support requires cabextract (sudo apt-get install for Ubuntu/Debian)" ;;
    esac
}
PATH="$PATH:$ievms_home/cabextract/cabextractinstall.pkg/usr/local/bin"
download_cabextract() {
    url="http://rudix.googlecode.com/files/cabextract-1.4-3.pkg"
    archive="cabextract.pkg"

    log "Downloading cabextract from $url to $ievms_home/$archive"
    _dw "$url" "$archive" ||
        fail "Failed to download $url to $ievms_home/$archive using 'curl', error code ($?)"

    mkdir -p "$ievms_home/cabextract"
    xar -xf "$archive" -C "$ievms_home/cabextract" ||
        fail "Failed to extract $ievms_home/$archive to $ievms_home/cabextract," \
            "xar command returned error code $?"

    cd "$ievms_home/cabextract/cabextractinstall.pkg"
    gzcat Payload | cpio -i --quiet
    cd "$ievms_home"
    has cabextract ||
        fail "Could not find cabextract in $ievms_home/cabextract/cabextractinstall.pkg/usr/local/bin"
}
PATH="$ievms_home/p7zip:$PATH"
check_unpack_cab() {
    log "Checking for cab extractor (IE6)"
    has 7z || has cabextract || has wine || install_cabextract || install_7zrar ||
        fail "You need a tool to extract cabinet files, like cabextract or 7z"
}
_unpack_cab() {
    if has 7z
    then
        7z x "$*"
    elif has cabextract
    then
        cabextract "$*"
    elif has wine
    then
        # TODO: can be better?
        log '\nYou must put E:\\ when prompted to extract.' \
            '\nPress [ENTER] to continue and open the gui prompt'
        read -s
        _wine "$*" /Q
    fi
    return $?
}

_wine() {
    export WINEPREFIX="$ievms_home/wine"
    export WINEDEBUG="-all"
    # the easy way :P
    mkdir -p "$WINEPREFIX/dosdevices"
    ln -s "$PWD" "$WINEPREFIX/dosdevices/e:"
    # no need to update prefix:
    [[ -f "/usr/share/wine/wine.inf" ]] &&
        date -r "/usr/share/wine/wine.inf" +"%s" > "$WINEPREFIX/.update-timestamp"
    HOME="$WINEPREFIX" wine "$@" &>/dev/null
    err=$?
    rm -rf "$WINEPREFIX"
    return $err
}

check_ga_iso() {
    log "Checking for the guest additions iso"
    case "$system" in
        Darwin*) ga_iso="/Applications/VirtualBox.app/Contents/MacOS/VBoxGuestAdditions.iso" ;;
        Linux*)
            ga_iso="/usr/share/virtualbox/VBoxGuestAdditions.iso"
            [[ -f "$ga_iso" ]] ||
                ga_iso="/usr/lib/virtualbox/additions/VBoxGuestAdditions.iso"
            ;;
    esac
    # if not found, search in default user place, or download it
    if [[ ! -f "$ga_iso" ]]
    then
        version=`VBoxManage -v`
        short_version="${version/r*/}"
        short_version="${short_version/_*/}"
        ga_iso="$HOME/.VirtualBox/VBoxGuestAdditions_$short_version.iso"
        if [[ ! -f "$ga_iso" ]]
        then
            mkdir -p "$HOME/.VirtualBox"
            url="http://download.virtualbox.org/virtualbox/$short_version/VBoxGuestAdditions_$short_version.iso"
            log "Downloading guest additions iso from $url to $ga_iso"
            if ! _dw "$url" "$ga_iso"
            then
                warn "could not download guest additions iso, skiping"
                ga_iso="none"
            fi
        fi
    fi
}

build_ievm() {
    case "$1" in
        6)
            url="http://download.microsoft.com/download/B/7/2/B72085AE-0F04-4C6F-9182-BF1EE90F5273/Windows_XP_IE6.exe"
            parts=""
            archive="Windows_XP_IE6.exe"
            vhd="Windows XP.vhd"
            vm_type="WindowsXP"
            filetype="cab"
            ;;
        7)
            url="http://download.microsoft.com/download/B/7/2/B72085AE-0F04-4C6F-9182-BF1EE90F5273/Windows_Vista_IE7.part0"
            parts="1.exe 2.rar 3.rar 4.rar 5.rar 6.rar"
            archive="Windows_Vista_IE7.part01.exe"
            vhd="Windows Vista.vhd"
            vm_type="WindowsVista"
            filetype="rar"
            ;;
        8)
            url="http://download.microsoft.com/download/B/7/2/B72085AE-0F04-4C6F-9182-BF1EE90F5273/Windows_7_IE8.part0"
            parts="1.exe 2.rar 3.rar 4.rar"
            archive="Windows_7_IE8.part01.exe"
            vhd="Win7_IE8.vhd"
            vm_type="Windows7"
            filetype="rar"
            ;;
        9)
            url="http://download.microsoft.com/download/B/7/2/B72085AE-0F04-4C6F-9182-BF1EE90F5273/Windows_7_IE9.part0"
            parts="1.exe 2.rar 3.rar 4.rar 5.rar 6.rar 7.rar"
            archive="Windows_7_IE9.part01.exe"
            vhd="Windows 7.vhd"
            vm_type="Windows7"
            filetype="rar"
            ;;
        *)
            fail "Invalid IE version: $1"
            ;;
    esac

    vm="IE$1"
    vhd_path="$ievms_home/vhd/$vm"
    mkdir -p "$vhd_path"
    cd "$vhd_path"
    
    log "Checking for existing VHD at $vhd_path/$vhd"
    if [[ ! -f "$vhd" ]]
    then
        "check_unpack_$filetype"
        cd "$vhd_path"
        log "Checking for downloaded VHD at $vhd_path/$archive"
        if ! _downloaded "$url" "$parts"
        then
            log "Downloading VHD from $url [$parts] to $ievms_home/"
            _dw "$url" "$archive" "$parts" ||
                fail "Failed to download $url [$parts] to $vhd_path/, error code ($?)"
        fi

        log "Extracting VHD from $vhd_path/$archive"
        if "_unpack_$filetype" "$archive"
        then
            rm -f *.vmc
        else
            err=$?
            rm -f *.vhd *.vmc
            fail "Failed to extract $filetype $archive to $vhd_path/$vhd," \
                "unpack command returned error code $err"
        fi

    fi

    log "Checking for existing $vm VM"
    if ! VBoxManage showvminfo "$vm" &>/dev/null
    then
        log "Creating $vm VM"
        #VBoxManage createvm --name "$vm" --ostype "$vm_type" --basefolder "$vhd_path" --register
        VBoxManage createvm --name "$vm" --ostype "$vm_type" --register
        VBoxManage modifyvm "$vm" --snapshotfolder "$vhd_path/Snapshots"
        VBoxManage modifyvm "$vm" --memory 256 --vram 32
        VBoxManage storagectl "$vm" --name "IDE Controller" --add ide --controller PIIX4 --bootable on
        VBoxManage storagectl "$vm" --name "Floppy Controller" --add floppy
        VBoxManage internalcommands sethduuid "$vhd_path/$vhd"
        VBoxManage storageattach "$vm" --storagectl "Floppy Controller" --port 0 --device 0 --type fdd --medium emptydrive
        VBoxManage storageattach "$vm" --storagectl "IDE Controller" --port 0 --device 0 --type hdd --medium "$vhd_path/$vhd"
        VBoxManage storageattach "$vm" --storagectl "IDE Controller" --port 0 --device 1 --type dvddrive --medium "$ga_iso"
        declare -F "build_ievm_ie$1" &>/dev/null && "build_ievm_ie$1"
        log "Taking a initial snapshot"
        VBoxManage snapshot "$vm" take clean --description "The initial VM state"
    fi

}
build_ievm_ie6() {
    log "Setting up $vm VM"

    driver_dir="$ievms_home/drivers/$vm"
    iso="$vhd_path/drivers_$vm.iso"

    if [[ ! -f "$driver_dir/PRO2KXP.exe" ]]
    then
        log "Downloading 82540EM network adapter driver"
        mkdir -p "$driver_dir"
        cd "$driver_dir"
        _dw "http://downloadmirror.intel.com/8659/eng/PRO2KXP.exe"

        if [[ ! -f "autorun.inf" ]]
        then
            echo '[autorun]' > autorun.inf
            echo 'open=PRO2KXP.exe' >> autorun.inf
            echo 'label=82540EM network adapter driver' >> autorun.inf
        fi
        cd "$ievms_home"
    fi

    log "Changing network adapter to 82540EM"
    VBoxManage modifyvm "$vm" --nictype1 "82540EM"

    build_and_attach_drivers
}

build_and_attach_drivers() {
    log "Building drivers ISO for $vm"
    if [[ ! -f "$iso" ]]
    then
        log "Writing drivers ISO"
        if has mkisofs
        then
            mkisofs -o "$iso" "$driver_dir"
        elif has hdiutil
        then
            hdiutil makehybrid "$driver_dir" -o "$iso"
        else
            warn "You need a cli ISO burning tool, like mkisofs or hdiutil.\nSkiping ISO image with drivers."
            return 1
        fi
    fi
    VBoxManage storageattach "$vm" --storagectl "IDE Controller" --port 1 --device 0 --type dvddrive --medium "$iso"
}

check_system
create_home
check_virtualbox
# you need this? TODO: ask for it
check_extpack
check_ga_iso

all_versions="6 7 8 9"
for ver in ${IEVMS_VERSIONS:-$all_versions}
do
    log "\nBuilding IE$ver VM"
    build_ievm $ver
done

log "Done!"
