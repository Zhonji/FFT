//---------------------------------------------------------------------------
//  Alter_FFT : FFT Module With Alternative Points
//  Author    : zhongyuanji
//  Company   : Ravsense
//  Time      : 2023/06/26
//  Version   ：V2.0 
//---------------------------------------------------------------------------
//  Version   ：V1.0 
//      
//  Version   ：V2.0 
//      Change the way Where Ready and Success signals are assigned and add comments
//  
//---------------------------------------------------------------------------
module Alter_FFT #(
    parameter WIDTH = 16
)(
    input                       clock,      //  Master Clock
    input                       reset,      //  Active High Asynchronous Reset
    input                       di_en,      //  Input Data Enable
    input   signed [WIDTH-1:0]  di_re,      //  Input Data (Real)
    input   signed [WIDTH-1:0]  di_im,      //  Input Data (Imag)
    input   [1:0]                 sel,      //  Selecting the points
    input   [2:0]                 LSN,      //  Depend on the inputdata bit width, Left_Shift_Number
    input                     do_form,      //  Decide the outputdata format, 1 for the true form/ 0 for the complement form
  // ***DISCARDED***   input               di_disable,    interrupt the input
    output                      do_en,      //  Output Data Enable
    output  signed [WIDTH-1:0]  do_re,      //  Output Data (Real)
    output  signed [WIDTH-1:0]  do_im,      //  Output Data (Imag)
    output                      Ready,      //  Signal indicating the fft module could accept inputdata
    output  wire              Success       //  Signal indicating the fft successfully completed the current output, please check the "error" in testbench
);

wire signed [WIDTH-1:0] di_fft_re;  //  Real Inputdata Before Left Shift
wire signed [WIDTH-1:0] di_fft_im;  //  Imag Inputdata Before Left Shift

wire su1_in_en;                     //  Inputdata for Module SU_1
wire signed [WIDTH-1:0] su1_in_re;
wire signed [WIDTH-1:0] su1_in_im;
wire su1_do_en;                     //  Outputdata from Module Su_1
wire signed [WIDTH-1:0] su1_do_re;
wire signed [WIDTH-1:0] su1_do_im;

wire su2_in_en;                     //  Inputdata for Module SU_2
wire signed [WIDTH-1:0] su2_in_re;
wire signed [WIDTH-1:0] su2_in_im;
wire su2_do_en;                     //  Outputdata from Module Su_2
wire signed [WIDTH-1:0] su2_do_re;
wire signed [WIDTH-1:0] su2_do_im;

wire su3_do_en;                     //  Outputdata from Module Su_3
wire signed [WIDTH-1:0] su3_do_re;
wire signed [WIDTH-1:0] su3_do_im;

wire su4_do_en;                     //  Outputdata from Module Su_4
wire signed [WIDTH-1:0] su4_do_re;
wire signed [WIDTH-1:0] su4_do_im;

wire su5_in_en;                     //  Inputdata for Module SU_5
wire signed [WIDTH-1:0] su5_in_re;
wire signed [WIDTH-1:0] su5_in_im;
wire su5_do_en;                     //  Outputdata from Module Su_5
wire signed [WIDTH-1:0] su5_do_re;
wire signed [WIDTH-1:0] su5_do_im;

wire su6_in_en;                     //  Inputdata for Module SU_6
wire signed [WIDTH-1:0] su6_in_re;
wire signed [WIDTH-1:0] su6_in_im;
wire su6_do_en;                     //  Outputdata from Module Su_6
wire signed [WIDTH-1:0] su6_do_re;
wire signed [WIDTH-1:0] su6_do_im;

wire su7_do_en;                     //  Outputdata from Module Su_7
wire signed [WIDTH-1:0] su7_do_re;
wire signed [WIDTH-1:0] su7_do_im;
//---------------------------------------------------------------------------
//  Select the module that corresponds to the number of points
//---------------------------------------------------------------------------
assign su1_in_en = (sel[1] && (!sel[0])) ? di_en     : 1'b0;
assign su1_in_re = (sel[1] && (!sel[0])) ? di_fft_re : {WIDTH{1'b0}};
assign su1_in_im = (sel[1] && (!sel[0])) ? di_fft_im : {WIDTH{1'b0}};

assign su2_in_en = (sel[1]) ? ((sel[0]) ? di_en : su1_do_en)     : 1'b0;
assign su2_in_re = (sel[1]) ? ((sel[0]) ? di_fft_re : su1_do_re) : {WIDTH{1'b0}};
assign su2_in_im = (sel[1]) ? ((sel[0]) ? di_fft_im : su1_do_im) : {WIDTH{1'b0}};

assign su5_in_en = ((!sel[1]) && sel[0]) ? di_en     : 1'b0;
assign su5_in_re = ((!sel[1]) && sel[0]) ? di_fft_re : {WIDTH{1'b0}};
assign su5_in_im = ((!sel[1]) && sel[0]) ? di_fft_im : {WIDTH{1'b0}};

assign su6_in_en = (!sel[1]) ? ((sel[0]) ? su5_do_en : di_en)     : 1'b0;
assign su6_in_re = (!sel[1]) ? ((sel[0]) ? su5_do_re : di_fft_re) : {WIDTH{1'b0}};
assign su6_in_im = (!sel[1]) ? ((sel[0]) ? su5_do_im : di_fft_im) : {WIDTH{1'b0}};
//---------------------------------------------------------------------------
// assign di_fft_re/di_fft_im
//---------------------------------------------------------------------------
assign di_fft_re = di_re << LSN;
assign di_fft_im = di_im << LSN;
//---------------------------------------------------------------------------
// Setup do_en counter, for Success signal 
//---------------------------------------------------------------------------
reg [7:0] do_counter;

always@(posedge clock)begin
    if(reset)begin
        do_counter <= 'd0;
    end
    else begin
        if(do_en)begin
            do_counter <= do_counter + 1'b1;
        end
        else begin
            do_counter <= 1'b0;
        end
    end
end
// --------------------------------------------------------------------------
// Output Singal : Ready
// --------------------------------------------------------------------------
reg reset_state0;
reg reset_state1;
reg Ready_state;
// Capture The Negedge Reset
always@(posedge clock)begin
    reset_state0 <= reset;
    reset_state1 <= reset_state0;
end
//  Determine the current Ready status

always@(posedge clock, posedge reset)begin
    if(reset)begin
        Ready_state = 1'b0;
    end
    else begin
        if((!reset_state0)&&(reset_state1))begin
            Ready_state = 1'b1; 
        end
        else begin
            if(di_en)begin
                Ready_state = 1'b0;
            end
            else begin
                if(Success)begin
                    Ready_state = 1;
                end
            end
        end
    end
end
assign Ready = Ready_state;
// --------------------------------------------------------------------------
// Output Singal : Success
// --------------------------------------------------------------------------
reg do_en_state;
reg Success_state;
always@(posedge clock)begin
    if(reset)begin
        do_en_state <= 'd0;
    end
    else begin
        do_en_state <= do_en;
    end
end
//  Determine whether the output is completed
always@(posedge clock, posedge reset)begin
    if(reset)begin
        Success_state <= 'd0;
    end
    else begin
        case(sel)
            2'b00:begin//16 points
                Success_state <= (do_counter == 'd15)? 1'b1 : 1'b0;
            end
            2'b01:begin//64 points
                Success_state <= (do_counter == 'd63)? 1'b1 : 1'b0;
            end
            2'b10:begin//128 points
                Success_state <= (do_counter == 'd127)? 1'b1 : 1'b0; 
            end
            2'b11:begin//32 points
                Success_state <= (do_counter == 'd31)? 1'b1 : 1'b0;
            end
        endcase
    end
end
assign Success = Success_state;
// --------------------------------------------------------------------------
// 128/32 points circuit architecture implementation
// --------------------------------------------------------------------------

SdfUnit1 #(.N(128),.M(128),.WIDTH(WIDTH)) SU1 (
    .clock  (clock      ),  //  i
    .reset  (reset      ),  //  i
    .di_en  (su1_in_en  ),  //  i
    .di_re  (su1_in_re  ),  //  i
    .di_im  (su1_in_im  ),  //  i
    .adjust(sel[1]&&sel[0]),//  i
    .do_en  (su1_do_en  ),  //  o
    .do_re  (su1_do_re  ),  //  o
    .do_im  (su1_do_im  )   //  o
);

SdfUnit1 #(.N(128),.M(32),.WIDTH(WIDTH)) SU2 (
    .clock  (clock      ),  //  i
    .reset  (reset      ),  //  i
    .di_en  (su2_in_en  ),  //  i
    .di_re  (su2_in_re  ),  //  i
    .di_im  (su2_in_im  ),  //  i
    .adjust(sel[1]&&sel[0]),//  i
    .do_en  (su2_do_en  ),  //  o
    .do_re  (su2_do_re  ),  //  o
    .do_im  (su2_do_im  )   //  o
);

SdfUnit1 #(.N(128),.M(8),.WIDTH(WIDTH)) SU3 (
    .clock  (clock      ),  //  i
    .reset  (reset      ),  //  i
    .di_en  (su2_do_en  ),  //  i
    .di_re  (su2_do_re  ),  //  i
    .di_im  (su2_do_im  ),  //  i
    .adjust(sel[1]&&sel[0]),//  i
    .do_en  (su3_do_en  ),  //  o
    .do_re  (su3_do_re  ),  //  o
    .do_im  (su3_do_im  )   //  o
);

SdfUnit2 #(.WIDTH(WIDTH)) SU4 (
    .clock  (clock          ),  //  i
    .reset  (reset          ),  //  i
    .di_en  (su3_do_en      ),  //  i
    .di_re  (su3_do_re      ),  //  i
    .di_im  (su3_do_im      ),  //  i
    .do_en  (su4_do_en      ),  //  o
    .do_re  (su4_do_re      ),  //  o
    .do_im  (su4_do_im      )   //  o
);

// --------------------------------------------------------------------------
// 64/16 points circuit architecture implementation
// --------------------------------------------------------------------------

SdfUnit0 #(.N(64),.M(64),.WIDTH(WIDTH)) SU5 (
    .clock  (clock      ),          //  i
    .reset  (reset      ),          //  i
    .di_en  (su5_in_en  ),          //  i
    .di_re  (su5_in_re  ),          //  i
    .di_im  (su5_in_im  ),          //  i
    .adjust((!sel[1])&&(!sel[0])),  //  i
    .do_en  (su5_do_en  ),          //  o
    .do_re  (su5_do_re  ),          //  o
    .do_im  (su5_do_im  )           //  o
);

SdfUnit0 #(.N(64),.M(16),.WIDTH(WIDTH)) SU6 (
    .clock  (clock      ),          //  i
    .reset  (reset      ),          //  i
    .di_en  (su6_in_en  ),          //  i
    .di_re  (su6_in_re  ),          //  i
    .di_im  (su6_in_im  ),          //  i
    .adjust((!sel[1])&&(!sel[0])),  //  i
    .do_en  (su6_do_en  ),          //  o
    .do_re  (su6_do_re  ),          //  o
    .do_im  (su6_do_im  )           //  o
);

SdfUnit0 #(.N(64),.M(4),.WIDTH(WIDTH)) SU7 (
    .clock  (clock      ),          //  i
    .reset  (reset      ),          //  i
    .di_en  (su6_do_en  ),          //  i
    .di_re  (su6_do_re  ),          //  i
    .di_im  (su6_do_im  ),          //  i
    .adjust((!sel[1])&&(!sel[0])),  //  i
    .do_en  (su7_do_en  ),          //  o
    .do_re  (su7_do_re  ),          //  o
    .do_im  (su7_do_im  )           //  o
);
// ------------------------------------------------------------------
// Outputdata, and decide the Outputdata form
// ------------------------------------------------------------------
assign do_en = sel[1] ? su4_do_en : su7_do_en;
assign do_re = do_form ? (sel[1] ? (su4_do_re[15] ? {su4_do_re[15], ~su4_do_re[14:0] + 1} : su4_do_re) : (su7_do_re[15] ? {su7_do_re[15], ~su7_do_re[14:0] + 1} : su7_do_re)) : (sel[1] ? su4_do_re : su7_do_re);
assign do_im = do_form ? (sel[1] ? (su4_do_im[15] ? {su4_do_im[15], ~su4_do_im[14:0] + 1} : su4_do_im) : (su7_do_im[15] ? {su7_do_im[15], ~su7_do_im[14:0] + 1} : su7_do_im)) : (sel[1] ? su4_do_im : su7_do_im);

endmodule
