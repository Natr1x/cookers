#############################
# Author
# Technexion
#############################

TOP="${PWD}"
PATH_KERNEL="${PWD}/vendor/nxp-opensource/kernel_imx"
PATH_UBOOT="${PWD}/vendor/nxp-opensource/uboot-imx"
PATH_OUT_DRIVERS="${PWD}/vendor/nxp-opensource/out-of-tree_drivers"

export PATH="${PATH_UBOOT}/tools:${PATH}"
JAVA_HOME="/usr/lib/jvm/java-8-openjdk-amd64"
CLASSPATH=".:$JAVA_HOME/lib:$JAVA_HOME/lib/dt.jar:$JAVA_HOME/lib/tools.jar"
PATH="$JAVA_HOME/bin:${PATH}"
export ARCH=arm64
export AARCH64_GCC_CROSS_COMPILE="${PWD}/prebuilts/gcc/linux-x86/aarch64/gcc-arm-8.3-2019.03-x86_64-aarch64-linux-gnu/bin/aarch64-linux-gnu-"
export USER=$(whoami)
export USE_CCACHE=1

export MY_ANDROID=$TOP
export LC_ALL=C
export DRAM_SIZE_1G=false
export AUDIOHAT_ACTIVE=false
export NFC_ACTIVE=false
export WM8960_AUDIO_CODEC_ACTIVE=false
export EXPORT_BASEBOARD_NAME="PI"

# TARGET support: pico-imx8m, pico-imx8mm
MODULE=$(basename $BASH_SOURCE)
CPU_TYPE=$(echo $MODULE | awk -F. '{print $3}')
CPU_MODULE=$(echo $MODULE | awk -F. '{print $4}')
BASEBOARD=$(echo $MODULE | awk -F. '{print $5}')
OUTPUT_DISPLAY=$(echo $MODULE | awk -F. '{print $6}')

PATH_TOOLS="${TOP}/device/fsl/common/tools"

if [[ "$CPU_TYPE" == "imx8" ]]; then
  if [[ "$CPU_MODULE" == "axon-imx8mp" ]]; then
    if [[ "$BASEBOARD" == "wizard" ]]; then
      KERNEL_IMAGE='Image'
      KERNEL_CONFIG='tn_imx8_android_defconfig'
      UBOOT_CONFIG='axon-imx8mp_android_defconfig'
      TARGET_DEVICE=evk_8mp
      TARGET_DEVICE_NAME=imx8mp
      export EXPORT_BASEBOARD_NAME="PI"

      if [[ "$OUTPUT_DISPLAY" == "hdmi" ]]; then
        export DISPLAY_TARGET="DISP_HDMI"
      fi
    fi
  elif [[ "$CPU_MODULE" == "edm-g-imx8mp" ]]; then
    if [[ "$BASEBOARD" == "wandboard" ]]; then
      KERNEL_IMAGE='Image'
      KERNEL_CONFIG='tn_imx8_android_defconfig'
      UBOOT_CONFIG='edm-g-imx8mp_android_defconfig'
      TARGET_DEVICE=edm_g_imx8mp
      TARGET_DEVICE_NAME=imx8mp
      UBOOT_TARGET=imx8mp-edm-g
      export EXPORT_BASEBOARD_NAME="WANDBOARD"

      if [[ "$OUTPUT_DISPLAY" == "hdmi" ]]; then
        export DISPLAY_TARGET="DISP_HDMI"
      fi
    fi
  fi
fi

PATH_UBOOT_OUTPUT="${PWD}/out/target/product/${TARGET_DEVICE}/obj/UBOOT_OBJ"
PATH_KERNEL_OUTPUT="${PWD}/out/target/product/${TARGET_DEVICE}/obj/KERNEL_OBJ"

recipe() {
    local TMP_PWD="${PWD}"

    case "${PWD}" in
        "${PATH_UBOOT_OUTPUT}"*)
            cd "${PATH_UBOOT_OUTPUT}"
            make "$@" menuconfig || return $?
            cd -
            ;;
        "${PATH_KERNEL_OUTPUT}"*)
            cd "${PATH_KERNEL_OUTPUT}"
            make "$@" menuconfig || return $?
            cd -
            ;;
        *)
            echo -e "Error: outside the project" >&2
            return 1
            ;;
    esac

    cd "${TMP_PWD}"
}

cook() {
    local TMP_PWD="${PWD}"
    echo "$TMP_PWD"

    case "${PWD}" in
        "${TOP}")
            cd "${TMP_PWD}"
            cd ${PATH_UBOOT} && throw "$@" || return $?
            cd "${TMP_PWD}"
            source build/envsetup.sh
            lunch "$TARGET_DEVICE"-userdebug
            ./imx-make.sh "$@" || return $?
            cd ${PATH_UBOOT} && cook "$@" || return $?
            sed -i "$(grep -rn "id -u" ./install_uboot_imx8.sh | awk -F: '{print $1}'),$(($(grep -rn "id -u" ./install_uboot_imx8.sh | awk -F: '{print $1}') +3)) s/^/#/" install_uboot_imx8.sh
            yes | ./install_uboot_imx8.sh -b "$UBOOT_TARGET".dtb -d /dev/loop0  > /dev/null
            sed -i "$(grep -rn "id -u" ./install_uboot_imx8.sh | awk -F: '{print $1}'),$(($(grep -rn "id -u" ./install_uboot_imx8.sh | awk -F: '{print $1}') +3)) s/#//" install_uboot_imx8.sh
            sudo cp -rv "./imx-mkimage/iMX8M/flash.bin" "${TOP}/out/target/product/${TARGET_DEVICE}"
            cd "${TMP_PWD}"
            sudo cp -rv "${TOP}/out/target/product/${TARGET_DEVICE}/flash.bin" "${TOP}/out/target/product/${TARGET_DEVICE}/u-boot-"${TARGET_DEVICE_NAME}".imx"
            sudo cp -rv "${TOP}/out/target/product/${TARGET_DEVICE}/flash.bin" "${TOP}/out/target/product/${TARGET_DEVICE}/u-boot-"${TARGET_DEVICE_NAME}"-evk-uuu.imx"
            sudo cp -rv "${TOP}/out/target/product/${TARGET_DEVICE}/flash.bin" "${TOP}/out/target/product/${TARGET_DEVICE}/u-boot.bin"
            ;;
        "${PATH_KERNEL}"*)
            cd "${TMP_PWD}"
            ./imx-make.sh kernel "$@" || return $?
            ;;
        "${PATH_UBOOT}"*)
            export CROSS_COMPILE="${TOP}/prebuilts/gcc/linux-x86/aarch64/gcc-arm-8.3-2019.03-x86_64-aarch64-linux-gnu/bin/aarch64-linux-gnu-"
            cd "${PATH_UBOOT}"
            make "$@" $UBOOT_CONFIG || return $?
            make "$@" || return $?
            ;;
        *)
            echo -e "Error: outside the project" >&2
            return 1
            ;;
    esac

    cd "${TMP_PWD}"
}

throw() {
    local TMP_PWD="${PWD}"

    case "${PWD}" in
        "${TOP}")
            rm -rf out
            cd ${PATH_UBOOT} && throw "$@" || return $?
            ;;
        "${PATH_UBOOT}"*)
            cd "${PATH_UBOOT}"
            make "$@" distclean || return $?
            make "$@" mrproper  || return $?
            ;;
        *)
            echo -e "Error: outside the project" >&2
            return 1
            ;;
    esac

    cd "${TMP_PWD}"
}

merge_restricted_extras() {
  wget -c -t 0 --timeout=60 --waitretry=60 ftp://ftp.technexion.net/development_resources/NXP/android/11.0/imx-android-11.0.0_1.2.0.tar.gz
  tar zxvf imx-android-11.0.0_1.2.0.tar.gz
  # prebuilt libraries
  cp -rv imx-android-11.0.0_1.2.0/EULA.txt .
  cat EULA.txt

  while true; do
    read -p $'\e[31mCould you agree this EULA and keep install packages?' yn
    case $yn in
        [Yy]* ) break;;
        [Nn]* ) rm -rf imx-android-10.0.0-2.5.0.tar.gz imx-android-11.0.0_1.2.0 fsl_aacp_dec_4.5.6; sync; exit;;
        * ) echo "Please answer yes or no.";;
    esac
  done

  cp -rv imx-android-11.0.0_1.2.0/vendor/nxp/* vendor/nxp/
  cp -rv imx-android-11.0.0_1.2.0/SCR* .
  # prebuilt audio codec files
  cp -rv imx-android-11.0.0_1.2.0/fsl_aacp_dec_4.5.6/fsl_aacp_dec external

  # fix compile bug
  cp -rv vendor/nxp/imx_android_mm/mediacodec-profile/imx8mp/media_codecs_c2.xml vendor/nxp/imx_android_mm/mediacodec-profile/imx8mp/media_codecs_c2_temp.xml

  rm -rf imx-android-11.0.0_1.2.0.tar.gz imx-android-11.0.0_1.2.0
  sync

  # download toolchain
  wget -c -t 0 --timeout=60 --waitretry=60 "https://developer.arm.com/-/media/Files/downloads/gnu-a/8.3-2019.03/binrel/gcc-arm-8.3-2019.03-x86_64-aarch64-linux-gnu.tar.xz?revision=2e88a73f-d233-4f96-b1f4-d8b36e9bb0b9&la=en&hash=167687FADA00B73D20EED2A67D0939A197504ACD"
  mv gcc-arm-8.3-2019.03-x86_64-aarch64-linux-gnu.tar.xz\?revision\=2e88a73f-d233-4f96-b1f4-d8b36e9bb0b9\&la\=en\&hash\=167687FADA00B73D20EED2A67D0939A197504ACD gcc-arm-8.3-2019.03-x86_64-aarch64-linux-gnu.tar.xz
  tar Jxvf gcc-arm-8.3-2019.03-x86_64-aarch64-linux-gnu.tar.xz
  mv gcc-arm-8.3-2019.03-x86_64-aarch64-linux-gnu prebuilts/gcc/linux-x86/aarch64/
  rm -rf gcc-arm-8.3-2019.03-x86_64-aarch64-linux-gnu.tar.xz
  sync
}

gen_mp_images() {

  local TMP_PWD="${PWD}"
  PATH_OUT="${TOP}/out/target/product/${TARGET_DEVICE}"

  mkdir -p auto_test
  cp -rv "${PATH_OUT}"/boot.img auto_test/
  cp -rv "${PATH_OUT}"/dtbo*.img auto_test/
  cp -rv "${PATH_OUT}"/partition-table-*.img auto_test/
  cp -rv "${PATH_OUT}"/partition-table.img auto_test/
  cp -rv "${PATH_OUT}"/vbmeta*.img auto_test/
  cp -rv "${PATH_OUT}"/vendor.img auto_test/
  cp -rv "${PATH_OUT}"/system.img auto_test/
  cp -rv "${PATH_OUT}"/product.img auto_test/
  cp -rv "${PATH_OUT}"/super*.img auto_test/
  cp -rv "${PATH_OUT}"/flash.bin auto_test/
  cp -rv "${PATH_OUT}"/u-boot-"${TARGET_DEVICE_NAME}".imx auto_test/
  cp -rv "${PATH_OUT}"/u-boot-"${TARGET_DEVICE_NAME}"-evk-uuu.imx auto_test/
  cp -rv "${PATH_OUT}"/u-boot.bin auto_test/
  cp -rv "${PATH_OUT}"/lpmake auto_test/
  cp -rv "${PATH_OUT}"/lpmake.exe auto_test/

  cp -rv device/fsl/common/tools/uuu_imx_android_flash.sh auto_test/
  cp -rv device/fsl/common/tools/uuu_imx_android_flash.bat auto_test/
  cp -rv device/fsl/common/tools/fsl-sdcard-partition-gen_image.sh auto_test/
  cp -rv device/fsl/common/tools/fsl-sdcard-partition.sh auto_test/

  sync
}

gen_local_images() {

  PATH_OUT="${TOP}/out/target/product/${TARGET_DEVICE}"

  img_size="$@"

  if [[ "$img_size" == "" ]];then
    img_size=13
  fi

  cd "${PATH_OUT}"
  sudo dd if=/dev/zero of=test.img bs="$img_size"M count=1024
  sudo kpartx -av test.img
  loop_dev=$(losetup | grep "test.img" | awk  '{print $1}')
  sudo ./fsl-sdcard-partition-gen_image.sh -f "$TARGET_DEVICE_NAME" -c "$img_size" "${loop_dev}"
  sudo kpartx -d test.img
  sync
  sudo kpartx -av test.img
  sudo ./fsl-sdcard-partition-gen_image.sh -f "$TARGET_DEVICE_NAME" -c "$img_size" "${loop_dev}"
  sudo kpartx -d test.img
  sync
  cd "${TMP_PWD}"
}
