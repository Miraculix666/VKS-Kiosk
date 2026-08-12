#!/bin/bash
echo "Baseline (inside loop):"
time for i in {1..10}; do
	HDMI="$(pactl list short sinks 2>/dev/null | awk '/hdmi/ {print $2; exit}')"
	ANALOG="$(pactl list short sinks 2>/dev/null | awk '/analog/ {print $2; exit}')"
	DP="$(pactl list short sinks 2>/dev/null | awk '/dsp_generic.HiFi__Speaker/ {print $2; exit}')"
	CURRENT=$(pactl get-default-sink 2>/dev/null)
done

echo "Optimized (outside loop):"
time {
    HDMI="$(pactl list short sinks 2>/dev/null | awk '/hdmi/ {print $2; exit}')"
    ANALOG="$(pactl list short sinks 2>/dev/null | awk '/analog/ {print $2; exit}')"
    DP="$(pactl list short sinks 2>/dev/null | awk '/dsp_generic.HiFi__Speaker/ {print $2; exit}')"
    for i in {1..10}; do
        CURRENT=$(pactl get-default-sink 2>/dev/null)
    done
}
