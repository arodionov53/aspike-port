all: deps compile

deps:
	git submodule update --init
	git -C aerospike-client-c submodule update --init
	make -C aerospike-client-c EVENT_LIB=libev

compile: compile_aerospike_client compile_gateway_client

compile_aerospike_client:
	make -C aerospike-client-c EVENT_LIB=libev

compile_gateway_client:
	make -C c_src

clean: clean_gateway_client clean_aerospike_client clean_erlang

clean_gateway_client:
	make -C c_src/nif clean
	make -C c_src/port clean

clean_aerospike_client:
	make -C aerospike-client-c clean

clean_erlang:
	rm -rf _build
	rm -f erl_crash.dump

ensure_aerospike_test:
	@if ! docker ps --format '{{.Names}}' | grep -q '^aerospike_test$$'; then \
		echo "Starting Aerospike Docker container..."; \
		docker run -d --rm --name aerospike_test --ulimit nofile=65536:65536 \
			-p 3000:3000 -p 3001:3001 -p 3002:3002 -p 3003:3003 aerospike:ce-7.1.0.0; \
		sleep 1; \
	fi

test: ensure_aerospike_test
	rebar3 eunit --verbose

stress_test: ensure_aerospike_test
	rebar3 as test compile
	erl -pa _build/test/lib/aspike_port/ebin -pa _build/test/lib/aspike_port/test \
		-noshell -s aspike_nif_test stress_test

memory_leak_test: ensure_aerospike_test
	rebar3 as test compile
	erl -pa _build/test/lib/aspike_port/ebin -pa _build/test/lib/aspike_port/test \
		-noshell -s aspike_nif_test memory_leak_test
