#!/bin/bash

# source and package dir.
BUILD_SRCDIR=$PWD/src

# host system
TRIAD_HOST=x86_64-w64-mingw32
# target system
TRIAD_TARGET=x86_64-w64-mingw32

# mingw-w64 for linux
BUILD_SYSDIR=/usr/local/mingw64
# mingw-w64 for windows
BUILD_OPTDIR=/opt/mingw64

# system root dir
# x86_64-linux for linux
BUILD_SYSROOT=$BUILD_SYSDIR/$TRIAD_TARGET
# x86_64-linux for windows
BUILD_OPTROOT=$BUILD_OPTDIR/$TRIAD_TARGET

# global
FUNC_RET_SUCC=0
FUNC_RET_FAIL=1

export PATH=$BUILD_SYSDIR/bin:$PATH

PROGRAM_LIST="autoconf
        autogen
        automake
        bash
        binutils
        bison
        bzip2
        dejagnu
        diffutils
        expect
        flex
        g++
        g++-multilib
        gawk
        gcc
        gettext
        gfortran
        git
        gnat
        gperf
        guile-3.0
        gzip
        libc6-dev-i386
        libgmp-dev
        libisl-dev
        libmpc-dev
        libmpfr-dev
        libtool
        libzstd-dev
        m4
        make
        patch
        perl
        sphinxsearch
        ssh
        tar
        tcl
        texinfo
        texlive
        unzip
        wget"

_install_program() {
    for i in ${PROGRAM_LIST}
    do
        apt-get -y install ${i}
    done
}

PROGRAM_LIST="mingw_w64
              binutils
              gcc
              expat
              gdb
              make
              nasm"

_uppercase() {
    param=$1
    up_str=`echo ${param^^}`
}

_search_package_topdir() {
    local serach_cmd=$1
    local serach_package=$2
    find_str=`echo $(${serach_cmd} ${serach_package} | awk -F '/' '{print $1}' | tail -n 1)`
}

_decompress_package() {
    local package_name=$1
    local package_special_suffix=$2
    local decompress_path=$3
    local package_full_name=${package_name}.${package_special_suffix}
    local suffix=`echo ${package_special_suffix##*.}`
    local ext=tar
    local append_need_pipe=1
    local decompress_cmd=
    local decompress_append=`echo "${ext} -C ${decompress_path} -xf-"`
    local package_topdir=
    local serach_cmd=`echo "${ext} -tf"`

    # package is decompressed ?
    if [ -d ${decompress_path}/${package_name} ]; then
        #rm -rf ${decompress_path}/${package_name}
        printf "The target file ${package_full_name} has been decompressed, no need to decompress repeatedly!\n"
        return ${FUNC_RET_SUCC}
    fi

    case "${suffix}" in
        "xz")
        decompress_cmd=xzcat
        ;;
        "bz2")
        decompress_cmd=bzcat
        ;;
        "gz")
        decompress_cmd=`echo "gzip -dc"`
        ;;
        "zip")
        decompress_cmd="unzip -q"
        decompress_append=`echo "-d ${decompress_path}"`
        serach_cmd=`echo "zipinfo -1"`
        append_need_pipe=0
        ;;
    esac
    mkdir -p ${decompress_path}/${package_name}

    # decompress package
    if [ ${append_need_pipe} -eq 1 ]; then
        ${decompress_cmd} ${decompress_path}/${package_full_name} | ${decompress_append}
    else
        ${decompress_cmd} ${decompress_path}/${package_full_name} ${decompress_append}
    fi

    if [ "$?" = "${FUNC_RET_FAIL}" ]; then
        return ${FUNC_RET_FAIL}
    fi

    # serach package top dir name.
    _search_package_topdir "${serach_cmd}" "${decompress_path}/${package_full_name}"
    if [ "${find_str}" != "${package_name}" ]; then
        if [ -z "$(ls -A ${BUILD_SRCDIR}/${package_name})" ]; then
            rm -rf ${BUILD_SRCDIR}/${package_name}
        fi
        mv ${BUILD_SRCDIR}/${find_str} ${BUILD_SRCDIR}/${package_name} -f
    fi
    printf "${package_full_name} is decompress, path: ${decompress_path}/${package_name}\n"
    return ${FUNC_RET_SUCC}
}

_download_source() {
    source package_source.list

    local ext=tar
    local package_ver=
    local package_url=
    local package_suffix=
    local special_suffix=

    for i in ${PROGRAM_LIST}
    do
        _uppercase ${i}
        package_ver=PACKAGE_${up_str}_VER
        package_url=PACKAGE_${up_str}_URL
        package_suffix=`echo ${!package_url##*.}`
        special_suffix=

        case ${package_suffix} in
            xz)
            special_suffix=${ext}.${package_suffix}
            ;;
            bz2)
            special_suffix=${ext}.${package_suffix}
            ;;
            gz)
            special_suffix=${ext}.${package_suffix}
            ;;
            *)
            special_suffix=${package_suffix}
            ;;
        esac

        if [ "${!package_ver}" != "" -a "${!package_url}" != "" ]; then
            if [ ! -f ${BUILD_SRCDIR}/${i}-${!package_ver}.${special_suffix} ]; then
                printf "Now, we get \e[1;31m${i}\e[0m version: ${!package_ver}\n"
                wget ${!package_url} -O ${BUILD_SRCDIR}/${i}-${!package_ver}.${special_suffix}
            fi

            _decompress_package ${i}-${!package_ver} ${special_suffix} ${BUILD_SRCDIR}
        fi
    done

    # download gmp, mpfr, mpc, isl to gcc source dir.
    #gmp_ver=6.1.0
    #mpfr_ver=3.1.4
    #mpc_ver=1.0.3
    #isl_ver=0.18

    #cd $BUILD_SRCDIR/gcc-$GCC_VER
    #wget https://mirror.bjtu.edu.cn/gnu/gmp/gmp-$gmp_ver.tar.bz2
    #wget https://mirror.bjtu.edu.cn/gnu/mpfr/mpfr-$mpfr_ver.tar.bz2
    #wget https://mirror.bjtu.edu.cn/gnu/mpc/mpc-$mpc_ver.tar.gz
    #wget http://isl.gforge.inria.fr/isl-$isl_ver.tar.bz2
    
}

_build_prepare_common() {
    local program_name=$1
    local func=$2
    local package_ver=

    _uppercase ${program_name}
    package_ver=PACKAGE_${up_str}_VER

    ${func} ${program_name}-${!package_ver}
}

_build_mingw64_header() {
    local program_dir=$1

    cd $BUILD_SRCDIR
    #rm -rf build-headers
    mkdir -p build-headers

    cd $BUILD_SRCDIR/build-headers
    ../${program_dir}/mingw-w64-headers/configure --host=$TRIAD_HOST \
                                                  --prefix=$BUILD_SYSROOT
    make
    make install
}

_build_binutils() {
    local program_dir=$1
    cd $BUILD_SRCDIR

    #rm -rf build-binutils
    mkdir -p build-binutils
    cd $BUILD_SRCDIR/build-binutils
    ../${program_dir}/configure --target=$TRIAD_TARGET \
                                --prefix=$BUILD_SYSDIR \
                                --with-sysroot=$BUILD_SYSDIR \
                                --enable-multilib \
                                --enable-targets=x86_64-w64-mingw32,i686-w64-mingw32
    make
    make install
}

_link_symlink() {
    ln -sf $BUILD_SYSDIR/$TRIAD_TARGET $BUILD_SYSDIR/mingw
}

_build_gcc_core_prepare() {
    local program_dir=$1

    cd $BUILD_SRCDIR
    #rm -rf build-gcc
    mkdir -p build-gcc

    cd $BUILD_SRCDIR/${program_dir}
    ./contrib/download_prerequisites

    cd $BUILD_SRCDIR/build-gcc
    ../${program_dir}/configure --target=$TRIAD_TARGET \
                              --prefix=$BUILD_SYSDIR \
                              --with-sysroot=$BUILD_SYSDIR \
                              --enable-languages=c,c++ \
                              --enable-multilib \
                              --enable-targets=x86_64-w64-mingw32,i686-w64-mingw32
    make all-gcc
    make install-gcc
}

_build_mingw_w64_crt() {
    local program_dir=$1

    cd $BUILD_SRCDIR
    #rm -rf build-crt
    mkdir -p build-crt

    cd $BUILD_SRCDIR/build-crt
    ../${program_dir}/mingw-w64-crt/configure --host=$TRIAD_HOST \
                                              --prefix=$BUILD_SYSROOT \
                                              --with-sysroot=$BUILD_SYSROOT \
                                              --enable-lib64 \
                                              --enable-lib32
    make
    make install
}

_build_gcc_core_complete() {
    cd $BUILD_SRCDIR/build-gcc
    make
    make install
}

_main() {
    mkdir -p $BUILD_SRCDIR
    #_install_program
    _download_source
    # build
    _build_prepare_common binutils _build_binutils
    _build_prepare_common mingw_w64 _build_mingw64_header
    _build_prepare_common mingw_w64 _link_symlink
    _build_prepare_common gcc _build_gcc_core_prepare
    _build_prepare_common mingw_w64 _build_mingw_w64_crt
    _build_prepare_common gcc _build_gcc_core_complete
    $TRIAD_TARGET-ld -v
    $TRIAD_TARGET-gcc -v
    
}

_main

