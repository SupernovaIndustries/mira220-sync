obj-m += mira220.o

KDIR := /lib/modules/$(shell uname -r)/build

all:
	make -C $(KDIR) M=$(PWD) modules

install:
	sudo cp mira220.ko /lib/modules/$(shell uname -r)/kernel/drivers/media/i2c/
	sudo depmod -a

clean:
	make -C $(KDIR) M=$(PWD) clean
