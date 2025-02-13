%{
This program simulates a room that can be specified in the initialization
parameters with a set of noise sources and microphone nodes. RTFs are
generated (RIRs produced via Emmanuel Habet's RIR generator)and used to
localize sound sources based off a set of learned manifolds (see 
Semi-Supervised Source Localization on Multiple Manifolds With Distributed
Microphones for more details). Gradient descent method used to initialize
hyper-params.
%}
 
% % load desired scenario (scroll past commented section) or uncomment and simulate new environment RTFs 
clear
addpath ./RIR-Generator-master
addpath ./functions
addpath ../../../
load('rtfDatabase.mat')
mex -setup c++
mex RIR-Generator-master/rir_generator.cpp;
addpath ./stft
addpath ./shortSpeech

% ---- TRAINING DATA ----
% room setup
disp('Setting up the room');
% ---- Initialize Parameters for training ----
c = 340;
fs = 8000;
roomSize = [6,6,3];    
height = 1.5;
width = 1.5;
numRow = 7;
numCol = 7;
ref = [roomSize(1:2)./2 1];
% sourceTrainL = sourceGrid(height, width, numRow, numCol, ref);
sourceTrainL = [4,4,1; 2,2,1; 4,2,1; 2,4,1; 3 3 1];
numArrays = 4;
numMics = 2;
nU = 300;
radiusU = 2;
nL = size(sourceTrainL,1);
micsPos = [3.025,5.75 1;2.975,5.75,1; 5.75,2.975,1;5.75,3.025,1; 3.025,.25,1;2.975,.25,1; .25,2.975,1;.25,3.025,1];
% micsPos = [3.025,5,1;2.975,5,1; 5,2.975,1;5,3.025,1; 3.025,1,1;2.975,1,1; 1,2.975,1;1,3.025,1];
sourceTrainU = randSourcePos(nU, roomSize, radiusU, ref);
sourceTrain = [sourceTrainL; sourceTrainU];
nD = size(sourceTrain,1);

% ---- generate RIRs and estimate RTFs ----
totalMics = numMics*numArrays;
rirLen = 1000;
rtfLen = 500;
T60s = [0.15 .2 .25 .3 .35 .4];
num_ts = size(T60s,2);
x = randn(1,10*fs);
% [x_tst,fs_in] = audioread('f0001_us_f0001_00209.wav');
% x_tst = x_tst';
% disp('Generating the train set');

% ---- Simulate RTFs between microphones within each node ----
kern_typ = 'gaussian';
tol = 10e-3;
alpha = .01;
max_iters = 100;
init_scales = 1*ones(1,numMics);
var_init = rand(1,nL)*.1-.05;
RTF_train = zeros(num_ts, numArrays, nD, rtfLen, numMics);
scales = zeros(num_ts, numArrays,numMics);
gammaLs = zeros(num_ts, numArrays, nL, nL);

for t6 = 1:num_ts
    for t = 1:numArrays
        curr_mics = micsPos((t-1)*numMics+1:t*numMics,:); 
        RTF_train(t6,t,:,:,:) = rtfEst(x, curr_mics, rtfLen, 1, numMics, sourceTrain, roomSize, T60, rirLen, c, fs);

        %Initialize hyper-parameter estimates (gaussian kernel scalar
        %value and noise variance estimate)
        RTF_curr = reshape(RTF_train(t6,t,:,:,:), [nD, rtfLen, numMics]);
        [~,sigmaL] = trCovEst(nL, nD, numMics, RTF_curr, kern_typ, init_scales);

        %---- perform grad. descent to get optimal params ----
        gammaL = inv(sigmaL + diag(ones(1,nL).*var_init));
        p_sqL = gammaL*sourceTrainL;

        [costs, ~, ~, varis_set, scales_set] = grad_descent(sourceTrainL, numMics, RTF_curr, sigmaL, init_scales, var_init, max_iters, tol, alpha, kern_typ);
        [~,I] = min(sum(costs));

        scales(t6,t,:) = scales_set(I,:);
        v_curr = varis_set(I,:);
        [~,sigmaL] = trCovEst(nL, nD, numMics, RTF_curr, kern_typ, scales(t6,t,:));
        gammaLs(t6,t,:,:) = inv(sigmaL + diag(ones(1,nL).*v_curr));
    end
end

save('mat_outputs/biMicCircle_5L300U_monoNode', 'RTF_train', 'scales', 'gammaLs')

