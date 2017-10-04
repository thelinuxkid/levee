size_t
sp_ws_mask (void *dst, const void *restrict buf, size_t len, const uint8_t *key);

ssize_t
sp_ws_enc_ping (void *buf, size_t len, const uint8_t *key);

ssize_t
sp_ws_enc_pong (void *buf, size_t len, const uint8_t *key);
