=======================================================================
CATALOG: Common_IPs/FFT_NEW/testbench/matlab
CREATE TIME: 2023/06/20
=======================================================================

TABLE OF CONTENTS
-----------------
1. data1(   signal = cos(2*pi*200*t) + cos(2*pi*300*t)          )   *Inputdata Bit Width - 16 Bit*
2. data2(   signal = cos(2*pi*200*t)*i + cos(2*pi*300*t)*i      )   *Inputdata Bit Width - 16 Bit*
3. data3(   signal = square(2*pi*100*t)                         )   *Inputdata Bit Width - 16 Bit*
4. data4(   signal = sawtooth(2*pi*100*t)                       )   *Inputdata Bit Width - 16 Bit*
5. data5(   signal = cos(2*pi*200*t) + cos(2*pi*300*t)          )   *Inputdata Bit Width - 11 Bit*
6. data6(   signal = cos(2*pi*200*t)*i + cos(2*pi*300*t)*i      )   *Inputdata Bit Width - 11 Bit*
7. data7(   signal = square(2*pi*100*t)                         )   *Inputdata Bit Width - 11 Bit*
8. data8(   signal = sawtooth(2*pi*100*t)                       )   *Inputdata Bit Width - 11 Bit*

======================================================================
data contents
    1.data_before_fft.txt(generated from matalb)
    2.data_before_fft_b.txt(used for Alter_FFT.v, almost same as data_before_fft.txt)
    3.matlab_fft.m(matalb file)
    4.out_real.txt(generated from matlab, the real number result of fft from matalb)
    5.out_imag.txt(generated from matlab, the imag number result of fft from matalb)
    6.M_out_real.txt(generated from Modelsim, the real number result of fft from Modelsim)
    7.M_out_imag.txt(generated from Modelsim, the imag number result of fft from Modelsim)
=======================================================================

