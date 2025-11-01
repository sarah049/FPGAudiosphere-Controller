import scipy.io
import numpy as np
import mmap

# hrir_r = hrir_right_struct["hrir_r"][0]
# print("hrirr", len(hrir_r), len(hrir_r[0]))

hrir_right_mem = "./overlord/hrir/hrir_r_bs30_azi_full.mem"
img_mem = "./overlord/util/palette2.mem"

# with open(img_mem, "r+b") as f:
#     img_m = mmap.mmap(f.fileno(), 0)
#     # Now you can access the content of the file as if it were a bytearray
#     val = img_m[:8]
#     print(type(val))
#     print(val)  # Print the first 10 bytes
#     print(int.from_bytes(val, byteorder='big', signed=True))
#     img_m.close()


with open(hrir_right_mem, "r+b") as f:
    hr_m = mmap.mmap(f.fileno(), 0)
    # Now you can access the content of the file as if it were a bytearray
    convolved_sums = []
    total = 0
    for j in range(10):
      for i in range(200):
          temp = hr_m[9*(i+j):9*(i+j)+8]
          total += int(temp.decode('utf-8'), 16)
      convolved_sums.append(hex(total)) 
    print(convolved_sums)
    hr_m.close()
    # val = hr_m[:16]
    # print(val)  # Print the first 10 bytes
    # print(int.from_bytes(val, byteorder='big', signed=True))

'''
#summed values of convolutions, first 10 sets - GROUND TRUTH
# base 10: 
    [523447488308, 
    1046894976616, 
    1570342464924, 
    2093789953232, 
    2617237441540, 
    3140684929830, 
    3664132418006, 
    4183284940122, 
    4706732424914, 
    5230179946945]
#base 16:
['0x79dfe6cf34', 
'0xf3bfcd9e68', 
'0x16d9fb46d9c', 
'0x1e77f9b3cd0', 
'0x2615f820c04', 
'0x2db3f68db26', 
'0x3551f4fa9d6', 
'0x3cdff367d5a', 
'0x447df1d3ed2', 
'0x4c1bf0491c1']
'''


