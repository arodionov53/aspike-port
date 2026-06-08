# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

aspike-port is an Erlang NIF (Native Implemented Function) wrapper for the Aerospike C client library. It provides high-performance, asynchronous access to Aerospike databases from Erlang applications.

There are roughly 20 aerospike servers running in the production cluster, and the traffic coming to this NIF is about 100k ops/sec.
Also, the NIF might be used by approximately 1000 concurrent processes (OS threads) at any given time.
These numbers must be used while developing and optimizing the code.

## Architecture

The project has a two-layer architecture:

1. **C/C++ Layer**: Located in `c_src/`, contains:
   - `c_src/nif/aspike_nif.cpp`: Main NIF implementation that wraps Aerospike C client calls
   - `c_src/port/`: Alternative port-based implementation (legacy)
   - Integration with `aerospike-client-c/` (git submodule) and bundled `libev-4.33/`

2. **Erlang Layer**: Located in `src/`, provides:
   - `aspike_nif.erl`: Main API module with sync/async operations for key-value and CDT (Collection Data Types)
   - `aspike_nif_test.erl`: Performance testing utilities for single/multi-process benchmarks
   - `as_render.erl`: Response formatting and rendering utilities
   - OTP application structure (`aspike_port_app.erl`, `aspike_port_sup.erl`)

The NIF uses libev for event handling and provides both synchronous and asynchronous APIs. Key operations include:
- Basic CRUD: `key_get/3`, `key_put/4`, `key_remove/3`, `binary_get/3`, `cdt_put/6`
- Advanced: CDT operations, batch operations, segment tagging
- Cluster management: `host_add/2`, `connect/2`, `node_info/2`

## Common Development Commands

### Building
```bash
make                    # Full build (aerospike client, gateway client, erlang)
make compile_erl        # Build only Erlang code
rebar3 compile          # Alternative Erlang build
```

### Testing and Development
Start Erlang shell with compiled code:
```bash
erl -pa _build/default/lib/aspike_port/ebin
```

Initialize connection (requires running Aerospike instance):
```erlang
application:set_env(aspike_port, host, "172.17.0.2").
application:set_env(aspike_port, port, 3000).
aspike_nif:host_add().
aspike_nif:connect().
```

### Performance Testing
Single process tests:
```erlang
aspike_nif_test:sp_insert(<<"test">>, <<"set">>, 1000000, 3600, 0, 1000000000000, 0, 0).
aspike_nif_test:sp_read(<<"test">>, <<"set">>, 1000000, 0, 1000000000000, 0, 0, 0).
```

Multi-process tests:
```erlang
aspike_nif_test:mp_insert(40, 1000000, 0).  % 40 processes, 1M ops each
aspike_nif_test:mp_reads(40, 1000000, 0).
```

Get performance stats:
```erlang
aspike_nif_test:dump_stats().  % Outputs to /tmp/read_stats.txt and /tmp/insert_stats.txt
```

### Code Formatting
```bash
rebar3 erlfmt           # Format Erlang code
```

## Aerospike Setup

The project requires a running Aerospike instance. For development:

```bash
# Start Aerospike CE 7.1.0.0 in Docker
docker run -d --name aerospike --ulimit nofile=65536:65536 -p 3000:3000 -p 3001:3001 -p 3002:3002 -p 3003:3003 aerospike:ce-7.1.0.0

# Get container IP
docker inspect -f '{{.NetworkSettings.Networks.bridge.IPAddress}}' aerospike

# Access AQL shell
docker run -ti aerospike/aerospike-tools:latest aql -h <aerospike_ip>
```

## Configuration

Default connection settings in `include/defines.hrl`:
- Host: "127.0.0.1" (override with `application:set_env(aspike_port, host, "IP")`)
- Port: 3010 (override with `application:set_env(aspike_port, port, Port)`)
- Default namespace: "test"
- Default set: "erl-set"

## Key Files for Development

- `src/aspike_nif.erl`: Main API, all NIF function definitions and wrappers
- `c_src/nif/aspike_nif.cpp`: C++ NIF implementation
- `include/defines.hrl`: Configuration macros and defaults
- `src/aspike_nif_test.erl`: Performance testing utilities
- `Makefile`: Build system coordination
- `rebar.config`: Erlang build configuration