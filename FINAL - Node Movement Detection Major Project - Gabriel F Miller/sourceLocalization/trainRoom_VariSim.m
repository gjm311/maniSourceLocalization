%{
This program estimates the mean and standard devaition of the source
localization algorithm.
%}
 
% % load desired scenario (scroll past commented section) or uncomment and simulate new environment RTFs 
clear
addpath ./RIR-Generator-master
addpath ./functions
addpath ../../../
mex -setup c++
mex RIR-Generator-master/rir_generator.cpp;
addpath ./stft
addpath ./shortSpeech

% ---- TRAINING DATA ----
% room setup
disp('Setting up the room');
num_samples = 1000;
diffs = zeros(1,num_samples);
c = 340;
fs = 8000;
roomSize = [6,6,3];    
ref = [roomSize(1:2)./2 1];
% sourceTrainL = sourceGrid(height, width, numRow, numCol, ref);
sourceTrainL = [4,4,1; 2,2,1; 4,2,1; 2,4,1; 3 3 1];
numArrays = 4;
numMics = 2;
nU = 300;
radiusU = 2;
nL = size(sourceTrainL,1);
micsPos = [3.025,5.75 1;2.975,5.75,1; 5.75,2.975,1;5.75,3.025,1; 3.025,.25,1;2.975,.25,1; .25,2.975,1;.25,3.025,1];
sourceTrainU = randSourcePos(nU, roomSize, radiusU, ref);
sourceTrain = [sourceTrainL; sourceTrainU];
nD = size(sourceTrain,1);
totalMics = numMics*numArrays;
rirLen = 1000;
rtfLen = 500;
T60s = .15:.05:.85;
num_ts = size(T60s,2);
%grad descent params
x = randn(1,10*fs);
kern_typ = 'gaussian';
tol = 10e-3;
alpha = .01;
max_iters = 100;
init_scales = 1*ones(1,numArrays);
var_init = rand(1,nL)*.1-.05;

RTF_trains = zeros(num_ts, nD, rtfLen, numArrays);
scales_t = zeros(num_ts, numArrays);
gammaLs = zeros(num_ts, nL, nL);

modelMeans = zeros(1,num_ts);
modelSds = zeros(1,num_ts);

for t = 1:num_ts
    T60 = T60s(t);
    
    % ---- generate RIRs and estimate RTFs ----
    RTF_train = rtfEst(x, micsPos, rtfLen, numArrays, numMics, sourceTrain, roomSize, T60, rirLen, c, fs);
    RTF_trains(t,:,:,:) = RTF_train;

    %Initialize hyper-parameter estimates (gaussian kernel scalar
    %value and noise variance estimate)
    [~,sigmaL] = trCovEst(nL, nD, numArrays, RTF_train, kern_typ, init_scales);

    %---- perform grad. descent to get optimal params ----
    [costs, ~, ~, varis_set, scales_set] = grad_descent(sourceTrainL, numArrays, RTF_train, sigmaL, init_scales, var_init, max_iters, tol, alpha, kern_typ);
    [~,I] = min(sum(costs));

    scales_t(t,:) = scales_set(I,:);
    scales = scales_t(t,:);
    vari = varis_set(I,:);
    [~,sigmaL] = trCovEst(nL, nD, numArrays, RTF_train, kern_typ, scales_t(t,:));
    gammaL = inv(sigmaL + diag(ones(1,nL).*vari));
    gammaLs(t,:,:) = gammaL;
    
    for n = 1:num_samples
        try
            wavs = dir('./shortSpeech/');
            rand_wav = randi(25);
            file = wavs(rand_wav+2).name;
            [x_tst,fs_in] = audioread(file);
            [numer, denom] = rat(fs/fs_in);
            x_tst = resample(x_tst,numer,denom);
            x_tst = x_tst'; 
        catch
            continue
        end
        
        sourceTest = randSourcePos(1, roomSize, radiusU, ref);
        [~,~, p_hat_t] = test(x_tst, gammaL, RTF_train, micsPos, rirLen, rtfLen, numArrays,...
                    numMics, sourceTrain, sourceTest, nL, nU, roomSize, T60, c, fs, kern_typ, scales);
        diffs(n) = mean(mean((sourceTest-p_hat_t).^2));
       
    end

    modelMeans(t) = mean(diffs);
    modelSds(t) = std(diffs);
end

save('mat_outputs/monoTestSource_biMicCircle_5L300U_4.mat')