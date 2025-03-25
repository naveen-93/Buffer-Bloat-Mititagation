#ifndef FQ_CODEL_PLUS_H
#define FQ_CODEL_PLUS_H

#include <linux/types.h>

#define MAX_QUEUE_LEN 100  // Simple buffer limit

/* Main structure for fq_codel_plus qdisc */
struct simple_buffer_qdisc {
    struct sk_buff_head queue;  // Queue to hold packets
};

#endif /* FQ_CODEL_PLUS_H */
