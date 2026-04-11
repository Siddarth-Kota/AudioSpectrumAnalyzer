import numpy as np
FFT_SIZE = 1024 
window_float = np.hanning(FFT_SIZE)
window_int = np.int16(window_float * 32767)

with open(r"C:\Users\sidko\Desktop\GitHub\EE271Project\window_coeffs.mem", "w") as f:
    for val in window_int:
        hex_val = f"{int(val) & 0xFFFF:04X}"
        f.write(f"{hex_val}\n")

print("window_coeffs.mem generated successfully!")