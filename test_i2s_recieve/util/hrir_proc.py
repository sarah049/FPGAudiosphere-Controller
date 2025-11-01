import scipy.io
import numpy as np

# Load the .mat file
hrir_struct = scipy.io.loadmat('../hrir/hrir_final.mat')
# print (hrir_struct)
hrir_l = hrir_struct['hrir_l']
hrir_r = hrir_struct['hrir_r']

pow10_to_bit2shift = {
    7: 24,
    8: 27,
    9: 30,
    12: 40
}

bit_shift = 30 # bit shift of 7
print(len(hrir_l[0][8]))
print([sum(list(map(abs,hrir_l[i][8]))) for i in range(25)])

# def pre_bitshift(val, num_bit_shift=bit_shift):
#     return int(val * 2**num_bit_shift)

# vectorized_func = np.vectorize(pre_bitshift)
# bitshifted_hrir_l = vectorized_func(hrir_l)
# bitshifted_hrir_r = vectorized_func(hrir_r)

# print(hrir_r, bitshifted_hrir_r)
# # print(np.min(abs(hrir_l[np.nonzero(hrir_l)]))) # --> 2.228909073397602e-12
# print(np.max(abs(bitshifted_hrir_r[np.nonzero(bitshifted_hrir_r)]))) # max int (from bs = )




# max_int_values = {
#     8: 1774746734, #log2 -> 30.7 => 32
# }
# scipy.io.savemat(f'hrir/proc_hrir_l_bs{bit_shift}.mat', {'hrir_l': bitshifted_hrir_l})
# scipy.io.savemat(f'hrir/proc_hrir_r_bs{bit_shift}.mat', {'hrir_r': bitshifted_hrir_r})

'''
left coefficients:
before abs, summing: 
[-0.5893292188587362, -0.5814950842658007, -0.5732233189299056, -0.6516224927540087, -0.6744441327730585, -0.5588210947203169, -0.5551265770084384, -0.5340658498205813, -0.5992848676791296, -0.5576793977733331, -0.6048879203873024, -0.6221988221778116, -0.5836894274227422, -0.6336546958515261, -0.5901330609769718, -0.5118907116740651, -0.5881633837477267, -0.5956620838250303, -0.6153706862111736, -0.6133333157206684, -0.6280239151010432, -0.6319256723559065, -0.6710963156620744, -0.7304803666184548, -0.7367130730651789]

after abs, summing:
[11.154571055283737, 11.097375056376297, 9.736167453020474, 9.0893084632728, 9.140740142250769, 9.12785660697799, 10.028946720725733, 9.207936050918384, 9.177258874912912, 8.481219056602542, 7.716014592681417, 7.447173652863127, 6.643213324332002, 6.119000203330719, 5.409611868081054, 5.158340538164088, 4.620513774059403, 4.000657288033094, 3.6420073623847204, 3.3671845746604734, 3.2308766038021624, 3.0448367727197136, 2.436355347512081, 2.472100993348115, 1.932273470167691]
'''