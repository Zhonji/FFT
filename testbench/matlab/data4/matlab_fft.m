
%% 采样参数
Fs=1e3;
T=1/Fs;        
length = 128;
t=(0:length-1)*T;
%% 生成测试信号
f1 = 100;
%f2 = 300;
s1 = sawtooth(2*pi*f1*t);    
%s2 = 0 + cos(2*pi*f2*t);
%s11 = 0 + cos(2*pi*f1*t)*1i;    
%s21 = 0 + cos(2*pi*f2*t)*1i;
%signalN = s1 + s2 ;
%signalN1 = s11 + s21;
signalN = s1;
data_before_fft = fix(8*1024*signalN);  %系数放大2^13倍
%data_before_fft1 = fix(8*1024*signalN1);  %系数放大2^13倍
%data_before_fft = signalN;
%% 生成输入数据txt，让fpga调用
%fp = fopen('C:\FFT\Common_IPs\FFT_NEW\testbench\matlab\data_before_fft.txt','w');
fp = fopen('C:\FFT\Common_IPs\FFT_NEW\testbench\matlab\data4\data_before_fft.txt','w');

for K = 1:length
   if(data_before_fft(K)>=0)
       temp= dec2bin(data_before_fft(K),16);
   else
       temp= dec2bin(data_before_fft(K)+2^16,16);
   end
%fprintf(fp,'0000000000000000');
    for j=1:16
        
        fprintf(fp,'%s',temp(j));
    end
    fprintf(fp,'0000000000000000'); %虚部补0
    
    fprintf(fp,'\r\n');
end
fclose(fp);
%% 把测试信号fft
%data_after_fft1 = DIF_FFT_2(data_before_fft, 128);
data_after_fft1 = fft(data_before_fft,128);
data_after_fft = data_after_fft1.';
data_real = fix(real(data_after_fft));
data_imag = fix(imag(data_after_fft));
%% 生成测试结果txt
fp_real = fopen('out_real.txt','w');
for K = 1:length
   if(data_real(K)>=0)
       temp_real= dec2bin((data_real(K)/128),16);
   else
       temp_real= dec2bin((data_real(K)/128)+2^16,16);
   end
    for j=1:16
        fprintf(fp_real,'%s',temp_real(j));
    end
    fprintf(fp_real,'\r\n');
end
fp_imag = fopen('out_imag.txt','w');
for K = 1:length
   if(data_imag(K)>=0)
       temp_imag= dec2bin(data_imag(K)/128,16);
   else
       temp_imag= dec2bin(data_imag(K)/128+2^16, 16);
   end
    for j=1:16
        fprintf(fp_imag,'%s',temp_imag(j));
    end
    fprintf(fp_imag,'\r\n');
end
%% 画理想fft频谱图
n = 0:(length-1);
%N = bitrevorder(n);
N = n;
for K = 1:length
    data_after_fft2(K)=data_after_fft1(N(K)+1);
end
P2 = abs(data_after_fft2/length);
P1 = P2(1:length/2+1);
P1(2:end-1) = 2*P1(2:end-1);
f = Fs*(0:(length/2))/length;
subplot(2,1,1)
plot(f,P1)
xlabel('f/(hz)');
ylabel('Am/(mV)');
title('matlab fft 频谱图');
%% 画流水线fft频谱图
%data_real_1 = load('M_out_real.txt');
%data_imag_1 = load('M_out_imag.txt');


fid = fopen('M_out_real.txt', 'r'); % open the file in read mode
data_real_1 = fscanf(fid, '%s', [1 inf]); % read the binary data as a string
fclose(fid); % close the file
data_real_1 = reshape(data_real_1, 16, [])'; % reshape the data into a 128x16 matrix
data_real_1 = bin2dec(data_real_1); % convert binary to decimal
for i = 1:numel(data_real_1)
    if bitget(data_real_1(i), 16) % check if the most significant bit is 1 (negative number)
        data_real_1(i) = -(65536 - data_real_1(i)); % convert to two's complement
    end
end

fid = fopen('M_out_imag.txt', 'r'); % open the file in read mode
data_imag_1 = fscanf(fid, '%s', [1 inf]); % read the binary data as a string
fclose(fid); % close the file
data_imag_1 = reshape(data_imag_1, 16, [])'; % reshape the data into a 128x16 matrix
data_imag_1 = bin2dec(data_imag_1); % convert binary to decimal
for i = 1:numel(data_imag_1)
    if bitget(data_imag_1(i), 16) % check if the most significant bit is 1 (negative number)
        data_imag_1(i) = -(65536 - data_imag_1(i)); % convert to two's complement
    end
end






data_after_fft3 = complex(data_real_1, data_imag_1);
for i = 1:length
    data_after_fft4(i)=data_after_fft3(N(i)+1);
end
P4 = abs(data_after_fft4/length);
P3 = P4(1:length/2+1);
P3(2:end-1) = 2*P3(2:end-1);
f1 = Fs*(0:(length/2))/length;
subplot(2,1,2) 
plot(f1,P3)
xlabel('f/(hz)');
ylabel('Am/(mV)');
title('流水线 fft 频谱图');
%% 基2 DIF FFT函数
function [Xk]=DIF_FFT_2(xn,N);
M=log2(N);
for m=0:M-1
    Num_of_Group=2^m;
    Interval_of_Group=N/2^m;
    Interval_of_Unit=N/2^(m+1);
    Cycle_Count=N/2^(m+1)-1;
    Wn=exp(-j*2*pi/Interval_of_Group);
    for g=1:Num_of_Group 
        Interval_1=(g-1)*Interval_of_Group;
        Interval_2=(g-1)*Interval_of_Group+Interval_of_Unit;
        for r=0:Cycle_Count;
            k=r+1;
            xn(k+Interval_1)=xn(k+Interval_1)+xn(k+Interval_2);
            xn(k+Interval_2)=[xn(k+Interval_1)-xn(k+Interval_2)-xn(k+Interval_2)]*Wn^r;
        end
    end
end
Xk = xn;
end