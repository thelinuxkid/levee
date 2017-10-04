typedef enum {
	SpWsNonCtrlType = 0x0,
	SpWsCtrlType = 0x8
} SpWsOpcode;

typedef enum {
	SP_WS_CONT = SpWsNonCtrlType,
	SP_WS_TEXT,
	SP_WS_BIN,
} SpWsNonCtrlOpcode;

typedef enum {
	SP_WS_CLOSE = SpWsCtrlType,
	SP_WS_PING,
	SP_WS_PONG,
} SpWsCtrlOpcode;

typedef enum {
	SP_WS_LEN_NONE = 0,
	SP_WS_LEN_7,
	SP_WS_LEN_16,
	SP_WS_LEN_64,
} SpWsLenType;


typedef enum {
	SP_WS_STATUS_NONE   = 0,
	SP_WS_STATUS_NORMAL = 1000,
	SP_WS_STATUS_AWAY   = 1001,
	SP_WS_STATUS_PROTO  = 1002,
	SP_WS_STATUS_TYPE   = 1004,
	SP_WS_STATUS_DATA   = 1007,
	SP_WS_STATUS_POLICY = 1008,
	SP_WS_STATUS_BIG    = 1009,
	SP_WS_STATUS_EXT    = 1010,
	SP_WS_STATUS_FAIL   = 1011,
} SpWsStatus;

typedef struct {
	// frame metadata
	bool fin;
	bool rsv1;
	bool rsv2;
	bool rsv3;
	SpWsOpcode opcode;
	bool masked;

	// 7-bit payload length or extended 16-bit/64-bit payload length
	struct {
		SpWsLenType type;  // the type of the payload length
		union {
			uint8_t u7;      // 0 <= encoded paylen <= 125
			uint16_t u16;    // encoded paylen == 126
			uint64_t u64;    // encoded paylen == 127
		} len;
	} paylen;

	// masking key
	uint8_t mask_key[4];
} SpWsFrame;

// parser states
typedef enum {
	SP_WS_NONE = -1,
	SP_WS_META,          // FIN flag, 3 RSV flags, opcode, MASK flag, lencode
	SP_WS_PAYLEN,        // length of the payload
	SP_WS_MASK_KEY,      // masking key, for servers only
} SpWsType;

typedef struct {
	// readonly
	uint16_t scans;      // number of passes through the scanner
	uint8_t cscans;      // number of scans in the current rule
	SpWsFrame as;        // captured value
	SpWsType type;       // type of the captured value
	unsigned cs;         // current scanner state
	size_t off;          // internal offset mark
} SpWs;

size_t
sp_ws_mask (void *dst, const void *restrict buf, size_t len, const uint8_t *key);

ssize_t
sp_ws_enc_ping (void *buf, size_t len, const uint8_t *key);

ssize_t
sp_ws_enc_pong (void *buf, size_t len, const uint8_t *key);

ssize_t
sp_ws_enc_frame (void *buf, const SpWsFrame *f);
