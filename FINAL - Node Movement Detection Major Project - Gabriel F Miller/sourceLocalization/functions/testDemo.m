function [RTF_test, k_t_new, p_hat_t] = testDemo(gammaL, RTF_train, numArrays, sourceTrain, RTF_test, nL, nU, kern_typ, scales)
    %---- update estimate based off test ----
    %estimate test RTF
%     RTF_test =  rtfEst(x, micsPos, rtfLen, numArrays, numMics, sourceTest, roomSize, T60, rirLen, c, fs);

    %estimate kernel array between labelled data and test
    k_t_new = zeros(1,nL);
    for i = 1:nL
        array_kern = 0;
        for j = 1:numArrays
            k_t_new(i) = array_kern + kernel(RTF_train(i,:,j), RTF_test(:,:,j), kern_typ, scales(j));
        end
    end

    %update covariance (same as before but including test as additional unlabelled
    %pt) and update gamma to calculate new gamma.
    nD = nL+nU;
    sourceTrainL = sourceTrain(1:nL,:);
%     RTF_upd = [RTF_train; RTF_test];
%     sigmaL = trC  ovEst(nL, nD, numArrays, RTF_train, kern_typ ,scales);
%     sigmaL_upd = sigmaL + (1/numArrays^2)*k_Lt'*k_Lt;
%     gammaL_upd = inv(sigmaL_upd + diag(ones(1,nL)*vari));

%Uncomment for update method via Bracha's paper (vs. update done in
%bayesUpd.m from Vaerenbergh's paper.
%     gammaL_new = gammaL - ((gammaL*(k_Lt*k_Lt)'*gammaL)/(numArrays^2+k_Lt*gammaL*k_Lt'));
    gammaL_new = gammaL;
    p_sqL_new = gammaL_new*sourceTrainL;

    %estimate test covariance
    sigmaLt_new = sigma_Lt + (1/numArrays)*k_t_new;
    p_hat_t = sigmaLt_new*p_sqL_new;

end