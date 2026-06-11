## Aerospike setup

Obviously you need a running instance of Aerospike. Currently, in the production we are running version 6, but for
development purposes it's OK to go with version 7. Version 8 was found having many differences from 7 and is
not yet tested. CE (Community Edition) version is fine for development. It's recommended to use docker
image to run Aerospike, but you can choose any. For reference, you can follow guides on this page:
 * https://aerospike.com/download/server/community/
 * https://hub.docker.com/r/aerospike/aerospike-server

Run next command to download and run aerospike docker image:
```bash
docker run -d --rm --name aerospike_test --ulimit nofile=65536:65536 -p 3000-3003:3000-3003 aerospike:ce-7.1.0.0
```
This will download and store image and create a container under 'aerospike_test' name. Later you can reference this container with commands like:
```bash
docker logs aerospike_test # to get logs from Aerospike
docker exec -ti aerospike_test /bin/bash # to get shell inside container
docker stop aerospike_test # note - this will remove container due to '--rm' flag to 'docker run' command
```

If you need to talk to aerospike in AQL you can run the aql utility:
```bash
docker run --rm --network host -ti aerospike/aerospike-tools:latest aql -h 127.0.0.1
```
and there you can run sample queries like
```sql
SELECT * FROM test.rtb_setname
```
to see all records from that namespace/set, or
```sql
SELECT * FROM test.rtb_setname WHERE PK = 'user_defined_PK'
```
to see specific record that namespace/set.

If you need to run AS Admin (ASADM) you can run next command:
```bash
docker run --rm --network host -ti aerospike/aerospike-tools:latest asadm -h 127.0.0.1
```

## Building aspike-port

Just run make:

```bash
$ rebar3 compile
```

## Port implementation (disabled)

This repository previously included both a NIF and an Erlang Port implementation
for communicating with Aerospike. The Port implementation (`aspike_srv`,
`aspike_port_app`, `aspike_port_sup`) has been disabled because all consumers
now use the NIF directly via `aspike_nif` module, making the Port process
unnecessary overhead.

To re-enable the Port implementation:

1. Restore the OTP application callback in `src/aspike_port.app.src`:
   ```erlang
   {mod, {aspike_port_app, []}},
   {included_applications, [pooler]},
   ```

2. Add the port build back to `c_src/Makefile`:
   ```makefile
   %:
   	$(MAKE) -C port
   	$(MAKE) -C nif
   ```

## Tests

```bash
make test
```

### Run perf tests

In general, you can cover all major functions used in RTB by doing:

```bash
make stress_test
```
This runs certain amount of operations with different amount of parallel clients and measures the operation times.
Then it outputs the results to the console.
You might want to edit function `aspike_nif_stress_test:run_all()` to define some parameters. The main are:
- **AmountOfOps** - amount operations each client will do. Not all clients combined, but each client.
- **AmountsOfClients** - number of clients to run in parallel. For instance, [5, 10] means first 5 clients will query database in parallel, and after they finish the same will be repeated with 10 parallel clients.

### Memory leak test
You can run next command:
```bash
make memory_leak_test
```
Then just monitor the memory consumption while test is running.

### Single process tests

To run a single producer process:
```erlang
aspike_nif_test:sp_insert(<<"test">>, <<"rtb_setname">>, 1_000_000, 3600, 0, 1_000_000_000_000, 0, 0).
```
it will insert 1_000_000 keys to namespace=test, set=rtb_setname. Data TTL=3600 seconds. Delay between operations = 0ms. Initial key value = 1_000_000_000_000. (key will be 1_000_001_000_000 ... 1_000_001_999_999).
Function will return: {Number_of_success_operations, Number_of_errors}.

To run a single consumer process:
```erlang
aspike_nif_test:sp_read(<<"test">>, <<"rtb_setname">>, 1_000_000, 0, 1_000_000_000_000, 0, 0, 0).
```
it will read from namespace=test, set=rtb_setname. Delay between operations = 0ms. Initial key value = 1_000_000_000_000. (key will be 1_000_001_000_000 ... 1_000_001_999_999).

To get the raw stats:
```erlang
aspike_nif_test:dump_stats().
```
it will produce 2 files: /tmp/read_stats.txt and /tmp/insert_stats.txt

### Multi-process tests

```erlang
aspike_nif_test:mp_insert(40, 1_000_000, 0).
aspike_nif_test:mp_reads(40, 1_000_000, 0).
```
It will run 10 concurrent insert processes, each will insert 1000000 keys, with 0ms delay
and 20 concurrent read processes, each will read 1000000 keys with 0ms delay.
