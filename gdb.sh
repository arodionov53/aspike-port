#!/bin/bash

# Debug script for Erlang NIF with GDB

echo "Starting GDB debugging session for aspike_nif..."

# Get Erlang process PID
ERL_PID=$(pgrep -f "beam.smp" | tail -n 1)

if [ -z "$ERL_PID" ]; then
    echo "No Erlang process found. Start your Erlang application first."
    echo "Example: erl -pa _build/default/lib/aspike_port/ebin"
    exit 1
fi

#ERL_PID=488972
echo "Found Erlang process PID: $ERL_PID"

#echo 0 | sudo tee /proc/sys/kernel/sched_rt_runtime_us

# Create GDB commands file
cat > /tmp/gdb_commands << EOF
# Set non-stop mode BEFORE attaching (this is the key!)
set non-stop off

# Attach to Erlang process
attach $ERL_PID

# Load NIF symbols
add-symbol-file ./priv/aspike_nif.so

# Set source directories
directory ./aerospike-client-c/src/main/aerospike
directory ./c_src/nif
directory ./c_src

# SIGSEGV Catching - MOST IMPORTANT
#handle SIGSEGV stop print nopass
#handle SIGBUS stop print nopass
#handle SIGABRT stop print nopass
#handle SIGFPE stop print nopass
#handle SIGILL stop print nopass

# Handle Erlang normal signals gracefully
#handle SIGPIPE nostop noprint pass
#handle SIGUSR1 nostop noprint pass
#handle SIGUSR2 nostop noprint pass
#handle SIGCHLD nostop noprint pass
#handle SIGTERM nostop noprint pass

# Thread settings for multi-thread debugging
#set scheduler-locking off
#set print thread-events on

# Force signal checking
#set debug infrun 1
catch signal SIGSEGV

# Show instructions when stopping
#set disassemble-next-line on

# Better stack traces
set print pretty on
set print object on
set print static-members on
set print address on
set pagination off

# Set useful breakpoints
#break cdt_put_sync
#break cdt_put_async
#break async_methods.cpp:151

# Continue execution
continue
EOF

gdb -x /tmp/gdb_commands

# Cleanup
rm -f /tmp/gdb_commands
