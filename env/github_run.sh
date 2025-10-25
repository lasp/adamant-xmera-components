#!/bin/sh

this_dir=`dirname "$0"`

# Install cmake and compile fp32-fsw-xmera algorithms
sudo apt-get -y install cmake
cd $this_dir/../../fp32-fsw-xmera
./build.sh linux-gcc-debug
cd - >/dev/null

# Set the environment for the github command:
. $this_dir/activate

# Run the command passed to the script:
echo "$ $@"
eval "$@"
