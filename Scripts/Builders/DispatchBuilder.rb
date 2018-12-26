require_relative "../Common/Builder.rb"

# See:
# - Dispatch build script: https://github.com/readdle/swift-android-toolchain/blob/master/build/Linux/040_build_corelibs_libdispatch.sh
# - Cmake. Cross Compiling for Android: https://cmake.org/cmake/help/v3.7/manual/cmake-toolchains.7.html#id20
class DispatchBuilder < Builder

   def initialize(arch = Arch.default)
      super(Lib.dispatch, arch)
   end

   def prepare
      prepareBuilds()
   end

   def configure
      logConfigureStarted
      swift = SwiftBuilder.new(@arch)
      ndk = AndroidBuilder.new(@arch)
      # See: /swift/swift-corelibs-libdispatch/INSTALL.md
      prepare
      configurePatches(false)
      configurePatches

      cmd = []
      cmd << "cd #{@builds} &&"
      cmd << "cmake -G Ninja"
      if @arch == Arch.host
         cmd << "-DCMAKE_INSTALL_PREFIX=#{@installs}"
         cmd << "-DCMAKE_C_COMPILER=\"#{swift.llvm}/bin/clang\""
      else
         cmd << "-DCMAKE_ANDROID_ARCH_ABI=armeabi-v7a"
         cmd << "-DCMAKE_ANDROID_NDK_TOOLCHAIN_VERSION=clang"
         cmd << "-DCMAKE_ANDROID_STL_TYPE=\"c++_static\""
         cmd << "-DCMAKE_SYSTEM_NAME=Android"
         cmd << "-DCMAKE_SYSTEM_VERSION=#{ndk.api}"
         cmd << "-DCMAKE_ANDROID_NDK=#{ndk.sources}"
         cmd << "-DCMAKE_INSTALL_PREFIX=#{swift.installs}/usr" # Applying Dispatch over existing file structure.
      end
      cmd << "-DCMAKE_BUILD_TYPE=Release"
      cmd << "-DENABLE_SWIFT=true"
      cmd << "-DENABLE_TESTING=false"
      cmd << "-DCMAKE_SWIFT_COMPILER=\"#{swift.swift}/bin/swiftc\""
      cmd << "-DCMAKE_PREFIX_PATH=\"#{swift.swift}/lib/cmake/swift\""
      cmd << @sources
      execute cmd.join(" ")
      fixNinjaBuild
      logConfigureCompleted
   end

   def fixNinjaBuild
      if @arch == Arch.host
         return
      end
      ndk = AndroidBuilder.new(@arch)
      file = "#{@builds}/build.ninja"
      message "Applying fix for #{file}"
      contents = File.readlines(file).join()
      if !contents.include?('-tools-directory')
         contents = contents.gsub('-use-ld=gold', "-use-ld=gold -tools-directory #{ndk.installs}/bin")
         contents = contents.gsub('-module-link-name swiftDispatch', "-module-link-name swiftDispatch -Xcc -I#{ndk.installs}/sysroot/usr/include")
      end
      File.write(file, contents)
   end

   def configurePatches(shouldEnable = true)
      if @arch == Arch.host && shouldEnable
         return
      end
      originalFile = "#{@sources}/cmake/modules/SwiftSupport.cmake"
      patchFile = "#{@patches}/CmakeSystemProcessor.patch"
      configurePatch(originalFile, patchFile, shouldEnable)

      originalFile = "#{@sources}/cmake/modules/DispatchCompilerWarnings.cmake"
      patchFile = "#{@patches}/DisableWarningsAsErrors.patch"
      configurePatch(originalFile, patchFile, shouldEnable)
   end

   def build
      logBuildStarted
      execute "cd #{@builds} && ninja"
      logBuildCompleted
   end

   def install
      logInstallStarted
      execute "cd #{@builds} && ninja install"
      logInstallCompleted
   end

   def make
      configure
      build
      install
      configurePatches(false)
   end

   def clean
      configurePatches(false)
      removeBuilds()
   end

   def checkout
      checkoutIfNeeded(@sources, "https://github.com/apple/swift-corelibs-libdispatch.git", "afa6cc3d1c42935c5a1016ec7ae13ddcbb1853d4")
   end

end