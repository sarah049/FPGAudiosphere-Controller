def parse2(value_list, segment_bit_width, num_segments):
    segment_value_list = []
    other = []
    assert len(value_list) == num_segments, f"incorrect length {len(value_list)}"
    assert len(value_list[0]) == segment_bit_width, f"incorrect length {len(value_list[0])}"
    max_val = 2**(segment_bit_width - 1)
    # print(len(value_list)/num_segments)
    total = 0
    for num in value_list:
        val = int(num, 2)
        if val >= max_val:
            # If it's negative, subtract 2^bit_width to get the signed equivalent
            val  =  val - int(2**segment_bit_width)
        other.append(val)
        total += val
        segment_value_list.append(hex(val & 0xFFFF_FFFF_FFFF))
    return segment_value_list, other, sum(other)

# # inp = ["00000000000000000000000000000000000000000111001010100010", "11111111111111111111111111111111111111111110100100011110", "00000000000000000000000000000000000000000000010000111111", "00000000000000000000000000000000000000000000000000101100", "00000000000000000000000000000000000000000000000000000000", "00000000000000000000000000000000000000000000000000000000", "00000000000000000000000000000000000000000000000000000000", "00000000000000000000000000000000000000000000000000000000"]
# # print(parse2(inp, 56, 8)) #24619 (first 8)

# inp = ["00000000000000000000000000000000001000011100000010001110", "11111111111111111111111111111111001001010010101010010001", "11111111111111111111111111111111110111100100100001100001", "11111111111111111111111111111111011101011001001000001011", "00000000000000000000000000000000010110100010110111011010", "00000000000000000000000000000000011100001110100001111001", "11111111111111111111111111111111111111010101100101010011", "11111111111111111111111111111111111111010011001001100011"]
# print(parse2(inp, 56, 8)) -10459244

inp = ["00000000000000000000000000000001010011011001000101111100", "11111111111111111111111111111110100001100100100011110110", "00000000000000000000000000000000110001010000110010111110", "11111111111111111111111111111111010101100010000111000001", "00000000000000000000000000000000000000001011100110111000", "00000000000000000000000000000000001000011100000010001110", "11111111111111111111111111111111001001010010101010010001", "00000000000000000000000000000000010110100010110111011010"]
print(parse2(inp, 56, 8))

hex_values = [
    "00000000", "00000000", "00000000", "00000000", "0000002c", "0000043f", "ffffe91e", "000072a2", 
    "fffd3263", "000131a5", "fff716e9", "ffdca949", "fffd5953", "0070e879", "005a2dda", "ff75920b", 
    "ffde4861", "ff252a91", "0021c08e", "0000b9b8", "ff5621c1", "00c50cbe", "fe8648f6", "014d917c", 
    "ff82ba87", "fe191b04", "0206b33e", "ff6995d7", "09f38935", "3553093b", "1d5ce35f", "ec8c2c52", 
    "02181b1d", "ea808ec6", "e67f322c", "00fe1282", "f2913fd8", "e72cd4c6", "e47b1839", "0ec3fca9", 
    "3cd0236a", "088cb191", "e4f9aba5", "f9f19872", "eb322a7b", "f358e160", "0b7f14b7", "fdeafb17", 
    "ef206c52", "ffa31d5c", "00c4b0cb", "ff3ca6e3", "0b8b83ea", "f7d233f5", "f598109a", "03e85762", 
    "003c1d1b", "feb9e7e0", "032d746a", "00d28fdb", "fe90880a", "0370baaf", "fe96f13c", "fdb162b6",
#     ] 
# print(len(hex_values))
# rest = [
    "ff6a1cd3", "fdca2e87", "009d34bc", "ff0dca98", "febbffc0", "0304f044", "02321e39", "ff315b08", 
    "0024ccbd", "ffdf34f1", "fe544cee", "01195c02", "00940321", "fdf0a30f", "ffdb3e82", "00d2ccec", 
    "ffda2b4f", "012839af", "00f57907", "fefd261e", "ffa24944", "ff5db88d", "fef89a66", "003379ca", 
    "ffda7bee", "00923b2e", "00e5ec95", "ff48d7dd", "feaab810", "ff92ed0a", "ffe15e80", "0000dd31", 
    "00a0d1ba", "004d03b0", "00220f76", "005f00c9", "003ca802", "00f880e3", "00f29109", "ff51657e", 
    "fef59342", "ffbcaca2", "ffb07ffd", "003d33f5", "014b176e", "00e3e3e2", "0035830b", "0058f561", 
    "00a8cce5", "00e075c3", "0003cbf9", "ff7c89d8", "004fa6bf", "0031f575", "ffd99835", "0056ef7a", 
    "007856d8", "00080f7b", "ffb30bff", "ff9eeec6", "ff72b3e9", "ff74d623", "ff5d43ac", "ff181bfe", 
    "ffc1aa04", "0016f6c8", "00133e5c", "0085e5dd", "0047bccc", "ffd583b4", "ffb3112a", "ff7eb3dc", 
    "ff12fb96", "ff08e166", "ffb1bb0d", "fff5e7e9", "fffb598e", "0068cab0", "00a84777", "00abcec7", 
    "005eaef4", "0032a6f8", "fff407f7", "ff955345", "ff99e923", "ffca07fe", "ffa690a5", "ffa675a4", 
    "fff99411", "ffd87751", "ff2f7803", "fef9d618", "ff7f3620", "ff313401", "fee9c0e8", "ffd0e891", 
    "00050bae", "003d31d7", "00d9d036", "ffe743e7", "ff3f32f3", "ffdda6e1", "0064df43", "00623e23", 
    "ff4db4af", "ff206df7", "005a2382", "00521570", "003987a6", "00995da2", "fff62807", "ff938996", 
    "ffc838d8", "000f7f59", "005ff256", "00232758", "ffa5f953", "ffacd15a", "fffcabc5", "000cff82", 
    "00004b44", "ffeee119", "ffe228b0", "fffe867e", "0001ce51", "fff0305a", "000124b5", "fffada2a", 
    "ffe8d40c", "fffb6247", "fffc55f2", "ffe731c9", "ffeeb44c", "0001864c", "0002f5f6", "fffefc23"
]

# hex_values = ["ffffffff", "ffffffff", "ffffffff", "ffffffff", "ffffffff", "ffffffff", "ffffffff", "ffffffff"]
# Convert hex to signed decimal and sum
segment_bit_width = 32
max_val = 2**(segment_bit_width - 1)
total_sum = 0
accuma = [0,0,0,0]
for ix, hex_val in enumerate(hex_values):
    
    if int(hex_val, 16) < max_val:
        val = int(hex_val, 16) 
    else: 
        val = int(hex_val, 16) - int(max_val*2)
    # print (val)
    total_sum += val

    if ix < 8:
        accuma[0] += val
    elif 8 < ix < 16:
        accuma[1] += val
    elif ix < 32:
        accuma[2] += val
    elif ix  < 40:
        accuma[3] += val

# Convert the result back to signed hexadecimal
result_hex = hex(total_sum & 0xFFFFFFFFFFFFFFFF)
accuma = [hex(v & 0xFFFFFFFFFFFFFFFF) for v in accuma]
print(result_hex, accuma)