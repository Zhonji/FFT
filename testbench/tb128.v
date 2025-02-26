//----------------------------------------------------------------------
//	TB: FftTop Testbench
//----------------------------------------------------------------------
`timescale	1ns/1ns
module tb128 #(
	parameter	N = 128
);

localparam		NN = log2(N);	//	Count Bit Width of FFT Point

//	log2 constant function
function integer log2;
	input integer x;
	integer value;
	begin
		value = x-1;
		for (log2=0; value>0; log2=log2+1)
			value = value>>1;
	end
endfunction

//	Internal Regs and Nets
reg			clock;
reg			reset;
reg			di_en;
reg	signed [15:0]	di_re;
reg	signed [15:0]	di_im;
wire		do_en;
wire signed [15:0]	do_re;
wire signed [15:0]	do_im;
reg do_form;
reg [2:0] LSN;
reg	signed [15:0]	imem[0:2*N-1];
reg	signed [15:0]	omem[0:2*N-1];
reg [1:0] 	sel;

reg signed [15:0] inst_re [0:N-1];
reg signed [15:0] inst_im [0:N-1];
wire Ready, Success;
reg signed [15:0]  matlabmem_re[0:N-1];
reg signed [15:0]  matlabmem_im[0:N-1];
reg signed [15:0]  naromen_re[0:N-1];
reg signed [15:0]  naromen_im[0:N-1];

reg [7:0] error;

// Define the inputdata and output data format
initial begin
	do_form = 0;
	LSN = 5;
end

// Initialize the error
initial begin
	error = 'd0;
end

// Include the matlab data
initial begin
	$readmemb("C:/FFT/Common_IPs/FFT_NEW/testbench/matlab/data8/out_real.txt",matlabmem_re);
end
initial begin
	$readmemb("C:/FFT/Common_IPs/FFT_NEW/testbench/matlab/data8/out_imag.txt",matlabmem_im);
end
//----------------------------------------------------------------------
//	Clock and Reset
//----------------------------------------------------------------------
always begin
	clock = 0; #10;
	clock = 1; #10;
end

initial begin
	reset = 0; #20;
	reset = 1; #100;
	reset = 0;
end

initial begin
	sel = 2'b10;
end
//----------------------------------------------------------------------
//	Functional Blocks
//----------------------------------------------------------------------

//	Input Control Initialize
initial begin
	wait (reset == 1);
	di_en = 0;
end

//	Output Data Capture
initial begin : OCAP
	integer		n;
	forever begin
		n = 0;
		while (do_en !== 1) @(negedge clock);
		while ((do_en == 1) && (n < N)) begin
			omem[2*n  ] = do_re;
			omem[2*n+1] = do_im;
			n = n + 1;
			@(negedge clock);
		end
	end
end

//----------------------------------------------------------------------
//	Tasks
//----------------------------------------------------------------------
task LoadInputData;
	input[80*8:1]	filename;
begin
	$readmemb(filename, imem);
end
endtask

task GenerateInputWave;
	integer	n;
begin
	di_en <= 1;
	for (n = 0; n < N; n = n + 1) begin
		di_re <= imem[2*n];
		di_im <= imem[2*n+1];
		@(posedge clock);
	end
	di_en <= 0;
	di_re <= 'bx;
	di_im <= 'bx;
end
endtask

task SaveOutputData;
	input[80*8:1]	filename1;
	input[80*8:1]   filename2;
	integer			fp1,fp2, n, m, i;
begin
	fp1 = $fopen(filename1);
	fp2 = $fopen(filename2);
	m = 0;
	for (n = 0; n < N; n = n + 1) begin
		for (i = 0; i < NN; i = i + 1) m[NN-1-i] = n[i];
		$fdisplay(fp1, "%b", omem[2*m]);
		$fdisplay(fp2, "%b", omem[2*m+1]);
		// $fdisplay(fp, "%h  %h  // %d", omem[2*m], omem[2*m+1], n[NN-1:0]);
		naromen_re[n] =  omem[2*m];
		naromen_im[n] = omem[2*m+1];
	end
	$fclose(fp1);
	$fclose(fp2);
end
endtask

task compare;
integer j;
begin
	for(j = 0; j<128 ; j = j + 1)begin
		inst_re[j] = matlabmem_re[j] - naromen_re[j] + 16'b0000_1000_0000_0000; 
		inst_im[j] = matlabmem_im[j] - naromen_im[j] + 16'b0000_1000_0000_0000; 
	end
end
endtask

integer l = 0;
task jiaoyan;
begin
	for(l = 0; l<128 ; l = l + 1)begin
		if(inst_re[l]>16'b0000_1000_0000_0010||inst_re[l]<16'b0000_0111_1111_1110) begin
			error = error + 1;
		end
		if(inst_im[l]>16'b0000_1000_0000_0010||inst_im[l]<16'b0000_0111_1111_1110) begin
			error = error + 1;
		end
	end
end
endtask

//----------------------------------------------------------------------
//	Module Instances
//----------------------------------------------------------------------
Alter_FFT FFT (
	.clock	(clock	),	//	i
	.reset	(reset	),	//	i
	.di_en	(di_en	),	//	i
	.di_re	(di_re	),	//	i
	.di_im	(di_im	),	//	i
	.sel	(sel	),	//	i
	.LSN	(LSN	),	//  i
	.do_form(do_form),	//  i
	.do_en	(do_en	),	//	o
	.do_re	(do_re	),	//	o
	.do_im	(do_im	),	//	o
	.Ready	(Ready  ),	//  o
	.Success(Success)	//  o
);

//----------------------------------------------------------------------
//	Test Stimuli
//----------------------------------------------------------------------
initial begin : STIM
	wait (reset == 1);
	wait (reset == 0);
	repeat(10) @(posedge clock);

	fork
		begin
			LoadInputData("C:/FFT/Common_IPs/FFT_NEW/testbench/matlab/data8/data_before_fft_b.txt");
			GenerateInputWave;
		end
		begin
			wait (do_en == 1);
			repeat(N) @(posedge clock);
			SaveOutputData("C:/FFT/Common_IPs/FFT_NEW/testbench/matlab/data8/M_out_real.txt","C:/FFT/Common_IPs/FFT_NEW/testbench/matlab/data8/M_out_imag.txt");
			@(negedge clock);
			@(posedge clock);
			compare;
			jiaoyan;
		end
	join

	repeat(10) @(posedge clock);
	$finish;
end
endmodule




// //----------------------------------------------------------------------
// //	TB: FftTop Testbench
// //----------------------------------------------------------------------
// `timescale	1ns/1ns
// module tb128 #(
// 	parameter	N = 128
// );

// localparam		NN = log2(N);	//	Count Bit Width of FFT Point

// //	log2 constant function
// function integer log2;
// 	input integer x;
// 	integer value;
// 	begin
// 		value = x-1;
// 		for (log2=0; value>0; log2=log2+1)
// 			value = value>>1;
// 	end
// endfunction

// //	Internal Regs and Nets
// reg			clock;
// reg			reset;
// reg			di_en;
// reg	[15:0]	di_re;
// reg	[15:0]	di_im;
// wire		do_en;
// wire[15:0]	do_re;
// wire[15:0]	do_im;

// reg	[15:0]	imem[0:2*N-1];
// reg	[15:0]	omem[0:2*N-1];
// reg [1:0] 	sel;
// //----------------------------------------------------------------------
// //	Clock and Reset
// //----------------------------------------------------------------------
// always begin
// 	clock = 0; #10;
// 	clock = 1; #10;
// end

// initial begin
// 	reset = 0; #20;
// 	reset = 1; #100;
// 	reset = 0;
// end

// initial begin
// 	sel = 2'b10;
// end
// //----------------------------------------------------------------------
// //	Functional Blocks
// //----------------------------------------------------------------------

// //	Input Control Initialize
// initial begin
// 	wait (reset == 1);
// 	di_en = 0;
// end

// //	Output Data Capture
// initial begin : OCAP
// 	integer		n;
// 	forever begin
// 		n = 0;
// 		while (do_en !== 1) @(negedge clock);
// 		while ((do_en == 1) && (n < N)) begin
// 			omem[2*n  ] = do_re;
// 			omem[2*n+1] = do_im;
// 			n = n + 1;
// 			@(negedge clock);
// 		end
// 	end
// end

// //----------------------------------------------------------------------
// //	Tasks
// //----------------------------------------------------------------------
// task LoadInputData;
// 	input[80*8:1]	filename;
// begin
// 	$readmemb(filename, imem);
// end
// endtask

// task GenerateInputWave;
// 	integer	n;
// begin
// 	di_en <= 1;
// 	for (n = 0; n < N; n = n + 1) begin
// 		di_re <= imem[2*n];
// 		di_im <= imem[2*n+1];
// 		@(posedge clock);
// 	end
// 	di_en <= 0;
// 	di_re <= 'bx;
// 	di_im <= 'bx;
// end
// endtask

// task SaveOutputData;
// 	input[80*8:1]	filename1;
// 	input[80*8:1]   filename2;
// 	integer			fp1,fp2, n, m, i;
// begin
// 	fp1 = $fopen(filename1);
// 	fp2 = $fopen(filename2);
// 	m = 0;
// 	for (n = 0; n < N; n = n + 1) begin
// 		for (i = 0; i < NN; i = i + 1) m[NN-1-i] = n[i];
// 		$fdisplay(fp1, "%b", omem[2*m]);
// 		$fdisplay(fp2, "%b", omem[2*m+1]);
// 		// $fdisplay(fp, "%h  %h  // %d", omem[2*m], omem[2*m+1], n[NN-1:0]);
// 	end
// 	$fclose(fp1);
// 	$fclose(fp2);
// end
// endtask

// //----------------------------------------------------------------------
// //	Module Instances
// //----------------------------------------------------------------------
// Alter_FFT FFT (
// 	.clock	(clock	),	//	i
// 	.reset	(reset	),	//	i
// 	.di_en	(di_en	),	//	i
// 	.di_re	(di_re	),	//	i
// 	.di_im	(di_im	),	//	i
// 	.sel	(sel	),
// 	.do_en	(do_en	),	//	o
// 	.do_re	(do_re	),	//	o
// 	.do_im	(do_im	),	//	o
// 	.Ready	(Ready  ),
// 	.Success(Success)
// );

// //----------------------------------------------------------------------
// //	Include Stimuli
// //----------------------------------------------------------------------
// // `include "stim.v"
// //----------------------------------------------------------------------
// //	Test Stimuli
// //----------------------------------------------------------------------
// initial begin : STIM
// 	wait (reset == 1);
// 	wait (reset == 0);
// 	repeat(10) @(posedge clock);

// 	fork
// 		begin
// 			LoadInputData("C:/FFT/Common_IPs/FFT_NEW/testbench/matlab/data4/data_before_fft_b.txt");
// 			// LoadInputData("input4.txt");
// 			GenerateInputWave;
// 			//@(posedge clock);
// 			// LoadInputData("input5.txt");
// 			// GenerateInputWave;
// 		end
// 		begin
// 			wait (do_en == 1);
// 			repeat(N) @(posedge clock);
// 			SaveOutputData("C:/FFT/Common_IPs/FFT_NEW/testbench/matlab/data4/M_out_real.txt","C:/FFT/Common_IPs/FFT_NEW/testbench/matlab/data4/M_out_imag.txt");
// 			@(negedge clock);
// 			// wait (do_en == 1);
// 			// repeat(N) @(posedge clock);
// 			// SaveOutputData("output5.txt");
// 		end
// 	join

// 	repeat(10) @(posedge clock);
// 	$finish;
// end
// initial begin : TIMEOUT
// 	repeat(1000) #20;	//  1000 Clock Cycle Time
// 	$display("[FAILED] Simulation timed out.");
// 	$finish;
// end

// endmodule
