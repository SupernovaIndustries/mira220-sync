# mira220-sync — MIRA220 Driver con supporto Master/Slave

Driver kernel modificato e overlay Device Tree per sincronizzazione hardware di due sensori MIRA220 su Raspberry Pi CM5.

Il modulo usa compatible `ams,mira220-sync` (diversa da `ams,mira220`), quindi non entra in conflitto con il driver originale. Per tornare al driver standard basta cambiare l'overlay in config.txt.

## Modifiche al driver

Aggiunta lettura della proprietà DT `ams,trigger-mode` e scrittura condizionale dei registri 0x1003 e 0x1001:

| trigger-mode | Reg 0x1003 | Reg 0x1001 | Comportamento |
|---|---|---|---|
| `<0>` o assente | 0x10 | — | Master — free-running, genera ILLUM_TRIGGER + FRAME_TRIGG |
| `<1>` | 0x08 | 0xD1 | Slave — external trigger, esposizione da registro EXP_TIME |

In slave mode, il registro 0x1001 viene impostato a 0xD1 (default 0xD0 + bit 0 EXT_EXP_PW_SEL). Il valore di default del registro dopo reset è 0xD0 (bit 7, 6, 4 attivi). IMAGER_STATE=0x08 potrebbe resettare questo registro, quindi viene riscritto dopo la transizione a slave mode con un breve delay. Il bit 0 attiva l'esposizione controllata dal registro EXP_TIME via I2C. Il bit 6 (EXT_EVENT_SEL=1) mantiene la modalità two-pin (REQ_FRAME attiva il readout). Questo permette a libcamera AEC di funzionare normalmente anche in modalità slave.

## Overlay

L'overlay `mira220-sync` segue il pattern RPi standard con override `cam0`/`cam1` e aggiunge il parametro `trigger-mode`.

## Build e installazione sul Raspberry Pi

### Prerequisiti

```bash
sudo apt install linux-headers-$(uname -r) device-tree-compiler
```

### Driver

```bash
cd ~/mira220-sync/driver/
make clean
make
sudo cp mira220-sync.ko /lib/modules/$(uname -r)/kernel/drivers/media/i2c/
sudo depmod -a
```

### Tuning file libcamera

Il driver si chiama `mira220-sync`, quindi libcamera cerca `mira220-sync.json`. Creare un symlink al tuning file originale:

```bash
sudo ln -s /usr/local/share/libcamera/ipa/rpi/pisp/mira220.json /usr/local/share/libcamera/ipa/rpi/pisp/mira220-sync.json
sudo ln -s /usr/local/share/libcamera/ipa/rpi/vc4/mira220.json /usr/local/share/libcamera/ipa/rpi/vc4/mira220-sync.json
```

### Overlay

```bash
cd ~/mira220-sync/overlay/
dtc -@ -I dts -O dtb -o mira220-sync.dtbo mira220-sync.dts
sudo cp mira220-sync.dtbo /boot/firmware/overlays/
```

I warning `unit_address_vs_reg` sui fragment sono normali e non influenzano il funzionamento.

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
# Verifica modulo e trigger mode
lsmod | grep mira220
dmesg | grep -i "trigger mode\|MASTER mode\|SLAVE mode"

# Verifica device
v4l2-ctl --list-devices
```

## Test cattura stereo

Lo slave dipende dal trigger del master: avviare sempre lo slave prima del master, e far girare il master più a lungo dello slave.

```bash
# Slave (cam1) parte prima, master (cam0) gira 1 secondo in più
rpicam-vid --camera 1 -t 5000 --mode 1600:1400:12:P --codec yuv420 -o /dev/null &
rpicam-vid --camera 0 -t 6000 --mode 1600:1400:12:P --codec yuv420 -o /dev/null &
wait
```

Per esposizione identica su entrambe le camere, fissare shutter e gain manualmente:

```bash
rpicam-vid --camera 1 -t 5000 --mode 1600:1400:12:P --codec yuv420 --shutter 5000 --gain 1.0 -o /dev/null &
rpicam-vid --camera 0 -t 6000 --mode 1600:1400:12:P --codec yuv420 --shutter 5000 --gain 1.0 -o /dev/null &
wait
```

## Struttura

```
mira220-sync/
├── driver/
│   ├── mira220-sync.c   # Driver con supporto ams,trigger-mode
│   └── Makefile
├── overlay/
│   └── mira220-sync.dts # Overlay con override cam0/cam1 + trigger-mode
└── README.md
```

## Note tecniche

- Kernel: 6.12.47+rpt-rpi-2712 (aarch64)
- Compatible: `ams,mira220-sync` (non conflittuale con driver originale `ams,mira220`)
- I2C addr: 0x54, registro sync: 0x1003
- Link frequency: 750 MHz, 2 data lanes
- cam0_reg: GPIO 34 always-on (attivato dall'override `cam0`)
- cam1 enable: pull-up hardware R8 2.2K a 3V3
- Sync hardware: cavo JST tra J6 (master) e J4 (slave) con segnali ILLUM_TRIGGER e FRAME_TRIGG
