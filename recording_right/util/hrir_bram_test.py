import scipy.io
import numpy as np
import mmap

hrir_struct = scipy.io.loadmat('./overlord/hrir/hrir_final.mat')
# print (hrir_struct)
hrir_l = np.reshape(hrir_struct['hrir_l'], [50,25,200])
hrir_r = np.reshape(hrir_struct['hrir_r'], [50,25,200])

hrir_l = hrir_l[8,:,:].flatten() #becomes shape (5000,)
hrir_r = hrir_r[8,:,:].flatten() #becomes shape (5000,)

def pre_bitshift(val, num_bit_shift=30):
    return int(val * 2**num_bit_shift)

vectorized_func = np.vectorize(pre_bitshift)
bitshifted_hrir_l = vectorized_func(hrir_l) #ix: 8 = grab 0 deg elevational
bitshifted_hrir_r = vectorized_func(hrir_r)

def tohex(val, nbits=32):
  return hex((val + (1 << nbits)) % (1 << nbits))[2:]

for i in range(10,20):
    # print(i, tohex(bitshifted_hrir_l[i]), tohex(bitshifted_hrir_r[i]), bitshifted_hrir_l[i] == bitshifted_hrir_r[i])
   print(i, bitshifted_hrir_l[i]/hrir_l[i])

# Load the .mat file
# hrir_right_struct = scipy.io.loadmat('./overlord/hrir/mat_load_proc_data/proc_hrir_r_bs30.mat')

# hrir_struct = scipy.io.loadmat('./overlord/hrir/hrir_final.mat')
# hrir_r = hrir_struct['hrir_r'][0][8]



# hrir_r = hrir_right_struct["hrir_r"][0]
# print("hrirr", len(hrir_r), len(hrir_r[0]))

# hrir_right_mem = "./overlord/hrir/hrir_r_bs30_azi_full.mem"
# img_mem = "./overlord/util/palette2.mem"

# with open(img_mem, "r+b") as f:
#     img_m = mmap.mmap(f.fileno(), 0)
#     # Now you can access the content of the file as if it were a bytearray
#     val = img_m[:8]
#     print(type(val))
#     print(val)  # Print the first 10 bytes
#     print(int.from_bytes(val, byteorder='big', signed=True))
#     img_m.close()


# with open(hrir_right_mem, "r+b") as f:
#     hr_m = mmap.mmap(f.fileno(), 0)
#     # Now you can access the content of the file as if it were a bytearray
#     val = hr_m[:8]
#     print(val)  # Print the first 10 bytes
#     print(int.from_bytes(val, byteorder='big', signed=True))

#     hr_m.close()

[0x15555555, 0x2AAAAAA, 0x3FFFFFF, 0x5555554, 0x6AAAAA9, 0x7FFFFF, 0x9555553, 0xAAAAAA8, 0xBFFFFFD, 0x15555550,]

