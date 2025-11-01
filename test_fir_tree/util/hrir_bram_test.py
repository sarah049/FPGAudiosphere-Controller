import scipy.io
import numpy as np
import mmap

# hrir_r = hrir_right_struct["hrir_r"][0]
# print("hrirr", len(hrir_r), len(hrir_r[0]))

hrir_right_mem = "../hrir/hrir_r_bs30_azi_full.mem"
hrir_left_mem = "../hrir/hrir_l_bs30_azi_full.mem"
# img_mem = "./overlord/util/palette2.mem"

# with open(img_mem, "r+b") as f:
#     img_m = mmap.mmap(f.fileno(), 0)
#     # Now you can access the content of the file as if it were a bytearray
#     val = img_m[:8]
#     print(type(val))
#     print(val)  # Print the first 10 bytes
#     print(int.from_bytes(val, byteorder='big', signed=True))
#     img_m.close()


with open(hrir_left_mem, "r+b") as f:
    hr_m = mmap.mmap(f.fileno(), 0)
    # Now you can access the content of the file as if it were a bytearray
    bit_width = 32
    max_val = 2**(bit_width - 1)
    convolved_sums = []

    for j in range(10):
        total = 0
        for i in range(200):
            temp = hr_m[9*(i+j):9*(i+j)+8]
            val = int(temp.decode('utf-8'), 16)
            if val >= max_val:
            # If it's negative, subtract 2^bit_width to get the signed equivalent
                val  =  val - int(2**bit_width)
            total += val
        
            
        convolved_sums.append(total) 
    print(convolved_sums)
    hr_m.close()
    # val = hr_m[:16]
    # print(val)  # Print the first 10 bytes
    # print(int.from_bytes(val, byteorder='big', signed=True))

'''
#summed values of convolutions, first 10 sets - GROUND TRUTH

#left
#[-633010419, -633010419, -633010419, -633010419, -633010419, -633010460, -633010787, -633008156, -633025871, -632882944]
#

#right
# base 10: 
    [-538521804, -538521804, -538521804, -538521804, -538521804, -538521822, -538521936, -538520700, -538525320, -538488081]
#base 16:
['-0x201930cc', '-0x201930cc', '-0x201930cc', '-0x201930cc', '-0x201930cc', '-0x201930de', '-0x20193150', '-0x20192c7c', '-0x20193e88', '-0x2018ad11']
'''


