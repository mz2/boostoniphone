#================================================================================
#
# Builds boost for the iPhone
# Creates a set of universal libraries that can be used on an iPhone and in the
# iPhone simulator.
#
# To start, define:
#    BOOST_LIBS:        which libraries to build
#    BOOST_VERSION:     version number of the boost library (e.g. 1_41_0)
#    IPHONE_SDKVERSION: iPhone SDK version (e.g. 3.0)
#================================================================================

: ${BOOST_VERSION:=1_41_0}
: ${BOOST_LIBS:="--with-thread --with-signals --with-filesystem --with-regex --with-program_options --with-system "}
: ${IPHONE_SDKVERSION:=3.0}

: ${BUILDDIR:=`pwd`/build}
: ${PREFIXDIR:=`pwd`/prefix}

BOOST_TARBALL=boost_$BOOST_VERSION.tar.bz2
BOOST_SRC=boost_${BOOST_VERSION}

#================================================================================

abort()
{
    echo
    echo "Aborted: $@"
    exit 1
    exec false
}

#================================================================================

writeBjamUserConfig()
{
    echo Writing usr-config
    mkdir -p $BUILDDIR
    cat > $BUILDDIR/user-config.jam <<EOF
using darwin : 4.2.1~iphone
   :
/Developer/Platforms/iPhoneOS.platform/Developer/usr/bin/gcc-4.2 -arch armv6
   : <striper>
   : <architecture>arm <target-os>iphone <macosx-version>iphone-3.0
   ;
using darwin : 4.2.1~iphonesim
   :
/Developer/Platforms/iPhoneSimulator.platform/Developer/usr/bin/gcc-4.2 -arch i386
   : <striper>
   : <architecture>x86 <target-os>iphone <macosx-version>iphonesim-3.0
   ; 
EOF
}

#================================================================================

buildBjam()
{
    # build boost's jam (which is hidden in the depth of the boost tree)
    echo Build bjam
    cd $BOOST_SRC
    (
        echo
        echo "Building boost jam..."
        cd tools/jam/src
        (./build.sh) || abort "Build jam failed"
        mkdir -p $BUILDDIR/local-bin
        cp bin.*/bjam* $BUILDDIR/local-bin/
    ) || abort "Build jam failed"
}

#================================================================================

inventMissingHeaders()
{
    # These files are missing in the ARM SDK, but they are in the simulator.
    # They are supported on the device
    echo Invent missing headers
    cp /Developer/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator${IPHONE_SDKVERSION}.sdk/usr/include/{crt_externs,bzlib}.h $BUILDDIR
}

#================================================================================

# Called from buildBoostForiPhoneOS and buildBoostForiPhoneSimulator
#
# IPHONE_THING: iPhoneOS or iPhoneSimulator
buildBoost()
{
    : ${IPHONE_THING:?}
    : ${IPHONE_SDKVERSION:?}
    : ${IPHONE_ARCH:?}
    : ${BOOST_ARCH:?}
    : ${BOOST_LIBS:?}
    : ${BOOST_MACOSVERSION:?}
    : ${PREFIXDIR:?}

    IPHONE_PLATFORM=/Developer/Platforms/$IPHONE_THING.platform/Developer
    IPHONE_SDK=$IPHONE_PLATFORM/SDKs/$IPHONE_THING$IPHONE_SDKVERSION.sdk
    IPHONE_BIN=$IPHONE_PLATFORM/Developer/usr/bin
    IPHONE_INCLUDE=$IPHONE_SDK/usr/include

    if [ ! \( -d "$IPHONE_PLATFORM" \) ] ; then
       abort "The iPhone platform could not be found ($IPHONE_PLATFORM)."
    fi

    if [ ! \( -d "$IPHONE_SDK" \) ] ; then
       abort "The iPhone SDK could not be found ($IPHONE_SDK)."
    fi

    export AS="$IPHONE_PLATFORM/usr/bin/as"
    export ASCPP="$IPHONE_PLATFORM/usr/bin/as"
    export AR="$IPHONE_PLATFORM/usr/bin/ar"
    export RANLIB="$IPHONE_PLATFORM/usr/bin/ranlib"
    export CPPFLAGS="-miphoneos-version-min=$IPHONE_SDKVERSION -std=c99 -pipe -no-cpp-precomp -I$IPHONE_SDK/usr/include"
    export CFLAGS="-miphoneos-version-min=$IPHONE_SDKVERSION -std=c99 -arch $IPHONE_ARCH  -pipe -no-cpp-precomp --sysroot='$IPHONE_SDK' -isystem $IPHONE_SDK/usr/include "
    export CXXFLAGS="-miphoneos-version-min=$IPHONE_SDKVERSION -arch $IPHONE_ARCH  -pipe -no-cpp-precomp --sysroot='$IPHONE_SDK' -isystem $IPHONE_SDK/usr/include "
    export LDFLAGS="-miphoneos-version-min=$IPHONE_SDKVERSION -arch $IPHONE_ARCH  --sysroot='$IPHONE_SDK' -L$IPHONE_SDK/usr/lib "
    export CPP="$IPHONE_PLATFORM/usr/bin/cpp"
    export CXXCPP="$IPHONE_PLATFORM/usr/bin/cpp"
    export CC="$IPHONE_PLATFORM/usr/bin/gcc-4.2"
    export CXX="$IPHONE_PLATFORM/usr/bin/g++-4.2"
    export LD="$IPHONE_PLATFORM/usr/bin/ld"
    export STRIP="$IPHONE_PLATFORM/usr/bin/strip"

    echo
    echo "Building boost..."
    echo Using BOOST_LIBS:    $BOOST_LIBS

    PATH=$BUILDDIR/local-bin:$PATH

    bjam -d2 \
        toolset=darwin \
        architecture=$BOOST_ARCH \
        target-os=iphone \
        macosx-version=$BOOST_MACOSVERSION \
        link=static \
        include=$IPHONE_INCLUDE/c++/4.2.1/armv6-apple-darwin9 \
        --prefix=$PREFIXDIR \
        --layout=system \
        --build-dir=$BUILDDIR \
        --user-config=$BUILDDIR/user-config.jam \
        $BOOST_LIBS \
        $BOOST_EXTRACONFIG \
        install \
      || abort "Boost build failed"
}

buildBoostForiPhoneOS()
{
    echo iPhoneOS/ARM build
    IPHONE_THING=iPhoneOS
    IPHONE_ARCH=armv6
    BOOST_ARCH=arm
    BOOST_EXTRACONFIG="define=_LITTLE_ENDIAN include=$BUILDDIR"
    BOOST_MACOSVERSION=iphone-3.0
    buildBoost
}

buildBoostForiPhoneSimulator()
{
    echo iPhoneSimulator/x86 build
    IPHONE_THING=iPhoneSimulator
    IPHONE_ARCH=i386
    BOOST_ARCH=x86
    BOOST_EXTRACONFIG=
    BOOST_MACOSVERSION=iphonesim-3.0
    buildBoost
}

#================================================================================

lipoficate()
{
    : ${1:?}
    NAME=$1
    echo liboficate: $1
    ARMV6=$BUILDDIR/boost/bin.v2/libs/$NAME/build/darwin-4.2.1~iphone/release/architecture-arm/link-static/macosx-version-iphone-$IPHONE_SDKVERSION/target-os-iphone/threading-multi/libboost_$NAME.a
    I386=$BUILDDIR/boost/bin.v2/libs/$NAME/build/darwin-4.2.1~iphonesim/release/architecture-x86/link-static/macosx-version-iphonesim-$IPHONE_SDKVERSION/target-os-iphone/threading-multi/libboost_$NAME.a

    mkdir -p $PREFIXDIR/lib
    lipo \
        -create \
        -arch armv6 "$ARMV6" \
        -arch i386  "$I386" \
        -o          "$PREFIXDIR/lib/libboost_$NAME.a" \
    || abort "Lipo $1 failed"
}

lipoAllBoostLibraries()
{
    lipoficate filesystem
    lipoficate thread
    lipoficate signals
    lipoficate regex
    lipoficate program_options
    lipoficate system
}

#================================================================================
# Start execution here
#================================================================================

echo "Tarball is:  $BOOST_TARBALL"
echo "Source is:   $BOOST_SRC"
echo "BUILDDIR is: $BUILDDIR"
echo

[ -f "$BOOST_TARBALL" ] || abort "Source tarball missing."

mkdir -p $BUILDDIR
echo Unpacking boost...
[ -d $BOOST_SRC ] || tar xfj $BOOST_TARBALL
writeBjamUserConfig
buildBjam
inventMissingHeaders
buildBoostForiPhoneOS
buildBoostForiPhoneSimulator
lipoAllBoostLibraries

echo "Completed successfully"

#================================================================================

