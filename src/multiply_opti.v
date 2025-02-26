//----------------------------------------------------------------------
//  Multiply_opti   : Optimized Multiplier
//  Author          : zhongyuanji
//  Company         : Ravsense
//  Time            : 2023/06/26
//  Version         ：V2.0 
//----------------------------------------------------------------------
//  Version   ：V1.0 
//      Corrected the occurrence of "16'h8000"
//  Version   ：V2.0 
//      Add comments
//  
//----------------------------------------------------------------------
`timescale 1ns/1ns
module multiply_opti#(
    parameter WIDTH = 16
)(
    input   signed  [WIDTH-1:0] a_re,   //  Inputdata from BF
    input   signed  [WIDTH-1:0] a_im,   //  Inputdata from BF
    input   signed  [WIDTH-1:0] tw_re,  //  Input Twiddle
    input   signed  [WIDTH-1:0] tw_im,  //  Input Twiddle
    output  signed  [WIDTH-1:0] m_re,   //  Outputdata Real Part
    output  signed  [WIDTH-1:0] m_im    //  Outputdata Imag Part
);
//This module completes the multiplication of two complex numbers and outputs the complex numbers after operation
//m_re = a_re*tw_re - a_im*tw_im    //multi1 - multi2
//m_im = a_re*tw_im + a_im*tw_re    //multi3 + multi4
integer                   index;                                                //  Index, which indicates shift
wire          [WIDTH-2:0] a_re_trans,  a_im_trans;                              //  Expanded Inputdata
wire          [WIDTH-2:0] tw_re_trans, tw_im_trans;                             //  Expanded Input Twiddle
reg         [2*WIDTH-3:0] multi1_temp, multi2_temp, multi3_temp, multi4_temp;   //  Data that is being shifted and summed
reg  signed   [WIDTH-1:0] multi1, multi2, multi3, multi4;                       //  The result of the addition of the shifts Which has been processed
reg  signed   [WIDTH-1:0] multi10, multi20, multi30, multi40;                   //  a_re*tw_re/a_im*tw_im/a_re*tw_im/a_im*tw_re
reg  signed [2*WIDTH-2:0] multi11, multi21, multi31, multi41;                   //  The result of the addition of the shifts to be processed
reg         [2*WIDTH-3:0] a_re_ex, a_im_ex;                                     //  Expanded Inputdata, Waiting for The Shifts to Be Added
reg                       flag1, flag2, flag3 ,flag4;                           //  The Sign Bits of The Results

//  The data bits of the complement are taken separately and converted to the source code
//, which is necessary for the shift addition
assign a_re_trans   =  a_re[WIDTH-1]  ? { (~a_re[WIDTH-2:0] )+ 1'b1 }   : {a_re[WIDTH-2:0]};
assign a_im_trans   =  a_im[WIDTH-1]  ? { (~a_im[WIDTH-2:0] ) + 1'b1 }  : {a_im[WIDTH-2:0]};
assign tw_re_trans  =  tw_re[WIDTH-1] ? { (~tw_re[WIDTH-2:0] )+ 1'b1 }  : {tw_re[WIDTH-2:0]};
assign tw_im_trans  =  tw_im[WIDTH-1] ? { (~tw_im[WIDTH-2:0] )+ 1'b1 }  : {tw_im[WIDTH-2:0]};

//The sign bits are added to determine the result sign bit of the operation
always@(*)begin
    flag1 = a_re[WIDTH-1] + tw_re[WIDTH-1]; //a_re*tw_re
    flag2 = a_im[WIDTH-1] + tw_im[WIDTH-1]; //a_im*tw_im
    flag3 = a_re[WIDTH-1] + tw_im[WIDTH-1]; //a_re*tw_im
    flag4 = a_im[WIDTH-1] + tw_re[WIDTH-1]; //a_im*tw_re
end

//Core code:
//  Multiplication is achieved by adding shifts
always@(*)begin
    multi1_temp = 'd0;
    multi2_temp = 'd0;
    multi3_temp = 'd0;
    multi4_temp = 'd0;
    a_re_ex = {{(WIDTH-1){1'b0}},a_re_trans};
    a_im_ex = {{(WIDTH-1){1'b0}},a_im_trans};
    for(index = 0; index < (WIDTH-1); index = index + 1)begin
        multi1_temp = multi1_temp + ({(2*WIDTH-2){tw_re_trans[index]}} & ({a_re_ex << index}));   //    a_re*tw_re
        multi2_temp = multi2_temp + ({(2*WIDTH-2){tw_im_trans[index]}} & ({a_im_ex << index}));   //    a_im*tw_im 
        multi3_temp = multi3_temp + ({(2*WIDTH-2){tw_im_trans[index]}} & ({a_re_ex << index}));   //    a_re*tw_im
        multi4_temp = multi4_temp + ({(2*WIDTH-2){tw_re_trans[index]}} & ({a_im_ex << index}));   //    a_im*tw_re
    end
end
//Judge the sign bit and convert it to complement
always@(*)begin
    multi11 = flag1 ? ({flag1,{(~multi1_temp[2*WIDTH-3:0]) + 1'b1}}) : ({flag1,multi1_temp[2*WIDTH-3:0]});
    multi21 = flag2 ? ({flag2,{(~multi2_temp[2*WIDTH-3:0]) + 1'b1}}) : ({flag2,multi2_temp[2*WIDTH-3:0]});
    multi31 = flag3 ? ({flag3,{(~multi3_temp[2*WIDTH-3:0]) + 1'b1}}) : ({flag3,multi3_temp[2*WIDTH-3:0]});
    multi41 = flag4 ? ({flag4,{(~multi4_temp[2*WIDTH-3:0]) + 1'b1}}) : ({flag4,multi4_temp[2*WIDTH-3:0]});
end
//Truncation is performed, which is equivalent to 1/(2^15) times
always@(*)begin
    multi1 = multi11[2*WIDTH-2:WIDTH-1];
    multi2 = multi21[2*WIDTH-2:WIDTH-1];
    multi3 = multi31[2*WIDTH-2:WIDTH-1];
    multi4 = multi41[2*WIDTH-2:WIDTH-1];
end
//Determine whether "16'h8000" Exists, and if so, Special Treatment is Required
always@(*)begin
// multi1
    if((a_re == 16'h0)||(tw_re == 16'h0))begin
        multi10 = 16'b0;
    end
    else begin    
        if((a_re == 16'h8000)||(tw_re == 16'h8000))begin
            if((a_re == 16'h8000)&&(tw_re == 16'h8000))begin    //If Both are "16'h8000", Directly Assign The Value "16'h7fff" Manually, and There is A Further Explanation in The Doc
                multi10 = 16'h7fff;
            end
            else begin
                if((a_re == 16'h8000))begin                     //If There is Only One "16'h8000", Generate The Opposite 
                    multi10 = {~tw_re +1'b1};
                end
                else begin
                    multi10 = {~a_re + 1'b1};
                end
            end
        end
        else begin
            multi10 = multi1;
        end
    end
end
//Determine whether "16'h8000" Exists, and if so, Special Treatment is Required
always@(*)begin
// multi2
    if((a_im == 16'h0)||(tw_im == 16'h0))begin
        multi20 = 16'b0;
    end    
    else begin
        if((a_im == 16'h8000)||(tw_im == 16'h8000))begin
            if((a_im == 16'h8000)&&(tw_im == 16'h8000))begin
                multi20 = 16'h7fff;
            end
            else begin
                if((a_im == 16'h8000))begin
                    multi20 = {~tw_im +1'b1};
                end
                else begin
                    multi20 = {~a_im + 1'b1};
                end
            end
        end
        else begin
            multi20 = multi2;
        end
    end
end
//Determine whether "16'h8000" Exists, and if so, Special Treatment is Required
always@(*)begin
// multi3    
    if((a_re == 16'h0)||(tw_im == 16'h0))begin
        multi30 = 16'b0;
    end
    else begin    
        if((a_re == 16'h8000)||(tw_im == 16'h8000))begin
            if((a_re == 16'h8000)&&(tw_im == 16'h8000))begin
                multi30 = 16'h7fff;
            end
            else begin
                if((a_re == 16'h8000))begin
                    multi30 = {~tw_im +1'b1};
                end
                else begin
                    multi30 = {~a_re + 1'b1};
                end
            end
        end
        else begin
            multi30 = multi3;
        end
    end
end
//Determine whether "16'h8000" Exists, and if so, Special Treatment is Required
always@(*)begin
// multi4    
    if((a_im == 16'h0)||(tw_re == 16'h0))begin
        multi40 = 16'b0;
    end
    else begin
        if((a_im == 16'h8000)||(tw_re == 16'h8000))begin
            if((a_im == 16'h8000)&&(tw_re == 16'h8000))begin
                multi40 = 16'h7fff;
            end
            else begin
                if((a_im == 16'h8000))begin 
                    multi40 = {~tw_re +1'b1};
                end
                else begin
                    multi40 = {~a_im + 1'b1};
                end
            end
        end
        else begin
            multi40 = multi4;
        end
    end
end
// Output The Complex Result
assign m_re = multi10 - multi20;
assign m_im = multi30 + multi40;
endmodule




// `timescale 1ns/1ns
// module multiply_opti(
//     input   signed  [15:0] a_re,
//     input   signed  [15:0] a_im,
//     input   signed  [15:0] tw_re,
//     input   signed  [15:0] tw_im,
//     output  signed  [15:0] m_re,
//     output  signed  [15:0] m_im
// );
// //m_re = a_re*tw_re - a_im*tw_im    //multi1 - multi2
// //m_im = a_re*tw_im + a_im*tw_re    //multi3 + multi4
// integer index;
// wire [14:0] a_re_trans,  a_im_trans;
// wire [14:0] tw_re_trans, tw_im_trans;
// reg  [29:0] multi1_temp, multi2_temp, multi3_temp, multi4_temp;
// reg  [15:0] multi1, multi2, multi3, multi4;
// reg  [29:0] a_re_ex, a_im_ex;
// reg flag1, flag2, flag3 ,flag4;


// assign a_re_trans   =  a_re[15]  ? { ~a_re[14:0]  + 1'b1 }  : {a_re[14:0]};
// assign a_im_trans   =  a_im[15]  ? { ~a_im[14:0]  + 1'b1 }  : {a_im[14:0]};
// assign tw_re_trans  =  tw_re[15] ? { ~tw_re[14:0] + 1'b1 }  : {tw_re[14:0]};
// assign tw_im_trans  =  tw_im[15] ? { ~tw_im[14:0] + 1'b1 }  : {tw_im[14:0]};

// always@(a_re, a_im, tw_re, tw_im)begin
//     flag1 = a_re[15] + tw_re[15];
//     flag2 = a_im[15] + tw_im[15];
//     flag3 = a_re[15] + tw_im[15];
//     flag4 = a_im[15] + tw_re[15];
// end


// always@(a_re, a_im, tw_re, tw_im)begin
//     multi1_temp = 'd0;
//     multi2_temp = 'd0;
//     multi3_temp = 'd0;
//     multi4_temp = 'd0;
//     a_re_ex = {{15{1'b0}},a_re_trans};
//     a_im_ex = {{15{1'b0}},a_im_trans};
//     for(index = 0; index < 15; index = index + 1)begin
//         multi1_temp = multi1_temp + ({30{tw_re_trans[index]}}&({a_re_ex << index}));//a_re*tw_re
//         multi2_temp = multi2_temp + ({30{tw_im_trans[index]}}&({a_im_ex << index}));//a_im*tw_im 
//         multi3_temp = multi3_temp + ({30{tw_im_trans[index]}}&({a_re_ex << index}));//a_re*tw_im
//         multi4_temp = multi4_temp + ({30{tw_re_trans[index]}}&({a_im_ex << index}));//a_im*tw_re
//     end
// end

// // always@(a_re, a_im, tw_re, tw_im)begin
// //     a_re_ex = {{15{1'b0}},a_re_trans};//30bits
// //     a_im_ex = {{15{1'b0}},a_im_trans};
// //     for(index = 0; index < 15; index = index + 1)begin
// //         if(index == 0)begin
// //             multi1_temp = ({30{tw_re_trans[index]}}&({a_re_ex << index}));//a_re*tw_re
// //             multi2_temp = ({30{tw_im_trans[index]}}&({a_im_ex << index}));//a_im*tw_im 
// //             multi3_temp = ({30{tw_im_trans[index]}}&({a_re_ex << index}));//a_re*tw_im
// //             multi4_temp = ({30{tw_re_trans[index]}}&({a_im_ex << index}));//a_im*tw_re
// //         end
// //         else begin
// //             multi1_temp = multi1_temp + ({30{tw_re_trans[index]}}&({a_re_ex << index}));//a_re*tw_re
// //             multi2_temp = multi2_temp + ({30{tw_im_trans[index]}}&({a_im_ex << index}));//a_im*tw_im 
// //             multi3_temp = multi3_temp + ({30{tw_im_trans[index]}}&({a_re_ex << index}));//a_re*tw_im
// //             multi4_temp = multi4_temp + ({30{tw_re_trans[index]}}&({a_im_ex << index}));//a_im*tw_re
// //         end
// //     end
// // end

// always@(a_re, a_im, tw_re, tw_im)begin
//     multi1 = flag1 ? ({flag1,{~multi1_temp[29:15] + 1'b1}}) : ({flag1,multi1_temp[29:15]});
//     multi2 = flag2 ? ({flag2,{~multi2_temp[29:15] + 1'b1}}) : ({flag2,multi2_temp[29:15]});
//     multi3 = flag3 ? ({flag3,{~multi3_temp[29:15] + 1'b1}}) : ({flag3,multi3_temp[29:15]});
//     multi4 = flag4 ? ({flag4,{~multi4_temp[29:15] + 1'b1}}) : ({flag4,multi4_temp[29:15]});
// end

// assign m_re = multi1 - multi2;
// assign m_im = multi3 + multi4;

// endmodule





// `timescale 1ns/1ns
// module multiply_opti(
//     input   signed  [15:0] a_re,
//     input   signed  [15:0] a_im,
//     input   signed  [15:0] tw_re,
//     input   signed  [15:0] tw_im,
//     output  signed  [15:0] m_re,
//     output  signed  [15:0] m_im,
//     output  signed  [15:0] mul1,
//     output  signed  [15:0] mul2,
//     output  signed  [15:0] mul3,
//     output  signed  [15:0] mul4

// );
// //m_re = a_re*tw_re - a_im*tw_im    //multi1 - multi2
// //m_im = a_re*tw_im + a_im*tw_re    //multi3 + multi4
// integer index;
// wire [14:0] a_re_trans,  a_im_trans;
// wire [14:0] tw_re_trans, tw_im_trans;
// reg  [29:0] multi1_temp, multi2_temp, multi3_temp, multi4_temp;
// reg  signed[15:0] multi1, multi2, multi3, multi4;
// reg  signed[15:0] multi10, multi20, multi30, multi40;
// reg  [29:0] a_re_ex, a_im_ex;
// reg flag1, flag2, flag3 ,flag4;

// assign mul1 = multi10;
// assign mul2 = multi20;
// assign mul3 = multi30;
// assign mul4 = multi40;

// assign a_re_trans   =  a_re[15]  ? { (~a_re[14:0] )+ 1'b1 }  : {a_re[14:0]};
// assign a_im_trans   =  a_im[15]  ? { (~a_im[14:0] ) + 1'b1 }  : {a_im[14:0]};
// assign tw_re_trans  =  tw_re[15] ? { (~tw_re[14:0] )+ 1'b1 }  : {tw_re[14:0]};
// assign tw_im_trans  =  tw_im[15] ? { (~tw_im[14:0] )+ 1'b1 }  : {tw_im[14:0]};

// always@(*)begin
//     flag1 = a_re[15] + tw_re[15];
//     flag2 = a_im[15] + tw_im[15];
//     flag3 = a_re[15] + tw_im[15];
//     flag4 = a_im[15] + tw_re[15];
// end


// always@(*)begin
//     multi1_temp = 'd0;
//     multi2_temp = 'd0;
//     multi3_temp = 'd0;
//     multi4_temp = 'd0;
//     a_re_ex = {{15{1'b0}},a_re_trans};
//     a_im_ex = {{15{1'b0}},a_im_trans};
//     for(index = 0; index < 15; index = index + 1)begin
//         multi1_temp = multi1_temp + ({30{tw_re_trans[index]}}&({a_re_ex << index}));//a_re*tw_re
//         multi2_temp = multi2_temp + ({30{tw_im_trans[index]}}&({a_im_ex << index}));//a_im*tw_im 
//         multi3_temp = multi3_temp + ({30{tw_im_trans[index]}}&({a_re_ex << index}));//a_re*tw_im
//         multi4_temp = multi4_temp + ({30{tw_re_trans[index]}}&({a_im_ex << index}));//a_im*tw_re
//     end
// end

// always@(*)begin
//     multi1 = flag1 ? ({flag1,{(~multi1_temp[29:15]) + 1'b1}}) : ({flag1,multi1_temp[29:15]});
//     multi2 = flag2 ? ({flag2,{(~multi2_temp[29:15])+ 1'b1}})  : ({flag2,multi2_temp[29:15]});
//     multi3 = flag3 ? ({flag3,{(~multi3_temp[29:15]) + 1'b1}}) : ({flag3,multi3_temp[29:15]});
//     multi4 = flag4 ? ({flag4,{(~multi4_temp[29:15]) + 1'b1}}) : ({flag4,multi4_temp[29:15]});
// end

// always@(*)begin
//     multi10 = (multi1 == 16'h8000)? 16'b0 : multi1;
//     multi20 = (multi2 == 16'h8000)? 16'b0 : multi2;
//     multi30 = (multi3 == 16'h8000)? 16'b0 : multi3;
//     multi40 = (multi4 == 16'h8000)? 16'b0 : multi4;
// end


// assign m_re = multi10 - multi20;
// assign m_im = multi30 + multi40;

// endmodule







// `timescale 1ns/1ns
// module multiply_opti(
//     input   signed  [15:0] a_re,
//     input   signed  [15:0] a_im,
//     input   signed  [15:0] tw_re,
//     input   signed  [15:0] tw_im,
//     output  signed  [15:0] m_re,
//     output  signed  [15:0] m_im
// );
// //m_re = a_re*tw_re - a_im*tw_im    //multi1 - multi2
// //m_im = a_re*tw_im + a_im*tw_re    //multi3 + multi4
// integer index;
// reg [15:0] inputre,inputim;
// wire [14:0] a_re_trans,  a_im_trans;
// wire [14:0] tw_re_trans, tw_im_trans;
// reg  [29:0] multi1_temp, multi2_temp, multi3_temp, multi4_temp;
// reg  [15:0] multi1, multi2, multi3, multi4;
// reg  [15:0] multi10, multi20, multi30, multi40;
// reg  [29:0] a_re_ex, a_im_ex;
// reg flag1, flag2, flag3 ,flag4;


// always@(*)begin
//     inputre = (a_re == 16'h8000)? 16'h0: a_re;
//     inputim = (a_im == 16'h8000)? 16'h0: a_im;
// end

// assign a_re_trans   =  inputre[15]  ? { (~inputre[14:0] )+ 1'b1 }  : {inputre[14:0]};
// assign a_im_trans   =  inputim[15]  ? { (~inputim[14:0] ) + 1'b1 }  : {inputim[14:0]};
// assign tw_re_trans  =  tw_re[15] ? { (~tw_re[14:0] )+ 1'b1 }  : {tw_re[14:0]};
// assign tw_im_trans  =  tw_im[15] ? { (~tw_im[14:0] )+ 1'b1 }  : {tw_im[14:0]};










// always@(*)begin
//     flag1 = inputre[15] + tw_re[15];
//     flag2 = inputim[15] + tw_im[15];
//     flag3 = inputre[15] + tw_im[15];
//     flag4 = inputim[15] + tw_re[15];
// end


// always@(*)begin
//     multi1_temp = 'd0;
//     multi2_temp = 'd0;
//     multi3_temp = 'd0;
//     multi4_temp = 'd0;
//     a_re_ex = {{15{0}},a_re_trans};
//     a_im_ex = {{15{0}},a_im_trans};
//     for(index = 0; index < 15; index = index + 1)begin
//         multi1_temp = multi1_temp + ({30{tw_re_trans[index]}}&({a_re_ex << index}));//a_re*tw_re
//         multi2_temp = multi2_temp + ({30{tw_im_trans[index]}}&({a_im_ex << index}));//a_im*tw_im 
//         multi3_temp = multi3_temp + ({30{tw_im_trans[index]}}&({a_re_ex << index}));//a_re*tw_im
//         multi4_temp = multi4_temp + ({30{tw_re_trans[index]}}&({a_im_ex << index}));//a_im*tw_re



//     end
// end
//         // multi1_temp = multi1_temp + (tw_re_trans[index]?({a_re_ex << index}):'d0);//a_re*tw_re
//         // multi2_temp = multi2_temp + (tw_im_trans[index]?({a_im_ex << index}):'d0);//a_im*tw_im 
//         // multi3_temp = multi3_temp + (tw_im_trans[index]?({a_re_ex << index}):'d0);//a_re*tw_im
//         // multi4_temp = multi4_temp + (tw_re_trans[index]?({a_im_ex << index}):'d0);//a_im*tw_re

// // always@(a_re, a_im, tw_re, tw_im)begin
// //     multi1_temp = 'd0;
// //     multi2_temp = 'd0;
// //     multi3_temp = 'd0;
// //     multi4_temp = 'd0;
// //     a_re_ex = {{15{1'b0}},a_re_trans};
// //     a_im_ex = {{15{1'b0}},a_im_trans};
// //     for(index = 0; index < 15; index = index + 1)begin
// //         multi1_temp = multi1_temp + ({30{tw_re_trans[index]}}&({a_re_ex << index}));//a_re*tw_re
// //         multi2_temp = multi2_temp + ({30{tw_im_trans[index]}}&({a_im_ex << index}));//a_im*tw_im 
// //         multi3_temp = multi3_temp + ({30{tw_im_trans[index]}}&({a_re_ex << index}));//a_re*tw_im
// //         multi4_temp = multi4_temp + ({30{tw_re_trans[index]}}&({a_im_ex << index}));//a_im*tw_re
// //     end
// // end

// // always@(*)begin
// //     a_re_ex = {{15{1'b0}},a_re_trans};//30bits
// //     a_im_ex = {{15{1'b0}},a_im_trans};
// //     for(index = 0; index < 15; index = index + 1)begin
// //         if(index == 0)begin
// //             multi1_temp = ({30{tw_re_trans[index]}}&({a_re_ex << index}));//a_re*tw_re
// //             multi2_temp = ({30{tw_im_trans[index]}}&({a_im_ex << index}));//a_im*tw_im 
// //             multi3_temp = ({30{tw_im_trans[index]}}&({a_re_ex << index}));//a_re*tw_im
// //             multi4_temp = ({30{tw_re_trans[index]}}&({a_im_ex << index}));//a_im*tw_re
// //         end
// //         else begin
// //             multi1_temp = multi1_temp + ({30{tw_re_trans[index]}}&({a_re_ex << index}));//a_re*tw_re
// //             multi2_temp = multi2_temp + ({30{tw_im_trans[index]}}&({a_im_ex << index}));//a_im*tw_im 
// //             multi3_temp = multi3_temp + ({30{tw_im_trans[index]}}&({a_re_ex << index}));//a_re*tw_im
// //             multi4_temp = multi4_temp + ({30{tw_re_trans[index]}}&({a_im_ex << index}));//a_im*tw_re
// //         end
// //     end
// // end

// always@(*)begin
//     multi1 = flag1 ? ({flag1,{(~multi1_temp[29:15]) + 1'b1}}) : ({flag1,multi1_temp[29:15]});
//     multi2 = flag2 ? ({flag2,{(~multi2_temp[29:15])+ 1'b1}})  : ({flag2,multi2_temp[29:15]});
//     multi3 = flag3 ? ({flag3,{(~multi3_temp[29:15]) + 1'b1}}) : ({flag3,multi3_temp[29:15]});
//     multi4 = flag4 ? ({flag4,{(~multi4_temp[29:15]) + 1'b1}}) : ({flag4,multi4_temp[29:15]});
// end

// // always@(*)begin
// //     multi1 = flag1 ? ({(~multi1_temp[29:15]) + 1'b1} == 0? 16'b0 :{flag1,{(~multi1_temp[29:15]) + 1'b1}}) : ({flag1,multi1_temp[29:15]});
// //     multi2 = flag2 ? ({flag2,{(~multi2_temp[29:15])+ 1'b1}})  : ({flag2,multi2_temp[29:15]});
// //     multi3 = flag3 ? ({flag3,{(~multi3_temp[29:15]) + 1'b1}}) : ({flag3,multi3_temp[29:15]});
// //     multi4 = flag4 ? ({flag4,{(~multi4_temp[29:15]) + 1'b1}}) : ({flag4,multi4_temp[29:15]});
// // end
// always@(*)begin
//     multi10 = (multi1 == 16'h8000)? 16'b0 : multi1;
//     multi20 = (multi2 == 16'h8000)? 16'b0 : multi2;
//     multi30 = (multi3 == 16'h8000)? 16'b0 : multi3;
//     multi40 = (multi4 == 16'h8000)? 16'b0 : multi4;
// end


// assign m_re = multi10 - multi20;
// assign m_im = multi30 + multi40;


// // assign m_re = multi1 - multi2;
// // assign m_im = multi3 + multi4;

// endmodule































// `timescale 1ns/1ns
// module multiply_opti(
//     input   signed  [15:0] a_re,
//     input   signed  [15:0] a_im,
//     input   signed  [15:0] tw_re,
//     input   signed  [15:0] tw_im,
//     output  signed  [15:0] m_re,
//     output  signed  [15:0] m_im
// );
// //m_re = a_re*tw_re - a_im*tw_im    //multi1 - multi2
// //m_im = a_re*tw_im + a_im*tw_re    //multi3 + multi4
// wire [14:0] a_re_trans;
// wire [14:0] a_im_trans;
// // wire [15:0] tw_re_trans;
// // wire [15:0] tw_im_trans;
// wire flag;
// wire [31:0] multi1, multi2, multi3, multi4;

// assign a_re_trans  =  a_re[15] ? {~a_re[14:0]+1'b1} : a_re[14:0];
// assign a_im_trans  =  a_im[15] ? {~a_im[14:0]+1'b1} : a_im[14:0];
// // assign tw_re_trans = tw_re[15] ? {1'b1,~tw_re[14:0]+1'b1} : tw_re;
// // assign tw_im_trans = tw_im[15] ? {1'b1,~tw_im[14:0]+1'b1} : tw_im;

// always@(*)begin//multi1 and multi4
//     case(tw_re)
//     16'h0000:begin
//         multi1 = 32'b0;
//         multi4 = 32'b0;
//     end
//     16'h7FD9:begin//0 111_1111_1101_1001 // 1000_0000_0(-1)10_(-1)001
//         // multi1 = (a_re_trans << 15) - (a_re_trans << 5) - (a_re_trans << 2) - (a_re_trans << 1) - ;
//         // multi4 = (a_im_trans << 15) - (a_im_trans << 5) - (a_re_trans << 2) - (a_re_trans << 1);
//         multi1 = (a_re_trans << 15) + (a_re_trans << 0) - (a_re_trans << 3) + (a_re_trans << 5) - (a_re_trans << 6);
//         multi4 = (a_im_trans << 15) + (a_im_trans << 0) - (a_im_trans << 3) + (a_im_trans << 5) - (a_im_trans << 6);
//     end
//     16'h7F62:begin//0_111_1111_0110_0010    //1000_000(-1)_10(-1)0_0010
//         // multi1 = (a_re_trans << 15) - (a_re_trans << 7) - (a_re_trans << 4) - (a_re_trans << 3) - (a_re_trans << 2) - (a_re_trans << 0);
//         // multi4 = (a_im_trans << 15) - (a_im_trans << 7) - (a_im_trans << 4) - (a_im_trans << 3) - (a_im_trans << 2) - (a_im_trans << 0);
//         multi1 = ;
//         multi4 = ;
//     end
//     16'h7E9D:begin//0111 1110 1001 1101 //1000_00(-1)0_1010_0(-1)01
//         // multi1 = (a_re_trans << 15) - (a_re_trans << 8) - (a_re_trans << 6) - (a_re_trans << 5) - (a_re_trans << 1);
//         // multi4 = (a_im_trans << 15) - (a_im_trans << 8) - (a_im_trans << 6) - (a_im_trans << 5) - (a_im_trans << 1);
//     end
//     16'h7D8A:begin//0111 1101 1000 1010 // 1000_00(-1)0_(-1)000_1010
//         multi1 =
//         multi4 = 
//     end
//     16'h7C2A:begin//0111 1100 0010 1010 // 1000_0(-1)00_0010_1010
//         multi1 =
//         multi4 = 
//     end
//     16'h7A7D:begin//0111 1010 0111 1101 //  1000_(-1)010_1000_0(-1)01
//         multi1 =
//         multi4 = 
//     end
//     16'h7885:begin//0111 1000 1000 0101 //  1000_(-1)000_1000_0101
//         multi1 =
//         multi4 = 
//     end
//     16'h7642:begin//0111 0110 0100 0010 //  1000_(-1)0(-1)0_0100_0010
//         multi1 =
//         multi4 = 
//     end
//     16'h73B6:begin//0111 0011 1011 0110 //  100(-1)_0100_0(-1)00_(-1)0(-1)0
//         multi1 =
//         multi4 = 
//     end
//     16'h70E3:begin//0111 0000 1110 0011 //  100(-1)_0001_00(-1)0_010(-1)
//         multi1 =
//         multi4 = 
//     end
//     16'h6DCA:begin//0110 1101 1100 1010 //  100(-1)_00(-1)0_0(-1)00_1010
//         multi1 =
//         multi4 = 
//     end
//     16'h6A6E:begin//0110 1010 0110 1110 //  10(-1)0_1010_100(-1)_00(-1)0
//         multi1 =
//         multi4 = 
//     end
//     16'h66D0:begin//0110 0110 1101 0000 //  10(-1)0_100(-1)_0(-1)01_0000
//         multi1 =
//         multi4 = 
//     end
//     16'h62F2:begin//0110 0010 1111 0010 //  10(-1)0_010(-1)_000(-1)_0010
//         multi1 =
//         multi4 = 
//     end
//     16'h5ED7:begin//0101 1110 1101 0111 //  10(-1)0_000(-1)_00(-1)0_(-1)00(-1)
//         multi1 =
//         multi4 = 
//     end
//     16'h5A82:begin//0101 1010 1000 0010 //  0101_1010_1000_0010
//         multi1 =
//         multi4 = 
//     end
//     16'h55F6:begin//0101 0101 1111 0110 //  10(-1)0_(-1)0(-1)0_0000_(-1)0(-1)0
//         multi1 =
//         multi4 = 
//     end
//     16'h5134:begin//0101 0001 0011 0100 //  0101_0001_010(-1)_0100
//         multi1 =
//         multi4 = 
//     end
//     16'h4C40:begin//0100 1100 0100 0000//   0101_0(-1)00_0100_0000
//         multi1 =
//         multi4 = 
//     end
//     16'h471D:begin//0100 0111 0001 1101//   
//         multi1 =
//         multi4 = 
//     end
//     16'h41CE:begin//0100 0001 1100 1110
//         multi1 =
//         multi4 = 
//     end
//     16'h3C57:begin//0011 1100 0101 0111
//         multi1 =
//         multi4 = 
//     end
//     16'h36BA:begin//0011 0110 1011 1010
//         multi1 =
//         multi4 = 
//     end
//     16'h30FC:begin//0011 0000 1111 1100
//         multi1 =
//         multi4 = 
//     end
//     16'h2B1F:begin//0010 1011 0001 1111
//         multi1 =
//         multi4 = 
//     end
//     16'h2528:begin//0010 0101 0010 1000
//         multi1 =
//         multi4 = 
//     end
//     16'h1F1A:begin//0001 1111 0001 1010
//         multi1 =
//         multi4 = 
//     end
//     16'h18F9:begin//0001 1000 1111 1001
//         multi1 =
//         multi4 = 
//     end
//     16'h12C8:begin//0001 0010 1100 1000
//         multi1 =
//         multi4 = 
//     end
//     16'h0C8C:begin//0000 1100 1000 1100
//         multi1 =
//         multi4 = 
//     end
//     16'h0648:begin//0000 0110 0100 1000
//         multi1 =
//         multi4 = 
//     end
//     16'h0000:begin//0000 0000 0000 0000
//         multi1 =
//         multi4 = 
//     end
//     16'hF9B8:begin//1000 0110 0100 1000
//         multi1 =
//         multi4 = 
//     end
//     16'hF374:begin//1000 1100 1000 1100
//         multi1 =
//         multi4 = 
//     end
//     16'hE707:begin//1001 1000 1111 1001
//         multi1 =
//         multi4 = 
//     end
//     16'hDAD8:begin//1010 0101 0010 1000
//         multi1 =
//         multi4 = 
//     end
//     16'hD4E1:begin//1010 1011 0001 1111
//         multi1 =
//         multi4 = 
//     end
//     16'hCF04:begin//1011 0000 1111 1100
//         multi1 =
//         multi4 = 
//     end
//     16'hC3A9:begin//1011 1100 0101 0111
//         multi1 =
//         multi4 = 
//     end
//     16'hB8E3:begin//1100 0111 0001 1101
//         multi1 =
//         multi4 = 
//     end
//     16'hB3C0:begin//1100 1100 0100 0000
//         multi1 =
//         multi4 = 
//     end
//     16'hAECC:begin//1101 0001 0011 0100
//         multi1 =
//         multi4 = 
//     end
//     16'hA57E:begin//1101 1010 1000 0010
//         multi1 =
//         multi4 = 
//     end
//     16'h9D0E:begin//1110 0010 1111 0010
//         multi1 =
//         multi4 = 
//     end
//     16'h9930:begin//1110 0110 1101 0000
//         multi1 =
//         multi4 = 
//     end
//     16'h9592:begin//1110 1010 0110 1110
//         multi1 =
//         multi4 = 
//     end
//     16'h8F1D:begin//1111 0000 1110 0011
//         multi1 =
//         multi4 = 
//     end
//     16'h89BE:begin//1111 0110 0100 0010
//         multi1 =
//         multi4 = 
//     end
//     16'h877B:begin//1111 1000 1000 0101
//         multi1 =
//         multi4 = 
//     end
//     16'h8583:begin//1111 1010 0111 1101
//         multi1 =
//         multi4 = 
//     end
//     16'h8276:begin//1111 1101 1000 1010
//         multi1 =
//         multi4 = 
//     end
//     16'h809E:begin//1111 1111 0110 0010
//         multi1 =
//         multi4 = 
//     end
//     16'h8027:begin//1111 1111 1101 1001
//         multi1 =
//         multi4 = 
//     end
//     16'h809E:begin//1111 1111 0110 0010
//         multi1 =
//         multi4 = 
//     end
//     16'h83D6:begin//1111 1100 0010 1010
//         multi1 =
//         multi4 = 
//     end
//     16'h89BE:begin//1111 0110 0100 0010
//         multi1 =
//         multi4 = 
//     end
//     16'h9236:begin//1110 1101 1100 1010
//         multi1 =
//         multi4 = 
//     end
//     16'h9D0E:begin//1110 0010 1111 0010
//         multi1 =
//         multi4 = 
//     end
//     16'hAA0A:begin//1101 0101 1111 0110
//         multi1 =
//         multi4 = 
//     end
//     16'hB8E3:begin//1100 0111 0001 1101
//         multi1 =
//         multi4 = 
//     end
//     16'hC946:begin//1011 0110 1011 1010
//         multi1 =
//         multi4 = 
//     end
//     16'hDAD8:begin//1010 0101 0010 1000
//         multi1 =
//         multi4 = 
//     end
//     16'hED38:begin//1001 0010 1100 1000
//         multi1 =
//         multi4 = 
//     end
//     default:
//     endcase
// end

// always@(*)begin//multi2 and multi3
//     case(tw_im)
//     16'h0000:begin
//         multi2 = 
//         multi3 = 
//     end  
//     16'hF9B8:begin//1000 0110 0100 1000
//         multi2 = 
//         multi3 = 
//     end  
//     16'hF374:begin//1000 1100 1000 1100
//         multi2 = 
//         multi3 = 
//     end  
//     16'hED38:begin//1001 0010 1100 1000
//         multi2 = 
//         multi3 = 
//     end  
//     16'hE707:begin//1001 1000 1111 1001
//         multi2 = 
//         multi3 = 
//     end  
//     16'hE0E6:begin//1001 1111 0001 1010
//         multi2 = 
//         multi3 = 
//     end  
//     16'hDAD8:begin//1010 0101 0010 1000
//         multi2 = 
//         multi3 = 
//     end  
//     16'hD4E1:begin//1010 1011 0001 1111
//         multi2 = 
//         multi3 = 
//     end  
//     16'hCF04:begin//1011 0000 1111 1100
//         multi2 = 
//         multi3 = 
//     end  
//     16'hC946:begin//1011 0110 1011 1010
//         multi2 = 
//         multi3 = 
//     end  
//     16'hC3A9:begin//1011 1100 0101 0111
//         multi2 = 
//         multi3 = 
//     end  
//     16'hBE32:begin//1100 0001 1100 1110
//         multi2 = 
//         multi3 = 
//     end  
//     16'hB8E3:begin//1100 0111 0001 1101
//         multi2 = 
//         multi3 = 
//     end  
//     16'hB3C0:begin//1100 1100 0100 0000
//         multi2 = 
//         multi3 = 
//     end  
//     16'hAECC:begin//1101 0001 0011 0100
//         multi2 = 
//         multi3 = 
//     end  
//     16'hAA0A:begin//1101 0101 1111 0110
//         multi2 = 
//         multi3 = 
//     end  
//     16'hA57E:begin//1101 1010 1000 0010
//         multi2 = 
//         multi3 = 
//     end  
//     16'hA129:begin//1101 1110 1101 0111
//         multi2 = 
//         multi3 = 
//     end  
//     16'h9D0E:begin//1110 0010 1111 0010
//         multi2 = 
//         multi3 = 
//     end  
//     16'h9930:begin//1110 0110 1101 0000
//         multi2 = 
//         multi3 = 
//     end  
//     16'h9592:begin//1110 1010 0110 1110
//         multi2 = 
//         multi3 = 
//     end  
//     16'h9236:begin//1110 1101 1100 1010
//         multi2 = 
//         multi3 = 
//     end  
//     16'h8F1D:begin//1111 0000 1110 0011
//         multi2 = 
//         multi3 = 
//     end  
//     16'h8C4A:begin//1111 0011 1011 0110
//         multi2 = 
//         multi3 = 
//     end  
//     16'h89BE:begin//1111 0110 0100 0010
//         multi2 = 
//         multi3 = 
//     end  
//     16'h877B:begin//1111 1000 1000 0101
//         multi2 = 
//         multi3 = 
//     end  
//     16'h8583:begin//1111 1010 0111 1101
//         multi2 = 
//         multi3 = 
//     end  
//     16'h83D6:begin//1111 1100 0010 1010
//         multi2 = 
//         multi3 = 
//     end  
//     16'h8276:begin//1111 1101 1000 1010
//         multi2 = 
//         multi3 = 
//     end  
//     16'h8163:begin//1111 1110 1001 1101
//         multi2 = 
//         multi3 = 
//     end  
//     16'h809E:begin//1111 1111 0110 0010
//         multi2 = 
//         multi3 = 
//     end  
//     16'h8027:begin//1111 1111 1101 1001
//         multi2 = 
//         multi3 = 
//     end  
//     16'h8000:begin//1000 0000 0000 0000
//         multi2 = 
//         multi3 = 
//     end  
//     16'h8027:begin//1111 1111 1101 1001
//         multi2 = 
//         multi3 = 
//     end  
//     16'h809E:begin//1111 1111 0110 0010
//         multi2 = 
//         multi3 = 
//     end    
//     16'h8276:begin//1111 1101 1000 1010
//         multi2 = 
//         multi3 = 
//     end    
//     16'h8583:begin//1111 1010 0111 1101
//         multi2 = 
//         multi3 = 
//     end  
//     16'h877B:begin//1111 1000 1000 0101
//         multi2 = 
//         multi3 = 
//     end  
//     16'h89BE:begin//1111 0110 0100 0010
//         multi2 = 
//         multi3 = 
//     end    
//     16'h8F1D:begin//1111 0000 1110 0011
//         multi2 = 
//         multi3 = 
//     end    
//     16'h9592:begin//1110 1010 0110 1110
//         multi2 = 
//         multi3 = 
//     end  
//     16'h9930:begin//1110 0110 1101 0000
//         multi2 = 
//         multi3 = 
//     end  
//     16'h9D0E:begin//1110 0010 1111 0010
//         multi2 = 
//         multi3 = 
//     end    
//     16'hA57E:begin//1101 1010 1000 0010
//         multi2 = 
//         multi3 = 
//     end    
//     16'hAECC:begin//1101 0001 0011 0100
//         multi2 = 
//         multi3 = 
//     end  
//     16'hB3C0:begin//1100 1100 0100 0000
//         multi2 = 
//         multi3 = 
//     end  
//     16'hB8E3:begin//1100 0111 0001 1101
//         multi2 = 
//         multi3 = 
//     end    
//     16'hC3A9:begin//1011 1100 0101 0111
//         multi2 = 
//         multi3 = 
//     end    
//     16'hCF04:begin//1011 0000 1111 1100
//         multi2 = 
//         multi3 = 
//     end  
//     16'hD4E1:begin//1010 1011 0001 1111
//         multi2 = 
//         multi3 = 
//     end  
//     16'hDAD8:begin//1010 0101 0010 1000
//         multi2 = 
//         multi3 = 
//     end    
//     16'hE707:begin//1001 1000 1111 1001
//         multi2 = 
//         multi3 = 
//     end    
//     16'hF374:begin//1000 1100 1000 1100
//         multi2 = 
//         multi3 = 
//     end  
//     16'hF9B8:begin//1000 0110 0100 1000
//         multi2 = 
//         multi3 = 
//     end      
//     16'h0C8C:begin//0000 1100 1000 1100
//         multi2 = 
//         multi3 = 
//     end      
//     16'h1F1A:begin//0001 1111 0001 1010
//         multi2 = 
//         multi3 = 
//     end      
//     16'h30FC:begin//0011 0000 1111 1100
//         multi2 = 
//         multi3 = 
//     end      
//     16'h41CE:begin//0100 0001 1100 1110
//         multi2 = 
//         multi3 = 
//     end      
//     16'h5134:begin//0101 0001 0011 0100
//         multi2 = 
//         multi3 = 
//     end      
//     16'h5ED7:begin//0101 1110 1101 0111
//         multi2 = 
//         multi3 = 
//     end      
//     16'h6A6E:begin//0110 1010 0110 1110
//         multi2 = 
//         multi3 = 
//     end      
//     16'h73B6:begin//0111 0011 1011 0110
//         multi2 = 
//         multi3 = 
//     end      
//     16'h7A7D:begin//0111 1010 0111 1101
//         multi2 = 
//         multi3 = 
//     end      
//     16'h7E9D:begin//0111 1110 1001 1101
//         multi2 = 
//         multi3 = 
//     end              
//     default:
//     endcase
// end


// endmodule
