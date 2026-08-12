#!/bin/bash
# Mock pactl to sleep a little bit, as pactl usually does IPC which is slow
pactl() {
    sleep 0.05
    if [ "$1" = "list" ]; then
        echo "0 alsa_output.pci-0000_00_1b.0.analog-stereo module-alsa-card.c s16le 2ch 44100Hz SUSPENDED"
        echo "1 alsa_output.pci-0000_01_00.1.hdmi-stereo module-alsa-card.c s16le 2ch 44100Hz SUSPENDED"
    fi
}
export -f pactl

echo "Benchmarking old way..."
time for i in {1..20}; do
    HDMI="$(pactl list short sinks | awk '/hdmi/ {print $2; exit}')"
    ANALOG="$(pactl list short sinks | awk '/analog/ {print $2; exit}')"
    DP="$(pactl list short sinks | awk '/dsp_generic.HiFi__Speaker/ {print $2; exit}')"
done

echo "Benchmarking new way..."
time for i in {1..20}; do
    SINKS="$(pactl list short sinks)"
    HDMI="$(echo "$SINKS" | awk '/hdmi/ {print $2; exit}')"
    ANALOG="$(echo "$SINKS" | awk '/analog/ {print $2; exit}')"
    DP="$(echo "$SINKS" | awk '/dsp_generic.HiFi__Speaker/ {print $2; exit}')"
done
