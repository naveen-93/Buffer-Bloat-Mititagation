obj-m += fq_codel_plus.o

KERNELDIR ?= /lib/modules/$(shell uname -r)/build
PWD := $(shell pwd)
INCLUDE_DIR := $(PWD)/../include

ccflags-y := -I$(INCLUDE_DIR)

all:
	make -C $(KERNELDIR) M=$(PWD) modules

clean:
	make -C $(KERNELDIR) M=$(PWD) clean
