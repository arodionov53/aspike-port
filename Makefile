all: deps compile

deps:
	git submodule update --init
	git -C aerospike-client-c submodule update --init

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
