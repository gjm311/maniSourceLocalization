function [cov,covL] = wTrCovEst(weights, nL, nD, numArrays, rtfs, kernTyp, scales)
    cov = zeros(nD,nD);
    for r = 1:nD
        for l = 1:nD
            kern = 0;
            for i = 1:nD        
                for q = 1:numArrays
                    for w = 1:numArrays
                        kernQ = kernel(rtfs(r,:,q), rtfs(i,:,q), kernTyp, scales(q));
                        kernW = kernel(rtfs(l,:,w), rtfs(i,:,w), kernTyp, scales(w));
                        kern = kern + (weights(q).*kernQ)*(kernW.*weights(w));            
                    end
                end
            end
            cov(r,l) = (1/numArrays^2).*kern;
        end
    end
    covL = cov(1:nL,1:nL);
end