#!/bin/bash -p
#
# Generator script for a dracut initramfs

# Copyright 2005-2013 Red Hat, Inc.  All rights reserved.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#

unset BASH_ENV
unset GZIP

# Verify bash version, current minimum is 4
if ((BASH_VERSINFO[0] < 4)); then
    printf "%s\n" "dracut[F]: dracut requires at least Bash 4." >&2
    exit 1
fi

if [[ -n $POSIXLY_CORRECT ]]; then
    printf "%s\n" "dracut[F]: dracut is not compatible with Bash in POSIX mode." >&2
    exit 1
fi

if [[ $EUID != "0" ]]; then
    printf "%s\n" "dracut[F]: dracut must be run as root." >&2
    exit 1
fi

dracut_args=("$@")
# shellcheck disable=SC2155
readonly dracut_cmd=$(readlink -f "$0")

set -o pipefail

_usage() {
    [[ $dracutbasedir ]] || dracutbasedir=/usr/lib/dracut
    if [[ -f $dracutbasedir/dracut-version.sh ]]; then
        # shellcheck source=./dracut-version.sh
        . "$dracutbasedir"/dracut-version.sh
    fi

    #                                                   80x25 linebreak here ^
    cat << EOF
Usage: $dracut_cmd [OPTION]... [<initramfs> [<kernel-version>]]

Version: $DRACUT_VERSION

Creates initial ramdisk images for preloading modules

  -h, --help  Display all options

If a [LIST] has multiple arguments, then you have to put these in quotes.

For example:

    # dracut --add-drivers "module1 module2"  ...

EOF
}

_long_usage() {
    [[ $dracutbasedir ]] || dracutbasedir=/usr/lib/dracut
    if [[ -f $dracutbasedir/dracut-version.sh ]]; then
        # shellcheck source=./dracut-version.sh
        . "$dracutbasedir"/dracut-version.sh
    fi

    #                                                   80x25 linebreak here ^
    cat << EOF
Usage: $dracut_cmd [OPTION]... [<initramfs> [<kernel-version>]]

Version: $DRACUT_VERSION

Creates initial ramdisk images for preloading modules

  --kver [VERSION]      Set kernel version to [VERSION].
  -f, --force           Overwrite existing initramfs file.
  -a, --add [LIST]      Add a space-separated list of dracut modules.
  --force-add [LIST]    Force to add a space-separated list of dracut modules
                         to the default set of modules, when -H is specified.
  -o, --omit [LIST]     Omit a space-separated list of dracut modules.
  -m, --modules [LIST]  Specify a space-separated list of dracut modules to
                         call when building the initramfs. Modules are located
                         in /usr/lib/dracut/modules.d.
                         This option forces dracut to only include the specified
                         dracut modules.
                         In most cases the --add option is what you want to use.
  --add-drivers [LIST]  Specify a space-separated list of kernel
                         modules to add to the initramfs.
  --force-drivers [LIST]
                        Specify a space-separated list of kernel
                         modules to add to the initramfs and make sure they
                         are tried to be loaded via modprobe same as passing
                         rd.driver.pre=DRIVER kernel parameter.
  --omit-drivers [LIST] Specify a space-separated list of kernel
                         modules not to add to the initramfs.
  -d, --drivers [LIST]  Specify a space-separated list of kernel modules to
                         exclusively include in the initramfs.
  --filesystems [LIST]  Specify a space-separated list of kernel filesystem
                         modules to exclusively include in the generic
                         initramfs.
  -k, --kmoddir [DIR]   Specify the directory where to look for kernel
                         modules.
  --fwdir [DIR]         Specify additional colon-separated list of directories
                         where to look for firmware files.
  --libdirs [LIST]      Specify a space-separated list of directories
                         where to look for libraries.
  --kernel-only         Only install kernel drivers and firmware files.
  --no-kernel           Do not install kernel drivers and firmware files.
  --print-cmdline       Print the kernel command line for the given disk layout.
  --early-microcode     Combine early microcode with ramdisk.
  --no-early-microcode  Do not combine early microcode with ramdisk.
  --kernel-cmdline [PARAMETERS]
                        Specify default kernel command line parameters.
  --strip               Strip binaries in the initramfs.
  --aggressive-strip     Strip more than just debug symbol and sections,
                         for a smaller initramfs build. The --strip option must
                         also be specified.
  --nostrip             Do not strip binaries in the initramfs.
  --hardlink            Hardlink files in the initramfs.
  --nohardlink          Do not hardlink files in the initramfs.
  --prefix [DIR]        Prefix initramfs files with [DIR].
  --noprefix            Do not prefix initramfs files.
  --mdadmconf           Include local /etc/mdadm.conf file.
  --nomdadmconf         Do not include local /etc/mdadm.conf file.
  --lvmconf             Include local /etc/lvm/lvm.conf file.
  --nolvmconf           Do not include local /etc/lvm/lvm.conf file.
  --fscks [LIST]        Add a space-separated list of fsck helpers.
  --nofscks             Inhibit installation of any fsck helpers.
  --ro-mnt              Mount / and /usr read-only by default.
  -h, --help            This message.
  --debug               Output debug information of the build process.
  --profile             Output profile information of the build process.
  -L, --stdlog [0-6]    Specify logging level (to standard error)
                         0 - suppress any messages
                         1 - only fatal errors
                         2 - all errors
                         3 - warnings
                         4 - info
                         5 - debug info (here starts lots of output)
                         6 - trace info (and even more)
  -v, --verbose         Increase verbosity level.
  -q, --quiet           Decrease verbosity level.
  -c, --conf [FILE]     Specify configuration file to use.
                         Default: /etc/dracut.conf
  --confdir [DIR]       Specify configuration directory to use *.conf files
                         from. Default: /etc/dracut.conf.d
  --tmpdir [DIR]        Temporary directory to be used instead of default
                         ${TMPDIR:-/var/tmp}.
  -H, --hostonly        Host-only mode: Install only what is needed for
                         booting the local host instead of a generic host.
  -N, --no-hostonly     Disables host-only mode.
  --hostonly-mode [MODE]
                        Specify the host-only mode to use. [MODE] could be
                         one of "sloppy" or "strict". "sloppy" mode is used
                         by default.
                         In "sloppy" host-only mode, extra drivers and modules
                         will be installed, so minor hardware change won't make
                         the image unbootable (e.g. changed keyboard), and the
                         image is still portable among similar hosts.
                         With "strict" mode enabled, anything not necessary
                         for booting the local host in its current state will
                         not be included, and modules may do some extra job
                         to save more space. Minor change of hardware or
                         environment could make the image unbootable.
                         DO NOT use "strict" mode unless you know what you
                         are doing.
  --hostonly-cmdline    Store kernel command line arguments needed
                         in the initramfs.
  --no-hostonly-cmdline Do not store kernel command line arguments needed
                         in the initramfs.
  --no-hostonly-default-device
                        Do not generate implicit host devices like root,
                         swap, fstab, etc. Use "--mount" or "--add-device"
                         to explicitly add devices as needed.
  --hostonly-i18n       Install only needed keyboard and font files according
                         to the host configuration (default).
  --no-hostonly-i18n    Install all keyboard and font files available.
  --hostonly-nics [LIST]
                        Only enable listed NICs in the initramfs. The list can
                         be empty, so other modules can install only the
                         necessary network drivers.
  --persistent-policy [POLICY]
                        Use [POLICY] to address disks and partitions.
                         POLICY can be any directory name found in /dev/disk
                         (e.g. "by-uuid", "by-label"), or "mapper" to use
                         /dev/mapper device names (default).
  --fstab               Use /etc/fstab to determine the root device.
  --add-fstab [FILE]    Add file to the initramfs fstab.
  --mount "[DEV] [MP] [FSTYPE] [FSOPTS]"
                        Mount device [DEV] on mountpoint [MP] with filesystem
                         [FSTYPE] and options [FSOPTS] in the initramfs.
  --mount "[MP]"        Same as above, but [DEV], [FSTYPE] and [FSOPTS] are
                         determined by looking at the current mounts.
  --add-device "[DEV]"  Bring up [DEV] in initramfs.
  -i, --include [SOURCE] [TARGET]
                        Include the files in the SOURCE directory into the
                         Target directory in the final initramfs.
                        If SOURCE is a file, it will be installed to TARGET
                         in the final initramfs.
  -I, --install [LIST]  Install the space separated list of files into the
                         initramfs.
  --install-optional [LIST]
                        Install the space separated list of files into the
                         initramfs, if they exist.
  --gzip                Compress the generated initramfs using gzip.
                         This will be done by default, unless another
                         compression option or --no-compress is passed.
  --bzip2               Compress the generated initramfs using bzip2.
                         Make sure your kernel has bzip2 decompression support
                         compiled in, otherwise you will not be able to boot.
  --lzma                Compress the generated initramfs using lzma.
                         Make sure your kernel has lzma support compiled in,
                         otherwise you will not be able to boot.
  --xz                  Compress the generated initramfs using xz.
                         Make sure that your kernel has xz support compiled
                         in, otherwise you will not be able to boot.
  --lzo                 Compress the generated initramfs using lzop.
                         Make sure that your kernel has lzo support compiled
                         in, otherwise you will not be able to boot.
  --lz4                 Compress the generated initramfs using lz4.
                         Make sure that your kernel has lz4 support compiled
                         in, otherwise you will not be able to boot.
  --zstd                Compress the generated initramfs using Zstandard.
                         Make sure that your kernel has zstd support compiled
                         in, otherwise you will not be able to boot.
  --compress [COMPRESSION]
                        Compress the generated initramfs with the
                         passed compression program.  Make sure your kernel
                         knows how to decompress the generated initramfs,
                         otherwise you will not be able to boot.
  --no-compress         Do not compress the generated initramfs. This will
                         override any other compression options.
  --squash-compressor [COMPRESSION]
                        Specify the compressor and compressor specific options
                         used by mksquashfs if squash module is called when
                         building the initramfs.
  --list-modules        List all available dracut modules.
  -M, --show-modules    Print included module's name to standard output during
                         build.
  --keep                Keep the temporary initramfs for debugging purposes.
  --printsize           Print out the module install size.
  --sshkey [SSHKEY]     Add SSH key to initramfs (use with ssh-client module)
  --logfile [FILE]      Logfile to use (overrides configuration setting)
  --check-supported     Check to ensure that modules are marked supported when
                         using a kernel that is configured to check the
                         support status of a module before loading.
  --reproducible        Create reproducible images.
  --no-reproducible     Do not create reproducible images.
  --loginstall [DIR]    Log all files installed from the host to [DIR].
  --regenerate-all      Regenerate all initramfs images at the default location
                         for the kernel versions found on the system.
  -p, --parallel        Use parallel processing if possible (currently only
                         supported --regenerate-all)
                         images simultaneously.
  --no-create-sysusers  Create system users on every boot, instead of creating
                         them only when the initramfs is generated.
  --version             Display version.

If [LIST] has multiple arguments, then you have to put these in quotes.

For example:

    # dracut --add-drivers "module1 module2"  ...

EOF
}

_long_version() {
    [[ $dracutbasedir ]] || dracutbasedir=/usr/lib/dracut
    if [[ -f $dracutbasedir/dracut-version.sh ]]; then
        # shellcheck source=./dracut-version.sh
        . "$dracutbasedir"/dracut-version.sh
    fi
    echo "dracut $DRACUT_VERSION"
}

_check_conf_file() {
    if grep -H -e '^[^#]*[+]=\("[^ ]\|.*[^ ]"\)' "$@"; then
        printf '\ndracut[W]: <key>+=" <values> ": <values> should have surrounding white spaces!\n' >&2
        printf 'dracut[W]: This will lead to unwanted side effects! Please fix the configuration file.\n\n' >&2
    fi
}

_dropindirs_sort() {
    local suffix=$1
    shift
    local -a files
    local f d

    for d in "$@"; do
        for i in "$d/"*"$suffix"; do
            if [[ -e $i ]]; then
                printf "%s\n" "${i##*/}"
            fi
        done
    done | sort -Vu | {
        readarray -t files

        for f in "${files[@]}"; do
            for d in "$@"; do
                if [[ -e "$d/$f" ]]; then
                    printf "%s\n" "$d/$f"
                    continue 2
                fi
            done
        done
    }
}

_rearrange_params() {
    # Workaround -i, --include taking 2 arguments
    newat=()
    for i in "$@"; do
        if [[ $i == "-i" ]] || [[ $i == "--include" ]]; then
            newat+=("++include") # Replace --include by ++include
        else
            newat+=("$i")
        fi
    done
    set -- "${newat[@]}" # Set new $@

    TEMP=$(
        unset POSIXLY_CORRECT
        getopt \
            -o "a:m:o:d:I:k:c:r:L:fvqHhMNp" \
            --long kver: \
            --long add: \
            --long force-add: \
            --long add-drivers: \
            --long force-drivers: \
            --long omit-drivers: \
            --long modules: \
            --long omit: \
            --long drivers: \
            --long filesystems: \
            --long install: \
            --long install-optional: \
            --long fwdir: \
            --long libdirs: \
            --long fscks: \
            --long add-fstab: \
            --long mount: \
            --long device: \
            --long add-device: \
            --long nofscks \
            --long ro-mnt \
            --long kmoddir: \
            --long conf: \
            --long confdir: \
            --long tmpdir: \
            --long stdlog: \
            --long compress: \
            --long squash-compressor: \
            --long prefix: \
            --long force \
            --long kernel-only \
            --long no-kernel \
            --long print-cmdline \
            --long kernel-cmdline: \
            --long strip \
            --long aggressive-strip \
            --long nostrip \
            --long hardlink \
            --long nohardlink \
            --long noprefix \
            --long mdadmconf \
            --long nomdadmconf \
            --long lvmconf \
            --long nolvmconf \
            --long debug \
            --long profile \
            --long sshkey: \
            --long logfile: \
            --long verbose \
            --long quiet \
            --long hostonly \
            --long host-only \
            --long no-hostonly \
            --long no-host-only \
            --long hostonly-mode: \
            --long hostonly-cmdline \
            --long no-hostonly-cmdline \
            --long no-hostonly-default-device \
            --long persistent-policy: \
            --long fstab \
            --long help \
            --long bzip2 \
            --long lzma \
            --long xz \
            --long lzo \
            --long lz4 \
            --long zstd \
            --long no-compress \
            --long gzip \
            --long list-modules \
            --long show-modules \
            --long keep \
            --long printsize \
            --long regenerate-all \
            --long parallel \
            --long noimageifnotneeded \
            --long early-microcode \
            --long no-early-microcode \
            --long check-supported \
            --long reproducible \
            --long no-reproducible \
            --long loginstall: \
            --long no-hostonly-i18n \
            --long hostonly-i18n \
            --long hostonly-nics: \
            --long no-machineid \
            --long no-create-sysusers \
            --long version \
            -- "$@"
    )

    # shellcheck disable=SC2181
    if (($? != 0)); then
        _usage
        exit 1
    fi
}

declare -a host_devs
declare -A host_fs_types

# Fills up host_devs stack variable and makes sure there are no duplicates
_push_host_devs() {
    local _dev
    for _dev in "$@"; do
        [[ -z $_dev ]] && continue
        [[ " ${host_devs[*]} " == *" $_dev "* ]] && return
        host_devs+=("$_dev")
    done
}

_get_fs_type() {
    [[ $1 ]] || return
    if [[ -b /dev/block/$1 ]]; then
        ID_FS_TYPE=$(get_fs_env "/dev/block/$1") && host_fs_types["$(readlink -f "/dev/block/$1")"]="$ID_FS_TYPE"
        return 1
    fi
    if [[ -b $1 ]]; then
        ID_FS_TYPE=$(get_fs_env "$1") && host_fs_types["$(readlink -f "$1")"]="$ID_FS_TYPE"
        return 1
    fi
    if fstype=$(find_dev_fstype "$1"); then
        host_fs_types["$1"]="$fstype"
        return 1
    fi
    return 1
}

verbosity_mod_l=0
unset kernel
unset outfile

_rearrange_params "$@"
eval set -- "$TEMP"

while :; do
    if [ "$1" == "--" ]; then
        shift
        break
    fi
    shift
done

# get output file name and kernel version from command line arguments
while (($# > 0)); do
    case ${1%%=*} in
        ++include)
            shift 2
            ;;
        *)
            if ! [[ ${outfile+x} ]]; then
                outfile=$1
            elif ! [[ ${kernel+x} ]]; then
                kernel=$1
            else
                printf "\nUnknown arguments: %s\n\n" "$*" >&2
                _usage
                exit 1
            fi
            ;;
    esac
    shift
done

unset PARMS_TO_STORE
PARMS_TO_STORE=""

eval set -- "$TEMP"

while :; do
    if [[ $1 != "--" ]]; then
        PARMS_TO_STORE+=" $1"
    fi
    case $1 in
        --kver)
            kernel="$2"
            PARMS_TO_STORE+=" '$2'"
            shift
            ;;
        -a | --add)
            add_dracutmodules_l+=("$2")
            PARMS_TO_STORE+=" '$2'"
            shift
            ;;
        --force-add)
            force_add_dracutmodules_l+=("$2")
            PARMS_TO_STORE+=" '$2'"
            shift
            ;;
        --add-drivers)
            add_drivers_l+=("$2")
            PARMS_TO_STORE+=" '$2'"
            shift
            ;;
        --force-drivers)
            force_drivers_l+=("$2")
            PARMS_TO_STORE+=" '$2'"
            shift
            ;;
        --omit-drivers)
            omit_drivers_l+=("$2")
            PARMS_TO_STORE+=" '$2'"
            shift
            ;;
        -m | --modules)
            dracutmodules_l+=("$2")
            PARMS_TO_STORE+=" '$2'"
            shift
            ;;
        -o | --omit)
            omit_dracutmodules_l+=("$2")
            PARMS_TO_STORE+=" '$2'"
            shift
            ;;
        -d | --drivers)
            drivers_l+=("$2")
            PARMS_TO_STORE+=" '$2'"
            shift
            ;;
        --filesystems)
            filesystems_l+=("$2")
            PARMS_TO_STORE+=" '$2'"
            shift
            ;;
        -I | --install)
            install_items_l+=("$2")
            PARMS_TO_STORE+=" '$2'"
            shift
            ;;
        --install-optional)
            install_optional_items_l+=("$2")
            PARMS_TO_STORE+=" '$2'"
            shift
            ;;
        --fwdir)
            fw_dir_l+=("$2")
            PARMS_TO_STORE+=" '$2'"
            shift
            ;;
        --libdirs)
            libdirs_l+=("$2")
            PARMS_TO_STORE+=" '$2'"
            shift
            ;;
        --fscks)
            fscks_l+=("$2")
            PARMS_TO_STORE+=" '$2'"
            shift
            ;;
        --add-fstab)
            add_fstab_l+=("$2")
            PARMS_TO_STORE+=" '$2'"
            shift
            ;;
        --mount)
            fstab_lines+=("$2")
            PARMS_TO_STORE+=" '$2'"
            shift
            ;;
        --add-device | --device)
            add_device_l+=("$2")
            PARMS_TO_STORE+=" '$2'"
            shift
            ;;
        --kernel-cmdline)
            kernel_cmdline_l+=("$2")
            PARMS_TO_STORE+=" '$2'"
            shift
            ;;
        --nofscks) nofscks_l="yes" ;;
        --ro-mnt) ro_mnt_l="yes" ;;
        -k | --kmoddir)
            drivers_dir_l="$2"
            PARMS_TO_STORE+=" '$2'"
            shift
            ;;
        -c | --conf)
            conffile="$2"
            PARMS_TO_STORE+=" '$2'"
            shift
            ;;
        --confdir)
            confdir="$2"
            PARMS_TO_STORE+=" '$2'"
            shift
            ;;
        --tmpdir)
            tmpdir_l="$2"
            PARMS_TO_STORE+=" '$2'"
            shift
            ;;
        -L | --stdlog)
            stdloglvl_l="$2"
            PARMS_TO_STORE+=" '$2'"
            shift
            ;;
        --compress)
            compress_l="$2"
            PARMS_TO_STORE+=" '$2'"
            shift
            ;;
        --squash-compressor)
            squash_compress_l="$2"
            PARMS_TO_STORE+=" '$2'"
            shift
            ;;
        --prefix)
            prefix_l="$2"
            PARMS_TO_STORE+=" '$2'"
            shift
            ;;
        --loginstall)
            loginstall_l="$2"
            PARMS_TO_STORE+=" '$2'"
            shift
            ;;
        -f | --force) force=yes ;;
        --kernel-only)
            kernel_only="yes"
            no_kernel="no"
            ;;
        --no-kernel)
            kernel_only="no"
            no_kernel="yes"
            ;;
        --print-cmdline)
            print_cmdline="yes"
            hostonly_l="yes"
            kernel_only="yes"
            no_kernel="yes"
            ;;
        --early-microcode)
            early_microcode_l="yes"
            ;;
        --no-early-microcode)
            early_microcode_l="no"
            ;;
        --strip) do_strip_l="yes" ;;
        --aggressive-strip) aggressive_strip_l="yes" ;;
        --nostrip) do_strip_l="no" ;;
        --hardlink) do_hardlink_l="yes" ;;
        --nohardlink) do_hardlink_l="no" ;;
        --noprefix) prefix_l="/" ;;
        --mdadmconf) mdadmconf_l="yes" ;;
        --nomdadmconf) mdadmconf_l="no" ;;
        --lvmconf) lvmconf_l="yes" ;;
        --nolvmconf) lvmconf_l="no" ;;
        --debug) debug="yes" ;;
        --profile) profile="yes" ;;
        --sshkey)
            sshkey="$2"
            PARMS_TO_STORE+=" '$2'"
            shift
            ;;
        --logfile)
            logfile_l="$2"
            shift
            ;;
        -v | --verbose) ((verbosity_mod_l++)) ;;
        -q | --quiet) ((verbosity_mod_l--)) ;;
        -H | --hostonly | --host-only)
            hostonly_l="yes"
            ;;
        -N | --no-hostonly | --no-host-only)
            hostonly_l="no"
            ;;
        --hostonly-mode)
            hostonly_mode_l="$2"
            PARMS_TO_STORE+=" '$2'"
            shift
            ;;
        --hostonly-cmdline)
            hostonly_cmdline_l="yes"
            ;;
        --hostonly-i18n)
            i18n_install_all_l="no"
            ;;
        --hostonly-nics)
            hostonly_nics_l+=("$2")
            PARMS_TO_STORE+=" '$2'"
            shift
            ;;
        --no-hostonly-i18n)
            i18n_install_all_l="yes"
            ;;
        --no-hostonly-cmdline)
            hostonly_cmdline_l="no"
            ;;
        --no-hostonly-default-device)
            hostonly_default_device="no"
            ;;
        --persistent-policy)
            persistent_policy_l="$2"
            PARMS_TO_STORE+=" '$2'"
            shift
            ;;
        --fstab) use_fstab_l="yes" ;;
        -h | --help)
            _long_usage
            exit 0
            ;;
        --bzip2) compress_l="bzip2" ;;
        --lzma) compress_l="lzma" ;;
        --xz) compress_l="xz" ;;
        --lzo) compress_l="lzop" ;;
        --lz4) compress_l="lz4" ;;
        --zstd) compress_l="zstd" ;;
        --no-compress) _no_compress_l="cat" ;;
        --gzip) compress_l="gzip" ;;
        --list-modules) do_list="yes" ;;
        -M | --show-modules)
            show_modules_l="yes"
            ;;
        --keep) keep="yes" ;;
        --printsize) printsize="yes" ;;
        --regenerate-all) regenerate_all_l="yes" ;;
        -p | --parallel) parallel_l="yes" ;;
        --noimageifnotneeded) noimageifnotneeded="yes" ;;
        --check-supported) check_supported="yes" ;;
        --reproducible) reproducible_l="yes" ;;
        --no-reproducible) reproducible_l="no" ;;
        --no-machineid)
            machine_id_l="no"
            ;;
        --no-create-sysusers)
            create_sysusers_l="no"
            ;;
        --version)
            _long_version
            exit 0
            ;;
        --)
            shift
            break
            ;;

        *) # should not even reach this point
            printf "\n!Unknown option: '%s'\n\n" "$1" >&2
            _usage
            exit 1
            ;;
    esac
    shift
done

# getopt cannot handle multiple arguments, so just handle "-I,--include"
# the old fashioned way

while (($# > 0)); do
    if [ "${1%%=*}" == "++include" ]; then
        include_src+=("$2")
        include_target+=("$3")
        PARMS_TO_STORE+=" --include '$2' '$3'"
        shift 2
    fi
    shift
done

export LC_ALL=C
export LANG=C
unset LC_MESSAGES
unset LC_CTYPE
unset LD_LIBRARY_PATH
unset LD_PRELOAD
unset GREP_OPTIONS

export DRACUT_LOG_LEVEL=warning
[[ $debug ]] && {
    export DRACUT_LOG_LEVEL=debug
    export PS4='${BASH_SOURCE}@${LINENO}(${FUNCNAME[0]-}): '
    set -x
}

[[ $profile ]] && {
    export PS4='+ $(date "+%s.%N") ${BASH_SOURCE}@${LINENO}: '
    set -x
    debug=yes
}

[[ $dracutbasedir ]] || dracutbasedir=/usr/lib/dracut

# if we were not passed a config file, try the default one
if [[ -z $conffile ]]; then
    conffile="/etc/dracut.conf"
elif [[ ! -e $conffile ]]; then
    printf "%s\n" "dracut[F]: Configuration file '$conffile' not found." >&2
    exit 1
fi

if [[ -z $confdir ]]; then
    confdir="/etc/dracut.conf.d"
elif [[ ! -d $confdir ]]; then
    printf "%s\n" "dracut[F]: Configuration directory '$confdir' not found." >&2
    exit 1
fi

# source our config file
if [[ -f $conffile ]]; then
    _check_conf_file "$conffile"
    # shellcheck disable=SC1090
    . "$conffile"
fi

# source our config dir
for f in $(_dropindirs_sort ".conf" "$confdir" "$dracutbasedir/dracut.conf.d"); do
    _check_conf_file "$f"
    # shellcheck disable=SC1090
    [[ -e $f ]] && . "$f"
done

# check if automatic guessing of the output file is disabled.
if [[ $force_output_file == "yes" && -z $outfile ]]; then
    printf "%s\n" "dracut[F]: dracut is configured with force_output_file=yes" >&2
    printf "%s\n" "dracut[F]: so it is required to specify the file path of the generated initramfs image." >&2
    exit 1
fi

# regenerate_all shouldn't be set in conf files
regenerate_all=$regenerate_all_l
if [[ $parallel_l == "yes" ]]; then
    parallel=yes
fi

if [[ $regenerate_all == "yes" ]]; then
    ret=0
    if [[ $kernel ]]; then
        printf "%s\n" "dracut[F]: --regenerate-all cannot be called with a kernel version." >&2
        exit 1
    fi

    if [[ $outfile ]]; then
        printf "%s\n" "dracut[F]: --regenerate-all cannot be called with an image file." >&2
        exit 1
    fi

    ((len = ${#dracut_args[@]}))
    for ((i = 0; i < len; i++)); do
        case ${dracut_args[$i]} in
            --regenerate-all | --parallel)
                # shellcheck disable=SC2184
                unset dracut_args["$i"]
                ;;
        esac
    done

    cd /lib/modules || exit 1
    if [[ $parallel != "yes" ]]; then
        for i in *; do
            [[ -f $i/modules.dep ]] || [[ -f $i/modules.dep.bin ]] || continue
            [[ -d $i/kernel ]] || continue
            "$dracut_cmd" --kver="$i" "${dracut_args[@]}"
            ((ret += $?))
        done
    else
        for i in *; do
            [[ -f $i/modules.dep ]] || [[ -f $i/modules.dep.bin ]] || continue
            [[ -d $i/kernel ]] || continue
            "$dracut_cmd" --kver="$i" "${dracut_args[@]}" &
        done
        while true; do
            wait -n
            wst=$?
            if [[ $wst == 127 ]]; then
                break
            else
                ((ret += wst))
            fi
        done
    fi
    exit "$ret"
fi

if ! [[ $kernel ]]; then
    kernel=$(uname -r)
fi

DRACUT_PATH=${DRACUT_PATH:-/sbin /bin /usr/sbin /usr/bin}

for i in $DRACUT_PATH; do
    rl=$i
    if [ -L "$i" ]; then
        rl=$(readlink -f "$i")
    fi
    if [[ $NPATH != *:$rl* ]]; then
        NPATH+=":$rl"
    fi
done
export PATH="${NPATH#:}"
unset NPATH

export SYSTEMCTL=${SYSTEMCTL:-systemctl}

# these options add to the stuff in the config file
((${#add_dracutmodules_l[@]})) && add_dracutmodules+=" ${add_dracutmodules_l[*]} "
((${#omit_dracutmodules_l[@]})) && omit_dracutmodules+=" ${omit_dracutmodules_l[*]} "
((${#force_add_dracutmodules_l[@]})) && force_add_dracutmodules+=" ${force_add_dracutmodules_l[*]} "
((${#fscks_l[@]})) && fscks+=" ${fscks_l[*]} "
((${#add_fstab_l[@]})) && add_fstab+=" ${add_fstab_l[*]} "
((${#install_items_l[@]})) && install_items+=" ${install_items_l[*]} "
((${#install_optional_items_l[@]})) && install_optional_items+=" ${install_optional_items_l[*]} "
((${#hostonly_nics_l[@]})) && hostonly_nics+=" ${hostonly_nics_l[*]} "

# these options override the stuff in the config file
((${#dracutmodules_l[@]})) && dracutmodules="${dracutmodules_l[*]}"
((${#filesystems_l[@]})) && filesystems="${filesystems_l[*]}"
((${#fw_dir_l[@]})) && fw_dir="${fw_dir_l[*]}"
((${#libdirs_l[@]})) && libdirs="${libdirs_l[*]}"

[[ $stdloglvl_l ]] && stdloglvl=$stdloglvl_l
[[ ! $stdloglvl ]] && stdloglvl=4
stdloglvl=$((stdloglvl + verbosity_mod_l))
((stdloglvl > 6)) && stdloglvl=6
((stdloglvl < 0)) && stdloglvl=0

[[ $drivers_dir_l ]] && drivers_dir=$drivers_dir_l
drivers_dir="${drivers_dir%"${drivers_dir##*[!/]}"}"
[[ $do_strip_l ]] && do_strip=$do_strip_l
[[ $do_strip ]] || do_strip=yes
[[ $aggressive_strip_l ]] && aggressive_strip=$aggressive_strip_l
[[ $do_hardlink_l ]] && do_hardlink=$do_hardlink_l
[[ $do_hardlink ]] || do_hardlink=yes
[[ $prefix_l ]] && prefix=$prefix_l
[[ $prefix == "/" ]] && unset prefix
[[ $hostonly_l ]] && hostonly=$hostonly_l
[[ $hostonly_cmdline_l ]] && hostonly_cmdline=$hostonly_cmdline_l
[[ $hostonly_mode_l ]] && hostonly_mode=$hostonly_mode_l
[[ $hostonly == "yes" ]] && ! [[ $hostonly_cmdline ]] && hostonly_cmdline="yes"
# shellcheck disable=SC2034
[[ $i18n_install_all_l ]] && i18n_install_all=$i18n_install_all_l
# shellcheck disable=SC2034
[[ $persistent_policy_l ]] && persistent_policy=$persistent_policy_l
[[ $use_fstab_l ]] && use_fstab=$use_fstab_l
[[ $mdadmconf_l ]] && mdadmconf=$mdadmconf_l
[[ $lvmconf_l ]] && lvmconf=$lvmconf_l
[[ $dracutbasedir ]] || dracutbasedir=/usr/lib/dracut
[[ $fw_dir ]] || {
    fw_path_para=$(< /sys/module/firmware_class/parameters/path)
    fw_dir="${fw_path_para:+$fw_path_para:}/lib/firmware/updates/$kernel:/lib/firmware/updates:/lib/firmware/$kernel:/lib/firmware"
}
[[ $tmpdir_l ]] && tmpdir="$tmpdir_l"
[[ $tmpdir ]] || tmpdir="$TMPDIR"
[[ $tmpdir ]] || tmpdir=/var/tmp
[[ $INITRD_COMPRESS ]] && compress=$INITRD_COMPRESS
[[ $compress_l ]] && compress=$compress_l
[[ $squash_compress_l ]] && squash_compress=$squash_compress_l
[[ $show_modules_l ]] && show_modules=$show_modules_l
[[ $nofscks_l ]] && nofscks="yes"
[[ $ro_mnt_l ]] && ro_mnt="yes"
[[ $early_microcode_l ]] && early_microcode=$early_microcode_l
[[ $early_microcode ]] || early_microcode=yes
[[ $early_microcode_image_dir ]] || early_microcode_image_dir=('/boot')
[[ $early_microcode_image_name ]] \
    || early_microcode_image_name=('intel-uc.img' 'intel-ucode.img' 'amd-uc.img' 'amd-ucode.img' 'early_ucode.cpio' 'microcode.cpio')
[[ $logfile_l ]] && logfile="$logfile_l"
[[ $reproducible_l ]] && reproducible="$reproducible_l"
[[ $loginstall_l ]] && loginstall="$loginstall_l"
[[ $machine_id_l ]] && machine_id="$machine_id_l"
[[ $create_sysusers_l ]] && create_sysusers="$create_sysusers_l"
[[ $create_sysusers ]] || create_sysusers=yes

# eliminate IFS hackery when messing with fw_dir
export DRACUT_FIRMWARE_PATH=${fw_dir// /:}
fw_dir=${fw_dir//:/ }

# check for logfile and try to create one if it doesn't exist
if [[ -n $logfile ]]; then
    if [[ ! -f $logfile ]]; then
        if touch "$logfile"; then
            printf "%s\n" "dracut[W]: touch $logfile failed." >&2
        fi
    fi
fi

# handle compression options.
DRACUT_COMPRESS_BZIP2=${DRACUT_COMPRESS_BZIP2:-bzip2}
DRACUT_COMPRESS_LBZIP2=${DRACUT_COMPRESS_LBZIP2:-lbzip2}
DRACUT_COMPRESS_LZMA=${DRACUT_COMPRESS_LZMA:-lzma}
DRACUT_COMPRESS_XZ=${DRACUT_COMPRESS_XZ:-xz}
DRACUT_COMPRESS_GZIP=${DRACUT_COMPRESS_GZIP:-gzip}
DRACUT_COMPRESS_PIGZ=${DRACUT_COMPRESS_PIGZ:-pigz}
DRACUT_COMPRESS_LZOP=${DRACUT_COMPRESS_LZOP:-lzop}
DRACUT_COMPRESS_ZSTD=${DRACUT_COMPRESS_ZSTD:-zstd}
DRACUT_COMPRESS_LZ4=${DRACUT_COMPRESS_LZ4:-lz4}
DRACUT_COMPRESS_CAT=${DRACUT_COMPRESS_CAT:-cat}

if [[ $_no_compress_l == "$DRACUT_COMPRESS_CAT" ]]; then
    compress="$DRACUT_COMPRESS_CAT"
fi

[[ $hostonly == yes ]] && hostonly="-h"
[[ $hostonly != "-h" ]] && unset hostonly

case $hostonly_mode in
    '')
        [[ $hostonly ]] && hostonly_mode="sloppy"
        ;;
    sloppy | strict)
        if [[ ! $hostonly ]]; then
            unset hostonly_mode
        fi
        ;;
    *)
        printf "%s\n" "dracut[F]: Invalid hostonly mode '$hostonly_mode'." >&2
        exit 1
        ;;
esac

[[ $reproducible == yes ]] && DRACUT_REPRODUCIBLE=1

if [[ -z $DRACUT_KMODDIR_OVERRIDE && -n $drivers_dir ]]; then
    drivers_basename="${drivers_dir##*/}"
    if [[ -n $drivers_basename && $drivers_basename != "$kernel" ]]; then
        printf "%s\n" "dracut[F]: The provided directory where to look for kernel modules ($drivers_basename)" >&2
        printf "%s\n" "dracut[F]: does not match the kernel version set for the initramfs ($kernel)." >&2
        printf "%s\n" "dracut[F]: Set DRACUT_KMODDIR_OVERRIDE=1 to ignore this check." >&2
        exit 1
    fi
    drivers_dirname="${drivers_dir%/*}/"
    if [[ ! $drivers_dirname =~ .*/lib/modules/$ ]]; then
        printf "%s\n" "dracut[F]: drivers_dir path ${drivers_dir_l:+"set via -k/--kmoddir "}must contain \"/lib/modules/\" as a parent of your kernel module directory," >&2
        printf "%s\n" "dracut[F]: or modules may not be placed in the correct location inside the initramfs." >&2
        printf "%s\n" "dracut[F]: was given: ${drivers_dir}" >&2
        printf "%s\n" "dracut[F]: expected: ${drivers_dirname}lib/modules/${kernel}" >&2
        printf "%s\n" "dracut[F]: Please move your modules into the correct directory structure and pass the new location," >&2
        printf "%s\n" "dracut[F]: or set DRACUT_KMODDIR_OVERRIDE=1 to ignore this check." >&2
        exit 1
    fi
fi

# shellcheck disable=SC2155
readonly TMPDIR="$(realpath -e "$tmpdir")"
[ -d "$TMPDIR" ] || {
    printf "%s\n" "dracut[F]: Invalid tmpdir '$tmpdir'." >&2
    exit 1
}

if findmnt --raw -n --target "$tmpdir" --output=options | grep -q noexec; then
    [[ $debug == yes ]] && printf "%s\n" "dracut[D]: Tmpdir '$tmpdir' is mounted with 'noexec'." >&2
    noexec=1
fi

# shellcheck disable=SC2155
readonly DRACUT_TMPDIR="$(mktemp -p "$TMPDIR/" -d -t dracut.XXXXXX)"
[ -d "$DRACUT_TMPDIR" ] || {
    printf "%s\n" "dracut[F]: mktemp -p '$TMPDIR/' -d -t dracut.XXXXXX failed." >&2
    exit 1
}

# Cache file used to optimize get_maj_min()
declare -x -r get_maj_min_cache_file="${DRACUT_TMPDIR}/majmin_cache"
: > "$get_maj_min_cache_file"

# clean up after ourselves no matter how we die.
trap '
    ret=$?;
    [[ $keep ]] && echo "Not removing $DRACUT_TMPDIR." >&2 || { [[ $DRACUT_TMPDIR ]] && rm -rf -- "$DRACUT_TMPDIR"; };
    if [[ ${FSFROZEN} ]]; then
      fsfreeze -u "${FSFROZEN}"
    fi
    exit $ret;
    ' EXIT

# clean up after ourselves no matter how we die.
trap 'exit 1;' SIGINT

readonly initdir="${DRACUT_TMPDIR}/initramfs"
mkdir -p "$initdir"

# shellcheck disable=SC2154
if [[ $early_microcode == yes ]] || { [[ $acpi_override == yes ]] && [[ -d $acpi_table_dir ]]; }; then
    readonly early_cpio_dir="${DRACUT_TMPDIR}/earlycpio"
    mkdir "$early_cpio_dir"
fi

[[ "$noexec" ]] || export DRACUT_RESOLVE_LAZY="1"

if [[ $print_cmdline ]]; then
    stdloglvl=0
    sysloglvl=0
    fileloglvl=0
    kmsgloglvl=0
fi

if [[ -f $dracutbasedir/dracut-version.sh ]]; then
    # shellcheck source=./dracut-version.sh
    . "$dracutbasedir"/dracut-version.sh
fi

if systemd-detect-virt -c &> /dev/null; then
    export DRACUT_NO_MKNOD=1 DRACUT_NO_XATTR=1
    if [[ $hostonly ]]; then
        printf "%s\n" "dracut[W]: Running in hostonly mode in a container!" >&2
    fi
fi

if [[ -f $dracutbasedir/dracut-init.sh ]]; then
    # shellcheck source=./dracut-init.sh
    . "$dracutbasedir"/dracut-init.sh
else
    printf "%s\n" "dracut[F]: Cannot find $dracutbasedir/dracut-init.sh." >&2
    printf "%s\n" "dracut[F]: Are you running from a git checkout?" >&2
    printf "%s\n" "dracut[F]: Try passing -l as an argument to $dracut_cmd" >&2
    exit 1
fi

if ! [[ $outfile ]]; then
    DOLLAR_BOOT="$(get_dollar_boot)"
    [[ $DOLLAR_BOOT ]] && ddebug "\$BOOT set to $DOLLAR_BOOT"

    if [[ $machine_id != "no" ]]; then
        MACHINE_ID="$(get_machine_id "${DOLLAR_BOOT:-no}")"
    fi

    outfile="$(get_default_initramfs_image "$kernel" "${DOLLAR_BOOT:-no}" "${MACHINE_ID:-no}")"
fi

if [[ $persistent_policy == "mapper" ]]; then
    unset persistent_policy
elif [[ -n $persistent_policy && ! -d "/dev/disk/${persistent_policy}" ]]; then
    dwarn "Invalid persistent policy, your system does not have a /dev/disk/${persistent_policy} directory."
    unset persistent_policy
fi

# shellcheck disable=SC2154
if [[ $no_kernel != yes ]] && ! [[ -d $srcmods ]]; then
    dfatal "Cannot find module directory $srcmods"
    dfatal "and --no-kernel was not specified"
    exit 1
fi

if ! [[ $print_cmdline ]]; then
    inst "$DRACUT_TESTBIN"
    if ! $DRACUT_INSTALL ${initdir:+-D "$initdir"} -R "$DRACUT_TESTBIN" &> /dev/null; then
        unset DRACUT_RESOLVE_LAZY
        export DRACUT_RESOLVE_DEPS=1
    fi
    rm -fr -- "${initdir:?}"/*
fi

dracutfunctions=$dracutbasedir/dracut-functions.sh
export dracutfunctions

((${#drivers_l[@]})) && drivers="${drivers_l[*]}"
drivers=${drivers/-/_}

((${#add_drivers_l[@]})) && add_drivers+=" ${add_drivers_l[*]} "
add_drivers=${add_drivers/-/_}

((${#force_drivers_l[@]})) && force_drivers+=" ${force_drivers_l[*]} "
force_drivers=${force_drivers/-/_}

((${#omit_drivers_l[@]})) && omit_drivers+=" ${omit_drivers_l[*]} "
omit_drivers=${omit_drivers/-/_}

((${#kernel_cmdline_l[@]})) && kernel_cmdline+=" ${kernel_cmdline_l[*]} "

omit_drivers_corrected=""
for d in $omit_drivers; do
    [[ " $drivers $add_drivers " == *\ $d\ * ]] && continue
    [[ " $drivers $force_drivers " == *\ $d\ * ]] && continue
    omit_drivers_corrected+="^$d$|"
done
omit_drivers="${omit_drivers_corrected%|}"
unset omit_drivers_corrected

# prepare args for logging
for ((i = 0; i < ${#dracut_args[@]}; i++)); do
    [[ ${dracut_args[$i]} == *\ * ]] \
        && dracut_args[$i]="\"${dracut_args[$i]}\""
    #" keep vim happy
done

dinfo "Executing: $dracut_cmd ${dracut_args[*]}"

[[ $do_list == yes ]] && {
    for mod in "$dracutbasedir"/modules.d/*; do
        [[ -e $mod/module-setup.sh ]] || continue
        printf "%s\n" "${mod##*/??}"
    done
    exit 0
}

# This is kinda legacy -- eventually it should go away.
case $dracutmodules in
    "" | auto) dracutmodules="all" ;;
esac

abs_outfile=$(readlink -f "$outfile") && outfile="$abs_outfile"

# Helper function to set global variables
# _set_global_var <pkg_config> <var> <value[:check_file]> [<value[:check_file]>] ...
_set_global_var() {
    local _pkgconfig="$1"
    local _var="$2"
    [[ -z ${!_var} || ! -d ${!_var} ]] \
        && export "$_var"="$(pkg-config "$_pkgconfig" --variable="$_var" 2> /dev/null)"
    if [[ -z ${!_var} || ! -d ${!_var} ]]; then
        shift 2
        if (($# == 1)); then
            export "$_var"="$1"
        else
            local _val
            for _val in "$@"; do
                _check=${_val##*:}
                _val=${_val%:*}
                [[ -e ${_check} ]] && export "$_var"="$_val"
            done
        fi
    fi
}

# dbus global variables
_set_global_var "dbus" "dbus" "/usr/share/dbus-1"
_set_global_var "dbus" "dbusconfdir" "/etc/dbus-1"
_set_global_var "dbus" "dbusinterfaces" "${dbus}/interfaces"
_set_global_var "dbus" "dbusinterfacesconfdir" "${dbusconfdir}/interfaces"
_set_global_var "dbus" "dbusservices" "${dbus}/services"
_set_global_var "dbus" "dbusservicesconfdir" "${dbusconfdir}/services"
_set_global_var "dbus" "dbussession" "${dbus}/session.d"
_set_global_var "dbus" "dbussessionconfdir" "${dbusconfdir}/session.d"
_set_global_var "dbus" "dbussystem" "${dbus}/system.d"
_set_global_var "dbus" "dbussystemconfdir" "${dbusconfdir}/system.d"
_set_global_var "dbus" "dbussystemservices" "${dbus}/system-services"
_set_global_var "dbus" "dbussystemservicesconfdir" "${dbusconfdir}/system-services"

# udev global variables
_set_global_var "udev" "udevdir" "/lib/udev:/lib/udev/ata_id" "/usr/lib/udev:/usr/lib/udev/ata_id"
_set_global_var "udev" "udevconfdir" "/etc/udev"
_set_global_var "udev" "udevrulesdir" "${udevdir}/rules.d"
_set_global_var "udev" "udevrulesconfdir" "${udevconfdir}/rules.d"

# systemd global variables
_set_global_var "systemd" "systemdutildir" "/lib/systemd:/lib/systemd/systemd-udevd" "/usr/lib/systemd:/usr/lib/systemd/systemd-udevd"
_set_global_var "systemd" "systemdutilconfdir" "/etc/systemd"
_set_global_var "systemd" "environment" "/usr/lib/environment.d"
_set_global_var "systemd" "environmentconfdir" "/etc/environment.d"
_set_global_var "systemd" "modulesload" "/usr/lib/modules-load.d"
_set_global_var "systemd" "modulesloadconfdir" "/etc/modules-load.d"
_set_global_var "systemd" "sysctld" "/usr/lib/sysctl.d"
_set_global_var "systemd" "sysctlconfdir" "/etc/sysctl.d"
_set_global_var "systemd" "systemdcatalog" "${systemdutildir}/catalog"
_set_global_var "systemd" "systemdnetwork" "${systemdutildir}/network"
_set_global_var "systemd" "systemdnetworkconfdir" "${systemdutilconfdir}/network"
_set_global_var "systemd" "systemdntpunits" "${systemdutildir}/ntp-units.d"
_set_global_var "systemd" "systemdntpunitsconfdir" "${systemdutilconfdir}/ntp-units.d"
_set_global_var "systemd" "systemdportable" "${systemdutildir}/portable"
_set_global_var "systemd" "systemdportableconfdir" "${systemdutilconfdir}/portable"
_set_global_var "systemd" "systemdsystemunitdir" "${systemdutildir}/system"
_set_global_var "systemd" "systemdsystemconfdir" "${systemdutilconfdir}/system"
_set_global_var "systemd" "systemduser" "${systemdutildir}/user"
_set_global_var "systemd" "systemduserconfdir" "${systemdutilconfdir}/user"
_set_global_var "systemd" "sysusers" "/usr/lib/sysusers.d"
_set_global_var "systemd" "sysusersconfdir" "/etc/sysusers.d"
_set_global_var "systemd" "tmpfilesdir" "/lib/tmpfiles.d" "/usr/lib/tmpfiles.d"
_set_global_var "systemd" "tmpfilesconfdir" "/etc/tmpfiles.d"

# libkmod global variables
_set_global_var "libkmod" "depmodd" "/usr/lib/depmod.d"
_set_global_var "libkmod" "depmodconfdir" "/etc/depmod.d"

if [[ $no_kernel != yes ]] && [[ -d $srcmods ]]; then
    if ! [[ -f $srcmods/modules.dep ]]; then
        if [[ -n "$(find "$srcmods" -name '*.ko*')" ]]; then
            dfatal "$srcmods/modules.dep is missing. Did you run depmod?"
            exit 1
        else
            dwarn "$srcmods/modules.dep is missing. Did you run depmod?"
        fi
    fi
fi

if [[ ! $print_cmdline ]]; then
    if [[ -f $outfile && ! $force ]]; then
        dfatal "Will not override existing initramfs ($outfile) without --force"
        exit 1
    fi

    outdir=${outfile%/*}
    [[ $outdir ]] || outdir="/"

    if [[ ! -d $outdir ]]; then
        dfatal "Can't write to $outdir: Directory $outdir does not exist or is not accessible."
        exit 1
    elif [[ ! -w $outdir ]]; then
        dfatal "No permission to write to $outdir."
        exit 1
    elif [[ -f $outfile && ! -w $outfile ]]; then
        dfatal "No permission to write $outfile."
        exit 1
    fi

    if [[ $loginstall ]]; then
        if ! mkdir -p "$loginstall"; then
            dfatal "Could not create directory to log installed files to '$loginstall'."
            exit 1
        fi
        loginstall=$(readlink -f "$loginstall")
    fi
fi

if [[ $acpi_override == yes ]] && ! (check_kernel_config CONFIG_ACPI_TABLE_UPGRADE || check_kernel_config CONFIG_ACPI_INITRD_TABLE_OVERRIDE); then
    dwarn "Disabling ACPI override, because kernel does not support it. CONFIG_ACPI_INITRD_TABLE_OVERRIDE!=y or CONFIG_ACPI_TABLE_UPGRADE!=y"
    unset acpi_override
fi

if [[ $early_microcode == yes ]]; then
    if [[ $hostonly ]]; then
        CPU_VENDOR=$(get_cpu_vendor)
        if [[ $CPU_VENDOR == "AMD" || $CPU_VENDOR == "Intel" ]]; then
            check_kernel_config CONFIG_MICROCODE || unset early_microcode
        else
            unset early_microcode
        fi
    else
        ! check_kernel_config CONFIG_MICROCODE \
            && unset early_microcode
    fi
    # Do not complain on non-x86 architectures as it makes no sense
    case "${DRACUT_ARCH:-$(uname -m)}" in
        x86_64 | i?86)
            [[ $early_microcode != yes ]] \
                && dwarn "Disabling early microcode, because kernel does not support it. CONFIG_MICROCODE!=y"
            ;;
        *) ;;
    esac
fi

# Need to be able to have non-root users read stuff (rpcbind etc)
chmod 755 "$initdir"

if [[ $hostonly ]]; then
    for i in /sys /proc /run /dev; do
        if ! findmnt --target "$i" &> /dev/null; then
            dwarning "Turning off host-only mode: '$i' is not mounted!"
            unset hostonly
        fi
    done
fi

for line in "${fstab_lines[@]}"; do
    # shellcheck disable=SC2086
    set -- $line
    dev="$1"
    #dev mp fs fsopts
    case "$dev" in
        UUID=*)
            dev=$(blkid -l -t "UUID=${dev#UUID=}" -o device)
            ;;
        LABEL=*)
            dev=$(blkid -l -t "LABEL=${dev#LABEL=}" -o device)
            ;;
        PARTUUID=*)
            dev=$(blkid -l -t "PARTUUID=${dev#PARTUUID=}" -o device)
            ;;
        PARTLABEL=*)
            dev=$(blkid -l -t "PARTLABEL=${dev#PARTLABEL=}" -o device)
            ;;
    esac
    [ -z "$dev" ] && dwarn "Bad fstab entry $*" && continue
    if [[ $3 == btrfs ]]; then
        for mp in $(findmnt --source "$1" -o TARGET -n); do
            for i in $(btrfs_devs "$mp"); do
                _push_host_devs "$i"
            done
        done
    elif [[ $3 == zfs ]]; then
        for mp in $(zfs_devs "$1"); do
            _push_host_devs "$mp"
        done
    fi
    _push_host_devs "$dev"
    host_fs_types["$dev"]="$3"
done

for f in $add_fstab; do
    [[ -e $f ]] || continue
    while read -r dev _ || [ -n "$dev" ]; do
        _push_host_devs "$dev"
    done < "$f"
done

for dev in $add_device; do
    _push_host_devs "$dev"
done

if ((${#add_device_l[@]})); then
    add_device+=" ${add_device_l[*]} "
    _push_host_devs "${add_device_l[@]}"
fi

if [[ $hostonly ]] && [[ $hostonly_default_device != "no" ]]; then
    # in hostonly mode, determine all devices, which have to be accessed
    # and examine them for filesystem types

    for mp in \
        "/" \
        "/etc" \
        "/bin" \
        "/sbin" \
        "/lib" \
        "/lib64" \
        "/usr" \
        "/usr/bin" \
        "/usr/sbin" \
        "/usr/lib" \
        "/usr/lib64" \
        "/boot" \
        "/boot/zipl"; do
        mp=$(readlink -f "$mp")
        mountpoint "$mp" > /dev/null 2>&1 || continue
        _dev=$(find_block_device "$mp") || continue
        _bdev=$(readlink -f "/dev/block/$_dev")
        [[ -b $_bdev ]] && _dev=$_bdev
        [[ $mp == "/" ]] && root_devs+=("$_dev")
        _push_host_devs "$_dev"
        _mp_fstype=$(find_mp_fstype "$mp")
        if [[ $_mp_fstype == btrfs ]]; then
            for i in $(btrfs_devs "$mp"); do
                [[ $mp == "/" ]] && root_devs+=("$i")
                _push_host_devs "$i"
            done
        elif [[ $_mp_fstype == zfs ]]; then
            for i in $(zfs_devs "$(findmnt -n -o SOURCE "$mp")"); do
                [[ $mp == "/" ]] && root_devs+=("$i")
                _push_host_devs "$i"
            done
        fi

    done

    if [[ -f /proc/swaps ]] && [[ -f /etc/fstab ]]; then
        while read -r dev type _ || [ -n "$dev" ]; do
            [[ -b $dev ]] || continue
            [[ $type == "partition" ]] || continue

            while read -r _d _m _t _o _ || [ -n "$_d" ]; do
                [[ $_d == \#* ]] && continue
                [[ $_d ]] || continue
                [[ $_t != "swap" ]] && continue
                [[ $_m != "swap" ]] && [[ $_m != "none" ]] && continue
                [[ $_o == *noauto* ]] && continue
                _d=$(expand_persistent_dev "$_d")
                [[ $_d -ef $dev ]] || continue

                if [[ -f /etc/crypttab ]]; then
                    while read -r _mapper _ _p _o || [ -n "$_mapper" ]; do
                        [[ $_mapper == \#* ]] && continue
                        [[ $_d -ef /dev/mapper/"$_mapper" ]] || continue
                        [[ "$_o" ]] || _o="$_p"
                        # skip entries with password files
                        [[ $_p == /* ]] && [[ -f $_p ]] && continue 2
                        # skip mkswap swap
                        [[ $_o == *swap* ]] && continue 2
                    done < /etc/crypttab
                fi

                _dev="$(readlink -f "$dev")"
                _push_host_devs "$_dev"
                swap_devs+=("$_dev")
                break
            done < /etc/fstab
        done < /proc/swaps
    fi

    # collect all "x-initrd.mount" entries from /etc/fstab
    if [[ -f /etc/fstab ]]; then
        while read -r _d _m _t _o _ || [ -n "$_d" ]; do
            [[ $_d == \#* ]] && continue
            [[ $_d ]] || continue
            [[ $_o != *x-initrd.mount* ]] && continue
            _dev=$(expand_persistent_dev "$_d")
            _dev="$(readlink -f "$_dev")"
            [[ -b $_dev ]] || continue

            _push_host_devs "$_dev"
            if [[ $_t == btrfs ]]; then
                for i in $(btrfs_devs "$_m"); do
                    _push_host_devs "$i"
                done
            elif [[ $_t == zfs ]]; then
                for i in $(zfs_devs "$_d"); do
                    _push_host_devs "$i"
                done
            fi
        done < /etc/fstab
    fi
fi

for dev in "${host_devs[@]}"; do
    _get_fs_type "$dev"
    check_block_and_slaves_all _get_fs_type "$(get_maj_min "$dev")"
done

for dev in "${!host_fs_types[@]}"; do
    [[ ${host_fs_types[$dev]} == "reiserfs" ]] || [[ ${host_fs_types[$dev]} == "xfs" ]] || continue
    rootopts=$(find_dev_fsopts "$dev")
    if [[ ${host_fs_types[$dev]} == "reiserfs" ]]; then
        journaldev=$(fs_get_option "$rootopts" "jdev")
    elif [[ ${host_fs_types[$dev]} == "xfs" ]]; then
        journaldev=$(fs_get_option "$rootopts" "logdev")
    fi
    if [[ $journaldev ]]; then
        dev="$(readlink -f "$dev")"
        _push_host_devs "$dev"
        _get_fs_type "$dev"
        check_block_and_slaves_all _get_fs_type "$(get_maj_min "$dev")"
    fi
done

export initdir dracutbasedir \
    dracutmodules force_add_dracutmodules add_dracutmodules omit_dracutmodules \
    mods_to_load \
    fw_dir drivers_dir debug no_kernel kernel_only \
    omit_drivers mdadmconf lvmconf root_devs \
    use_fstab fstab_lines libdirs fscks nofscks ro_mnt \
    stdloglvl sysloglvl fileloglvl kmsgloglvl logfile \
    host_fs_types host_devs swap_devs sshkey add_fstab \
    DRACUT_VERSION \
    prefix filesystems drivers \
    hostonly_cmdline loginstall check_supported create_sysusers

mods_to_load=""
# check all our modules to see if they should be sourced.
# This builds a list of modules that we will install next.
for_each_module_dir check_module
if ! [[ $hostonly ]] && ((${#host_fs_types[@]})); then
    for_each_module_dir check_mount
fi

dracut_module_included "fips" && export DRACUT_FIPS_MODE=1

_do_print_cmdline() {
    local -A _mods_to_print
    for i in $modules_loaded $mods_to_load; do
        _mods_to_print[$i]=1
    done

    # source our modules.
    for moddir in "$dracutbasedir/modules.d"/[0-9][0-9]*; do
        _d_mod=${moddir##*/}
        _d_mod=${_d_mod#[0-9][0-9]}
        [[ ${_mods_to_print[$_d_mod]} ]] || continue
        module_cmdline "$_d_mod" "$moddir"
    done
    unset moddir
}

if [[ $print_cmdline ]]; then
    _do_print_cmdline
    printf "\n"
    exit 0
fi

# Create some directory structure first
# shellcheck disable=SC2174
[[ $prefix ]] && mkdir -m 0755 -p "${initdir}${prefix}"

# shellcheck disable=SC2174
[[ -L /lib ]] || mkdir -m 0755 -p "${initdir}${prefix}/lib"
[[ $prefix ]] && ln -sfn "${prefix#/}/lib" "$initdir/lib"

if [[ $prefix ]]; then
    for d in bin etc lib sbin tmp usr var $libdirs; do
        d=${d#/}
        [[ $d == */* ]] && continue
        ln -sfn "${prefix#/}/${d#/}" "$initdir/$d"
    done
fi

if [[ $kernel_only != yes ]]; then
    for d in usr usr/bin usr/sbin bin etc lib sbin tmp var var/tmp $libdirs; do
        d=${d#/}
        [[ -e "${initdir}${prefix}/$d" ]] && continue
        if [ -L "/$d" ]; then
            inst_symlink "/$d" "${prefix}/$d"
        else
            # shellcheck disable=SC2174
            mkdir -m 0755 -p "${initdir}${prefix}/$d"
        fi
    done

    for d in dev proc sys sysroot root run; do
        if [ -L "/$d" ]; then
            inst_symlink "/$d"
        else
            # shellcheck disable=SC2174
            mkdir -m 0755 -p "$initdir/$d"
        fi
    done

    ln -sfn ../run "$initdir/var/run"
    ln -sfn ../run/lock "$initdir/var/lock"
else
    for d in lib "$libdirs"; do
        [[ -e "${initdir}${prefix}/$d" ]] && continue
        if [ -h "/$d" ]; then
            inst "/$d" "${prefix}/$d"
        else
            # shellcheck disable=SC2174
            mkdir -m 0755 -p "${initdir}${prefix}/$d"
        fi
    done
fi

mkdir -p "${initdir}"/lib/dracut

if [[ $kernel_only != yes ]]; then
    mkdir -p "${initdir}/etc/cmdline.d"
    mkdir -m 0755 -p "${initdir}"/var/lib/dracut/hooks

    # symlink to old hooks location for compatibility
    ln_r /var/lib/dracut/hooks /lib/dracut/hooks

    # shellcheck disable=SC2154
    for _d in $hookdirs; do
        # shellcheck disable=SC2174
        mkdir -m 0755 -p "${initdir}/lib/dracut/hooks/$_d"
    done
    if ! [[ $DRACUT_NO_MKNOD ]]; then
        [[ -c ${initdir}/dev/null ]] || mknod "${initdir}"/dev/null c 1 3
        [[ -c ${initdir}/dev/kmsg ]] || mknod "${initdir}"/dev/kmsg c 1 11
        [[ -c ${initdir}/dev/console ]] || mknod "${initdir}"/dev/console c 5 1
        [[ -c ${initdir}/dev/random ]] || mknod "${initdir}"/dev/random c 1 8
        [[ -c ${initdir}/dev/urandom ]] || mknod "${initdir}"/dev/urandom c 1 9
    fi
fi

_isize=0 #initramfs size
modules_loaded=" "
# source our modules.
for moddir in "$dracutbasedir/modules.d"/[0-9][0-9]*; do
    _d_mod=${moddir##*/}
    _d_mod=${_d_mod#[0-9][0-9]}
    [[ $mods_to_load == *\ $_d_mod\ * ]] || continue
    if [[ $show_modules == yes ]]; then
        printf "%s\n" "$_d_mod"
    elif [[ $create_sysusers == yes && $_d_mod == "systemd-sysusers" ]]; then
        continue
    else
        dinfo "*** Including module: $_d_mod ***"
    fi
    if [[ $kernel_only == yes ]]; then
        module_installkernel "$_d_mod" "$moddir" || {
            dfatal "installkernel failed in module $_d_mod"
            exit 1
        }
    else
        module_install "$_d_mod" "$moddir"
        if [[ $no_kernel != yes ]]; then
            module_installkernel "$_d_mod" "$moddir" || {
                dfatal "installkernel failed in module $_d_mod"
                exit 1
            }
        fi
    fi
    mods_to_load=${mods_to_load// $_d_mod /}
    modules_loaded+="$_d_mod "

    #print the module install size
    if [ -n "$printsize" ]; then
        _isize_new=$(du -sk "${initdir}" | {
            read -r a _
            echo -n "$a"
        })
        _isize_delta=$((_isize_new - _isize))
        printf "%s\n" "$_d_mod install size: ${_isize_delta}k"
        _isize=$_isize_new
    fi
done
unset moddir

for i in $modules_loaded; do
    printf "%s\n" "$i" >> "$initdir"/lib/dracut/modules.txt
done

dinfo "*** Including modules done ***"

## final stuff that has to happen
if [[ $no_kernel != yes ]]; then
    if [[ $hostonly_mode == "strict" ]]; then
        cp "$DRACUT_KERNEL_MODALIASES" "$initdir"/lib/dracut/hostonly-kernel-modules.txt
    fi

    if [[ $drivers ]]; then
        # shellcheck disable=SC2086
        hostonly='' instmods $drivers
    fi

    if [[ -n ${add_drivers// /} ]]; then
        # shellcheck disable=SC2086
        hostonly='' instmods -c $add_drivers
    fi
    if [[ $force_drivers ]]; then
        # shellcheck disable=SC2086
        hostonly='' instmods -c $force_drivers
        rm -f "$initdir"/etc/cmdline.d/20-force_driver.conf
        for mod in $force_drivers; do
            echo "rd.driver.pre=$mod" >> "$initdir"/etc/cmdline.d/20-force_drivers.conf
        done
    fi
    if [[ $filesystems ]]; then
        # shellcheck disable=SC2086
        hostonly='' instmods -c $filesystems
    fi

    dinfo "*** Installing kernel module dependencies ***"
    dracut_kernel_post
    dinfo "*** Installing kernel module dependencies done ***"

    if [[ $noimageifnotneeded == yes ]] && [[ $hostonly ]]; then
        if [[ ! -f "$initdir/lib/dracut/need-initqueue" ]] \
            && [[ -f ${initdir}/lib/modules/$kernel/modules.dep && ! -s ${initdir}/lib/modules/$kernel/modules.dep ]]; then
            for i in "${initdir}"/etc/cmdline.d/*.conf; do
                # We need no initramfs image and do not generate one.
                [[ $i == "${initdir}/etc/cmdline.d/*.conf" ]] && exit 0
            done
        fi
    fi
fi

if [[ $kernel_only != yes ]]; then
    # FIXME: handle legacy item split
    # shellcheck disable=SC2068
    ((${#install_items[@]} > 0)) && inst_multiple ${install_items[@]}
    # shellcheck disable=SC2068
    ((${#install_optional_items[@]} > 0)) && inst_multiple -o ${install_optional_items[@]}

    if [[ $kernel_cmdline ]]; then
        printf "%s\n" "$kernel_cmdline" >> "${initdir}/etc/cmdline.d/01-default.conf"
    fi

    for line in "${fstab_lines[@]}"; do
        read -r -a fstab_field <<< "$line"
        if [ -z "${fstab_field[1]}" ]; then
            # Determine device and mount options from current system
            mountpoint -q "${fstab_field[0]}" || derror "${fstab_field[0]} is not a mount point!"
            read -r -a fstab_field < <(findmnt --raw -n --target "${fstab_field[0]}" --output=source,target,fstype,options)
            dinfo "Line for ${fstab_field[1]}: ${fstab_field[*]}"
        else
            # Use default options
            [ -z "${fstab_field[3]}" ] && fstab_field[3]="defaults"
        fi

        # Default options for freq and passno
        [ -z "${fstab_field[4]}" ] && fstab_field[4]="0"
        [ -z "${fstab_field[5]}" ] && fstab_field[5]="2"

        strstr "${fstab_field[2]}" "nfs" && fstab_field[5]="0"
        echo "${fstab_field[@]}" >> "${initdir}/etc/fstab"
    done

    for f in $add_fstab; do
        cat "$f" >> "${initdir}/etc/fstab"
    done

    if [[ $systemdutildir ]]; then
        if [[ -d ${initdir}/$systemdutildir ]]; then
            mkdir -p "${initdir}"/etc/conf.d
            {
                printf "%s\n" "systemdutildir=\"$systemdutildir\""
                printf "%s\n" "systemdsystemunitdir=\"$systemdsystemunitdir\""
                printf "%s\n" "systemdsystemconfdir=\"$systemdsystemconfdir\""
            } > "${initdir}"/etc/conf.d/systemd.conf
        fi
    fi

    if [[ $create_sysusers == yes ]] && type -P systemd-sysusers > /dev/null 2>&1; then
        dinfo "*** Creating system users ***"
        systemd-sysusers --root="$initdir" 2>&1 | dinfo
        dinfo "*** Creating system users done ***"
        [[ "${initdir}${sysusers}" != "${initdir}" ]] && rm -rf "${initdir}${sysusers}"
        [[ "${initdir}${sysusersconfdir}" != "${initdir}" ]] && rm -rf "${initdir}${sysusersconfdir}"
    fi

    if [[ $DRACUT_RESOLVE_LAZY ]] && [[ $DRACUT_INSTALL ]]; then
        dinfo "*** Resolving executable dependencies ***"
        # shellcheck disable=SC2086
        find "$initdir" -type f -perm /0111 -not -path '*.ko*' -print0 \
            | xargs -r -0 $DRACUT_INSTALL ${initdir:+-D "$initdir"} -R ${DRACUT_FIPS_MODE:+-f} --
        # shellcheck disable=SC2181
        if (($? == 0)); then
            dinfo "*** Resolving executable dependencies done ***"
        else
            dfatal "Resolving executable dependencies failed"
            exit 1
        fi
    fi

    # Now we are done with lazy resolving, always install dependencies
    unset DRACUT_RESOLVE_LAZY
    export DRACUT_RESOLVE_DEPS=1
fi

for ((i = 0; i < ${#include_src[@]}; i++)); do
    src="${include_src[$i]}"
    target="${include_target[$i]}"
    if [[ $src && $target ]]; then
        if [[ -f $src ]]; then
            inst "$src" "$target"
        elif [[ -d $src ]]; then
            ddebug "Including directory: $src"
            destdir="${initdir}/${target}"
            mkdir -p "$destdir"
            # check for preexisting symlinks, so we can cope with the
            # symlinks to $prefix
            # Objectname is a file or a directory
            reset_dotglob="$(shopt -p dotglob)"
            shopt -q -s dotglob
            for objectname in "$src"/*; do
                [[ -e $objectname || -L $objectname ]] || continue
                if [[ -d $objectname ]] && [[ ! -L $objectname ]]; then
                    # objectname is a directory, let's compute the final directory name
                    object_destdir=${destdir}/${objectname#"$src"/}
                    if ! [[ -e $object_destdir ]]; then
                        # shellcheck disable=SC2174
                        mkdir -m 0755 -p "$object_destdir"
                        chmod --reference="$objectname" "$object_destdir"
                    fi
                    $DRACUT_CP -t "$object_destdir" "$objectname"/.
                else
                    $DRACUT_CP -t "$destdir" "$objectname"
                fi
            done
            eval "$reset_dotglob"
        elif [[ -e $src ]]; then
            derror "$src is neither a directory nor a regular file"
        else
            derror "$src doesn't exist"
        fi
    fi
done

if [[ $do_hardlink == yes ]] && command -v hardlink > /dev/null; then
    dinfo "*** Hardlinking files ***"
    hardlink "$initdir" 2>&1 | ddebug
    dinfo "*** Hardlinking files done ***"
fi

# strip binaries
if [[ $do_strip == yes ]]; then
    # Prefer strip from elfutils for package size
    declare strip_cmd
    strip_cmd=$(command -v eu-strip)
    [ -z "$strip_cmd" ] && strip_cmd="strip"

    for p in $strip_cmd xargs find; do
        if ! type -P $p > /dev/null; then
            dinfo "Could not find '$p'. Not stripping the initramfs."
            do_strip=no
        fi
    done

    kstrip_args=(-g)
    if [[ $aggressive_strip == yes ]]; then
        # `eu-strip` and `strip` both strips all unneeded parts by default
        strip_args=(-p)
    else
        strip_args=(-g -p)
    fi
fi

# cleanup empty ldconfig_paths directories
for d in $(ldconfig_paths); do
    rmdir -p --ignore-fail-on-non-empty "$initdir/$d" > /dev/null 2>&1
done

if [[ $early_microcode == yes ]]; then
    dinfo "*** Generating early-microcode cpio image ***"
    ucode_dir=(amd-ucode intel-ucode)
    ucode_dest=(AuthenticAMD.bin GenuineIntel.bin)
    _dest_dir="$early_cpio_dir/d/kernel/x86/microcode"
    _dest_idx="0 1"
    mkdir -p "$_dest_dir"
    if [[ $hostonly ]]; then
        case "$CPU_VENDOR" in
            AMD)
                _dest_idx="0"
                ;;
            Intel)
                _dest_idx="1"
                ;;
        esac
    fi
    for idx in $_dest_idx; do
        _fw=${ucode_dir[$idx]}
        for _fwdir in $fw_dir; do
            if [[ -d $_fwdir && -d $_fwdir/$_fw ]]; then
                _src="*"
                dinfo "*** Constructing ${ucode_dest[$idx]} ***"
                if [[ $hostonly ]]; then
                    _src=$(get_ucode_file)
                    [[ $_src ]] || break
                    [[ -r $_fwdir/$_fw/$_src ]] || _src="${_src}.early"
                    [[ -r $_fwdir/$_fw/$_src ]] || break
                fi

                for i in $_fwdir/$_fw/$_src; do
                    [ -e "$i" ] && break
                    break 2
                done
                for i in $_fwdir/$_fw/$_src; do
                    [[ -e $i ]] || continue
                    # skip README{.xz,.zst,...}
                    str_starts "$i" "$_fwdir/$_fw/README" && continue
                    # skip gpg files
                    str_ends "$i" ".asc" && continue
                    cat "$i" >> "$_dest_dir/${ucode_dest[$idx]}"
                done
                create_early_cpio="yes"
            fi
        done
        if [[ ! -e "$_dest_dir/${ucode_dest[$idx]}" ]]; then
            if cd "$early_cpio_dir/d"; then
                for _ucodedir in "${early_microcode_image_dir[@]}"; do
                    for _ucodename in "${early_microcode_image_name[@]}"; do
                        [[ -e "$_ucodedir/$_ucodename" ]] \
                            && cpio --extract --file "$_ucodedir/$_ucodename" --quiet \
                                "kernel/x86/microcode/${ucode_dest[$idx]}"
                        if [[ -e "$_dest_dir/${ucode_dest[$idx]}" ]]; then
                            dinfo "*** Using microcode found in '$_ucodedir/$_ucodename' ***"
                            create_early_cpio="yes"
                            break 2
                        fi
                    done
                done
            fi
        fi
    done
fi

if [[ $acpi_override == yes ]] && [[ -d $acpi_table_dir ]]; then
    dinfo "*** Packaging ACPI tables to override BIOS provided ones ***"
    _dest_dir="$early_cpio_dir/d/kernel/firmware/acpi"
    mkdir -p "$_dest_dir"
    for table in "$acpi_table_dir"/*.aml; do
        dinfo "   Adding ACPI table: $table"
        $DRACUT_CP "$table" "$_dest_dir"
        create_early_cpio="yes"
    done
fi

dinfo "*** Store current command line parameters ***"
if ! (echo "$PARMS_TO_STORE" > "$initdir"/lib/dracut/build-parameter.txt); then
    dfatal "Could not store the current command line parameters"
    exit 1
fi

if [[ $hostonly_cmdline == "yes" ]]; then
    unset _stored_cmdline
    if [[ -d $initdir/etc/cmdline.d ]]; then
        dinfo "Stored kernel commandline:"
        for conf in "$initdir"/etc/cmdline.d/*.conf; do
            [ -e "$conf" ] || continue
            dinfo "$(< "$conf")"
            _stored_cmdline=1
        done
    fi
    if ! [[ $_stored_cmdline ]]; then
        dinfo "No dracut internal kernel commandline stored in the initramfs"
    fi
fi

if [[ $kernel_only != yes ]]; then
    # libpthread workaround: pthread_cancel wants to dlopen libgcc_s.so
    for _dir in $libdirs; do
        for _f in "$_dir/libpthread.so"*; do
            [[ -e $_f ]] || continue
            inst_libdir_file "libgcc_s.so*"
            break 2
        done
    done

    # FIPS workaround for Fedora/RHEL: libcrypto needs libssl when FIPS is enabled
    if [[ $DRACUT_FIPS_MODE ]]; then
        for _dir in $libdirs; do
            for _f in "$_dir/libcrypto.so"*; do
                [[ -e $_f ]] || continue
                inst_libdir_file -o "libssl.so*"
                break 2
            done
        done
    fi
fi

if [[ $kernel_only != yes ]]; then
    # make sure that library links are correct and up to date
    build_ld_cache
fi

if dracut_module_included "squash"; then
    readonly squash_dir="$initdir/squash/root"
    readonly squash_img="$initdir/squash-root.img"
    mkdir -p "$squash_dir"
    dinfo "*** Install squash loader ***"
    DRACUT_SQUASH_POST_INST=1 module_install "squash"
fi

if [[ $do_strip == yes ]] && ! [[ $DRACUT_FIPS_MODE ]]; then
    # stripping files negates (dedup) benefits of using reflink
    dinfo "*** Stripping files ***"
    find "$initdir" -type f \
        -executable -not -path '*/lib/modules/*.ko*' -print0 \
        | xargs -r -0 $strip_cmd "${strip_args[@]}" 2> /dev/null

    # strip kernel modules, but do not touch signed modules
    find "$initdir" -type f -path '*/lib/modules/*.ko' -print0 \
        | while read -r -d $'\0' f || [ -n "$f" ]; do
            SIG=$(tail -c 28 "$f" | tr -d '\000')
            [[ $SIG == '~Module signature appended~' ]] || { printf "%s\000" "$f"; }
        done | xargs -r -0 $strip_cmd "${kstrip_args[@]}"
    dinfo "*** Stripping files done ***"
fi

if dracut_module_included "squash"; then
    dinfo "*** Squashing the files inside the initramfs ***"
    declare squash_compress_arg
    # shellcheck disable=SC2086
    if [[ $squash_compress ]]; then
        if ! mksquashfs /dev/null "$DRACUT_TMPDIR"/.squash-test.img -no-progress -comp $squash_compress &> /dev/null; then
            dwarn "mksquashfs doesn't support compressor '$squash_compress', failing back to default compressor."
        else
            squash_compress_arg="$squash_compress"
        fi
    fi

    # shellcheck disable=SC2086
    if ! mksquashfs "$squash_dir" "$squash_img" \
        -no-xattrs -no-exports -noappend -no-recovery -always-use-fragments \
        -no-progress ${squash_compress_arg:+-comp $squash_compress_arg} 1> /dev/null; then
        dfatal "Failed making squash image"
        exit 1
    fi

    rm -rf "$squash_dir"
    dinfo "*** Squashing the files inside the initramfs done ***"

    # Skip initramfs compress
    compress="cat"
fi

dinfo "*** Creating image file '$outfile' ***"

if [[ $DRACUT_REPRODUCIBLE ]]; then
    find "$initdir" -newer "$dracutbasedir/dracut-functions.sh" -print0 \
        | xargs -r -0 touch -h -m -c -r "$dracutbasedir/dracut-functions.sh"

    if [[ "$(cpio --help)" == *--reproducible* ]]; then
        CPIO_REPRODUCIBLE=1
    else
        dinfo "cpio does not support '--reproducible'. Resulting image will not be reproducible."
    fi
fi

if [[ $create_early_cpio == yes ]]; then
    echo 1 > "$early_cpio_dir/d/early_cpio"

    if [[ $DRACUT_REPRODUCIBLE ]]; then
        find "$early_cpio_dir/d" -newer "$dracutbasedir/dracut-functions.sh" -print0 \
            | xargs -r -0 touch -h -m -c -r "$dracutbasedir/dracut-functions.sh"
    fi

    # The microcode blob is _before_ the initramfs blob, not after
    if ! (
        umask 077
        cd "$early_cpio_dir/d"
        find . -print0 | sort -z \
            | cpio ${CPIO_REPRODUCIBLE:+--reproducible} --null -H newc -o --quiet > "${DRACUT_TMPDIR}/initramfs.img"
    ); then
        dfatal "Creation of $outfile failed"
        exit 1
    fi
fi

if check_kernel_config CONFIG_RD_ZSTD; then
    DRACUT_KERNEL_RD_ZSTD=yes
else
    DRACUT_KERNEL_RD_ZSTD=
fi

if [[ $compress == $DRACUT_COMPRESS_ZSTD* && ! $DRACUT_KERNEL_RD_ZSTD ]]; then
    dwarn "Kernel has no zstd support compiled in."
    compress=
fi

if [[ $compress && $compress != cat ]]; then
    if ! command -v "${compress%% *}" &> /dev/null; then
        derror "Cannot execute compression command '$compress', falling back to default"
        compress=
    fi
fi

if ! [[ $compress ]]; then
    # check all known compressors, if none specified
    for i in $DRACUT_COMPRESS_PIGZ $DRACUT_COMPRESS_GZIP $DRACUT_COMPRESS_LZ4 $DRACUT_COMPRESS_LZOP $DRACUT_COMPRESS_ZSTD $DRACUT_COMPRESS_LZMA $DRACUT_COMPRESS_XZ $DRACUT_COMPRESS_LBZIP2 $DRACUT_COMPRESS_BZIP2 $DRACUT_COMPRESS_CAT; do
        [[ $i != "$DRACUT_COMPRESS_ZSTD" || $DRACUT_KERNEL_RD_ZSTD ]] || continue
        command -v "$i" &> /dev/null || continue
        compress="$i"
        break
    done
    if [[ $compress == cat ]]; then
        dwarn "No compression tool available. Initramfs image is going to be big."
    else
        dinfo "Using auto-determined compression method '$compress'"
    fi
fi

# choose the right arguments for the compressor
case $compress in
    bzip2 | lbzip2)
        if [[ $compress == lbzip2 ]] || command -v "$DRACUT_COMPRESS_LBZIP2" &> /dev/null; then
            compress="$DRACUT_COMPRESS_LBZIP2 -9"
        else
            compress="$DRACUT_COMPRESS_BZIP2 -9"
        fi
        ;;
    lzma)
        compress="$DRACUT_COMPRESS_LZMA -9 -T0"
        ;;
    xz)
        compress="$DRACUT_COMPRESS_XZ --check=crc32 --lzma2=dict=1MiB -T0"
        ;;
    gzip | pigz)
        if [[ $compress == pigz ]] || command -v "$DRACUT_COMPRESS_PIGZ" &> /dev/null; then
            compress="$DRACUT_COMPRESS_PIGZ -9 -n -T -R"
        elif command -v gzip &> /dev/null && $DRACUT_COMPRESS_GZIP --help 2>&1 | grep -q rsyncable; then
            compress="$DRACUT_COMPRESS_GZIP -n -9 --rsyncable"
        else
            compress="$DRACUT_COMPRESS_GZIP -n -9"
        fi
        ;;
    lzo | lzop)
        compress="$DRACUT_COMPRESS_LZOP -9"
        ;;
    lz4)
        compress="$DRACUT_COMPRESS_LZ4 -l -9"
        ;;
    zstd)
        compress="$DRACUT_COMPRESS_ZSTD -15 -q -T0"
        ;;
esac

if ! (
    umask 077
    cd "$initdir"
    find . -print0 | sort -z \
        | cpio ${CPIO_REPRODUCIBLE:+--reproducible} --null -H newc -o --quiet \
        | $compress >> "${DRACUT_TMPDIR}/initramfs.img"
); then
    dfatal "Creation of $outfile failed"
    exit 1
fi

# shellcheck disable=SC2154
if ((maxloglvl >= 5)) && ((verbosity_mod_l >= 0)); then
    lsinitrd "${DRACUT_TMPDIR}/initramfs.img" | ddebug
fi

umask 077

if cp --reflink=auto "${DRACUT_TMPDIR}/initramfs.img" "$outfile"; then
    dinfo "*** Creating initramfs image file '$outfile' done ***"
else
    rm -f -- "$outfile"
    dfatal "Creation of $outfile failed"
    exit 1
fi

# We sync/fsfreeze only if we're operating on a live booted system.
# It's possible for e.g. `kernel` to be installed as an RPM BuildRequires or equivalent,
# and there's no reason to sync, and *definitely* no reason to fsfreeze.
# Another case where this happens is rpm-ostree, which performs its own sync/fsfreeze
# globally.  See e.g. https://github.com/ostreedev/ostree/commit/8642ef5ab3fec3ac8eb8f193054852f83a8bc4d0
if [[ -d /run/systemd/system ]]; then
    if ! sync "$outfile" 2> /dev/null; then
        dinfo "sync operation on newly created initramfs $outfile failed"
        exit 1
    fi

    # use fsfreeze only if we're not writing to /
    if [[ "$(stat -c %m -- "$outfile")" != "/" ]] && freeze_ok_for_fstype "$outfile"; then
        FSFROZEN="$(dirname "$outfile")"
        if ! (fsfreeze -f "${FSFROZEN}" 2> /dev/null && fsfreeze -u "${FSFROZEN}" 2> /dev/null); then
            dwarn "Could not fsfreeze $(dirname "$outfile")"
        fi
        unset FSFROZEN
    fi
fi

exit 0
