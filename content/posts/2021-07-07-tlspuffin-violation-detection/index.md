---
layout: post
title: "tlspuffin: Security Violations"
date: 2021-07-07
slug: tlspuffin-violation-detection
draft: false

katex: false
hypothesis: true

keywords: []
categories: [research-blog]
---

The goal of tlspuffin is to find logical security vulnerabilities within TLS implementations. A security vulnerability violates a security property of TLS. This could be for example Confidentiality, Integrity or Authentication ([more](https://www.davidwong.fr/tls13/#appendix-E)).

For example a downgrade attack against OpenSSL like FREAK, does not expose the plaintext of the communication directly, but allows an arbitrary attacker with common computation power to factorize the RSA key and therefore break the encryption.

These kinds of logical attacks do not crash the implementation. A crash is also not desirable by an attacker because it represents a Denial-of-Service attack. If the goal of the attacker is to eavesdrop on a connection, then she has to find a logical attack like FREAK.

Usually fuzzers try to find crashes of implementations. These are easily detectable because the process which executes the library crashes. A security violation is more difficult to check as we need to introduce invariants which hold during the execution of a handshake. In the following we try to give some ideas over which variables such variants could be defined.

## Channel Binding

* the server's key share MUST be in the same group as one of the client's shares (https://hypothes.is/a/1jdqEMHcEeuQN-vVtD7B9A)

## Downgrade

TLS 1.2:

1. `used_public_rsa_key` (ClientKeyExchange) < `ssl_cipher_st.cipher.strength_bits`

TLS 1.3:

1. Protocol Version on Client and Server
1. Secrets match between client and server:
    * `early_secret`
    * `handshake_secret`
    * `master_secret`
    * `resumption_master_secret`
    * `client_finished_secret`
    * `server_finished_secret`
    * `server_finished_hash`
    * `handshake_traffic_hash`
    * `client_app_traffic_secret`
    * `server_app_traffic_secret`
    * `exporter_master_secret`
    * `early_exporter_master_secret`
1. Verify `cert_verify_hash` between client and server -> not neccassarily a successful attack


## Authentication Violations

To check for security violations we introduce the concept of claims, which are also known as events. A claim has a name, an executing agent, as well as data attached to it. For example during the execution of a successful TLS 1.3 handshake the claim `Finished(client, master_secret)` is recorded. That means that the honest agent `client` has reached the protocol state in which the finished the handshake. The additional data `master_secret` can be used in security queries.

Let's compare a query with events from ProVerif with our notion of queries and claims. The following query demands that if the client reached a state in which it is finished, that the corresponding server should already have finished. This query is a sanity check and does not check security properties.

```kotlin
query cr:random, sr:random, 
      psk:preSharedKey,p:pubkey,o:params, m:params, 
      ck:ae_key, sk:ae_key, cb:bitstring, ms:bitstring;
      event(ClientFinished(TLS12,cr,sr,psk,p,m,o,ck,sk,cb,ms)) ==>
      event(ServerFinished(TLS12,cr,sr,psk,p,m,o,ck,sk,cb,ms)).
```

The query also makes sure that server and client both have negotiated the same parameters as versions and keys.

ProVerif proves that for all traces of the protocol the above query is true. In the case of tlspuffin we only need to check queries for a single trace.

Let's suppose that the execution of a TLS 1.3 handshake in tlspuffin yields the following trace:

`ClientHello(client, ...)`, `ServerHelloUntilFinished(server, ...)`, `CCSUntilClientFinished(client, ...)`

We are using here a bit-step execution of the protocol. We are only creating events after a flight of messages, not after each individual message.


## Messy state of the union

```c
typedef struct state {
    Role role; //r∈ {Client,Server}
    PV version; //v∈{SSLv3,TLSv1.0,TLSv1.1,TLSv1.2}
    KEM kx; //kx∈{DH∗,ECDH∗,RSA∗}
    Auth clientauth; //(c_ask,c_offer)
    int resumption; //(r_id,r_tick)
    int renegotiation; //reneg = 1 if renegotiating
    int ntick; //ntickMsg
    type lastmessage; // previous message 
    type unsigned char∗ log; // full handshake log
    unsigned int loglength;
    } STATE;
```

Ideas:
* Key Exchange method the same in client and server?
* Do ciphers match in client and server?
  
**When do I check for a difference? After `Finished` e.g. after Transcript check?**


## Implementation

We want to do most of the checks in the testing harness which is implemented in Rust. A unified interface should make it possible that the same invariants can be used across different implementations like LibreSSL and OpenSSL, but also between OpenSSL versions like 1.0.x and 1.1.1.


OpenSSL 1.1.1 Session:
```c
struct ssl_st {
    /*
     * protocol version (one of SSL2_VERSION, SSL3_VERSION, TLS1_VERSION,
     * DTLS1_VERSION)
     */
    int version;
    /* SSLv3 */
    const SSL_METHOD *method;
    /*
     * There are 2 BIO's even though they are normally both the same.  This
     * is so data can be read and written to different handlers
     */
    /* used by SSL_read */
    BIO *rbio;
    /* used by SSL_write */
    BIO *wbio;
    /* used during session-id reuse to concatenate messages */
    BIO *bbio;
    /*
     * This holds a variable that indicates what we were doing when a 0 or -1
     * is returned.  This is needed for non-blocking IO so we know what
     * request needs re-doing when in SSL_accept or SSL_connect
     */
    int rwstate;
    int (*handshake_func) (SSL *);
    /*
     * Imagine that here's a boolean member "init" that is switched as soon
     * as SSL_set_{accept/connect}_state is called for the first time, so
     * that "state" and "handshake_func" are properly initialized.  But as
     * handshake_func is == 0 until then, we use this test instead of an
     * "init" member.
     */
    /* are we the server side? */
    int server;
    /*
     * Generate a new session or reuse an old one.
     * NB: For servers, the 'new' session may actually be a previously
     * cached session or even the previous session unless
     * SSL_OP_NO_SESSION_RESUMPTION_ON_RENEGOTIATION is set
     */
    int new_session;
    /* don't send shutdown packets */
    int quiet_shutdown;
    /* we have shut things down, 0x01 sent, 0x02 for received */
    int shutdown;
    /* where we are */
    OSSL_STATEM statem;
    SSL_EARLY_DATA_STATE early_data_state;
    BUF_MEM *init_buf;          /* buffer used during init */
    void *init_msg;             /* pointer to handshake message body, set by
                                 * ssl3_get_message() */
    size_t init_num;               /* amount read/written */
    size_t init_off;               /* amount read/written */
    struct ssl3_state_st *s3;   /* SSLv3 variables */
    struct dtls1_state_st *d1;  /* DTLSv1 variables */
    /* callback that allows applications to peek at protocol messages */
    void (*msg_callback) (int write_p, int version, int content_type,
                          const void *buf, size_t len, SSL *ssl, void *arg);
    void *msg_callback_arg;
    int hit;                    /* reusing a previous session */
    X509_VERIFY_PARAM *param;
    /* Per connection DANE state */
    SSL_DANE dane;
    /* crypto */
    STACK_OF(SSL_CIPHER) *peer_ciphers;
    STACK_OF(SSL_CIPHER) *cipher_list;
    STACK_OF(SSL_CIPHER) *cipher_list_by_id;
    /* TLSv1.3 specific ciphersuites */
    STACK_OF(SSL_CIPHER) *tls13_ciphersuites;
    /*
     * These are the ones being used, the ones in SSL_SESSION are the ones to
     * be 'copied' into these ones
     */
    uint32_t mac_flags;
    /*
     * The TLS1.3 secrets.
     */
    unsigned char early_secret[EVP_MAX_MD_SIZE];
    unsigned char handshake_secret[EVP_MAX_MD_SIZE];
    unsigned char master_secret[EVP_MAX_MD_SIZE];
    unsigned char resumption_master_secret[EVP_MAX_MD_SIZE];
    unsigned char client_finished_secret[EVP_MAX_MD_SIZE];
    unsigned char server_finished_secret[EVP_MAX_MD_SIZE];
    unsigned char server_finished_hash[EVP_MAX_MD_SIZE];
    unsigned char handshake_traffic_hash[EVP_MAX_MD_SIZE];
    unsigned char client_app_traffic_secret[EVP_MAX_MD_SIZE];
    unsigned char server_app_traffic_secret[EVP_MAX_MD_SIZE];
    unsigned char exporter_master_secret[EVP_MAX_MD_SIZE];
    unsigned char early_exporter_master_secret[EVP_MAX_MD_SIZE];
    EVP_CIPHER_CTX *enc_read_ctx; /* cryptographic state */
    unsigned char read_iv[EVP_MAX_IV_LENGTH]; /* TLSv1.3 static read IV */
    EVP_MD_CTX *read_hash;      /* used for mac generation */
    COMP_CTX *compress;         /* compression */
    COMP_CTX *expand;           /* uncompress */
    EVP_CIPHER_CTX *enc_write_ctx; /* cryptographic state */
    unsigned char write_iv[EVP_MAX_IV_LENGTH]; /* TLSv1.3 static write IV */
    EVP_MD_CTX *write_hash;     /* used for mac generation */
    /* session info */
    /* client cert? */
    /* This is used to hold the server certificate used */
    struct cert_st /* CERT */ *cert;

    /*
     * The hash of all messages prior to the CertificateVerify, and the length
     * of that hash.
     */
    unsigned char cert_verify_hash[EVP_MAX_MD_SIZE];
    size_t cert_verify_hash_len;

    /* Flag to indicate whether we should send a HelloRetryRequest or not */
    enum {SSL_HRR_NONE = 0, SSL_HRR_PENDING, SSL_HRR_COMPLETE}
        hello_retry_request;

    /*
     * the session_id_context is used to ensure sessions are only reused in
     * the appropriate context
     */
    size_t sid_ctx_length;
    unsigned char sid_ctx[SSL_MAX_SID_CTX_LENGTH];
    /* This can also be in the session once a session is established */
    SSL_SESSION *session;
    /* TLSv1.3 PSK session */
    SSL_SESSION *psksession;
    unsigned char *psksession_id;
    size_t psksession_id_len;
    /* Default generate session ID callback. */
    GEN_SESSION_CB generate_session_id;
    /*
     * The temporary TLSv1.3 session id. This isn't really a session id at all
     * but is a random value sent in the legacy session id field.
     */
    unsigned char tmp_session_id[SSL_MAX_SSL_SESSION_ID_LENGTH];
    size_t tmp_session_id_len;
    /* Used in SSL3 */
    /*
     * 0 don't care about verify failure.
     * 1 fail if verify fails
     */
    uint32_t verify_mode;
    /* fail if callback returns 0 */
    int (*verify_callback) (int ok, X509_STORE_CTX *ctx);
    /* optional informational callback */
    void (*info_callback) (const SSL *ssl, int type, int val);
    /* error bytes to be written */
    int error;
    /* actual code */
    int error_code;
# ifndef OPENSSL_NO_PSK
    SSL_psk_client_cb_func psk_client_callback;
    SSL_psk_server_cb_func psk_server_callback;
# endif
    SSL_psk_find_session_cb_func psk_find_session_cb;
    SSL_psk_use_session_cb_func psk_use_session_cb;

    SSL_CTX *ctx;
    /* Verified chain of peer */
    STACK_OF(X509) *verified_chain;
    long verify_result;
    /* extra application data */
    CRYPTO_EX_DATA ex_data;
    /*
     * What we put in certificate_authorities extension for TLS 1.3
     * (ClientHello and CertificateRequest) or just client cert requests for
     * earlier versions. If client_ca_names is populated then it is only used
     * for client cert requests, and in preference to ca_names.
     */
    STACK_OF(X509_NAME) *ca_names;
    STACK_OF(X509_NAME) *client_ca_names;
    CRYPTO_REF_COUNT references;
    /* protocol behaviour */
    uint32_t options;
    /* API behaviour */
    uint32_t mode;
    int min_proto_version;
    int max_proto_version;
    size_t max_cert_list;
    int first_packet;
    /*
     * What was passed in ClientHello.legacy_version. Used for RSA pre-master
     * secret and SSLv3/TLS (<=1.2) rollback check
     */
    int client_version;
    /*
     * If we're using more than one pipeline how should we divide the data
     * up between the pipes?
     */
    size_t split_send_fragment;
    /*
     * Maximum amount of data to send in one fragment. actual record size can
     * be more than this due to padding and MAC overheads.
     */
    size_t max_send_fragment;
    /* Up to how many pipelines should we use? If 0 then 1 is assumed */
    size_t max_pipelines;

    struct {
        /* Built-in extension flags */
        uint8_t extflags[TLSEXT_IDX_num_builtins];
        /* TLS extension debug callback */
        void (*debug_cb)(SSL *s, int client_server, int type,
                         const unsigned char *data, int len, void *arg);
        void *debug_arg;
        char *hostname;
        /* certificate status request info */
        /* Status type or -1 if no status type */
        int status_type;
        /* Raw extension data, if seen */
        unsigned char *scts;
        /* Length of raw extension data, if seen */
        uint16_t scts_len;
        /* Expect OCSP CertificateStatus message */
        int status_expected;

        struct {
            /* OCSP status request only */
            STACK_OF(OCSP_RESPID) *ids;
            X509_EXTENSIONS *exts;
            /* OCSP response received or to be sent */
            unsigned char *resp;
            size_t resp_len;
        } ocsp;

        /* RFC4507 session ticket expected to be received or sent */
        int ticket_expected;
# ifndef OPENSSL_NO_EC
        size_t ecpointformats_len;
        /* our list */
        unsigned char *ecpointformats;

        size_t peer_ecpointformats_len;
        /* peer's list */
        unsigned char *peer_ecpointformats;
# endif                         /* OPENSSL_NO_EC */
        size_t supportedgroups_len;
        /* our list */
        uint16_t *supportedgroups;

        size_t peer_supportedgroups_len;
         /* peer's list */
        uint16_t *peer_supportedgroups;

        /* TLS Session Ticket extension override */
        TLS_SESSION_TICKET_EXT *session_ticket;
        /* TLS Session Ticket extension callback */
        tls_session_ticket_ext_cb_fn session_ticket_cb;
        void *session_ticket_cb_arg;
        /* TLS pre-shared secret session resumption */
        tls_session_secret_cb_fn session_secret_cb;
        void *session_secret_cb_arg;
        /*
         * For a client, this contains the list of supported protocols in wire
         * format.
         */
        unsigned char *alpn;
        size_t alpn_len;
        /*
         * Next protocol negotiation. For the client, this is the protocol that
         * we sent in NextProtocol and is set when handling ServerHello
         * extensions. For a server, this is the client's selected_protocol from
         * NextProtocol and is set when handling the NextProtocol message, before
         * the Finished message.
         */
        unsigned char *npn;
        size_t npn_len;

        /* The available PSK key exchange modes */
        int psk_kex_mode;

        /* Set to one if we have negotiated ETM */
        int use_etm;

        /* Are we expecting to receive early data? */
        int early_data;
        /* Is the session suitable for early data? */
        int early_data_ok;

        /* May be sent by a server in HRR. Must be echoed back in ClientHello */
        unsigned char *tls13_cookie;
        size_t tls13_cookie_len;
        /* Have we received a cookie from the client? */
        int cookieok;

        /*
         * Maximum Fragment Length as per RFC 4366.
         * If this member contains one of the allowed values (1-4)
         * then we should include Maximum Fragment Length Negotiation
         * extension in Client Hello.
         * Please note that value of this member does not have direct
         * effect. The actual (binding) value is stored in SSL_SESSION,
         * as this extension is optional on server side.
         */
        uint8_t max_fragment_len_mode;

        /*
         * On the client side the number of ticket identities we sent in the
         * ClientHello. On the server side the identity of the ticket we
         * selected.
         */
        int tick_identity;
    } ext;

    /*
     * Parsed form of the ClientHello, kept around across client_hello_cb
     * calls.
     */
    CLIENTHELLO_MSG *clienthello;

    /*-
     * no further mod of servername
     * 0 : call the servername extension callback.
     * 1 : prepare 2, allow last ack just after in server callback.
     * 2 : don't call servername callback, no ack in server hello
     */
    int servername_done;
# ifndef OPENSSL_NO_CT
    /*
     * Validates that the SCTs (Signed Certificate Timestamps) are sufficient.
     * If they are not, the connection should be aborted.
     */
    ssl_ct_validation_cb ct_validation_callback;
    /* User-supplied argument that is passed to the ct_validation_callback */
    void *ct_validation_callback_arg;
    /*
     * Consolidated stack of SCTs from all sources.
     * Lazily populated by CT_get_peer_scts(SSL*)
     */
    STACK_OF(SCT) *scts;
    /* Have we attempted to find/parse SCTs yet? */
    int scts_parsed;
# endif
    SSL_CTX *session_ctx;       /* initial ctx, used to store sessions */
# ifndef OPENSSL_NO_SRTP
    /* What we'll do */
    STACK_OF(SRTP_PROTECTION_PROFILE) *srtp_profiles;
    /* What's been chosen */
    SRTP_PROTECTION_PROFILE *srtp_profile;
# endif
    /*-
     * 1 if we are renegotiating.
     * 2 if we are a server and are inside a handshake
     * (i.e. not just sending a HelloRequest)
     */
    int renegotiate;
    /* If sending a KeyUpdate is pending */
    int key_update;
    /* Post-handshake authentication state */
    SSL_PHA_STATE post_handshake_auth;
    int pha_enabled;
    uint8_t* pha_context;
    size_t pha_context_len;
    int certreqs_sent;
    EVP_MD_CTX *pha_dgst; /* this is just the digest through ClientFinished */

# ifndef OPENSSL_NO_SRP
    /* ctx for SRP authentication */
    SRP_CTX srp_ctx;
# endif
    /*
     * Callback for disabling session caching and ticket support on a session
     * basis, depending on the chosen cipher.
     */
    int (*not_resumable_session_cb) (SSL *ssl, int is_forward_secure);
    RECORD_LAYER rlayer;
    /* Default password callback. */
    pem_password_cb *default_passwd_callback;
    /* Default password callback user data. */
    void *default_passwd_callback_userdata;
    /* Async Job info */
    ASYNC_JOB *job;
    ASYNC_WAIT_CTX *waitctx;
    size_t asyncrw;

    /*
     * The maximum number of bytes advertised in session tickets that can be
     * sent as early data.
     */
    uint32_t max_early_data;
    /*
     * The maximum number of bytes of early data that a server will tolerate
     * (which should be at least as much as max_early_data).
     */
    uint32_t recv_max_early_data;

    /*
     * The number of bytes of early data received so far. If we accepted early
     * data then this is a count of the plaintext bytes. If we rejected it then
     * this is a count of the ciphertext bytes.
     */
    uint32_t early_data_count;

    /* TLS1.3 padding callback */
    size_t (*record_padding_cb)(SSL *s, int type, size_t len, void *arg);
    void *record_padding_arg;
    size_t block_padding;

    CRYPTO_RWLOCK *lock;

    /* The number of TLS1.3 tickets to automatically send */
    size_t num_tickets;
    /* The number of TLS1.3 tickets actually sent so far */
    size_t sent_tickets;
    /* The next nonce value to use when we send a ticket on this connection */
    uint64_t next_ticket_nonce;

    /* Callback to determine if early_data is acceptable or not */
    SSL_allow_early_data_cb_fn allow_early_data_cb;
    void *allow_early_data_cb_data;

    /*
     * Signature algorithms shared by client and server: cached because these
     * are used most often.
     */
    const struct sigalg_lookup_st **shared_sigalgs;
    size_t shared_sigalgslen;
};
```



Session:

```c
struct ssl_session_st {
    int ssl_version;            /* what ssl version session info is being kept
                                 * in here? */
    size_t master_key_length;

    /* TLSv1.3 early_secret used for external PSKs */
    unsigned char early_secret[EVP_MAX_MD_SIZE];
    /*
     * For <=TLS1.2 this is the master_key. For TLS1.3 this is the resumption
     * PSK
     */
    unsigned char master_key[TLS13_MAX_RESUMPTION_PSK_LENGTH];
    /* session_id - valid? */
    size_t session_id_length;
    unsigned char session_id[SSL_MAX_SSL_SESSION_ID_LENGTH];
    /*
     * this is used to determine whether the session is being reused in the
     * appropriate context. It is up to the application to set this, via
     * SSL_new
     */
    size_t sid_ctx_length;
    unsigned char sid_ctx[SSL_MAX_SID_CTX_LENGTH];
# ifndef OPENSSL_NO_PSK
    char *psk_identity_hint;
    char *psk_identity;
# endif
    /*
     * Used to indicate that session resumption is not allowed. Applications
     * can also set this bit for a new session via not_resumable_session_cb
     * to disable session caching and tickets.
     */
    int not_resumable;
    /* This is the cert and type for the other end. */
    X509 *peer;
    /* Certificate chain peer sent. */
    STACK_OF(X509) *peer_chain;
    /*
     * when app_verify_callback accepts a session where the peer's
     * certificate is not ok, we must remember the error for session reuse:
     */
    long verify_result;         /* only for servers */
    CRYPTO_REF_COUNT references;
    long timeout;
    long time;
    unsigned int compress_meth; /* Need to lookup the method */
    const SSL_CIPHER *cipher;
    unsigned long cipher_id;    /* when ASN.1 loaded, this needs to be used to
                                 * load the 'cipher' structure */
    CRYPTO_EX_DATA ex_data;     /* application specific data */
    /*
     * These are used to make removal of session-ids more efficient and to
     * implement a maximum cache size.
     */
    struct ssl_session_st *prev, *next;

    struct {
        char *hostname;
        /* RFC4507 info */
        unsigned char *tick; /* Session ticket */
        size_t ticklen;      /* Session ticket length */
        /* Session lifetime hint in seconds */
        unsigned long tick_lifetime_hint;
        uint32_t tick_age_add;
        /* Max number of bytes that can be sent as early data */
        uint32_t max_early_data;
        /* The ALPN protocol selected for this session */
        unsigned char *alpn_selected;
        size_t alpn_selected_len;
        /*
         * Maximum Fragment Length as per RFC 4366.
         * If this value does not contain RFC 4366 allowed values (1-4) then
         * either the Maximum Fragment Length Negotiation failed or was not
         * performed at all.
         */
        uint8_t max_fragment_len_mode;
    } ext;
# ifndef OPENSSL_NO_SRP
    char *srp_username;
# endif
    unsigned char *ticket_appdata;
    size_t ticket_appdata_len;
    uint32_t flags;
    CRYPTO_RWLOCK *lock;
};
```