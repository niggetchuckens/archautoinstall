#!/bin/bash

# Ensure script is run as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run with sudo."
   exit 1
fi

# 1. Install cpupower using yay
if ! command -v cpupower &> /dev/null; then
    echo "Installing cpupower..."
    # Running yay as the actual user since yay shouldn't be run as root
    sudo -u $(logname) yay -S --noconfirm cpupower
fi

# 2. Create the configuration file
echo "Creating /etc/default/cpupower configuration..."
cat <<EOF > /etc/default/cpupower
# Define CPUs governed by this config
# empty or 'all' for all CPUs
CPUS='all'

# Use the 'powersave' or 'performance' governor
# Powersave is usually recommended for modern Intel/AMD
governor='powersave'

# DISABLE BOOST MODE
# This is the equivalent of the Windows power plan setting
CPUPOWER_BOOST_DISABLE=true
EOF

# 3. Apply changes immediately to the kernel
echo "Applying immediate changes to sysfs..."
[ -f /sys/devices/system/cpu/intel_pstate/no_turbo ] && echo "1" > /sys/devices/system/cpu/intel_pstate/no_turbo
[ -f /sys/devices/system/cpu/cpufreq/boost ] && echo "0" > /sys/devices/system/cpu/cpufreq/boost

# 4. Enable and start the systemd service for persistence
echo "Enabling systemd service..."
systemctl enable --now cpupower.service

echo "---"
echo "Done! Processor boost is disabled and will stay disabled after reboot."
echo "Verification:"
cpupower frequency-info | grep "boost state"
