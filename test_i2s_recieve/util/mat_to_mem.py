import scipy.io
import numpy as np
import os
# print("Current working directory:", os.getcwd())

# Ensure the directory exists
if not os.path.exists('../hrir'):
    # os.makedirs('hrir')
    print('not found')


hrir_data_raw_l = scipy.io.loadmat('../hrir/proc_hrir_l_bs30.mat')
#slice along elevational dimension -> 8th angle = 0 deg elev
hrir_data_l = hrir_data_raw_l['hrir_l'][:,8,:] 
# print(len(hrir_data_l[0])) # need to slice the data [25, 50, 200] currently
# print(type(hrir_data_l[0]))

width = 32


mem_file = f'../hrir/hrir_l_bs30_azi_full.mem'

for azimuth in range(25):
    with open(mem_file, 'w') as f:
        
        azi_slice = hrir_data_l[azimuth,:] #array of 200 values for each azimuth

        # Write the address and data pairs in hexadecimal format
        for i in range(len(azi_slice)):
            # Convert data to hex, and address in UNS (unsigned) format
            # The format assumes a 32-bit width, adjust the formatting as needed
            f.write(f' {azi_slice[i]:0{width//4}X}\n')
        
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

print(f"File saved to: {os.path.abspath(mem_file)}")
