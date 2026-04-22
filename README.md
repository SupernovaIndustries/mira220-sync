# mira220-sync — MIRA220 Driver con supporto Master/Slave

Driver kernel modificato e overlay Device Tree per sincronizzazione hardware di due sensori MIRA220 su Raspberry Pi CM5.

## Modifiche al driver

Aggiunta lettura della proprietà DT `ams,trigger-mode` e scrittura condizionale del registro 0x1003:

| trigger-mode | Registro 0x1003 | Comportamento |
|---|---|---|
| `<0>` o assente | 0x10 | Master — free-running |
| `<1>` | 0x08 | Slave — external trigger |

## Overlay

L'overlay `mira220-sync` segue il pattern RPi standard con override `cam0`/`cam1` e aggiunge il parametro `trigger-mode`.

## Build e installazione sul Raspberry Pi

### Prerequisiti

```bash
sudo apt install linux-headers-$(uname -r) device-tree-compiler
```

### Driver

```bash
cd mira220-sync/driver/
sudo cp /lib/modules/$(uname -r)/kernel/drivers/media/i2c/mira220.ko \
        /lib/modules/$(uname -r)/kernel/drivers/media/i2c/mira220.ko.bak
make
sudo cp mira220.ko /lib/modules/$(uname -r)/kernel/drivers/media/i2c/
sudo depmod -a
```

### Overlay

```bash
cd ../overlay/
dtc -@ -I dts -O dtb -o mira220-sync.dtbo mira220-sync.dts
sudo cp mira220-sync.dtbo /boot/firmware/overlays/
```

### config.txt

```bash
sudo nano /boot/firmware/config.txt
```

```ini
camera_auto_detect=0
dtparam=i2c_arm=on
dtoverlay=mira220-sync,cam0
dtoverlay=mira220-sync,trigger-mode=1
dtoverlay=vc4-kms-v3d
dtoverlay=dwc2,dr_mode=host
```

Il primo `dtoverlay` carica cam0 come master (trigger-mode=0 di default, attiva `cam0_reg` always-on).
Il secondo carica cam1 come slave (trigger-mode=1, cam1 è la porta di default).

```bash
sudo reboot
```

### Verifica

```bash
dmesg | grep -i "trigger mode\|MASTER mode\|SLAVE mode"
v4l2-ctl --list-devices
libcamera-still --camera 0 -o test_cam0.jpg
libcamera-still --camera 1 -o test_cam1.jpg
```

## Struttura

```
mira220-sync/
├── driver/
│   ├── mira220.c        # Driver con supporto ams,trigger-mode
│   └── Makefile
├── overlay/
│   └── mira220-sync.dts # Overlay con override cam0/cam1 + trigger-mode
└── README.md
```

## Note tecniche

- Kernel: 6.12.47+rpt-rpi-2712 (aarch64)
- I2C addr: 0x54, registro sync: 0x1003
- Link frequency: 750 MHz, 2 data lanes
- cam0_reg: GPIO 34 always-on (attivato dall'override `cam0`)
- cam1 enable: pull-up hardware R8 2.2K a 3V3
