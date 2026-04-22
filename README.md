# Unlook CM5 — MIRA220 Stereo Sync Driver + Overlay

Driver kernel e overlay Device Tree per la piattaforma stereo camera **Unlook** basata su **Raspberry Pi CM5** con due sensori **MIRA220** (ams-OSRAM) global shutter.

## Architettura

```
CAM0 (J4) ─── CSI0 (i2c@88000 / csi@110000) ─── MASTER (free-running)
    │                                                 │
    │  JST cable (J6→J4)                              │
    │  ILLUM_TRIGGER + FRAME_TRIGG                    │
    ▼                                                 ▼
CAM1 (J2) ─── CSI1 (i2c@70000 / csi@128000) ─── SLAVE (external trigger)
```

Il sensore master opera in free-running e genera i segnali di sincronizzazione sulle uscite `ILLUM_TRIGGER` e `FRAME_TRIGG`. Il sensore slave riceve questi segnali e opera in external trigger mode (registro `0x1003 = 0x08`).

## Modifiche al driver

Il driver `mira220.c` è stato modificato per leggere la proprietà Device Tree `ams,trigger-mode`:

| Valore | Comportamento |
|--------|---------------|
| `<0>` o assente | Master — free-running (reg 0x1003 = 0x10) |
| `<1>` | Slave — external trigger (reg 0x1003 = 0x08) |

Il registro viene scritto in `mira220_write_start_streaming_regs()`, al momento giusto: dopo il power-on e prima dello streaming.

## Comandi per build e installazione sul Raspberry Pi

### Prerequisiti

```bash
sudo apt install linux-headers-$(uname -r) device-tree-compiler
```

### Build e installazione driver

```bash
cd mira220-sync/driver/

# Backup driver originale
sudo cp /lib/modules/$(uname -r)/kernel/drivers/media/i2c/mira220.ko \
        /lib/modules/$(uname -r)/kernel/drivers/media/i2c/mira220.ko.bak

# Compila
make

# Installa
sudo cp mira220.ko /lib/modules/$(uname -r)/kernel/drivers/media/i2c/
sudo depmod -a
```

### Build e installazione overlay

```bash
cd mira220-sync/overlay/

# Compila overlay
dtc -@ -I dts -O dtb -o unlook-cm5.dtbo unlook-cm5.dts

# Installa
sudo cp unlook-cm5.dtbo /boot/firmware/overlays/
```

### Configurazione config.txt

```bash
sudo nano /boot/firmware/config.txt
```

Assicurati che contenga (rimuovi/commenta eventuali `dtoverlay=mira220`):

```ini
camera_auto_detect=0
dtparam=i2c_arm=on
dtoverlay=unlook-cm5
dtoverlay=vc4-kms-v3d
dtoverlay=dwc2,dr_mode=host
```

### Riavvia

```bash
sudo reboot
```

## Verifica

```bash
# Verifica trigger mode nel log kernel
dmesg | grep -i "trigger mode\|MASTER mode\|SLAVE mode"

# Verifica device video
v4l2-ctl --list-devices

# Test cattura
libcamera-still --camera 0 -o test_cam0.jpg
libcamera-still --camera 1 -o test_cam1.jpg
```

## Fallback senza ricompilare il driver

Se vuoi testare la sync senza ricompilare, puoi scrivere il registro slave direttamente via i2cset:

```bash
sudo apt install i2c-tools

# Verifica che i sensori rispondano
i2cdetect -y 10    # cam0 master
i2cdetect -y 0     # cam1 slave

# Imposta cam1 in slave mode (reg 0x1003 = 0x08)
# Formato: i2cset -y <bus> <addr> <reg_high> <reg_low> <value> i
i2cset -y 0 0x54 0x10 0x03 0x08 i
```

Nota: va rieseguito ad ogni riavvio.

## Struttura progetto

```
unlook-mira220-sync/
├── driver/
│   ├── mira220.c      # Driver modificato con supporto trigger-mode
│   └── Makefile        # Compilazione nativa sul RPi
├── overlay/
│   └── unlook-cm5.dts  # Overlay DT per carrier board Unlook
└── README.md
```

## Note tecniche

- **Kernel target:** 6.12.47+rpt-rpi-2712 (Raspberry Pi OS Bookworm, aarch64)
- **Indirizzo I2C MIRA220:** 0x54 (7-bit)
- **Registro sync:** 0x1003 (16-bit address, 8-bit value)
- **Link frequency:** 750 MHz (2 data lanes + 1 clock lane)
- **cam0_reg:** GPIO 34, forzato always-on nell'overlay per attivare CAMEN
- **cam1 enable:** pull-up hardware R8 (2.2K a 3V3), non serve regolatore software
- **Licenza:** GPL v2

## Troubleshooting

**Il sensore slave non parte:**
- Verifica il cavo JST tra J6 (master) e J4 (slave)
- Controlla che `dmesg` mostri "Starting in SLAVE mode"
- Verifica con `i2cdetect -y 0` che il sensore risponda su i2c-0

**cam0 non si accende:**
- Verifica che `cam0_reg` sia always-on: `cat /sys/class/regulator/*/name` e controlla lo stato
- Il GPIO 34 deve essere HIGH

**Errore compilazione driver:**
- Assicurati di avere i kernel headers: `ls /lib/modules/$(uname -r)/build`
- Se mancano: `sudo apt install linux-headers-$(uname -r)`
