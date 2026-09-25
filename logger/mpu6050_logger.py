# runs on the pico, reads the MPU6050 over i2c at 100 Hz and logs it to a csv on the pico
# press the button to start a trial, press again to stop and save it
from machine import SoftI2C, Pin
import struct
import time
import os


I2C_SDA = 4
I2C_SCL = 5
MPU_ADDR = 0x68
SAMPLE_INTERVAL_MS = 10  # 10ms per sample = 100 Hz
CALIB_SAMPLES = 500  # 5s of sitting still to figure out the sensor offsets
BUTTON_PIN = 15

# MPU6050 register addresses from the datasheet
PWR_MGMT_1   = 0x6B
ACCEL_CONFIG = 0x1C
GYRO_CONFIG  = 0x1B
CONFIG_REG   = 0x1A
ACCEL_XOUT_H = 0x3B

# at +-8g the accel gives 4096 per g, so this turns raw counts into m/s^2
# at +-500 deg/s the gyro gives 65.5 per deg/s
ACCEL_SCALE = 9.81 / 4096.0
GYRO_SCALE  = 1.0  / 65.5


i2c = SoftI2C(sda=Pin(I2C_SDA), scl=Pin(I2C_SCL), freq=100000)
btn = Pin(BUTTON_PIN, Pin.IN, Pin.PULL_UP)  # pull up so the pin reads 0 when pressed
led = Pin(25, Pin.OUT)  # onboard led, used as a status light since theres no screen

# if the sensor isnt wired right just blink fast forever so i know
devices = i2c.scan()
if MPU_ADDR not in devices:
    while True:
        led.toggle()
        time.sleep_ms(100)

def write_reg(reg, val):
    i2c.writeto_mem(MPU_ADDR, reg, bytes([val]))

# one 14 byte read gets accel xyz, temp and gyro xyz all at once, big endian signed 16 bit
# vals[3] is the temperature so it gets skipped
def read_raw():
    buf = i2c.readfrom_mem(MPU_ADDR, ACCEL_XOUT_H, 14)
    vals = struct.unpack('>hhhhhhh', buf)
    return vals[0], vals[1], vals[2], vals[4], vals[5], vals[6]

# trial_01.csv, trial_02.csv... picks the first number thats not taken so nothing gets overwritten
def next_filename():
    n = 1
    while True:
        name = "trial_{:02d}.csv".format(n)
        try:
            os.stat(name)
            n += 1
        except OSError:
            return name

# reset the chip first, it can throw right as it resets so thats ignored
try:
    write_reg(PWR_MGMT_1, 0x80)
except:
    pass
time.sleep_ms(200)
write_reg(PWR_MGMT_1, 0x00)  # wake it up, it starts in sleep mode
time.sleep_ms(100)
write_reg(ACCEL_CONFIG, 0x10)  # +-8g range, dribbling impacts go way past 2g
write_reg(GYRO_CONFIG,  0x08)  # +-500 deg/s range
write_reg(CONFIG_REG,   0x04)  # built in low pass filter to cut some noise
time.sleep_ms(100)

print("Calibrating")
time.sleep(1)

# average a bunch of readings while its sitting still, that average is the offset
sax = 0; say = 0; saz = 0
sgx = 0; sgy = 0; sgz = 0

for i in range(CALIB_SAMPLES):
    rax, ray, raz, rgx, rgy, rgz = read_raw()
    sax += rax; say += ray; saz += raz
    sgx += rgx; sgy += rgy; sgz += rgz
    time.sleep_ms(SAMPLE_INTERVAL_MS)
    if i % 50 == 0:
        led.toggle()  # slow blink while calibrating

# z axis is pointing up during calibration so it should read 1g, not 0
ax_off = sax / CALIB_SAMPLES
ay_off = say / CALIB_SAMPLES
az_off = (saz / CALIB_SAMPLES) - (1.0 / ACCEL_SCALE)
gx_off = sgx / CALIB_SAMPLES
gy_off = sgy / CALIB_SAMPLES
gz_off = sgz / CALIB_SAMPLES

print("Calibration done.")
for _ in range(10):
    led.toggle()
    time.sleep_ms(100)
led.on()
print("Press button to start/stop recording.")


recording    = False
last_btn     = 1
f            = None
sample_count = 0

while True:
    # only trigger on the press itself (1 -> 0) not the whole time its held down
    cur_btn = btn.value()
    if last_btn == 1 and cur_btn == 0:
        recording = not recording
        if recording:
            fname = next_filename()
            f = open(fname, 'w')
            f.write("timestamp_ms,ax,ay,az,gx,gy,gz\n")
            start = time.ticks_ms()
            sample_count = 0
            led.on()
            print("RECORDING - " + fname)
        else:
            f.close()
            f = None
            for _ in range(5):  # quick blinks so i know it saved
                led.off(); time.sleep_ms(80)
                led.on();  time.sleep_ms(80)
            led.on()
            print("SAVED {} ({} samples)".format(fname, sample_count))
        time.sleep_ms(200)  # debounce so one press doesnt count twice
    last_btn = cur_btn

    if not recording:
        time.sleep_ms(10)
        continue

    t_before  = time.ticks_ms()
    timestamp = time.ticks_diff(t_before, start)  # ticks_diff handles the timer wrapping around
    rax, ray, raz, rgx, rgy, rgz = read_raw()

    ax = (rax - ax_off) * ACCEL_SCALE
    ay = (ray - ay_off) * ACCEL_SCALE
    az = (raz - az_off) * ACCEL_SCALE
    gx = (rgx - gx_off) * GYRO_SCALE
    gy = (rgy - gy_off) * GYRO_SCALE
    gz = (rgz - gz_off) * GYRO_SCALE

    line = "{},{:.4f},{:.4f},{:.4f},{:.4f},{:.4f},{:.4f}\n".format(
        timestamp, ax, ay, az, gx, gy, gz)
    f.write(line)
    sample_count += 1
    # flush every 50 rows so if the battery dies you only lose half a second of data
    if sample_count % 50 == 0:
        f.flush()
    # measure how long this loop took and only sleep whats left, so it stays at 100 Hz
    # a fixed 10ms sleep would drift slower since the i2c read and file write take time too
    elapsed = time.ticks_diff(time.ticks_ms(), t_before)
    wait    = SAMPLE_INTERVAL_MS - elapsed
    if wait > 0:
        time.sleep_ms(wait)
