#!/bin/bash
# unlook-sync-test.sh — Test manuale sync MIRA220 master/slave
# Eseguire PRIMA di avviare le camere
# Prerequisito: driver standard mira220 (NON mira220-sync) in config.txt

CAM0_BUS=10    # master — i2c@88000
CAM1_BUS=0     # slave  — i2c@70000
ADDR=0x54

echo "=== Unlook MIRA220 Sync Setup ==="

# 1. Master: Master Exposure Control Mode (0x10)
echo -n "Master 0x1003 = 0x10 ... "
i2ctransfer -f -y $CAM0_BUS w3@$ADDR 0x10 0x03 0x10 && echo "OK" || echo "FAIL"

# 2. Slave: Slave Exposure Control Mode (0x08)
echo -n "Slave  0x1003 = 0x08 ... "
i2ctransfer -f -y $CAM1_BUS w3@$ADDR 0x10 0x03 0x08 && echo "OK" || echo "FAIL"

# 3. FIX CRITICO — Slave: EXT_EXP_PW_SEL=1 (reg 0x1001 bit[0])
#    Esposizione da registro EXP_TIME, non da durata pulse REQ_EXP
echo -n "Slave  0x1001 = 0x01 ... "
i2ctransfer -f -y $CAM1_BUS w3@$ADDR 0x10 0x01 0x01 && echo "OK" || echo "FAIL"

# 4. Verifica
echo ""
echo "=== Verifica registri ==="
echo -n "Master 0x1003: "; i2ctransfer -f -y $CAM0_BUS w2@$ADDR 0x10 0x03 r1
echo -n "Slave  0x1003: "; i2ctransfer -f -y $CAM1_BUS w2@$ADDR 0x10 0x03 r1
echo -n "Slave  0x1001: "; i2ctransfer -f -y $CAM1_BUS w2@$ADDR 0x10 0x01 r1

echo ""
echo "=== Pronto — avvia le camere ==="
echo "Ricorda: attiva gli switch sync (pos 2) e collega il cavo JST"
