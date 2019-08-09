#!/bin/bash

export LANG=C

# Bold / Non-bold
BOLD="\033[1m"
RED="\033[0;31m"
GREEN="\033[0;32m"
BLUE="\033[1;34m"
#echo -e "\033[0;32mCOLOR_GREEN\t\033[1;32mCOLOR_LIGHT_GREEN"
OFF="\033[m"

# Repository location
REPO=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
cd ${REPO}

doCommands=("./tools/dialog" "/usr/libexec/plistbuddy -c" "./tools/bootoption")
BACKTITLE="XPS 13 9350 Post-install by maz-1"

array_contains () {
    local array="$1[@]"
    local seeking=$2
    local in=1
    for element in "${!array}"; do
        if [[ $element == $seeking ]]; then
            in=0
            break
        fi
    done
    return $in
}

if [[ $EUID -ne 0 ]];
then
    git_status="$(git status -sb 2>/dev/null|head -1)"
    local_branch="$(echo "$git_status"|perl -ne '/^##\s+(\S+)\.\.\./ and print "$1\n"')"
    remote_alias="$(echo "$git_status"|perl -ne '/^##\s+\S+\.\.\.(\S+)\/[^\s\/]+\s/ and print "$1\n"')"
    remote_branch="$(echo "$git_status"|perl -ne '/^##\s+\S+\.\.\.\S+\/([^\s\/]+)\s/ and print "$1\n"')"
    if test ! -z ${local_branch} && \
       test ! -z ${remote_alias} && \
       test ! -z ${remote_branch} && \
       test "$(git log ${local_branch} --not ${remote_alias}/${remote_branch})" = ""
    then
        echo -e "${GREEN}[GIT]${OFF}: Updating local data to latest version"
        git pull ${remote_alias} ${remote_branch}
    fi
    exec sudo /bin/bash "$0" "$@"
    exit 0
fi

EFIs=$(diskutil list|perl -ne '/^\s+\d+:\s+EFI\s+.*(disk\S+)\s*$/ and print "$1\n"'|while read line; \
    do \
    VOLNAME=$(diskutil info $line|perl -ne '/Volume Name:\s*(\S.*)\s*$/ and print "$1\n"'); \
    echo "\"$line ($VOLNAME)\""; \
    done
    )
EFI_ARG="$(echo -n "$EFIs"|awk '{printf " %d %s\n", NR, $0}')"
CLOVER_VERIFY_TITLE="Please manually specify the clover folder"
if ! test -z "${EFI_ARG}"
then
    if CMD="${doCommands[0]} --title \"Choose EFI partition\" --backtitle \"${BACKTITLE}\" --menu \"Choose EFI partition on your internal drive (click cancel to skip)\" 15 60 5 ${EFI_ARG} --stdout"
    then
        #clear
        CLOVER_VERIFY_TITLE="Is this the correct clover path? If not, modify it."
        selected_efi=$(echo "$EFIs"|sed -n $(eval $CMD)p)
        test -z "$selected_efi" && selected_efi=$(echo "$EFIs"|sed -n 1p)
        if test `expr $(echo "$EFIs" | wc -l) - 1` 1>/dev/null
        then
            vol=$(echo $selected_efi|perl -ne '/^\"(disk\d+s\d+)/ and print "$1\n"')
            if diskutil info $vol|grep -E "Mounted:\s+Yes" >/dev/null 2>&1
            then
                mount_point=$(diskutil info $vol|perl -ne '/^\s*Mount Point:\s*(\/.*\S)\s*$/ and print "$1\n"')
            else
                vol_label=$(diskutil info $vol|perl -ne '/^\s*Volume Name:\s*(\S.*)\s*$/ and print "$1\n"')
                if test -d "/Volumes/${vol_label// /_}"
                then
                    random_hex=$(hexdump -n 4 -e '4/4 "%08X" 1 "\n"' /dev/random)
                    random_hex=${random_hex:0:4}
                    mount_point="/Volumes/EFI_${random_hex}"
                else
                    mount_point="/Volumes/${vol_label// /_}"
                fi
                mkdir ${mount_point}
                if ! mount -t msdos /dev/$vol ${mount_point}
                then
                    ${doCommands[0]} --title 'Error!' --backtitle "${BACKTITLE}" --msgbox "Cannot mount specified EFI partition" 6 50 --stdout
                    exit 1
                fi
            fi
        fi
    fi
    clear
fi

test -z "${mount_point}" && CLOVER_VERIFY_DEFAULT="" || CLOVER_VERIFY_DEFAULT="${mount_point}/EFI/CLOVER"
clover_path_new="$(${doCommands[0]} --title "Verify clover folder" --backtitle "${BACKTITLE}" --inputbox "${CLOVER_VERIFY_TITLE}" 8 50 "${CLOVER_VERIFY_DEFAULT}" --stdout)"
test -z "$clover_path_new" || clover_path="$clover_path_new" 
if test -z "$clover_path"
then
    ${doCommands[0]} --title 'Error!' --backtitle "${BACKTITLE}" --msgbox 'Empty path specified!' 6 50 --stdout
    exit 1
fi
clear
# echo $clover_path
# get primary display info
gIOREG="$(ioreg -w0 -c AppleBacklightDisplay)"
gEDID=$(echo "${gIOREG}"|grep -i "IODisplayEDID"|head -1|sed -e 's/.*<//' -e 's/>//')
gDisplayVendorID=$(printf "%x\n" $(echo "${gIOREG}"|perl -ne '/"DisplayVendorID" = (\d+)/ and print "$1\n"'|head -1))
gDisplayProductID=$(printf "%x\n" $(echo "${gIOREG}"|perl -ne '/"DisplayProductID" = (\d+)/ and print "$1\n"'|head -1))
gHorizontalRez_pr=${gEDID:116:1}
gHorizontalRez_st=${gEDID:112:2}
gHorizontalRez=$((0x$gHorizontalRez_pr$gHorizontalRez_st))
gVerticalRez_pr=${gEDID:122:1}
gVerticalRez_st=${gEDID:118:2}
gVerticalRez=$((0x$gVerticalRez_pr$gVerticalRez_st))

if test "$(cat "$clover_path/XPS9350_REV" 2>/dev/null)" != "$(git rev-parse --short HEAD 2>/dev/null)" || test ! -f "$clover_path/XPS9350_REV" || test ! -f ./.git/index 
then
    mkdir -p "$clover_path"
    cp -f ./CLOVER/config.plist "$clover_path/../"
    mv -f "$clover_path/config.plist" "$clover_path/../" 2>/dev/null
    mv -f "$clover_path/themes" "$clover_path/../clover_themes" 2>/dev/null
    rm -rf "$clover_path"
    mkdir -p "$clover_path"
    cp -r ./CLOVER/* "$clover_path/"
    mv -n "$clover_path/../clover_themes"/* "$clover_path/themes" 2>/dev/null
    rm -rf "$clover_path/../clover_themes"
    if test -f ./.git/index
    then
        git rev-parse --short HEAD > "$clover_path/XPS9350_REV"
    else
        test -f ./XPS9350_REV && cat ./XPS9350_REV > "$clover_path/XPS9350_REV"
    fi
    
    PRESERVE_ENTRIES=(GUI RtVariables SMBIOS)
    ALL_ENTRIES=($(${doCommands[1]} "Print" "$clover_path/../config.plist"|perl -ne '/^(\t|\s{4})(\S+)\s+=\s+Dict\s+/ and print "$2 "'))
    for i in ${ALL_ENTRIES[@]}; do
        array_contains PRESERVE_ENTRIES $i || ${doCommands[1]} "Delete ':$i'" "$clover_path/../config.plist"
    done
    
    if [ `${doCommands[1]} "Print :SMBIOS:SerialNumber" "$clover_path/../config.plist"` != 'FAKESERIAL' ]
    then
        ${doCommands[0]} --title "Warning" --backtitle "${BACKTITLE}" --yesno "Preserve existing SMBIOS settings?" 6 40 --stdout || smbios_db="1"
        clear
    else
        smbios_db="1"
    fi
    if test "$smbios_db" = "1" 
    then
        gProductArr=['MacBookPro13,2','MacBookPro13,1','MacBook9,1']
        gProductName=`${doCommands[1]} "Print ':SMBIOS:ProductName'" "$clover_path/../config.plist"`
        if ! array_contains gProductArr "${gProductName}"
        then
            gProductName="MacBookPro13,2"
            ${doCommands[1]} "Add ':SMBIOS:ProductName' string" "$clover_path/../config.plist" 2>/dev/null
            ${doCommands[1]} "Set ':SMBIOS:ProductName' ${gProductName}" "$clover_path/../config.plist"
        fi
        gGenerateSerialAndMLB=`"${REPO}"/tools/macserial "${gProductName}" -n 1`
        gGenerateSerial=`echo ${gGenerateSerialAndMLB}|grep -oE '^\S+'`
        gGenerateMLB=`echo ${gGenerateSerialAndMLB}|grep -oE '\S+$'`
        gGenerateUUID=$(uuidgen)
        ${doCommands[1]} "Add ':RtVariables:MLB' string" "$clover_path/../config.plist" 2>/dev/null
        ${doCommands[1]} "Set ':RtVariables:MLB' ${gGenerateMLB}" "$clover_path/../config.plist"
        
        ${doCommands[1]} "Add ':RtVariables:ROM' string" "$clover_path/../config.plist" 2>/dev/null
        ${doCommands[1]} "Set ':RtVariables:ROM' UseMacAddr0" "$clover_path/../config.plist"
        
        ${doCommands[1]} "Add ':SMBIOS:SerialNumber' string" "$clover_path/../config.plist" 2>/dev/null
        ${doCommands[1]} "Set ':SMBIOS:SerialNumber' ${gGenerateSerial}" "$clover_path/../config.plist"
        
        ${doCommands[1]} "Add ':SMBIOS:BoardSerialNumber' string" "$clover_path/../config.plist" 2>/dev/null
        ${doCommands[1]} "Set ':SMBIOS:BoardSerialNumber' ${gGenerateMLB}" "$clover_path/../config.plist"
        
        ${doCommands[1]} "Add ':SMBIOS:SmUUID' string" "$clover_path/../config.plist" 2>/dev/null
        ${doCommands[1]} "Set ':SMBIOS:SmUUID' ${gGenerateUUID}" "$clover_path/../config.plist"
    fi
    ${doCommands[1]} "Delete ':GUI'" "$clover_path/config.plist" 2>/dev/null
    ${doCommands[1]} "Delete ':RtVariables'" "$clover_path/config.plist" 2>/dev/null
    ${doCommands[1]} "Delete ':SMBIOS'" "$clover_path/config.plist" 2>/dev/null
    ${doCommands[1]} "Merge \"$clover_path/../config.plist\"" "$clover_path/config.plist"
    rm -f "$clover_path/../config.plist"
    #
    # Fix HiDPI boot graphics issue
    #
    ${doCommands[1]} "Add ':BootGraphics:EFILoginHiDPI' string" "$clover_path/config.plist" 2>/dev/null
    ${doCommands[1]} "Add ':BootGraphics:UIScale' string" "$clover_path/config.plist" 2>/dev/null
    current_theme=`${doCommands[1]} "Print :GUI:Theme" "$clover_path/config.plist"`
    if [[ $gHorizontalRez -gt 1920 || $gSystemHorizontalRez -gt 1920 ]];
    then
      ${doCommands[1]} "Set :BootGraphics:EFILoginHiDPI 1" "$clover_path/config.plist"
      ${doCommands[1]} "Set :BootGraphics:UIScale 2" "$clover_path/config.plist"
      if test -d "$clover_path/themes/${current_theme}256"
      then
          ${doCommands[1]} "Set :GUI:Theme \"${current_theme}256\"" "$clover_path/config.plist"
      fi
    else
      ${doCommands[1]} "Set :BootGraphics:EFILoginHiDPI 0" "$clover_path/config.plist"
      ${doCommands[1]} "Set :BootGraphics:UIScale 1" "$clover_path/config.plist"
      if ! test -z "${current_theme%256*}" && test -d "$clover_path/themes/${current_theme%256*}"
      then
          ${doCommands[1]} "Set :GUI:Theme \"${current_theme%256*}\"" "$clover_path/config.plist"
      fi
    fi
    # install CPUFriend
    gCpuName=$(sysctl machdep.cpu.brand_string |sed -e "/.*) /s///" -e "/ CPU.*/s///")
    if test -d ./kexts/cpupm/${gCpuName}
    then
        rm -rf "$clover_path/kexts/Other/CPUFriend.kext"
        rm -rf "$clover_path/kexts/Other/CPUFriendDataProvider.kext"
        rm -f "$clover_path/ACPI/patched/SSDT-CpuFriend.aml"
        cp -r ./kexts/cpupm/CPUFriend.kext "$clover_path/kexts/Other/"
        cp -f ./kexts/cpupm/${gCpuName}/SSDT-CpuFriend.aml "$clover_path/ACPI/patched/"
    fi
    
    # add uefi entry for clover
    rm -f /tmp/entry_exists
    EFI_UUID=$(diskutil info "$(echo $clover_path|sed -e 's|/[Ee][Ff][Ii]/[Cc][Ll][Oo][Vv][Ee][Rr]||g')"|perl -ne '/Partition UUID:\s+(\S{8}-\S{4}-\S{4}-\S{4}-\S{12})/ and print "$1\n"')
    ROOT_UUID=$(diskutil info /|perl -ne '/Partition UUID:\s+(\S{8}-\S{4}-\S{4}-\S{4}-\S{12})/ and print "$1\n"')
    ${doCommands[2]} list|perl -ne '/\s+(\d+|--):\s+(Boot\d+)\s+/ and print "$2\n"'|while read line
    do
        entry_props="$(${doCommands[2]} info $line)"
        entry_uuid=$(echo "$entry_props"|perl -ne '/Partition UUID: (\S{8}-\S{4}-\S{4}-\S{4}-\S{12})/ and print "$1\n"')
        entry_name=$(echo "$entry_props"|perl -ne '/Description:\s+(\S.*\S)\s*$/ and print "$1\n"')
        entry_path=$(echo "$entry_props"|perl -ne '/Loader Path:\s+(\S.*\S)\s*$/ and print "$1\n"')
        if test "$ROOT_UUID" = "$entry_uuid" && test "${entry_name}" = "Mac OS X"
        then
            ${doCommands[2]} delete -n $line
        fi
        if [ "$entry_uuid" = "$EFI_UUID" ]
        then
            entry_path=$(echo $entry_path|tr [a-z] [A-Z]|sed -e 's/^\\//g')
            if [[ "$entry_path" == "EFI\CLOVER\CLOVERX64.EFI" ]]
            then
                touch /tmp/entry_exists
            fi
        fi
    done
    if test ! -f /tmp/entry_exists && test -f "$clover_path/CLOVERX64.efi"
    then
        ${doCommands[0]} --title "Attention" --backtitle "${BACKTITLE}" --yesno "Add Clover to UEFI entries?" 6 60 --stdout && \
        ${doCommands[2]} create -l "$clover_path/CLOVERX64.efi" -d "CLOVER"
    fi
    rm -f /tmp/entry_exists
fi
# optional operations
optional_ops=$(${doCommands[0]} --checklist "Select optional tweaks" 12 70 4 \
1 "Disable TouchID launch daemons" off \
2 "Enable 3rd Party application support" off \
3 "Force TRIM support on 3rd party SSD (not suggested)" off \
4 "Enable Thunderbolt force-power on boot (not suggested)" off \
--stdout)
clear
if [[ $optional_ops == *"1"* ]]; then
    echo -e "${BOLD}Disabling TouchID launch daemons...${OFF}"
    launchctl remove -w /System/Library/LaunchDaemons/com.apple.biometrickitd.plist
    launchctl remove -w /System/Library/LaunchDaemons/com.apple.biokitaggdd.plist
fi
if [[ $optional_ops == *"2"* ]]; then
    echo -e "${BOLD}Enabling 3rd Party application support...${OFF}"
    spctl --master-disable
fi
# put trimforce to end
# enable thunderbolt force-power
if test -f "$clover_path/kexts/Other/IOElectrify.kext/Contents/Info.plist"
then
    if [[ $optional_ops == *"4"* ]]; then
        echo -e "${BOLD}Enabling Thunderbolt force-power on boot...${OFF}"
        ${doCommands[1]} "Set :IOKitPersonalities:IOElectrify:IOElectrifyPowerHook 3" "$clover_path/kexts/Other/IOElectrify.kext/Contents/Info.plist"
    else
        ${doCommands[1]} "Set :IOKitPersonalities:IOElectrify:IOElectrifyPowerHook 0" "$clover_path/kexts/Other/IOElectrify.kext/Contents/Info.plist"
    fi
fi
# install display profiles
echo -e "${BOLD}Installing display profiles...${OFF}"
if test -f ./Displays/DisplayVendorID-${gDisplayVendorID}/DisplayProductID-${gDisplayProductID}
then
    echo "Installing resolution profile for VendorID 0x${gDisplayVendorID} & ProductID 0x${gDisplayProductID}..."
    mkdir -p /System/Library/Displays/Contents/Resources/Overrides/DisplayVendorID-${gDisplayVendorID}/
    cp -f  ./Displays/DisplayVendorID-${gDisplayVendorID}/DisplayProductID-${gDisplayProductID} \
            /System/Library/Displays/Contents/Resources/Overrides/DisplayVendorID-${gDisplayVendorID}/
    chmod 644 /System/Library/Displays/Contents/Resources/Overrides/DisplayVendorID-${gDisplayVendorID}/DisplayProductID-${gDisplayProductID}
fi
if test "${gDisplayVendorID}" = "4d10" && test "${gDisplayProductID}" = "144a"
then
    echo "Installing color profile RXN49_LQ133Z1_01.icm..."
    cp -f ./Displays/QHD+/RXN49_LQ133Z1_01.icm /Library/ColorSync/Profiles/
fi
# install kexts & daemons
echo -e "${BOLD}Installing ComboJack...${OFF}"
./kexts/ComboJack_Installer/install.sh
echo -e "${BOLD}Installing USBFix...${OFF}"
./kexts/USBFix/install.sh
echo -e "${BOLD}Installing kexts...${OFF}"
./kexts/Library-Extensions/install.sh

# put trimforce to end
if [[ $optional_ops == *"3"* ]]; then
    echo -e "${BOLD}Enabling TRIM support for 3rd party SSD...${OFF}"
    trimforce enable
fi

afplay /System/Library/Sounds/Glass.aiff &
osascript -e "display notification \"Done, restart to take effect.\" with title \"${BACKTITLE}\""
${doCommands[0]} --title "Done" --backtitle "${BACKTITLE}" --msgbox "Done, restart to take effect." 6 40 --stdout
clear
