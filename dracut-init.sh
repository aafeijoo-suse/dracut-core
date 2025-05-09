#!/bin/bash
#
# functions used only by dracut and dracut modules
#
# Copyright 2005-2009 Red Hat, Inc.  All rights reserved.
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
export LC_MESSAGES=C

if ! [[ $DRACUT_NO_XATTR ]]; then
    export DRACUT_CP="cp --reflink=auto --sparse=auto --preserve=mode,timestamps,xattr,links -dfr"
else
    export DRACUT_CP="cp --reflink=auto --sparse=auto --preserve=mode,timestamps,links -dfr"
fi

# is_func <command>
# Check whether $1 is a function.
is_func() {
    [[ "$(type -t "$1")" == "function" ]]
}

if ! [[ $dracutbasedir ]]; then
    dracutbasedir=${BASH_SOURCE[0]%/*}
    [[ $dracutbasedir == dracut-functions* ]] && dracutbasedir="."
    [[ $dracutbasedir ]] || dracutbasedir="."
    dracutbasedir="$(readlink -f $dracutbasedir)"
fi

if ! is_func dinfo > /dev/null 2>&1; then
    # shellcheck source=./dracut-logger.sh
    . "$dracutbasedir/dracut-logger.sh"
    dlog_init
fi

# shellcheck disable=SC2154
if ! [[ $initdir ]]; then
    dfatal "initdir not set"
    exit 1
fi

if ! [[ -d $initdir ]]; then
    mkdir -p "$initdir"
fi

if ! [[ $kernel ]]; then
    kernel=$(uname -r)
    export kernel
fi

# shellcheck disable=SC2154
srcmods="$(realpath -e "$dracutsysrootdir/lib/modules/$kernel")"

# shellcheck disable=SC2154
[[ $drivers_dir ]] && {
    if ! command -v kmod &> /dev/null; then
        exit 1
    fi
    srcmods="$drivers_dir"
}
export srcmods

# export standard hookdirs
[[ $hookdirs ]] || {
    hookdirs="cmdline pre-udev pre-trigger netroot "
    hookdirs+="initqueue initqueue/settled initqueue/online initqueue/finished initqueue/timeout "
    hookdirs+="pre-mount pre-pivot cleanup mount "
    hookdirs+="emergency shutdown-emergency pre-shutdown shutdown "
    export hookdirs
}

DRACUT_LDD=${DRACUT_LDD:-ldd}
DRACUT_TESTBIN=${DRACUT_TESTBIN:-/bin/sh}
DRACUT_LDCONFIG=${DRACUT_LDCONFIG:-ldconfig}

# shellcheck source=./dracut-functions.sh
. "$dracutbasedir"/dracut-functions.sh

# Detect lib paths
if ! [[ $libdirs ]]; then
    if [[ $("$DRACUT_LDD" "$DRACUT_TESTBIN") == */lib64/* ]] &> /dev/null \
        && [[ -d /lib64 ]]; then
        libdirs+=" /lib64"
        [[ -d /usr/lib64 ]] && libdirs+=" /usr/lib64"
    else
        libdirs+=" /lib"
        [[ -d /usr/lib ]] && libdirs+=" /usr/lib"
    fi

    libdirs+=" $(ldconfig_paths)"

    export libdirs
fi

# require_binaries [-s] [-m <module name>] <binary> [<binary>...]
# helper function for check() in module-setup.sh
# to check for required installed binaries
# issues a standardized warning message
# -m <module name> name of dracut module
# -s silent
require_binaries() {
    # shellcheck disable=SC2154
    local _module_name="${moddir##*/}"
    local _silent
    local _msg
    local _ret=0

    if [[ $1 == "-m" ]]; then
        _module_name="$2"
        shift 2
    fi

    if [[ $1 == "-s" ]]; then
        [[ $verbose_check == 1 ]] || _silent=1
        shift 1
    fi

    for cmd in "$@"; do
        if ! find_binary "$cmd" &> /dev/null; then
            _msg="Module '${_module_name#[0-9][0-9]}' will not be installed, because command '$cmd' could not be found!"
            if [[ $_silent == 1 ]]; then
                ddebug "$_msg"
            else
                dinfo "$_msg"
            fi
            ((_ret++))
        fi
    done
    return "$_ret"
}

# require_any_binary [-s] [-m <module name>] <binary> [<binary>...]
# -m <module name> name of dracut module
# -s silent
require_any_binary() {
    local _module_name="${moddir##*/}"
    local _silent
    local _msg
    local _ret=1

    if [[ $1 == "-m" ]]; then
        _module_name="$2"
        shift 2
    fi

    if [[ $1 == "-s" ]]; then
        [[ $verbose_check == 1 ]] || _silent=1
        shift 1
    fi

    for cmd in "$@"; do
        if find_binary "$cmd" &> /dev/null; then
            _ret=0
            break
        fi
    done

    if ((_ret != 0)); then
        _msg="$_module_name: Could not find any command of '$*'!"
        if [[ $_silent == 1 ]]; then
            ddebug "$_msg"
        else
            dinfo "$_msg"
        fi
        return 1
    fi

    return 0
}

# require_kernel_modules [-s] [-m <module name>] <kernel module> [<kernel module>...]
# helper function for check() in module-setup.sh
# to check for required kernel modules
# issues a standardized warning message
# -m <module name> name of dracut module
# -s silent
require_kernel_modules() {
    # shellcheck disable=SC2154
    local _module_name="${moddir##*/}"
    local _silent
    local _msg
    local _ret=0

    # Ignore kernel module requirement for no-kernel build
    [[ $no_kernel == yes ]] && return 0

    if [[ $1 == "-m" ]]; then
        _module_name="$2"
        shift 2
    fi

    if [[ $1 == "-s" ]]; then
        [[ $verbose_check == 1 ]] || _silent=1
        shift 1
    fi

    for mod in "$@"; do
        if ! check_kernel_module "$mod" &> /dev/null; then
            _msg="Module '${_module_name#[0-9][0-9]}' will not be installed, because kernel module '$mod' is not available!"
            if [[ $_silent == 1 ]]; then
                ddebug "$_msg"
            else
                dinfo "$_msg"
            fi
            ((_ret++))
        fi
    done
    return "$_ret"
}

dracut_need_initqueue() {
    : > "$initdir/lib/dracut/need-initqueue"
}

dracut_module_included() {
    # shellcheck disable=SC2154
    [[ " $mods_to_load $modules_loaded " == *\ $*\ * ]]
}

dracut_module_path() {
    local _dir

    # shellcheck disable=SC2231
    for _dir in "${dracutbasedir}"/modules.d/??${1}; do
        echo "$_dir"
        return 0
    done
    return 1
}

if ! [[ $DRACUT_INSTALL ]]; then
    DRACUT_INSTALL=$(find_binary dracut-install)
fi

if ! [[ $DRACUT_INSTALL ]] && [[ -x $dracutbasedir/dracut-install ]]; then
    DRACUT_INSTALL=$dracutbasedir/dracut-install
elif ! [[ $DRACUT_INSTALL ]] && [[ -x $dracutbasedir/src/install/dracut-install ]]; then
    DRACUT_INSTALL=$dracutbasedir/src/install/dracut-install
fi

# Test if dracut-install is a standalone executable with no options.
# E.g. DRACUT_INSTALL may be set externally as:
# DRACUT_INSTALL="valgrind dracut-install"
# or
# DRACUT_INSTALL="dracut-install --debug"
# in which case the string cannot be tested for being executable.
DRINSTALLPARTS=0
for i in $DRACUT_INSTALL; do
    DRINSTALLPARTS=$((DRINSTALLPARTS + 1))
done

if [[ $DRINSTALLPARTS == 1 ]] && ! command -v "$DRACUT_INSTALL" > /dev/null 2>&1; then
    dfatal "dracut-install not found!"
    exit 10
fi

if [[ $hostonly == "-h" ]]; then
    if ! [[ $DRACUT_KERNEL_MODALIASES ]] || ! [[ -f $DRACUT_KERNEL_MODALIASES ]]; then
        export DRACUT_KERNEL_MODALIASES="${DRACUT_TMPDIR}/modaliases"
        $DRACUT_INSTALL ${srcmods:+--kerneldir "$srcmods"} --modalias > "$DRACUT_KERNEL_MODALIASES"
    fi
fi

[[ $DRACUT_RESOLVE_LAZY ]] || export DRACUT_RESOLVE_DEPS=1
inst_dir() {
    local _ret
    [[ -e ${initdir}/"$1" ]] && return 0 # already there
    if $DRACUT_INSTALL ${initdir:+-D "$initdir"} -d "$@"; then
        return 0
    else
        _ret=$?
        derror FAILED: "$DRACUT_INSTALL" ${initdir:+-D "$initdir"} -d "$@"
        return $_ret
    fi
}

inst() {
    local _ret _hostonly_install
    if [[ $1 == "-H" ]]; then
        _hostonly_install="-H"
        shift
    fi
    [[ -e ${initdir}/"${2:-$1}" ]] && return 0 # already there
    if $DRACUT_INSTALL ${dracutsysrootdir:+-r "$dracutsysrootdir"} ${initdir:+-D "$initdir"} ${loginstall:+-L "$loginstall"} ${DRACUT_RESOLVE_DEPS:+-l} ${DRACUT_FIPS_MODE:+-f} ${_hostonly_install:+-H} "$@"; then
        return 0
    else
        _ret=$?
        derror FAILED: "$DRACUT_INSTALL" ${dracutsysrootdir:+-r "$dracutsysrootdir"} ${initdir:+-D "$initdir"} ${loginstall:+-L "$loginstall"} ${DRACUT_RESOLVE_DEPS:+-l} ${DRACUT_FIPS_MODE:+-f} ${_hostonly_install:+-H} "$@"
        return $_ret
    fi
}

inst_simple() {
    local _ret _hostonly_install
    if [[ $1 == "-H" ]]; then
        _hostonly_install="-H"
        shift
    fi
    [[ -e ${initdir}/"${2:-$1}" ]] && return 0 # already there
    [[ -e $1 ]] || return 1                    # no source
    if $DRACUT_INSTALL ${initdir:+-D "$initdir"} ${loginstall:+-L "$loginstall"} ${_hostonly_install:+-H} "$@"; then
        return 0
    else
        _ret=$?
        derror FAILED: "$DRACUT_INSTALL" ${initdir:+-D "$initdir"} ${loginstall:+-L "$loginstall"} ${_hostonly_install:+-H} "$@"
        return $_ret
    fi
}

inst_symlink() {
    local _ret _hostonly_install
    if [[ $1 == "-H" ]]; then
        _hostonly_install="-H"
        shift
    fi
    [[ -e ${initdir}/"${2:-$1}" ]] && return 0 # already there
    [[ -L $1 ]] || return 1
    if $DRACUT_INSTALL ${initdir:+-D "$initdir"} ${loginstall:+-L "$loginstall"} ${DRACUT_RESOLVE_DEPS:+-l} ${DRACUT_FIPS_MODE:+-f} ${_hostonly_install:+-H} "$@"; then
        return 0
    else
        _ret=$?
        derror FAILED: "$DRACUT_INSTALL" ${initdir:+-D "$initdir"} ${loginstall:+-L "$loginstall"} ${DRACUT_RESOLVE_DEPS:+-l} ${DRACUT_FIPS_MODE:+-f} ${_hostonly_install:+-H} "$@"
        return $_ret
    fi
}

inst_multiple() {
    local _ret _hostonly_install
    if [[ $1 == "-H" ]]; then
        _hostonly_install="-H"
        shift
    fi
    if $DRACUT_INSTALL ${initdir:+-D "$initdir"} -a ${loginstall:+-L "$loginstall"} ${DRACUT_RESOLVE_DEPS:+-l} ${DRACUT_FIPS_MODE:+-f} ${_hostonly_install:+-H} "$@"; then
        return 0
    else
        _ret=$?
        derror FAILED: "$DRACUT_INSTALL" ${initdir:+-D "$initdir"} -a ${loginstall:+-L "$loginstall"} ${DRACUT_RESOLVE_DEPS:+-l} ${DRACUT_FIPS_MODE:+-f} ${_hostonly_install:+-H} "$@"
        return $_ret
    fi
}

dracut_install() {
    inst_multiple "$@"
}

dracut_instmods() {
    local _ret _silent=0
    local i
    # shellcheck disable=SC2154
    [[ $no_kernel == yes ]] && return
    for i in "$@"; do
        [[ $i == "--silent" ]] && _silent=1
    done

    if $DRACUT_INSTALL \
        \
        ${kerneldir:+-D "$kerneldir"} ${loginstall:+-L "$loginstall"} ${hostonly:+-H} ${check_supported:+--check-supported} ${omit_drivers:+-N "$omit_drivers"} ${srcmods:+--kerneldir "$srcmods"} -m "$@"; then
        return 0
    else
        _ret=$?
        if ((_silent == 0)); then
            derror FAILED: "$DRACUT_INSTALL" ${kerneldir:+-D "$kerneldir"} ${loginstall:+-L "$loginstall"} ${hostonly:+-H} ${check_supported:+--check-supported} ${omit_drivers:+-N "$omit_drivers"} ${srcmods:+--kerneldir "$srcmods"} -m "$@"
        fi
        return $_ret
    fi
}

inst_binary() {
    local _ret
    if $DRACUT_INSTALL ${initdir:+-D "$initdir"} ${loginstall:+-L "$loginstall"} ${DRACUT_RESOLVE_DEPS:+-l} ${DRACUT_FIPS_MODE:+-f} "$@"; then
        return 0
    else
        _ret=$?
        derror FAILED: "$DRACUT_INSTALL" ${initdir:+-D "$initdir"} ${loginstall:+-L "$loginstall"} ${DRACUT_RESOLVE_DEPS:+-l} ${DRACUT_FIPS_MODE:+-f} "$@"
        return $_ret
    fi
}

inst_script() {
    inst_binary "$@"
}

inst_fsck_help() {
    local _ret _helper="/run/dracut/fsck/fsck_help_$1.txt"
    if $DRACUT_INSTALL ${initdir:+-D "$initdir"} ${loginstall:+-L "$loginstall"} ${DRACUT_RESOLVE_DEPS:+-l} ${DRACUT_FIPS_MODE:+-f} "$2" "$_helper"; then
        return 0
    else
        _ret=$?
        derror "$DRACUT_INSTALL" ${initdir:+-D "$initdir"} ${loginstall:+-L "$loginstall"} ${DRACUT_RESOLVE_DEPS:+-l} ${DRACUT_FIPS_MODE:+-f} "$2" "$_helper"
        return $_ret
    fi
}

# Use with form hostonly="$(optional_hostonly)" inst_xxxx <args>
# If hostonly mode is set to "strict", hostonly restrictions will still
# be applied, else will ignore hostonly mode and try to install all
# given modules.
optional_hostonly() {
    # shellcheck disable=SC2154
    if [[ $hostonly_mode == "strict" ]]; then
        printf -- "%s" "$hostonly"
    else
        printf ""
    fi
}

mark_hostonly() {
    for i in "$@"; do
        echo "$i" >> "$initdir/lib/dracut/hostonly-files"
    done
}

# attempt to install any programs specified in a udev rule
inst_rule_programs() {
    local _prog _bin

    # shellcheck disable=SC2013
    for _prog in $(sed -nr 's/.*PROGRAM==?"([^ "]+).*/\1/p' "$1"); do
        _bin=""
        # shellcheck disable=SC2154
        if [[ -x ${udevdir}/$_prog ]]; then
            _bin="${udevdir}"/$_prog
        elif [[ ${_prog/\$env\{/} == "$_prog" ]]; then
            _bin=$(find_binary "$_prog") || {
                dinfo "Skipping program $_prog using in udev rule ${1##*/} as it cannot be found"
                continue
            }
        fi

        [[ $_bin ]] && inst_binary "$_bin"
    done

    # shellcheck disable=SC2013
    for _prog in $(sed -nr 's/.*RUN[+=]=?"([^ "]+).*/\1/p' "$1"); do
        _bin=""
        if [[ -x ${udevdir}/$_prog ]]; then
            _bin=${udevdir}/$_prog
        elif [[ ${_prog/\$env\{/} == "$_prog" ]] && [[ ${_prog} != "/sbin/initqueue" ]]; then
            _bin=$(find_binary "$_prog") || {
                dinfo "Skipping program $_prog using in udev rule ${1##*/} as it cannot be found"
                continue
            }
        fi

        [[ $_bin ]] && inst_binary "$_bin"
    done

    # shellcheck disable=SC2013
    for _prog in $(sed -nr 's/.*IMPORT\{program\}==?"([^ "]+).*/\1/p' "$1"); do
        _bin=""
        if [[ -x ${udevdir}/$_prog ]]; then
            _bin=${udevdir}/$_prog
        elif [[ ${_prog/\$env\{/} == "$_prog" ]]; then
            _bin=$(find_binary "$_prog") || {
                dinfo "Skipping program $_prog using in udev rule ${1##*/} as it cannot be found"
                continue
            }
        fi

        [[ $_bin ]] && dracut_install "$_bin"
    done
}

# attempt to create any groups and users specified in a udev rule
inst_rule_group_owner() {
    local i

    # shellcheck disable=SC2013
    for i in $(sed -nr 's/.*OWNER=?"([^ "]+).*/\1/p' "$1"); do
        if ! grep -Eq "^$i:" "$initdir/etc/passwd" 2> /dev/null; then
            grep -E "^$i:" /etc/passwd 2> /dev/null >> "$initdir/etc/passwd"
        fi
    done

    # shellcheck disable=SC2013
    for i in $(sed -nr 's/.*GROUP=?"([^ "]+).*/\1/p' "$1"); do
        if ! grep -Eq "^$i:" "$initdir/etc/group" 2> /dev/null; then
            grep -E "^$i:" /etc/group 2> /dev/null >> "$initdir/etc/group"
        fi
    done
}

inst_rule_initqueue() {
    [[ -e "$initdir/lib/dracut/need-initqueue" ]] && return
    if grep -q -F initqueue "$1"; then
        dracut_need_initqueue
    fi
}

# udev rules always get installed in the same place, so
# create a function to install them to make life simpler.
inst_rules() {
    local _target=/etc/udev/rules.d _rule _found

    inst_dir "${udevdir}/rules.d"
    inst_dir "$_target"
    for _rule in "$@"; do
        if [ "${_rule#/}" = "$_rule" ]; then
            for r in "${udevdir}/rules.d" ${hostonly:+/etc/udev/rules.d}; do
                [[ -e $r/$_rule ]] || continue
                _found="$r/$_rule"
                inst_rule_programs "$_found"
                inst_rule_group_owner "$_found"
                inst_rule_initqueue "$_found"
                inst_simple "$_found"
            done
        fi
        for r in '' "$dracutbasedir/rules.d/"; do
            # skip rules without an absolute path
            [[ "${r}$_rule" != /* ]] && continue
            [[ -f ${r}$_rule ]] || continue
            _found="${r}$_rule"
            inst_rule_programs "$_found"
            inst_rule_group_owner "$_found"
            inst_rule_initqueue "$_found"
            inst_simple "$_found" "$_target/${_found##*/}"
        done
        [[ $_found ]] || ddebug "Skipping udev rule: $_rule"
    done
}

# make sure that library links are correct and up to date
build_ld_cache() {
    for f in /etc/ld.so.conf /etc/ld.so.conf.d/*; do
        [[ -f $f ]] && inst_simple "${f}"
    done
    if ! $DRACUT_LDCONFIG -r "$initdir" -f /etc/ld.so.conf; then
        derror "ldconfig exited ungracefully"
    fi
}

prepare_udev_rules() {
    for f in "$@"; do
        f="${initdir}/etc/udev/rules.d/$f"
        [ -e "$f" ] || continue
        while read -r line || [ -n "$line" ]; do
            if [ "${line%%IMPORT PATH_ID}" != "$line" ]; then
                printf '%sIMPORT{builtin}="path_id"\n' "${line%%IMPORT PATH_ID}"
            elif [ "${line%%IMPORT BLKID}" != "$line" ]; then
                printf '%sIMPORT{builtin}="blkid"\n' "${line%%IMPORT BLKID}"
            else
                echo "$line"
            fi
        done < "${f}" > "${f}.new"
        mv "${f}.new" "$f"
    done
}

# install function specialized for hooks
# $1 = type of hook, $2 = hook priority (lower runs first), $3 = hook
# All hooks should be POSIX/SuS compliant, they will be sourced by init.
inst_hook() {
    local hook
    if ! [[ -f $3 ]]; then
        dfatal "Cannot install a hook ($3) that does not exist."
        dfatal "Aborting initrd creation."
        exit 1
    elif ! [[ $hookdirs == *$1* ]]; then
        dfatal "No such hook type $1. Aborting initrd creation."
        exit 1
    fi
    hook="/var/lib/dracut/hooks/${1}/${2}-${3##*/}"
    inst_simple "$3" "$hook"
    chmod u+x "$initdir/$hook"
}

# inst_libdir_dir <dir> [<dir>...]
# Install a <dir> located on a lib directory to the initramfs image
inst_libdir_dir() {
    local -a _dirs
    for _dir in $libdirs; do
        for _i in "$@"; do
            for _d in "$_dir"/$_i; do
                [[ -d $_d ]] && _dirs+=("${_d}")
            done
        done
    done
    for _dir in "${_dirs[@]}"; do
        inst_dir "$_dir"
    done
}

# inst_libdir_file [-n <pattern>] <file> [<file>...]
# Install a <file> located on a lib directory to the initramfs image
# -n <pattern> install matching files
inst_libdir_file() {
    local -a _files
    if [[ $1 == "-n" ]]; then
        local _pattern=$2
        shift 2
        for _dir in $libdirs; do
            for _i in "$@"; do
                for _f in "$_dir"/$_i; do
                    [[ ${_f} =~ $_pattern ]] || continue
                    [[ -e $_f ]] && _files+=("${_f}")
                done
            done
        done
    else
        for _dir in $libdirs; do
            for _i in "$@"; do
                for _f in "$_dir"/$_i; do
                    [[ -e $_f ]] && _files+=("${_f}")
                done
            done
        done
    fi
    [[ ${#_files[@]} -gt 0 ]] && inst_multiple "${_files[@]}"
}

# get a command to decompress the given file
get_decompress_cmd() {
    case "$1" in
        *.gz) echo 'gzip -f -d' ;;
        *.bz2) echo 'bzip2 -d' ;;
        *.xz) echo 'xz -f -d' ;;
        *.zst) echo 'zstd -f -d ' ;;
    esac
}

# install function decompressing the target and handling symlinks
# $@ = list of compressed (gz or bz2) files or symlinks pointing to such files
#
# Function install targets in the same paths inside overlay but decompressed
# and without extensions (.gz, .bz2).
inst_decompress() {
    local _src _cmd

    for _src in "$@"; do
        _cmd=$(get_decompress_cmd "${_src}")
        [[ -z ${_cmd} ]] && return 1
        inst_simple "${_src}"
        # Decompress with chosen tool.  We assume that tool changes name e.g.
        # from 'name.gz' to 'name'.
        ${_cmd} "${initdir}${_src}"
    done
}

# It's similar to above, but if file is not compressed, performs standard
# install.
# $@ = list of files
inst_opt_decompress() {
    local _src

    for _src in "$@"; do
        inst_decompress "${_src}" || inst "${_src}"
    done
}

# module_check <dracut module> [<forced>] [<module path>]
# execute the check() function of module-setup.sh of <dracut module>
# or the "check" script, if module-setup.sh is not found
# "check $hostonly" is called
module_check() {
    local _moddir=$3
    local _ret
    local _forced=0
    local _hostonly=$hostonly
    [[ -z $_moddir ]] && _moddir=$(dracut_module_path "$1")
    [ $# -ge 2 ] && _forced=$2
    [[ -f $_moddir/module-setup.sh ]] || return 1
    unset check depends cmdline install installkernel
    check() { true; }
    # shellcheck disable=SC1090
    . "$_moddir"/module-setup.sh
    is_func check || return 0
    [[ $_forced != 0 ]] && unset hostonly
    # don't quote $hostonly to leave argument empty
    # shellcheck disable=SC2086
    moddir="$_moddir" check $hostonly
    _ret=$?
    unset check depends cmdline install installkernel
    hostonly=$_hostonly
    return $_ret
}

# module_check_mount <dracut module> [<module path>]
# execute the check() function of module-setup.sh of <dracut module>
# or the "check" script, if module-setup.sh is not found
# "mount_needs=1 check 0" is called
module_check_mount() {
    local _moddir=$2
    local _ret
    export mount_needs=1
    [[ -z $_moddir ]] && _moddir=$(dracut_module_path "$1")
    [[ -f $_moddir/module-setup.sh ]] || return 1
    unset check depends cmdline install installkernel
    check() { false; }
    # shellcheck disable=SC1090
    . "$_moddir"/module-setup.sh
    moddir=$_moddir check 0
    _ret=$?
    unset check depends cmdline install installkernel
    unset mount_needs
    return "$_ret"
}

# module_depends <dracut module> [<module path>]
# execute the depends() function of module-setup.sh of <dracut module>
# or the "depends" script, if module-setup.sh is not found
module_depends() {
    local _moddir=$2
    local _ret
    [[ -z $_moddir ]] && _moddir=$(dracut_module_path "$1")
    [[ -f $_moddir/module-setup.sh ]] || return 1
    unset check depends cmdline install installkernel
    depends() { true; }
    # shellcheck disable=SC1090
    . "$_moddir"/module-setup.sh
    moddir=$_moddir depends
    _ret=$?
    unset check depends cmdline install installkernel
    return $_ret
}

# module_cmdline <dracut module> [<module path>]
# execute the cmdline() function of module-setup.sh of <dracut module>
# or the "cmdline" script, if module-setup.sh is not found
module_cmdline() {
    local _moddir=$2
    local _ret
    [[ -z $_moddir ]] && _moddir=$(dracut_module_path "$1")
    [[ -f $_moddir/module-setup.sh ]] || return 1
    unset check depends cmdline install installkernel
    cmdline() { true; }
    # shellcheck disable=SC1090
    . "$_moddir"/module-setup.sh
    moddir="$_moddir" cmdline
    _ret=$?
    unset check depends cmdline install installkernel
    return $_ret
}

# module_install <dracut module> [<module path>]
# execute the install() function of module-setup.sh of <dracut module>
# or the "install" script, if module-setup.sh is not found
module_install() {
    local _moddir=$2
    local _ret
    [[ -z $_moddir ]] && _moddir=$(dracut_module_path "$1")
    [[ -f $_moddir/module-setup.sh ]] || return 1
    unset check depends cmdline install installkernel
    install() { true; }
    # shellcheck disable=SC1090
    . "$_moddir"/module-setup.sh
    moddir="$_moddir" install
    _ret=$?
    unset check depends cmdline install installkernel
    return $_ret
}

# module_installkernel <dracut module> [<module path>]
# execute the installkernel() function of module-setup.sh of <dracut module>
# or the "installkernel" script, if module-setup.sh is not found
module_installkernel() {
    local _moddir=$2
    local _ret
    [[ -z $_moddir ]] && _moddir=$(dracut_module_path "$1")
    [[ -f $_moddir/module-setup.sh ]] || return 1
    unset check depends cmdline install installkernel
    installkernel() { true; }
    # shellcheck disable=SC1090
    . "$_moddir"/module-setup.sh
    moddir="$_moddir" installkernel
    _ret=$?
    unset check depends cmdline install installkernel
    return $_ret
}

# check_mount <dracut module> [<use_as_dep>] [<module path>]
# check_mount checks, if a dracut module is needed for the given
# device and filesystem types in "${host_fs_types[@]}"
check_mount() {
    local _mod=$1
    local _moddir=$3
    local _ret
    local _moddep

    [[ -z $_moddir ]] && _moddir=$(dracut_module_path "$1")

    # If we are already scheduled to be loaded, no need to check again.
    [[ " $mods_to_load " == *\ $_mod\ * ]] && return 0
    [[ " $mods_checked_as_dep " == *\ $_mod\ * ]] && return 1

    # This should never happen, but...
    [[ -d $_moddir ]] || return 1

    if [[ $2 ]]; then
        unset verbose_check
    else
        mods_checked_as_dep+=" $_mod "
        export verbose_check=1
    fi

    # shellcheck disable=SC2154
    if [[ " $omit_dracutmodules " == *\ $_mod\ * ]]; then
        return 1
    fi

    if [[ " $dracutmodules $add_dracutmodules $force_add_dracutmodules" == *\ $_mod\ * ]]; then
        export verbose_check=1
        module_check_mount "$_mod" "$_moddir"
        _ret=$?

        # explicit module, so also accept _ret=255
        [[ $_ret == 0 || $_ret == 255 ]] || return 1
    else
        # module not in our list
        if [[ $dracutmodules == all ]]; then
            # check, if we can and should install this module
            module_check_mount "$_mod" "$_moddir" || return 1
        else
            # skip this module
            return 1
        fi
    fi

    for _moddep in $(module_depends "$_mod" "$_moddir"); do
        # handle deps as if they were manually added
        [[ " $dracutmodules " == *\ $_mod\ * ]] \
            && [[ " $dracutmodules " != *\ $_moddep\ * ]] \
            && dracutmodules+=" $_moddep "
        [[ " $add_dracutmodules " == *\ $_mod\ * ]] \
            && [[ " $add_dracutmodules " != *\ $_moddep\ * ]] \
            && add_dracutmodules+=" $_moddep "
        [[ " $force_add_dracutmodules " == *\ $_mod\ * ]] \
            && [[ " $force_add_dracutmodules " != *\ $_moddep\ * ]] \
            && force_add_dracutmodules+=" $_moddep "
        # if a module we depend on fail, fail also
        if ! check_module "$_moddep"; then
            derror "Module '$_mod' depends on '$_moddep', which can't be installed"
            return 1
        fi
    done

    [[ " $mods_to_load " == *\ $_mod\ * ]] \
        || mods_to_load+=" $_mod "

    return 0
}

# check_module <dracut module> [<use_as_dep>] [<module path>]
# check if a dracut module is to be used in the initramfs process
# if <use_as_dep> is set, then the process also keeps track
# that the modules were checked for the dependency tracking process
check_module() {
    local _mod=$1
    local _moddir=$3
    local _ret
    local _moddep

    [[ -z $_moddir ]] && _moddir=$(dracut_module_path "$1")
    # If we are already scheduled to be loaded, no need to check again.
    [[ " $mods_to_load " == *\ $_mod\ * ]] && return 0
    [[ " $mods_checked_as_dep " == *\ $_mod\ * ]] && return 1

    # This should never happen, but...
    [[ -d $_moddir ]] || return 1

    if [[ $2 ]]; then
        unset verbose_check
    else
        mods_checked_as_dep+=" $_mod "
        export verbose_check=1
    fi

    if [[ " $omit_dracutmodules " == *\ $_mod\ * ]]; then
        if [[ " $force_add_dracutmodules " != *\ $_mod\ * ]]; then
            ddebug "Module '$_mod' will not be installed, because it's in the list to be omitted!"
            return 1
        fi
    fi

    if [[ " $dracutmodules $add_dracutmodules $force_add_dracutmodules" == *\ $_mod\ * ]]; then
        export verbose_check=1
        if [[ " $dracutmodules $force_add_dracutmodules " == *\ $_mod\ * ]]; then
            module_check "$_mod" 1 "$_moddir"
            _ret=$?
        else
            module_check "$_mod" 0 "$_moddir"
            _ret=$?
        fi
        # explicit module, so also accept _ret=255
        [[ $_ret == 0 || $_ret == 255 ]] || return 1
    else
        # module not in our list
        if [[ $dracutmodules == all ]]; then
            # check, if we can and should install this module
            module_check "$_mod" 0 "$_moddir"
            _ret=$?
            if [[ $_ret != 0 ]]; then
                [[ $2 ]] && return 1
                [[ $_ret != 255 ]] && return 1
            fi
        else
            # skip this module
            return 1
        fi
    fi

    for _moddep in $(module_depends "$_mod" "$_moddir"); do
        # handle deps as if they were manually added
        [[ " $dracutmodules " == *\ $_mod\ * ]] \
            && [[ " $dracutmodules " != *\ $_moddep\ * ]] \
            && dracutmodules+=" $_moddep "
        [[ " $add_dracutmodules " == *\ $_mod\ * ]] \
            && [[ " $add_dracutmodules " != *\ $_moddep\ * ]] \
            && add_dracutmodules+=" $_moddep "
        [[ " $force_add_dracutmodules " == *\ $_mod\ * ]] \
            && [[ " $force_add_dracutmodules " != *\ $_moddep\ * ]] \
            && force_add_dracutmodules+=" $_moddep "
        # if a module we depend on fail, fail also
        if ! check_module "$_moddep"; then
            derror "Module '$_mod' depends on '$_moddep', which can't be installed"
            return 1
        fi
    done

    [[ " $mods_to_load " == *\ $_mod\ * ]] \
        || mods_to_load+=" $_mod "

    return 0
}

# for_each_module_dir <func>
# execute "<func> <dracut module> 1 <module path>"
for_each_module_dir() {
    local _modcheck
    local _mod
    local _moddir
    local _func
    local _reason
    _func=$1
    for _moddir in "$dracutbasedir/modules.d"/[0-9][0-9]*; do
        [[ -e $_moddir/module-setup.sh ]] || continue
        _mod=${_moddir##*/}
        _mod=${_mod#[0-9][0-9]}
        $_func "$_mod" 1 "$_moddir"
    done

    # Report any missing dracut modules, the user has specified
    _modcheck="$add_dracutmodules $force_add_dracutmodules"
    [[ $dracutmodules != all ]] && _modcheck="$_modcheck $dracutmodules"
    for _mod in $_modcheck; do
        [[ " $mods_to_load " == *\ $_mod\ * ]] && continue

        [[ " $force_add_dracutmodules " != *\ $_mod\ * ]] \
            && [[ " $dracutmodules " != *\ $_mod\ * ]] \
            && [[ " $omit_dracutmodules " == *\ $_mod\ * ]] \
            && continue

        [[ -d $(echo "$dracutbasedir/modules.d"/[0-9][0-9]"$_mod") ]] \
            && _reason="installed" \
            || _reason="found"
        derror "Module '$_mod' cannot be $_reason."
        [[ " $force_add_dracutmodules " == *\ $_mod\ * ]] && exit 1
        [[ " $dracutmodules " == *\ $_mod\ * ]] && exit 1
        [[ " $add_dracutmodules " == *\ $_mod\ * ]] && exit 1
    done
}

dracut_kernel_post() {
    for _f in modules.builtin modules.builtin.alias modules.builtin.modinfo modules.order; do
        if [[ -e $srcmods/$_f ]]; then
            if ! $DRACUT_INSTALL ${kerneldir:+-D "$kerneldir"} ${loginstall:+-L "$loginstall"} "$srcmods/$_f" "/lib/modules/$kernel/$_f"; then
                derror FAILED: "$DRACUT_INSTALL" ${kerneldir:+-D "$kerneldir"} ${loginstall:+-L "$loginstall"} "$srcmods/$_f" "/lib/modules/$kernel/$_f"
            fi
        fi
    done

    # generate module dependencies for the initrd
    if [[ -d $kerneldir/lib/modules/$kernel ]] \
        && ! depmod -a -b "$kerneldir" "$kernel"; then
        dfatal "\"depmod -a $kernel\" failed."
        exit 1
    fi
}

instmods() {
    # instmods [-c [-s]] <kernel module> [<kernel module> ... ]
    # instmods [-c [-s]] <kernel subsystem>
    # install kernel modules along with all their dependencies.
    # <kernel subsystem> can be e.g. "=block" or "=drivers/usb/storage"
    # -c check
    # -s silent
    local _optional="-o"
    local _silent
    local _ret

    [[ $no_kernel == yes ]] && return

    if [[ $1 == '-c' ]]; then
        unset _optional
        shift
    fi
    if [[ $1 == '-s' ]]; then
        _silent=1
        shift
    fi

    if (($# == 0)); then
        read -r -d '' -a args
        set -- "${args[@]}"
    fi

    if (($# == 0)); then
        return 0
    fi

    $DRACUT_INSTALL \
        ${kerneldir:+-D "$kerneldir"} \
        \
        ${loginstall:+-L "$loginstall"} \
        ${hostonly:+-H} \
        ${check_supported:+--check-supported} \
        ${omit_drivers:+-N "$omit_drivers"} \
        ${srcmods:+--kerneldir "$srcmods"} \
        ${_optional:+-o} \
        ${_silent:+--silent} \
        -m "$@"
    _ret=$?

    if ((_ret != 0)) && [[ -z $_silent ]]; then
        derror "FAILED: " \
            "$DRACUT_INSTALL" \
            ${kerneldir:+-D "$kerneldir"} \
            \
            ${loginstall:+-L "$loginstall"} \
            ${hostonly:+-H} \
            ${check_supported:+--check-supported} \
            ${omit_drivers:+-N "$omit_drivers"} \
            ${srcmods:+--kerneldir "$srcmods"} \
            ${_optional:+-o} \
            ${_silent:+--silent} \
            -m "$@"
    fi

    [[ "$_optional" ]] && return 0
    return $_ret
}

ln_r() {
    ln -sfnr "${initdir}/$1" "${initdir}/$2"
}

is_qemu_virtualized() {
    # 0 if a virt environment was detected
    # 1 if a virt environment could not be detected
    # 255 if any error was encountered
    if type -P systemd-detect-virt > /dev/null 2>&1; then
        if ! vm=$(systemd-detect-virt --vm 2> /dev/null); then
            return 255
        fi
        [[ $vm == "qemu" ]] && return 0
        [[ $vm == "kvm" ]] && return 0
        [[ $vm == "bochs" ]] && return 0
    fi

    for i in /sys/class/dmi/id/*_vendor; do
        [[ -f $i ]] || continue
        read -r vendor < "$i"
        [[ $vendor == "QEMU" ]] && return 0
        [[ $vendor == "Red Hat" ]] && return 0
        [[ $vendor == "Bochs" ]] && return 0
    done
    return 1
}
