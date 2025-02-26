`define OPTI
//----------------------------------------------------------------------
//  SdfUnit: Radix-2^2 Single-Path Delay Feedback Unit for N-Point FFT
//  Author    : zhongyuanji
//  Company   : Ravsense
//  Time      : 2023/06/26
//  Version   ：V2.0 
//----------------------------------------------------------------------
//  Version   ：V1.0 
//  Version   ：V2.0 
//      Change the Twiddle addressing method to 
//      selectable by the def parameter and add comments
//  
//----------------------------------------------------------------------
module SdfUnit1 #(
    parameter   N = 128,                //  Number of FFT Point
    parameter   M = 64,                 //  Twiddle Resolution
    parameter   WIDTH = 16              //  Data Bit Length
)(
    input                       clock,          //  Master Clock
    input                       reset,          //  Active High Asynchronous Reset
    input                       di_en,          //  Input Data Enable
    input    signed [WIDTH-1:0] di_re,          //  Input Data (Real)
    input    signed [WIDTH-1:0] di_im,          //  Input Data (Imag)
    input                      adjust,          //  used for adjusting different points,depends on the sel 
    output                      do_en,          //  Output Data Enable
    output   signed [WIDTH-1:0] do_re,          //  Output Data (Real)
    output   signed [WIDTH-1:0] do_im           //  Output Data (Imag)
);

//  log2 constant function
function integer log2;
    input integer x;
    integer value;
    begin
        value = x-1;
        for (log2=0; value>0; log2=log2+1)
            value = value>>1;
    end
endfunction

localparam  LOG_N = log2(N);        //  Bit Length of N
localparam  LOG_N32 = LOG_N - 2;    //  Bit Length of N - 2
localparam  LOG_M = log2(M);        //  Bit Length of M

//----------------------------------------------------------------------
//  Internal Regs and Nets
//----------------------------------------------------------------------
//  1st Butterfly
reg [LOG_N-1:0]          di_count;  //  Input Data Count
reg [LOG_N32 - 1:0]    di_count32;  //  Input Data Count(N-2)

wire                       bf1_bf;  //  Butterfly Add/Sub Enable
wire signed [WIDTH-1:0] bf1_x0_re;  //  Data #0 to Butterfly (Real)
wire signed [WIDTH-1:0] bf1_x0_im;  //  Data #0 to Butterfly (Imag)
wire signed [WIDTH-1:0] bf1_x1_re;  //  Data #1 to Butterfly (Real)
wire signed [WIDTH-1:0] bf1_x1_im;  //  Data #1 to Butterfly (Imag)
wire signed [WIDTH-1:0] bf1_y0_re;  //  Data #0 from Butterfly (Real)
wire signed [WIDTH-1:0] bf1_y0_im;  //  Data #0 from Butterfly (Imag)
wire signed [WIDTH-1:0] bf1_y1_re;  //  Data #1 from Butterfly (Real)
wire signed [WIDTH-1:0] bf1_y1_im;  //  Data #1 from Butterfly (Imag)
wire signed [WIDTH-1:0] db1_di_re;  //  Data to DelayBuffer (Real)
wire signed [WIDTH-1:0] db1_di_im;  //  Data to DelayBuffer (Imag)
wire signed [WIDTH-1:0] db1_do_re;  //  Data from DelayBuffer (Real)
wire signed [WIDTH-1:0] db1_do_im;  //  Data from DelayBuffer (Imag)
wire signed [WIDTH-1:0] bf1_sp_re;  //  Single-Path Data Output (Real)
wire signed [WIDTH-1:0] bf1_sp_im;  //  Single-Path Data Output (Imag)
reg                     bf1_sp_en;  //  Single-Path Data Enable
reg [LOG_N-1:0]         bf1_count;  //  Single-Path Data Count
reg [LOG_N32-1:0]     bf1_count32;  //  Single-Path Data Count(N-2)

wire                    bf1_start;  //  Single-Path Output Trigger
wire                      bf1_end;  //  End of Single-Path Data
wire                       bf1_mj;  //  Twiddle (-j) Enable
reg  signed [WIDTH-1:0] bf1_do_re;  //  1st Butterfly Output Data (Real)
reg  signed [WIDTH-1:0] bf1_do_im;  //  1st Butterfly Output Data (Imag)

//  2nd Butterfly
reg                        bf2_bf;  //  Butterfly Add/Sub Enable
wire signed [WIDTH-1:0] bf2_x0_re;  //  Data #0 to Butterfly (Real)
wire signed [WIDTH-1:0] bf2_x0_im;  //  Data #0 to Butterfly (Imag)
wire signed [WIDTH-1:0] bf2_x1_re;  //  Data #1 to Butterfly (Real)
wire signed [WIDTH-1:0] bf2_x1_im;  //  Data #1 to Butterfly (Imag)
wire signed [WIDTH-1:0] bf2_y0_re;  //  Data #0 from Butterfly (Real)
wire signed [WIDTH-1:0] bf2_y0_im;  //  Data #0 from Butterfly (Imag)
wire signed [WIDTH-1:0] bf2_y1_re;  //  Data #1 from Butterfly (Real)
wire signed [WIDTH-1:0] bf2_y1_im;  //  Data #1 from Butterfly (Imag)
wire signed [WIDTH-1:0] db2_di_re;  //  Data to DelayBuffer (Real)
wire signed [WIDTH-1:0] db2_di_im;  //  Data to DelayBuffer (Imag)
wire signed [WIDTH-1:0] db2_do_re;  //  Data from DelayBuffer (Real)
wire signed [WIDTH-1:0] db2_do_im;  //  Data from DelayBuffer (Imag)
wire signed [WIDTH-1:0] bf2_sp_re;  //  Single-Path Data Output (Real)
wire signed [WIDTH-1:0] bf2_sp_im;  //  Single-Path Data Output (Imag)
reg                     bf2_sp_en;  //  Single-Path Data Enable
reg [LOG_N-1:0]         bf2_count;  //  Single-Path Data Count
reg [LOG_N32-1:0]     bf2_count32;  //  Single-Path Data Count(N-2)

reg                     bf2_start;  //  Single-Path Output Trigger
wire                      bf2_end;  //  End of Single-Path Data
reg  signed [WIDTH-1:0] bf2_do_re;  //  2nd Butterfly Output Data (Real)
reg  signed [WIDTH-1:0] bf2_do_im;  //  2nd Butterfly Output Data (Imag)
reg                     bf2_do_en;  //  2nd Butterfly Output Data Enable

//  Multiplication
wire[1:0]                  tw_sel;  //  Twiddle Select (2n/n/3n)
wire[LOG_N-3:0]            tw_num;  //  Twiddle Number (n)
wire[LOG_N-1:0]           tw_addr;  //  Twiddle Table Address

wire signed [WIDTH-1:0]     tw_re;  //  Twiddle Factor (Real)
wire signed [WIDTH-1:0]     tw_im;  //  Twiddle Factor (Imag)
reg                         mu_en;  //  Multiplication Enable
wire signed [WIDTH-1:0]   mu_a_re;  //  Multiplier Input (Real)
wire signed [WIDTH-1:0]   mu_a_im;  //  Multiplier Input (Imag)
wire signed [WIDTH-1:0]   mu_m_re;  //  Multiplier Output (Real)
wire signed [WIDTH-1:0]   mu_m_im;  //  Multiplier Output (Imag)
reg  signed [WIDTH-1:0]  mu_do_re;  //  Multiplication Output Data (Real)
reg  signed [WIDTH-1:0]  mu_do_im;  //  Multiplication Output Data (Imag)
reg                      mu_do_en;  //  Multiplication Output Data Enable

// Assign The Count For Module
always@(*)begin
    di_count32 = di_count[(LOG_N32 - 1):0];
    bf1_count32 = bf1_count[(LOG_N32 - 1):0];
    bf2_count32 = bf2_count[(LOG_N32 - 1):0];
end


//----------------------------------------------------------------------
//  1st Butterfly
//----------------------------------------------------------------------
// Setup di_count, control the first bf and Delay 
always @(posedge clock or posedge reset) begin
    if (reset) begin
        di_count <= {LOG_N{1'b0}};
    end else begin
        di_count <= di_en ? (di_count + 1'b1) : {LOG_N{1'b0}};
    end
end
assign  bf1_bf = di_count[LOG_M-1];

//  Set unknown value x for verification
assign  bf1_x0_re = bf1_bf ? db1_do_re : {WIDTH{1'b0}};
assign  bf1_x0_im = bf1_bf ? db1_do_im : {WIDTH{1'b0}};
assign  bf1_x1_re = bf1_bf ? di_re : {WIDTH{1'b0}};
assign  bf1_x1_im = bf1_bf ? di_im : {WIDTH{1'b0}};

// The first bf(BF1), WIDTH decide the bit width, RH decides whether to round
Butterfly #(.WIDTH(WIDTH),.RH(0)) BF1 (
    .x0_re  (bf1_x0_re  ),  //  i
    .x0_im  (bf1_x0_im  ),  //  i
    .x1_re  (bf1_x1_re  ),  //  i
    .x1_im  (bf1_x1_im  ),  //  i
    .y0_re  (bf1_y0_re  ),  //  o
    .y0_im  (bf1_y0_im  ),  //  o
    .y1_re  (bf1_y1_re  ),  //  o
    .y1_im  (bf1_y1_im  )   //  o
);

DelayBuffer #(.DEPTH(2**(LOG_M-1)),.WIDTH(WIDTH)) DB1 (
    .clock  (clock      ),  //  i
    .di_re  (db1_di_re  ),  //  i
    .di_im  (db1_di_im  ),  //  i
    .do_re  (db1_do_re  ),  //  o
    .do_im  (db1_do_im  )   //  o
);
//Generate the timing signal for next BF
assign  db1_di_re = bf1_bf ? bf1_y1_re : di_re;
assign  db1_di_im = bf1_bf ? bf1_y1_im : di_im;
assign  bf1_sp_re = bf1_bf ? bf1_y0_re : bf1_mj ?  db1_do_im : db1_do_re;
assign  bf1_sp_im = bf1_bf ? bf1_y0_im : bf1_mj ? -db1_do_re : db1_do_im;

always @(posedge clock or posedge reset) begin
    if (reset) begin
        bf1_sp_en <= 1'b0;
        bf1_count <= {LOG_N{1'b0}};
    end else begin
        bf1_sp_en <= bf1_start ? 1'b1 : bf1_end ? 1'b0 : bf1_sp_en;
        bf1_count <= bf1_sp_en ? (bf1_count + 1'b1) : {LOG_N{1'b0}};
    end
end
assign  bf1_start = (di_count == (2**(LOG_M-1)-1));
assign  bf1_end = adjust? (bf1_count == (2**LOG_N32-1)): (bf1_count == (2**LOG_N-1));
assign  bf1_mj = (bf1_count[LOG_M-1:LOG_M-2] == 2'd3);

always @(posedge clock) begin
    bf1_do_re <= bf1_sp_re;
    bf1_do_im <= bf1_sp_im;
end

//----------------------------------------------------------------------
//  2nd Butterfly
//----------------------------------------------------------------------
always @(posedge clock) begin
    bf2_bf <= bf1_count[LOG_M-2];
end

//  Set unknown value x for verification
assign  bf2_x0_re = bf2_bf ? db2_do_re : {WIDTH{1'b0}};
assign  bf2_x0_im = bf2_bf ? db2_do_im : {WIDTH{1'b0}};
assign  bf2_x1_re = bf2_bf ? bf1_do_re : {WIDTH{1'b0}};
assign  bf2_x1_im = bf2_bf ? bf1_do_im : {WIDTH{1'b0}};

//  Negative bias occurs when RH=0 and positive bias occurs when RH=1.
//  Using both alternately reduces the overall rounding error.
Butterfly #(.WIDTH(WIDTH),.RH(1)) BF2 (
    .x0_re  (bf2_x0_re  ),  //  i
    .x0_im  (bf2_x0_im  ),  //  i
    .x1_re  (bf2_x1_re  ),  //  i
    .x1_im  (bf2_x1_im  ),  //  i
    .y0_re  (bf2_y0_re  ),  //  o
    .y0_im  (bf2_y0_im  ),  //  o
    .y1_re  (bf2_y1_re  ),  //  o
    .y1_im  (bf2_y1_im  )   //  o
);

DelayBuffer #(.DEPTH(2**(LOG_M-2)),.WIDTH(WIDTH)) DB2 (
    .clock  (clock      ),  //  i
    .di_re  (db2_di_re  ),  //  i
    .di_im  (db2_di_im  ),  //  i
    .do_re  (db2_do_re  ),  //  o
    .do_im  (db2_do_im  )   //  o
);

assign  db2_di_re = bf2_bf ? bf2_y1_re : bf1_do_re;
assign  db2_di_im = bf2_bf ? bf2_y1_im : bf1_do_im;
assign  bf2_sp_re = bf2_bf ? bf2_y0_re : db2_do_re;
assign  bf2_sp_im = bf2_bf ? bf2_y0_im : db2_do_im;

always @(posedge clock or posedge reset) begin
    if (reset) begin
        bf2_sp_en <= 1'b0;
        bf2_count <= {LOG_N{1'b0}};
    end else begin
        bf2_sp_en <= bf2_start ? 1'b1 : bf2_end ? 1'b0 : bf2_sp_en;
        bf2_count <= bf2_sp_en ? (bf2_count + 1'b1) : {LOG_N{1'b0}};
    end
end

always @(posedge clock) begin
    bf2_start <= (bf1_count == (2**(LOG_M-2)-1)) & bf1_sp_en;
end
assign  bf2_end = adjust? (bf2_count == (2**LOG_N32-1)) : (bf2_count == (2**LOG_N-1));

always @(posedge clock) begin
    bf2_do_re <= bf2_sp_re;
    bf2_do_im <= bf2_sp_im;
end

always @(posedge clock or posedge reset) begin
    if (reset) begin
        bf2_do_en <= 1'b0;
    end else begin
        bf2_do_en <= bf2_sp_en;
    end
end

//----------------------------------------------------------------------
//  Multiplication
//----------------------------------------------------------------------
assign  tw_sel[1] = bf2_count[LOG_M-2];
assign  tw_sel[0] = bf2_count[LOG_M-1];
assign  tw_num = bf2_count << (LOG_N-LOG_M);
// Choose the way you address the Twiddle
`ifdef  OPTI
    reg [LOG_N-1:0]       tw_addr_reg;  //  Twiddle Table Address(REG)
    always@(*)begin
        case(tw_sel)
            2'b00:  tw_addr_reg = 'd0;
            2'b01:  tw_addr_reg = tw_num;
            2'b10:  tw_addr_reg = tw_num + tw_num;
            2'b11:  tw_addr_reg = tw_num + tw_num + tw_num;
            default:;
        endcase
    end
    assign  tw_addr = tw_addr_reg;
`else
    assign  tw_addr = tw_num * tw_sel;
`endif



Twiddle128 TW (
    .clock  (clock  ),  //  i
    .addr   (tw_addr),  //  i
    .tw_re  (tw_re  ),  //  o
    .tw_im  (tw_im  )   //  o
);

//  Multiplication is bypassed when twiddle address is 0.
always @(posedge clock) begin
    mu_en <= (tw_addr != {LOG_N{1'b0}});
end
//  Set unknown value x for verification
assign  mu_a_re = mu_en ? bf2_do_re : {WIDTH{1'b0}};
assign  mu_a_im = mu_en ? bf2_do_im : {WIDTH{1'b0}};

// Decide whether to use the optimized multiplier ; if define,then use the optimized one
`ifdef OPTI
    multiply_opti #(
        .WIDTH(WIDTH)
    )inst1(
    .a_re   (mu_a_re),      //  i
    .a_im   (mu_a_im),      //  i
    .tw_re  (tw_re  ),      //  i
    .tw_im  (tw_im  ),      //  i
    .m_re   (mu_m_re),      //  o
    .m_im   (mu_m_im)       //  o
    );
`else
    Multiply #(.WIDTH(WIDTH)) MU (
    .a_re   (mu_a_re),  //  i
    .a_im   (mu_a_im),  //  i
    .b_re   (tw_re  ),  //  i
    .b_im   (tw_im  ),  //  i
    .m_re   (mu_m_re),  //  o
    .m_im   (mu_m_im)   //  o
    );
`endif

always @(posedge clock) begin
    mu_do_re <= mu_en ? mu_m_re : bf2_do_re;
    mu_do_im <= mu_en ? mu_m_im : bf2_do_im;
end

always @(posedge clock or posedge reset) begin
    if (reset) begin
        mu_do_en <= 1'b0;
    end else begin
        mu_do_en <= bf2_do_en;
    end
end

//  No multiplication required at final stage
assign  do_en = (LOG_M == 2) ? bf2_do_en : mu_do_en;
assign  do_re = (LOG_M == 2) ? bf2_do_re : mu_do_re;
assign  do_im = (LOG_M == 2) ? bf2_do_im : mu_do_im;

endmodule


// `define OPTI
// //----------------------------------------------------------------------
// //  SdfUnit: Radix-2^2 Single-Path Delay Feedback Unit for N-Point FFT
// //  Author    : zhongyuanji
// //  Company   : Ravsense
// //  Time      : 2023/06/26
// //  Version   ：V2.0 
// //----------------------------------------------------------------------
// module SdfUnit1 #(
//     parameter   N = 128,                //  Number of FFT Point
//     parameter   M = 64,                 //  Twiddle Resolution
//     parameter   WIDTH = 16              //  Data Bit Length
// )(
//     input                       clock,          //  Master Clock
//     input                       reset,          //  Active High Asynchronous Reset
//     input                       di_en,          //  Input Data Enable
//     input    signed [WIDTH-1:0] di_re,          //  Input Data (Real)
//     input    signed [WIDTH-1:0] di_im,          //  Input Data (Imag)
//     input                      adjust,          //  used for adjusting different points,depends on the sel 
//     output                      do_en,          //  Output Data Enable
//     output   signed [WIDTH-1:0] do_re,          //  Output Data (Real)
//     output   signed [WIDTH-1:0] do_im           //  Output Data (Imag)
// );

// //  log2 constant function
// function integer log2;
//     input integer x;
//     integer value;
//     begin
//         value = x-1;
//         for (log2=0; value>0; log2=log2+1)
//             value = value>>1;
//     end
// endfunction

// localparam  LOG_N = log2(N);        //  Bit Length of N
// localparam  LOG_N32 = LOG_N - 2;    //  Bit Length of N - 2
// localparam  LOG_M = log2(M);        //  Bit Length of M

// //----------------------------------------------------------------------
// //  Internal Regs and Nets
// //----------------------------------------------------------------------
// //  1st Butterfly
// reg [LOG_N-1:0] di_count;           //  Input Data Count
// reg [LOG_N32 - 1:0] di_count32;     //  Input Data Count(N-2)

// wire            bf1_bf;             //  Butterfly Add/Sub Enable
// wire signed [WIDTH-1:0] bf1_x0_re;  //  Data #0 to Butterfly (Real)
// wire signed [WIDTH-1:0] bf1_x0_im;  //  Data #0 to Butterfly (Imag)
// wire signed [WIDTH-1:0] bf1_x1_re;  //  Data #1 to Butterfly (Real)
// wire signed [WIDTH-1:0] bf1_x1_im;  //  Data #1 to Butterfly (Imag)
// wire signed [WIDTH-1:0] bf1_y0_re;  //  Data #0 from Butterfly (Real)
// wire signed [WIDTH-1:0] bf1_y0_im;  //  Data #0 from Butterfly (Imag)
// wire signed [WIDTH-1:0] bf1_y1_re;  //  Data #1 from Butterfly (Real)
// wire signed [WIDTH-1:0] bf1_y1_im;  //  Data #1 from Butterfly (Imag)
// wire signed [WIDTH-1:0] db1_di_re;  //  Data to DelayBuffer (Real)
// wire signed [WIDTH-1:0] db1_di_im;  //  Data to DelayBuffer (Imag)
// wire signed [WIDTH-1:0] db1_do_re;  //  Data from DelayBuffer (Real)
// wire signed [WIDTH-1:0] db1_do_im;  //  Data from DelayBuffer (Imag)
// wire signed [WIDTH-1:0] bf1_sp_re;  //  Single-Path Data Output (Real)
// wire signed [WIDTH-1:0] bf1_sp_im;  //  Single-Path Data Output (Imag)
// reg             bf1_sp_en;          //  Single-Path Data Enable
// reg [LOG_N-1:0] bf1_count;          //  Single-Path Data Count
// reg [LOG_N32-1:0] bf1_count32;      //  Single-Path Data Count(N-2)

// wire            bf1_start;          //  Single-Path Output Trigger
// wire            bf1_end;            //  End of Single-Path Data
// wire            bf1_mj;             //  Twiddle (-j) Enable
// reg  signed [WIDTH-1:0] bf1_do_re;  //  1st Butterfly Output Data (Real)
// reg  signed [WIDTH-1:0] bf1_do_im;  //  1st Butterfly Output Data (Imag)

// //  2nd Butterfly
// reg             bf2_bf;             //  Butterfly Add/Sub Enable
// wire signed [WIDTH-1:0] bf2_x0_re;  //  Data #0 to Butterfly (Real)
// wire signed [WIDTH-1:0] bf2_x0_im;  //  Data #0 to Butterfly (Imag)
// wire signed [WIDTH-1:0] bf2_x1_re;  //  Data #1 to Butterfly (Real)
// wire signed [WIDTH-1:0] bf2_x1_im;  //  Data #1 to Butterfly (Imag)
// wire signed [WIDTH-1:0] bf2_y0_re;  //  Data #0 from Butterfly (Real)
// wire signed [WIDTH-1:0] bf2_y0_im;  //  Data #0 from Butterfly (Imag)
// wire signed [WIDTH-1:0] bf2_y1_re;  //  Data #1 from Butterfly (Real)
// wire signed [WIDTH-1:0] bf2_y1_im;  //  Data #1 from Butterfly (Imag)
// wire signed [WIDTH-1:0] db2_di_re;  //  Data to DelayBuffer (Real)
// wire signed [WIDTH-1:0] db2_di_im;  //  Data to DelayBuffer (Imag)
// wire signed [WIDTH-1:0] db2_do_re;  //  Data from DelayBuffer (Real)
// wire signed [WIDTH-1:0] db2_do_im;  //  Data from DelayBuffer (Imag)
// wire signed [WIDTH-1:0] bf2_sp_re;  //  Single-Path Data Output (Real)
// wire signed [WIDTH-1:0] bf2_sp_im;  //  Single-Path Data Output (Imag)
// reg             bf2_sp_en;          //  Single-Path Data Enable
// reg [LOG_N-1:0] bf2_count;          //  Single-Path Data Count
// reg [LOG_N32-1:0] bf2_count32;      //  Single-Path Data Count(N-2)

// reg             bf2_start;          //  Single-Path Output Trigger
// wire            bf2_end;            //  End of Single-Path Data
// reg  signed [WIDTH-1:0] bf2_do_re;  //  2nd Butterfly Output Data (Real)
// reg  signed [WIDTH-1:0] bf2_do_im;  //  2nd Butterfly Output Data (Imag)
// reg             bf2_do_en;          //  2nd Butterfly Output Data Enable

// //  Multiplication
// wire[1:0]       tw_sel;             //  Twiddle Select (2n/n/3n)
// wire[LOG_N-3:0] tw_num;             //  Twiddle Number (n)
// wire[LOG_N-1:0] tw_addr;            //  Twiddle Table Address
// wire signed [WIDTH-1:0] tw_re;      //  Twiddle Factor (Real)
// wire signed [WIDTH-1:0] tw_im;      //  Twiddle Factor (Imag)
// reg             mu_en;              //  Multiplication Enable
// wire signed [WIDTH-1:0] mu_a_re;    //  Multiplier Input (Real)
// wire signed [WIDTH-1:0] mu_a_im;    //  Multiplier Input (Imag)
// wire signed [WIDTH-1:0] mu_m_re;    //  Multiplier Output (Real)
// wire signed [WIDTH-1:0] mu_m_im;    //  Multiplier Output (Imag)
// reg  signed [WIDTH-1:0] mu_do_re;   //  Multiplication Output Data (Real)
// reg  signed [WIDTH-1:0] mu_do_im;   //  Multiplication Output Data (Imag)
// reg             mu_do_en;           //  Multiplication Output Data Enable

// // Assign The Count For Module
// always@(*)begin
//     di_count32 = di_count[(LOG_N32 - 1):0];
//     bf1_count32 = bf1_count[(LOG_N32 - 1):0];
//     bf2_count32 = bf2_count[(LOG_N32 - 1):0];
// end


// //----------------------------------------------------------------------
// //  1st Butterfly
// //----------------------------------------------------------------------
// // Setup di_count, control the first bf and Delay 
// always @(posedge clock or posedge reset) begin
//     if (reset) begin
//         di_count <= {LOG_N{1'b0}};
//     end else begin
//         di_count <= di_en ? (di_count + 1'b1) : {LOG_N{1'b0}};
//     end
// end
// assign  bf1_bf = di_count[LOG_M-1];

// //  Set unknown value x for verification
// assign  bf1_x0_re = bf1_bf ? db1_do_re : {WIDTH{1'b0}};
// assign  bf1_x0_im = bf1_bf ? db1_do_im : {WIDTH{1'b0}};
// assign  bf1_x1_re = bf1_bf ? di_re : {WIDTH{1'b0}};
// assign  bf1_x1_im = bf1_bf ? di_im : {WIDTH{1'b0}};

// // The first bf(BF1), WIDTH decide the bit width, RH decides whether to round
// Butterfly #(.WIDTH(WIDTH),.RH(0)) BF1 (
//     .x0_re  (bf1_x0_re  ),  //  i
//     .x0_im  (bf1_x0_im  ),  //  i
//     .x1_re  (bf1_x1_re  ),  //  i
//     .x1_im  (bf1_x1_im  ),  //  i
//     .y0_re  (bf1_y0_re  ),  //  o
//     .y0_im  (bf1_y0_im  ),  //  o
//     .y1_re  (bf1_y1_re  ),  //  o
//     .y1_im  (bf1_y1_im  )   //  o
// );

// DelayBuffer #(.DEPTH(2**(LOG_M-1)),.WIDTH(WIDTH)) DB1 (
//     .clock  (clock      ),  //  i
//     .di_re  (db1_di_re  ),  //  i
//     .di_im  (db1_di_im  ),  //  i
//     .do_re  (db1_do_re  ),  //  o
//     .do_im  (db1_do_im  )   //  o
// );

// assign  db1_di_re = bf1_bf ? bf1_y1_re : di_re;
// assign  db1_di_im = bf1_bf ? bf1_y1_im : di_im;
// assign  bf1_sp_re = bf1_bf ? bf1_y0_re : bf1_mj ?  db1_do_im : db1_do_re;
// assign  bf1_sp_im = bf1_bf ? bf1_y0_im : bf1_mj ? -db1_do_re : db1_do_im;

// always @(posedge clock or posedge reset) begin
//     if (reset) begin
//         bf1_sp_en <= 1'b0;
//         bf1_count <= {LOG_N{1'b0}};
//     end else begin
//         bf1_sp_en <= bf1_start ? 1'b1 : bf1_end ? 1'b0 : bf1_sp_en;
//         bf1_count <= bf1_sp_en ? (bf1_count + 1'b1) : {LOG_N{1'b0}};
//     end
// end
// assign  bf1_start = (di_count == (2**(LOG_M-1)-1));
// assign  bf1_end = adjust? (bf1_count == (2**LOG_N32-1)): (bf1_count == (2**LOG_N-1));
// assign  bf1_mj = (bf1_count[LOG_M-1:LOG_M-2] == 2'd3);

// always @(posedge clock) begin
//     bf1_do_re <= bf1_sp_re;
//     bf1_do_im <= bf1_sp_im;
// end

// //----------------------------------------------------------------------
// //  2nd Butterfly
// //----------------------------------------------------------------------
// always @(posedge clock) begin
//     bf2_bf <= bf1_count[LOG_M-2];
// end

// //  Set unknown value x for verification
// assign  bf2_x0_re = bf2_bf ? db2_do_re : {WIDTH{1'b0}};
// assign  bf2_x0_im = bf2_bf ? db2_do_im : {WIDTH{1'b0}};
// assign  bf2_x1_re = bf2_bf ? bf1_do_re : {WIDTH{1'b0}};
// assign  bf2_x1_im = bf2_bf ? bf1_do_im : {WIDTH{1'b0}};

// //  Negative bias occurs when RH=0 and positive bias occurs when RH=1.
// //  Using both alternately reduces the overall rounding error.
// Butterfly #(.WIDTH(WIDTH),.RH(1)) BF2 (
//     .x0_re  (bf2_x0_re  ),  //  i
//     .x0_im  (bf2_x0_im  ),  //  i
//     .x1_re  (bf2_x1_re  ),  //  i
//     .x1_im  (bf2_x1_im  ),  //  i
//     .y0_re  (bf2_y0_re  ),  //  o
//     .y0_im  (bf2_y0_im  ),  //  o
//     .y1_re  (bf2_y1_re  ),  //  o
//     .y1_im  (bf2_y1_im  )   //  o
// );

// DelayBuffer #(.DEPTH(2**(LOG_M-2)),.WIDTH(WIDTH)) DB2 (
//     .clock  (clock      ),  //  i
//     .di_re  (db2_di_re  ),  //  i
//     .di_im  (db2_di_im  ),  //  i
//     .do_re  (db2_do_re  ),  //  o
//     .do_im  (db2_do_im  )   //  o
// );

// assign  db2_di_re = bf2_bf ? bf2_y1_re : bf1_do_re;
// assign  db2_di_im = bf2_bf ? bf2_y1_im : bf1_do_im;
// assign  bf2_sp_re = bf2_bf ? bf2_y0_re : db2_do_re;
// assign  bf2_sp_im = bf2_bf ? bf2_y0_im : db2_do_im;

// always @(posedge clock or posedge reset) begin
//     if (reset) begin
//         bf2_sp_en <= 1'b0;
//         bf2_count <= {LOG_N{1'b0}};
//     end else begin
//         bf2_sp_en <= bf2_start ? 1'b1 : bf2_end ? 1'b0 : bf2_sp_en;
//         bf2_count <= bf2_sp_en ? (bf2_count + 1'b1) : {LOG_N{1'b0}};
//     end
// end

// always @(posedge clock) begin
//     bf2_start <= (bf1_count == (2**(LOG_M-2)-1)) & bf1_sp_en;
// end
// assign  bf2_end = adjust? (bf2_count == (2**LOG_N32-1)) : (bf2_count == (2**LOG_N-1));

// always @(posedge clock) begin
//     bf2_do_re <= bf2_sp_re;
//     bf2_do_im <= bf2_sp_im;
// end

// always @(posedge clock or posedge reset) begin
//     if (reset) begin
//         bf2_do_en <= 1'b0;
//     end else begin
//         bf2_do_en <= bf2_sp_en;
//     end
// end

// //----------------------------------------------------------------------
// //  Multiplication
// //----------------------------------------------------------------------
// assign  tw_sel[1] = bf2_count[LOG_M-2];
// assign  tw_sel[0] = bf2_count[LOG_M-1];
// assign  tw_num = bf2_count << (LOG_N-LOG_M);
// assign  tw_addr = tw_num * tw_sel;

// Twiddle128 TW (
//     .clock  (clock  ),  //  i
//     .addr   (tw_addr),  //  i
//     .tw_re  (tw_re  ),  //  o
//     .tw_im  (tw_im  )   //  o
// );

// //  Multiplication is bypassed when twiddle address is 0.
// always @(posedge clock) begin
//     mu_en <= (tw_addr != {LOG_N{1'b0}});
// end
// //  Set unknown value x for verification
// assign  mu_a_re = mu_en ? bf2_do_re : {WIDTH{1'b0}};
// assign  mu_a_im = mu_en ? bf2_do_im : {WIDTH{1'b0}};

// // Decide whether to use the optimized multiplier ; if define,then use the optimized one
// `ifdef OPTI
//     multiply_opti #(
//         .WIDTH(WIDTH)
//     )inst1(
//     .a_re   (mu_a_re),  //  i
//     .a_im   (mu_a_im),  //  i
//     .tw_re   (tw_re  ),  //  i
//     .tw_im   (tw_im  ),  //  i
//     .m_re   (mu_m_re),  //  o
//     .m_im   (mu_m_im)   //  o
//     );
// `else
//     Multiply #(.WIDTH(WIDTH)) MU (
//     .a_re   (mu_a_re),  //  i
//     .a_im   (mu_a_im),  //  i
//     .b_re   (tw_re  ),  //  i
//     .b_im   (tw_im  ),  //  i
//     .m_re   (mu_m_re),  //  o
//     .m_im   (mu_m_im)   //  o
//     );
// `endif

// always @(posedge clock) begin
//     mu_do_re <= mu_en ? mu_m_re : bf2_do_re;
//     mu_do_im <= mu_en ? mu_m_im : bf2_do_im;
// end

// always @(posedge clock or posedge reset) begin
//     if (reset) begin
//         mu_do_en <= 1'b0;
//     end else begin
//         mu_do_en <= bf2_do_en;
//     end
// end

// //  No multiplication required at final stage
// assign  do_en = (LOG_M == 2) ? bf2_do_en : mu_do_en;
// assign  do_re = (LOG_M == 2) ? bf2_do_re : mu_do_re;
// assign  do_im = (LOG_M == 2) ? bf2_do_im : mu_do_im;

// endmodule

