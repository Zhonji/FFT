=======================================================================
NAME: FFT_NEW
CATALOG: Common_IPs/FFT_NEW
CREATE TIME: 2023/06/14
=======================================================================

TABLE OF CONTENTS
-----------------
1. DESIGN DESCRIPTION
2. DESIGN CONTENTS

======================================================================
1. DESIGN DESCRIPTION 
=======================================================================
This project has designed as a variable point (16/32/64/128) FFT 
module that can also support optimised multiplication. It is based on 
the R22SDF and R2SDF structures

Alter_FFT:
Top-level cell: 
    Alter_FFT.v

=======================================================================
2. DESIGN DIRECTORY STRUCTURE
=======================================================================
|-- doc
|   |-- R22SDF_Testbench.txt
    |-- R22SDF_DESIGN.txt
|-- scripts
|-- scr
    |-- Alter_FFT.v
        |-- butterfly.v
        |-- DelayBuffer.v
        |-- Multiply.v
        |-- multiply_opti.v
        |-- SdfUnit0.v (for 16/64 points)
        |-- SdfUnit1.v (for 32/128 points)
        |-- SdfUnit2.v
        |-- Twiddle64.v (for 16/64 points)
        |-- Twiddle128.v (for 32/128 points)
|-- testbench   
    |-- tb128.txt(with the whole lastest functions)
        |--matlab(store the data compared)