#ifndef ASPIKE_NIF_H
#define ASPIKE_NIF_H

#include <string>
#include <memory>
#include <atomic>

using namespace std;

// Per-node connection tracking structures
struct NodeConnectionStats {
    atomic<uint32_t> async_current;
    atomic<uint32_t> async_peak;
    atomic<int64_t> async_peak_ttl;

    NodeConnectionStats() :
        async_current(0), async_peak(0), async_peak_ttl(0) {}
};

enum aspike_status {
    ASPIKE_NIF_OK = 0,
	ASPIKE_NIF_MEMORY_ALLOC_ERR = 1,
    ASPIKE_NIF_NO_CALLER_ID = 2
};

#define MAX_HOST_SIZE 1024
#define MAX_KEY_STR_SIZE 1024
#define MAX_NAMESPACE_SIZE 32	// based on current server limit
#define MAX_SET_SIZE 64			// based on current server limit
#define AS_BIN_NAME_MAX_SIZE 16
#define MAX_BINS_NUMBER 1024

// Extern and inline declarations for global variables and functions
extern ERL_NIF_TERM atom_error;
extern ERL_NIF_TERM atom_ok;
extern ERL_NIF_TERM atom_done;
extern ERL_NIF_TERM atom_true;
extern ERL_NIF_TERM atom_false;
extern ERL_NIF_TERM atom_connected;
extern ERL_NIF_TERM atom_not_connected;
extern ERL_NIF_TERM atom_in_progress;
extern ERL_NIF_TERM atom_undefined;

extern atomic<uint32_t> sync_current_counter;
extern atomic<uint32_t> sync_peak_counter;
extern atomic<int64_t> sync_peak_ttl_counter;
extern atomic<uint32_t> async_current_counter;
extern atomic<uint32_t> async_peak_counter;
extern atomic<int64_t> async_peak_ttl_counter;

extern string get_target_node_for_key (const char* namespace_name, const char* set, const char* key_str);
extern shared_ptr<NodeConnectionStats> get_or_create_node_stats (const string& node_name);

extern aerospike* get_aerospike ();
extern bool statistics_enabled ();
extern bool check_connected (ErlNifEnv* env, ERL_NIF_TERM* err);

#define RETURN_ERROR_WITH_MSG_IF(t_var, p_rec, err_code, err_msg) \
    if(t_var) { \
        rc = atom_error; \
        code = enif_make_int(env, int(err_code)); \
        msg = enif_make_string(env, err_msg, ERL_NIF_UTF8); \
        if(!p_rec) { \
            as_record_destroy(p_rec); \
        } \
        return enif_make_tuple3(env, rc, code, msg); \
    }

#endif // ASPIKE_NIF_H
