#!/bin/bash# USB Bootable Creator# Linux - Kali / antiX# WARNING: The selected USB disk will be completely erased.set -Eeuo pipefailAPP="USB Bootable Creator"# Check root privilegeif [[ $EUID -ne 0 ]]; then    echo "Please run this script with sudo:"    echo "sudo bash $0"    exit 1fi# Check dependenciesfor cmd in lsblk zenity dd cmp sync; do    if ! command -v "$cmd" >/dev/null 2>&1; then        echo "Missing dependency: $cmd"        exit 1    fidone# Check graphical sessioif [[ -z "${DISPLAY:-}" && -z "${WAYLAND_DISPLAY:-}" ]]; then    echo "No graphical session detected."    exit 1fi# Detect removable USB disksDEVICES=()while read -r device size tran removable type; do    [[ "$type" == "disk" ]] || continue    if [[ "$removable" == "1" || "$tran" == "usb" ]]; t        DEVICES+=("$device" "$size" "${tran:-unknown}" "$removable")    fidone < <(lsblk -dnro NAME,SIZE,TRAN,RM,TYPEif [[ ${#DEVICES[@]} -eq 0 ]]; then    zenity --error --title="$APP" \        --text="No USB disk detected. Connect your USB and try again."    exit 1fi# Select USBUSB=$(zenity --list \    --title="$APP - USB Detection" \    --text="Select the USB disk to make bootable:" \    --width=700 --height=350 \    --column="Device" \    --column="Size" \    --column="Transport" \    --column="Removable" \    --print-column=1 \    "${DEVICES[@]}") || exit 0[[ -b "$USB" ]] || exit 1# Show USB partitions and informationINFO=$(lsblk -o NAME,SIZE,FSTYPE,LABEL,MOUNTPOINTS "$USB")zenity --info \    --title="$APP - USB Inspection" \    --width=650 \    --text="Selected USB:\n$USB\n\nPartitions and detected filesystems:\n\n$INFO\n\nWARNING: All partitions and data will be erased."# Enter ISO path manuallyISO=$(zenity --entry \    --title="$APP - ISO Selection" \    --width=650     --text="Enter the full path of your ISO image:" \    --entry-text="/home/$SUDO_USER/Downloads/") || exit 0# Validate ISOif [[ ! -f "$ISO" ]]; then    zenity --error --title="$APP" \        --text="ISO file not found:\n$ISO"    exit fiif [[ ! "$ISO" =~ \.iso$ ]]; then    zenity --error --title="$APP"         --text="The selected file does not have an .iso extension."    exit 1fiISO_SIZE=$(stat -c%s "$ISO")USB_SIZE=$(blockdev --getsize64 "$USB")if (( ISO_SIZE > USB_SIZE )); then    zenity --error --title="$APP" \        --text="ISO is larger than the selected USB disk.    exit 1fi# Final confirmationzenity --question \    --title="$APP - Final Confirmation" \    --width=550 \    --text="READY TO CREATE BOOTABLE USB\n\nUSB: $USB\nISO: $ISO\n\nALL DATA ON THIS USB WILL BE PERMANENTLY ERASED!\n\nContinue?" # Unmount all mounted partitions on the selected USwhile read -r partition; do    [[ -n "$partition" ]] || continue    if findmnt -rn -S "$partition" >/dev/null 2>&1; then        umount "$partition" || {            zenity --error --title="$APP"                 --text="Cannot unmount $partition. Operation cancelled.            exit 1        }    fdone < <(lsblk -lnpo NAME "$USB" | tail -n +2)# Flash ISO to USLOG=$(mktemp)zenity --info \    --title="$APP - Flashing" \    --text="Writing ISO to USB...\n\nPlease do not disconnect the USB.\n\nThe progress will be displayed in the terminif ! dd if="$ISO" of="$USB" bs=4M status=progress conv=fsync 2>"$LOG"; then    zenity --error --title="$APP" \        --text="Flashing failed. Check the terminal and USB."    cat "$LOG"    rm -f "$LOG"    exit 1fisync# Verify written image against the original ISOif ! cmp -n "$ISO_SIZE" "$ISO" "$USB"; then    zenity --error --title="$APP" \        --text="Verification failed. The USB may not contain a valid image."    rm -f "$LOG"    exit 1firm -f "$LOG"# Successzenity --info \    --title="$APP - Success" \    --width=5

#!/usr/bin/env bash

# ==========================================================
# USB BOOTABLE CREATOR v2.1
# Kali Linux / Debian / antiX
# ==========================================================

set -Eeuo pipefail

APP="USB Bootable Creator v2.1"

# ----------------------------------------------------------
# 1. ROOT PRIVILEGES
# ----------------------------------------------------------

if [[ $EUID -ne 0 ]]; then
    echo "Please run:"
    echo "sudo bash $0"
    exit 1
fi

# ----------------------------------------------------------
# 2. DEPENDENCIES
# ----------------------------------------------------------

REQUIRED=(
    lsblk zenity dd cmp sync blockdev stat
    findmnt umount wipefs numfmt getent
)

for cmd in "${REQUIRED[@]}"; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "Missing dependency: $cmd"
        exit 1
    fi
done

if [[ -z "${DISPLAY:-}" && -z "${WAYLAND_DISPLAY:-}" ]]; then
    echo "No graphical session detected."
    exit 1
fi

# ----------------------------------------------------------
# 3. USER HOME DIRECTORY
# ----------------------------------------------------------

CALLING_USER="${SUDO_USER:-root}"
USER_HOME=$(getent passwd "$CALLING_USER" | cut -d: -f6)
USER_HOME="${USER_HOME:-/root}"

START_DIR="$USER_HOME"

if [[ -d "$USER_HOME/Downloads" ]]; then
    START_DIR="$USER_HOME/Downloads/"
fi

# ----------------------------------------------------------
# 4. USB DETECTION
# ----------------------------------------------------------

DEVICES=()

while IFS= read -r line; do

    eval "$line"

    [[ "${TYPE:-}" == "disk" ]] || continue

    if [[ "${TRAN:-}" == "usb" || "${RM:-}" == "1" ]]; then

        DEVICES+=(
            "$NAME"
            "$SIZE"
            "${MODEL:-Unknown}"
            "${TRAN:-Unknown}"
        )

    fi

done < <(
    lsblk -dnP -p -o NAME,SIZE,MODEL,TRAN,RM,TYPE
)

if [[ ${#DEVICES[@]} -eq 0 ]]; then

    zenity --error \
        --title="$APP" \
        --text="No USB device detected.\nPlease connect a USB device."

    exit 1
fi

# ----------------------------------------------------------
# 5. SELECT USB
# ----------------------------------------------------------

USB=$(zenity --list \
    --title="$APP - Select USB" \
    --text="Select the USB device:" \
    --width=850 \
    --height=400 \
    --column="Device" \
    --column="Size" \
    --column="Model" \
    --column="Transport" \
    --print-column=1 \
    "${DEVICES[@]}") || exit 0

[[ -b "$USB" ]] || exit 0

# ----------------------------------------------------------
# 6. USB INSPECTION
# ----------------------------------------------------------

USB_INFO=$(lsblk -o NAME,SIZE,TYPE,FSTYPE,LABEL,MOUNTPOINTS "$USB")

zenity --info \
    --title="$APP - USB Inspection" \
    --width=750 \
    --text="USB selected:\n$USB\n\nPartitions information:\n\n$USB_INFO\n\nClick OK to select your ISO image."

# ----------------------------------------------------------
# 7. ISO FILE SELECTION (BROWSE)
# ----------------------------------------------------------

ISO=$(zenity --file-selection \
    --title="$APP - Browse ISO Image" \
    --filename="$START_DIR" \
    --file-filter="ISO images | *.iso *.ISO" \
    --file-filter="All files | *") || exit 0

# ----------------------------------------------------------
# 8. ISO VALIDATION
# ----------------------------------------------------------

if [[ ! -f "$ISO" || ! -r "$ISO" ]]; then

    zenity --error \
        --title="$APP" \
        --text="Invalid ISO file or file not readable."

    exit 1
fi

if [[ "${ISO,,}" != *.iso ]]; then

    zenity --error \
        --title="$APP" \
        --text="Please select a valid .iso file."

    exit 1
fi

ISO_SIZE=$(stat -c%s "$ISO")

if (( ISO_SIZE == 0 )); then

    zenity --error \
        --title="$APP" \
        --text="The selected ISO is empty."

    exit 1
fi

USB_SIZE=$(blockdev --getsize64 "$USB")

if (( ISO_SIZE > USB_SIZE )); then

    zenity --error \
        --title="$APP" \
        --text="The ISO is larger than the USB capacity."

    exit 1
fi

ISO_HUMAN=$(numfmt --to=iec-i --suffix=B "$ISO_SIZE")
USB_HUMAN=$(numfmt --to=iec-i --suffix=B "$USB_SIZE")

# ----------------------------------------------------------
# 9. ISO INFORMATION
# ----------------------------------------------------------

zenity --info \
    --title="$APP - ISO Selected" \
    --width=650 \
    --text="ISO successfully selected!\n\nFile: $(basename "$ISO")\nPath: $ISO\nISO size: $ISO_HUMAN\n\nUSB: $USB\nUSB capacity: $USB_HUMAN\n\nClick OK to continue."

# ----------------------------------------------------------
# 10. SAFETY CHECKS
# ----------------------------------------------------------

# Prevent overwriting a mounted system partition.

while IFS= read -r mountpoint; do

    case "$mountpoint" in
        "/"|"/boot"|"/boot/"*|"/boot/efi"|"/run/live/medium"|"/lib/live/mount/medium")

            zenity --error \
                --title="$APP - Safety Protection" \
                --text="Operation blocked!\n\nThe selected USB contains a critical system mount:\n$mountpoint"

            exit 1
            ;;
    esac

done < <(lsblk -nrpo MOUNTPOINT "$USB" | sed '/^$/d')

# Prevent erasing the disk containing the selected ISO.

ISO_SOURCE=$(findmnt -nro SOURCE -T "$ISO" | head -n 1)

if [[ -n "$ISO_SOURCE" && -b "$ISO_SOURCE" ]]; then

    if lsblk -s -nrpo NAME "$ISO_SOURCE" | grep -Fxq "$USB"; then

        zenity --error \
            --title="$APP - Safety Protection" \
            --text="The ISO file is stored on the USB you selected.\n\nCopy it to another disk first."

        exit 1
    fi
fi

# ----------------------------------------------------------
# 11. FINAL CONFIRMATION
# ----------------------------------------------------------

zenity --question \
    --title="$APP - FINAL CONFIRMATION" \
    --width=600 \
    --text="READY TO CREATE BOOTABLE USB\n\nUSB DEVICE:\n$USB\n\nISO IMAGE:\n$(basename "$ISO")\n\nISO SIZE: $ISO_HUMAN\n\nWARNING:\nALL DATA ON THIS USB WILL BE PERMANENTLY ERASED!\n\nDo you want to continue?"

|| exit 0

# ----------------------------------------------------------
# 12. UNMOUNT USB PARTITIONS
# ----------------------------------------------------------

while IFS= read -r partition; do

    [[ -n "$partition" ]] || continue

    while IFS= read -r target; do

        [[ -n "$target" ]] || continue

        if ! umount -- "$target"; then

            zenity --error \
                --title="$APP - Unmount Error" \
                --text="Cannot unmount:\n$target\n\nClose applications using this USB and retry."

            exit 1
        fi

    done < <(findmnt -rn -S "$partition" -o TARGET)

done < <(
    lsblk -lnpo NAME,TYPE "$USB" |
    awk '$2=="part" {print $1}'
)

# ----------------------------------------------------------
# 13. REMOVE OLD FILESYSTEM SIGNATURES
# ----------------------------------------------------------

if ! wipefs -af "$USB"; then

    zenity --error \
        --title="$APP" \
        --text="Failed to remove old filesystem signatures."

    exit 1
fi

# ----------------------------------------------------------
# 14. FLASH ISO TO USB
# ----------------------------------------------------------

zenity --info \
    --title="$APP - Flashing" \
    --text="Starting USB flash operation...\n\nUSB: $USB\n\nDo not disconnect your USB.\n\nProgress will be displayed in the terminal."

if ! dd if="$ISO" of="$USB" bs=4M status=progress conv=fsync; then

    zenity --error \
        --title="$APP - Flashing Failed" \
        --text="ISO writing failed!\n\nPlease check your USB device."

    exit 1
fi

sync

# ----------------------------------------------------------
# 15. VERIFICATION
# ----------------------------------------------------------

zenity --info \
    --title="$APP - Verification" \
    --text="Flash operation completed.\n\nVerifying written data...\n\nPlease wait."

if ! cmp -n "$ISO_SIZE" "$ISO" "$USB"; then

    zenity --error \
        --title="$APP - Verification Failed" \
        --text="Verification failed!\n\nUSB content does not match the ISO."

    exit 1
fi

sync

# ----------------------------------------------------------
# 16. SUCCESS
# ----------------------------------------------------------

zenity --info \
    --title="$APP - SUCCESS" \
    --width=600 \
    --text="SUCCESS!\n\nYour USB has been successfully created and verified.\n\nUSB: $USB\nISO: $(basename "$ISO")\n\nVerification: PASSED\n\nYour USB is ready to boot!\n\nYou can now safely disconnect it."

exit 0
