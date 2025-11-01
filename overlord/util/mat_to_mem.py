import scipy.io
import numpy as np
import os
import mmap
# print("Current working directory:", os.getcwd())

# Ensure the directory exists
if not os.path.exists('./overlord/hrir'):
    # os.makedirs('hrir')
    print('overlord not found')


# hrir_data_raw_l = scipy.io.loadmat('../hrir/proc_hrir_l_bs30.mat')
# #slice along elevational dimension -> 8th angle = 0 deg elev
# hrir_data_l = hrir_data_raw_l['hrir_l'][:,8,:] 
# print(len(hrir_data_l[0])) # need to slice the data [25, 50, 200] currently
# print(type(hrir_data_l[0]))
    
    #not actually used
def int_to_hexstring(value, num_bits=32):
    # If the value is negative, we need to get its two's complement representation.
    # print(value)
    if value < 0:
        # Calculate two's complement for negative numbers
        value = (1 << num_bits) + value
    # Convert the integer to a binary string, remove the "0b" prefix, and pad with leading zeros
    bitstring = bin(value)[2:].zfill(num_bits)
    
    int_val = int(bitstring, 2)
    hex_value = hex(int_val)[2:].zfill(num_bits//4) # removes '0x'
    
    print(hex_value)
    return hex_value


hrir_data_raw_l = scipy.io.loadmat('./overlord/hrir/mat_load_proc_data/proc_hrir_l_bs30.mat')
hrir_data_raw_r = scipy.io.loadmat('./overlord/hrir/mat_load_proc_data/proc_hrir_r_bs30.mat')
#slice along elevational dimension -> 8th angle = 0 deg elev
hrir_data_l = hrir_data_raw_l['hrir_l']
hrir_data_r = hrir_data_raw_r['hrir_r']
print(np.shape(hrir_data_l))
width = 32

left_mem_file = f'./overlord/hrir/hrir_l_bs30_azi_full.mem'
right_mem_file = f'./overlord/hrir/hrir_r_bs30_azi_full.mem'

# mat_data_32bit = hrir_data_r.astype(np.int32)

with open(left_mem_file, 'w') as f:
    
    azi_slice = hrir_data_l #array of 200 values for each azimuth
    # mat_data_32bit.tofile(f)
    # # Write the address and data pairs in hexadecimal format
    len_azi = len(azi_slice)
    print(len_azi)
    assert len_azi == 5000, f"not 5000 {len_azi}"

    for num in azi_slice:
    #     # Convert data to hex, and address in UNS (unsigned) format
    #     # The format assumes a 32-bit width, adjust the formatting as needed
        # hexstring = int_to_hexstring(num, num_bits=32)
        f.write(f'{num}\n')


# count = 0
# with open(mem_file, "r+b") as f:
#     img_m = mmap.mmap(f.fileno(), 0)
#     print(len(img_m))
# print(count)
#for individual .mem files for each azimuth
'''
for azimuth in range(25):
    mem_file = f'../hrir/hrir_l_bs30_azi_ix{azimuth}.mem'
    with open(mem_file, 'w') as f:
        
        # Write the address and data pairs in hexadecimal format
        azi_slice = hrir_data_l[azimuth,:]
        for i in range(len(azi_slice)):
            # Convert data to hex, and address in UNS (unsigned) format
            # The format assumes a 32-bit width, adjust the formatting as needed
            f.write(f'  {i:04X} : {azi_slice[i]:0{width//4}X};\n')
        
        f.write('END;\n')
'''

print(f"File saved to: {os.path.abspath(left_mem_file)}")
