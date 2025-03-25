#include <linux/module.h>
#include <linux/kernel.h>
#include <linux/init.h>
#include <linux/netdevice.h>
#include <linux/skbuff.h>
#include <net/sch_generic.h>
#include <net/pkt_sched.h>
#include "../include/fq_codel_plus.h"

// Forward declaration of the qdisc operations
static struct Qdisc_ops fq_codel_plus_qdisc_ops;

static int fq_codel_plus_enqueue(struct sk_buff *skb, struct Qdisc *sch, struct sk_buff **to_free)
{
    struct simple_buffer_qdisc *q = qdisc_priv(sch);

    // Drop packet if queue exceeds limit (simplified buffer control)
    if (sch->q.qlen >= MAX_QUEUE_LEN) {
        qdisc_drop(skb, sch, to_free);
        sch->qstats.drops++;
        printk(KERN_INFO "fq_codel_plus: Packet dropped, queue full\n");
        return NET_XMIT_DROP;
    }

    // Add packet to the queue
    __skb_queue_tail(&q->queue, skb);
    sch->qstats.backlog += skb->len;
    sch->q.qlen++;
    printk(KERN_INFO "fq_codel_plus: Packet enqueued, qlen=%d\n", sch->q.qlen);
    return NET_XMIT_SUCCESS;
}

static struct sk_buff *fq_codel_plus_dequeue(struct Qdisc *sch)
{
    struct simple_buffer_qdisc *q = qdisc_priv(sch);
    struct sk_buff *skb = __skb_dequeue(&q->queue);

    if (skb) {
        sch->qstats.backlog -= skb->len;
        sch->q.qlen--;
        printk(KERN_INFO "fq_codel_plus: Packet dequeued, qlen=%d\n", sch->q.qlen);
    }
    return skb;
}

static int fq_codel_plus_init(struct Qdisc *sch, struct nlattr *opt, struct netlink_ext_ack *extack)
{
    struct simple_buffer_qdisc *q = qdisc_priv(sch);
    
    // Initialize the queue
    skb_queue_head_init(&q->queue);
    
    // Initialize qdisc statistics
    sch->qstats.backlog = 0;
    sch->q.qlen = 0;
    
    printk(KERN_INFO "fq_codel_plus: Qdisc initialized\n");
    return 0;
}

static void fq_codel_plus_reset(struct Qdisc *sch)
{
    struct simple_buffer_qdisc *q = qdisc_priv(sch);
    skb_queue_purge(&q->queue);
    sch->qstats.backlog = 0;
    sch->q.qlen = 0;
    printk(KERN_INFO "fq_codel_plus: Qdisc reset\n");
}

static void fq_codel_plus_destroy(struct Qdisc *sch)
{
    struct simple_buffer_qdisc *q = qdisc_priv(sch);
    skb_queue_purge(&q->queue);
    printk(KERN_INFO "fq_codel_plus: Qdisc destroyed\n");
}

// Required for peek operation
static struct sk_buff *fq_codel_plus_peek(struct Qdisc *sch)
{
    struct simple_buffer_qdisc *q = qdisc_priv(sch);
    return skb_peek(&q->queue);
}

// Required dump function
static int fq_codel_plus_dump(struct Qdisc *sch, struct sk_buff *skb)
{
    return 0;  // No parameters to dump
}

// Required change function
static int fq_codel_plus_change(struct Qdisc *sch, struct nlattr *opt, struct netlink_ext_ack *extack)
{
    return 0;  // No parameters to change
}

static struct Qdisc_ops fq_codel_plus_qdisc_ops = {
    .id         = "fqcodel+",
    .priv_size  = sizeof(struct simple_buffer_qdisc),
    .enqueue    = fq_codel_plus_enqueue,
    .dequeue    = fq_codel_plus_dequeue,
    .peek       = fq_codel_plus_peek,
    .init       = fq_codel_plus_init,
    .reset      = fq_codel_plus_reset,
    .destroy    = fq_codel_plus_destroy,
    .change     = fq_codel_plus_change,
    .dump       = fq_codel_plus_dump,
    .owner      = THIS_MODULE,
};

static int __init fq_codel_plus_module_init(void)
{
    printk(KERN_INFO "fq_codel_plus: Attempting to register qdisc...\n");
    int ret = register_qdisc(&fq_codel_plus_qdisc_ops);
    if (ret == 0)
        printk(KERN_INFO "fq_codel_plus: Module loaded and qdisc registered successfully!\n");
    else
        printk(KERN_ERR "fq_codel_plus: Failed to register qdisc (error %d)\n", ret);
    return ret;
}

static void __exit fq_codel_plus_module_exit(void)
{
    unregister_qdisc(&fq_codel_plus_qdisc_ops);
    printk(KERN_INFO "fq_codel_plus: Module unloaded and qdisc unregistered\n");
}

module_init(fq_codel_plus_module_init);
module_exit(fq_codel_plus_module_exit);

MODULE_LICENSE("GPL");
MODULE_AUTHOR("Naveen");
MODULE_DESCRIPTION("An enhanced FQ-CoDel qdisc implementation");
