function [upd_sub_p_hat_ts, prob_failure, posteriors] = moveDetector(x, gammaL, numMics, numArrays, micsPos, t, p_fails, sub_p_hat_ts, scales, RTF_train, rirLen, rtfLen,sourceTrain, sourceTest, nL, nU, roomSize, T60, c, fs, kern_typ)

    %---- Initialize CRF params ----
    posteriors = zeros(numArrays,2);
    likes = zeros(numArrays,2);
    latents = [ones(numArrays,1), zeros(numArrays,1), zeros(numArrays,1)]+1;
    transMat = [.9 .05 0.05; .05 .9 0.05; 1/3 1/3 1/3];
    init_var = .2;
    lambda = .2;
    eMax = .2;
    thresh = .5;

% ----Calculate new estimate based off movement for all subnets and resid. error from stationary time (turns off once estimates settle) ----
    upd_sub_p_hat_ts = zeros(numArrays, 3);
    for k1 = 1:numArrays
        [subnet, subscales, trRTF] = subNet(k1, numArrays, numMics, scales, micsPos, RTF_train);
        [~,~,upd_sub_p_hat_ts(k1,:)] = test(x, gammaL, trRTF, subnet, rirLen, rtfLen, numArrays-1, numMics, sourceTrain, sourceTest, nL, nU, roomSize, T60, c, fs, kern_typ, subscales);   
    end
    resids = mean(sub_p_hat_ts - upd_sub_p_hat_ts,2);

    %---- Set likelihoods (to be maximized during msg passing calc.) ----
    for k = 1:numArrays
        for l = 1:2
            theta2 = 2*normpdf(resids(k), 0, init_var);
            theta1 = (lambda*exp(-lambda*resids(k)))/(1-exp(-lambda*eMax));
%             theta3 = unifrnd(0,eMax);
        end
        likes(k,:) = [theta1 theta2];
    end

    % ---- For each incoming sample, use CRF to determine prob of latents and detection failure ----
    %Assuming fully connected network, we begin by allowing each latent
    %variable to receive messages from its connected variables to
    %initialize marginal posteriors.
    mu_alphas = zeros(numArrays,2);
    for k1 = 1:numArrays
        for l = 1:2
            for k2 = 1:numArrays
                if k2 ~= k1
                    mu_alphas(k1,l) = transMat(latents(k2,l), latents(k1,l))*(likes(k2,l)); 
                end
            end
            posteriors(k1,l) = likes(k1,l)*mu_alphas(k1,l); 
        end
        posteriors(k1,:) = posteriors(k1,:)./(sum(posteriors(k1,:)));
    end

    %Variables send further messages using arbitrary passing strategy.
    mu_alpha_prev = zeros(1,2);
    tol = 10e-3;
    err = inf;
    while err > tol
        if err == inf
            prev_posts = zeros(size(posteriors));
        end
        for k = 1:numArrays
            for l = 1:2
                if k == 1
                    mu_alpha = transMat(latents(1,l), latents(2,l))*(likes(k,l));
                    mu_alpha_prev(l) = mu_alpha;
                end
                if k == numArrays
                    mu_alpha = transMat(latents(k-1,l), latents(k,l))*mu_alpha_prev(l);
                    mu_alpha_prev(l) = mu_alpha;
                end 
                if and(k>1,k<numArrays)
                    mu_alpha = transMat(latents(k-1,l), latents(k,l))*mu_alpha_prev(l);
                    mu_alpha_prev(l) = mu_alpha;
                end
                posteriors(k,l) = likes(k,l)*mu_alpha;
            end
            posteriors(k,:) = posteriors(k,:)./(sum(posteriors(k,:)));
        end
        err = norm((posteriors-prev_posts), 2);
        prev_posts = posteriors;
    end

    %Calculate probability of misalignment for all subnets (should see higher probabilities of misalignment for subnets with moving array).    
    latents = round(posteriors);
    MIS = sum(latents(:,2))/numArrays;
    if MIS > thresh
        p_fail = 1;
    else
        p_fail = 0;
    end
    prob_failure = (1/t)*(p_fails*(t-1)+p_fail);
end
