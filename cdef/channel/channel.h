typedef volatile struct LeveeRef LeveeRef;

typedef struct LeveeChan LeveeChan;
typedef struct LeveeChanSender LeveeChanSender;

typedef enum {
	LEVEE_CHAN_EOF,
	LEVEE_CHAN_NIL,
	LEVEE_CHAN_PTR,
	LEVEE_CHAN_OBJ,
	LEVEE_CHAN_BUF,
	LEVEE_CHAN_DBL,
	LEVEE_CHAN_I64,
	LEVEE_CHAN_U64,
	LEVEE_CHAN_BOOL,
	LEVEE_CHAN_SND
} LeveeChanType;

typedef enum {
	LEVEE_CHAN_RAW,
	LEVEE_CHAN_MSGPACK
} LeveeChanFormat;

typedef struct {
	const void *val;
	uint32_t len;
	LeveeChanFormat fmt;
} LeveeChanPtr;

typedef struct {
	void *obj;
	void (*free)(void *obj);
} LeveeChanObj;

typedef struct {
	LeveeNode base;
	int64_t recv_id;
	LeveeChanType type;
	int error;
	union {
		LeveeChanPtr ptr;
		LeveeChanObj obj;
		double dbl;
		int64_t i64;
		uint64_t u64;
		bool b;
		LeveeChanSender *sender;
	} as;
} LeveeChanNode;

struct LeveeChan {
	LeveeList msg, senders;
	int64_t recv_id;
	int64_t chan_id;
	int loopfd;
};

struct LeveeChanSender {
	LeveeNode node;
	LeveeRef *chan;
	int64_t ref;
	int64_t recv_id;
	bool eof;
};

LeveeRef *
levee_chan_create (int loopfd);

LeveeChan *
levee_chan_ref (LeveeRef *self);

void
levee_chan_unref (LeveeRef *self);

void
levee_chan_close (LeveeRef *self);

uint64_t
levee_chan_event_id (LeveeRef *self);

int64_t
levee_chan_next_recv_id (LeveeRef *self);

LeveeChanSender *
levee_chan_sender_create (LeveeRef *self, int64_t recv_id);

LeveeChanSender *
levee_chan_sender_ref (LeveeChanSender *self);

void
levee_chan_sender_unref (LeveeChanSender *self);

int
levee_chan_sender_close (LeveeChanSender *self);

int
levee_chan_send_nil (LeveeChanSender *self, int err);

int
levee_chan_send_ptr (LeveeChanSender *self, int err,
		const void *val, uint32_t len,
		LeveeChanFormat fmt);

int
levee_chan_send_buf (LeveeChanSender *self, int err,
		LeveeBuffer *buf);

int
levee_chan_send_obj (LeveeChanSender *self, int err,
		void *obj, void (*free)(void *obj));

int
levee_chan_send_dbl (LeveeChanSender *self, int err, double val);

int
levee_chan_send_i64 (LeveeChanSender *self, int err, int64_t val);

int
levee_chan_send_u64 (LeveeChanSender *self, int err, uint64_t val);

int
levee_chan_send_bool (LeveeChanSender *self, int err, bool val);

int64_t
levee_chan_connect (LeveeChanSender *self, LeveeRef *chan);

LeveeChanNode *
levee_chan_recv (LeveeRef *self);

LeveeChanNode *
levee_chan_recv_next (LeveeChanNode *node);
