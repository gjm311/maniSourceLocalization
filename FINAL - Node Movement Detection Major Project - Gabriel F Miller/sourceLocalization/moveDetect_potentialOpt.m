clear
addpath ./RIR-Generator-master
addpath ./functions
% mex -setup c++
% mex RIR-Generator-master/rir_generator.cpp;
addpath ./stft
addpath ./shortSpeech

%{
This program optimizes the potential function of the MRF based on the
empirical prior distributions associated with aligned/misaligned/uncertain
latent classes. Optimization done via iterative proportional fitting (IPF)
method.
%}

% ---- TRAINING DATA ----
% room setup
disp('Setting up the room');
% ---- Initialize Parameters for training ----

%---- load training data (check mat_trainParams for options)----
% load('mat_results/vari_t60_data')
load('mat_outputs/monoTestSource_biMicCircle_5L300U_4')
load('mat_outputs/resEsts_4')

%---- Set MRF params ----
max_iters = 100;
num_iters = 2;
num_ts = size(T60s,2);
transMats = zeros(num_ts,3,3);

wavs = dir('./shortSpeech/');
radii = 0:.25:1;
num_radii = size(radii,2);
mic_ref = [3 5.75 1; 5.75 3 1; 3 .25 1; .25 3 1];
alpha = .01;

for t = 1:num_ts    
    T60 = T60s(t);
    modelMean = modelMeans(t);
    modelSd = modelSds(t);
    RTF_train = reshape(RTF_trains(t,:,:,:), [nD, rtfLen, numArrays]);    
    scales = scales_t(t,:);
    gammaL = reshape(gammaLs(t,:,:), [nL, nL]);
    align_resid = align_resids(2,:);
    misalign_resid = misalign_resids(2,:);
    pEmp_al = 0;
    pEmp_mis = 0;

    for it = 1:num_iters
        for rad = 1:num_radii
            radius_mic = radii(rad);

            sourceTest = randSourcePos(1, roomSize, radiusU, ref);
            movingArray = randi(numArrays);
            [~, micsPosNew] = micNoRotate(roomSize, radius_mic, mic_ref, movingArray, micsPos, numArrays, numMics);
            rand_wav = randi(25);
            try
                file = wavs(rand_wav+2).name;
                [x_tst,fs_in] = audioread(file);
                [numer, denom] = rat(fs/fs_in);
                x_tst = resample(x_tst,numer,denom);
                x_tst = x_tst';  
            catch
                continue
            end    

            %---- estimate test positions before movement ----
            [~,~, pre_p_hat_t] = test(x_tst, gammaL, RTF_train, micsPos, rirLen, rtfLen, numArrays,...
                            numMics, sourceTrain, sourceTest, nL, nU, roomSize, T60, c, fs, kern_typ, scales);

              %---- estimate test positions after movement ----
            [~,~, p_hat_t] = test(x_tst, gammaL, RTF_train, micsPosNew, rirLen, rtfLen, numArrays,...
                            numMics, sourceTrain, sourceTest, nL, nU, roomSize, T60, c, fs, kern_typ, scales);

            %Get errors associated for each LONO sub-network
            sub_error = (mean((pre_p_hat_t-p_hat_t).^2));

            %Get probability of error according to aligned and
            %misaligned prior distributions
            [pEmp_al_curr,pEmp_mis_curr] = empProbCheck(sub_error,align_resid,misalign_resid);
            pEmp_al = pEmp_al + pEmp_al_curr;
            pEmp_mis = pEmp_mis + pEmp_mis_curr;      
        end
    end
    pEmp_aa = pEmp_al/(num_iters*num_radii);
    pEmp_am = 1-pEmp_aa;
    pEmp_mm = pEmp_mis/(num_iters*num_radii);
    pEmp_ma = 1-pEmp_mm;

    emp_rows = [1 1];
    emp_cols = [pEmp_aa+pEmp_mm; pEmp_ma+pEmp_am];
    transMat = ones(2);
    pairity = 1;
    rows = 0;
    cols = 0;
    while and((isequal(emp_rows,rows)+isequal(emp_cols,cols))~=2, pairity<max_iters)
        if pairity == 1
            rows = emp_rows;
            cols = emp_cols;
        end
        if mod(pairity,2) == 1
            transMat = [transpose(cols); transpose(cols)].*(transMat./sum(transMat,1));
            rows = transpose(sum(transMat,2));
        else
            transMat = [transpose(rows) transpose(rows)].*(transMat./sum(transMat,2));
            cols = transpose(sum(transMat,1));
        end
        pairity = pairity+1;
    end

    transMat_t = [transMat(1,1) 0 transMat(1,2);0 transMat(2,1) transMat(2,2);ones(1,3).*(1/3)];
    transMats(t,:,:) = transMat_t; 
    save('./mat_outputs/optTransMatData2','transMats'); 
end