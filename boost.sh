#================================================================================
# Filename:  boost.sh
# Author:    Pete Goodliffe
# Copyright: (c) Copyright 2009 Pete Goodliffe
# Licence:   Please use this freely, with attribution
#================================================================================
#
# Builds a Boost framework for the iPhone.
# Creates a set of universal libraries that can be used on an iPhone and in the
# iPhone simulator.
#
# To configure the script, define:
#    BOOST_LIBS:        which libraries to build
#    BOOST_VERSION:     version number of the boost library (e.g. 1_41_0)
#    IPHONE_SDKVERSION: iPhone SDK version (e.g. 3.0)
#
# Then go get the source tar.bz of the boost you want to build, shove it in the
# same directory as this script, and run "./boost.sh"> Grab a cuppa. And voila.
#================================================================================

: ${BOOST_VERSION:=1_41_0}
: ${BOOST_LIBS:="thread signals filesystem regex program_options system"}
: ${IPHONE_SDKVERSION:=3.0}

: ${BUILDDIR:=`pwd`/build}
: ${PREFIXDIR:=`pwd`/prefix}
: ${FRAMEWORKDIR:=`pwd`/framework}

BOOST_TARBALL=boost_$BOOST_VERSION.tar.bz2
BOOST_SRC=boost_${BOOST_VERSION}

#================================================================================

echo "BOOST_VERSION:     $BOOST_VERSION"
echo "BOOST_LIBS:        $BOOST_LIBS"
echo "BOOST_TARBALL:     $BOOST_TARBALL"
echo "BOOST_SRC:         $BOOST_SRC"
echo "BUILDDIR:          $BUILDDIR"
echo "PREFIXDIR:         $PREFIXDIR"
echo "FRAMEWORKDIR:      $FRAMEWORKDIR"
echo "IPHONE_SDKVERSION: $IPHONE_SDKVERSION"
echo

#================================================================================
# Functions
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
    # build boost's jam (which is hidden in the depths of the boost tree)
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
    # These files are missing in the ARM iPhoneOS SDK, but they are in the simulator.
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

    BOOST_LIBS_CONFIG=""
    for i in $BOOST_LIBS; do BOOST_LIBS_CONFIG="$BOOST_LIBS_CONFIG --with-$i"; done;

    echo
    echo "Building boost..."
    echo "Using BOOST_LIBS:        $BOOST_LIBS"
    echo "Using BOOST_LIBS_CONFIG: $BOOST_LIBS_CONFIG"

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
        $BOOST_LIBS_CONFIG \
        $BOOST_EXTRACONFIG \
        install \
      || abort "Boost build failed"

    echo "Link all libraries together into a monolith"
    BOOST_LIB_FILES=""
    for i in $BOOST_LIBS; do BOOST_LIB_FILES="$BOOST_LIB_FILES $BUILDDIR/boost/bin.v2/libs/$i/build/darwin-4.2.1~iphone*/release/architecture-$BOOST_ARCH/link-static/macosx-version-$BOOST_MACOSVERSION/target-os-iphone/threading-multi/libboost_$i.a"; done;
    echo "Files are: $BOOST_LIB_FILES"
    $AR rc $BUILDDIR/libboost-$BOOST_ARCH.a $BOOST_LIB_FILES 
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

# $1: Name of a boost library to lipoficate (technical term)
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

# This creates universal versions of each individual boost library
lipoAllBoostLibraries()
{
    for i in $BOOST_LIBS; do lipoficate $i; done;
}

#================================================================================

                    VERSION_TYPE=Alpha
                  FRAMEWORK_NAME=Boost
               FRAMEWORK_VERSION=A

       FRAMEWORK_CURRENT_VERSION=1.0
 FRAMEWORK_COMPATIBILITY_VERSION=1.0

buildFramework()
{
    FRAMEWORK_BUNDLE=$FRAMEWORKDIR/$FRAMEWORK_NAME.framework

    echo "Framework: Setting up directories..."
    mkdir -p $FRAMEWORK_BUNDLE
    mkdir -p $FRAMEWORK_BUNDLE/Versions
    mkdir -p $FRAMEWORK_BUNDLE/Versions/$FRAMEWORK_VERSION
    mkdir -p $FRAMEWORK_BUNDLE/Versions/$FRAMEWORK_VERSION/Resources
    mkdir -p $FRAMEWORK_BUNDLE/Versions/$FRAMEWORK_VERSION/Headers
    mkdir -p $FRAMEWORK_BUNDLE/Versions/$FRAMEWORK_VERSION/Documentation

    echo "Framework: Creating symlinks..."
    ln -s $FRAMEWORK_VERSION               $FRAMEWORK_BUNDLE/Versions/Current
    ln -s Versions/Current/Headers         $FRAMEWORK_BUNDLE/Headers
    ln -s Versions/Current/Resources       $FRAMEWORK_BUNDLE/Resources
    ln -s Versions/Current/Documentation   $FRAMEWORK_BUNDLE/Documentation
    ln -s Versions/Current/$FRAMEWORK_NAME $FRAMEWORK_BUNDLE/$FRAMEWORK_NAME

    FRAMEWORK_INSTALL_NAME=$FRAMEWORK_BUNDLE/Versions/$FRAMEWORK_VERSION/$FRAMEWORK_NAME

    lipo \
        -create \
        -arch armv6 "$BUILDDIR/libboost-arm.a" \
        -arch i386  "$BUILDDIR/libboost-x86.a" \
        -o          "$FRAMEWORK_INSTALL_NAME" \
    || abort "Lipo $1 failed"

    echo "Framework: Copying includes..."
    cp -r $PREFIXDIR/include/boost/*  $FRAMEWORK_BUNDLE/Headers/
    echo "Framework: Creating plist..."
    cat > $FRAMEWORK_BUNDLE/Resources/Info.plist <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleDevelopmentRegion</key>
	<string>English</string>
	<key>CFBundleExecutable</key>
	<string>${FRAMEWORK_NAME}</string>
	<key>CFBundleIdentifier</key>
	<string>org.boost</string>
	<key>CFBundleInfoDictionaryVersion</key>
	<string>6.0</string>
	<key>CFBundlePackageType</key>
	<string>FMWK</string>
	<key>CFBundleSignature</key>
	<string>????</string>
	<key>CFBundleVersion</key>
	<string>${FRAMEWORK_CURRENT_VERSION}</string>
</dict>
</plist>
EOF
}

#================================================================================
# Execution starts here
#================================================================================

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
buildFramework

echo "Completed successfully"

#================================================================================

