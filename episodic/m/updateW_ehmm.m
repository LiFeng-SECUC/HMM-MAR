function ehmm = updateW_ehmm(ehmm,Gamma,residuals,XX,Tfactor,lambda)
% Updates all the states excepting baseline

if nargin < 5, Tfactor = 1; end
if nargin < 6, lambda = []; end

setstateoptions;
K = size(Gamma,2); ndim = size(ehmm.train.S,1); np = size(XX,2); 

Xhat = computeStateResponses(XX,ehmm,Gamma,K+1);
residuals = residuals - Xhat; % discount baseline

Gamma = [Gamma prod(1-Gamma,2) ];
Gamma = rdiv(Gamma,sum(Gamma,2));  

XXstar = zeros(size(XX,1),np * K);
%XXstar1 = zeros(size(XX,1),np * K);
for k = 1:K
   XXstar(:,(1:np) + (k-1)*np) = bsxfun(@times, XX, Gamma(:,k)); 
   %XXstar1(:,(1:np) + (k-1)*np) = bsxfun(@times, XX, sqrt(Gamma(:,k))); 
end
gram = XXstar' * XXstar;  
XY = XXstar' * residuals;

for n = 1:ndim

    if ~regressed(n), continue; end
    
    Sind_all = repmat(Sind(:,n),K,1) == 1;
    Sind_all2 = [Sind_all; false(np,1)];
    if ~isempty(lambda)
        Regterm = lambda * eye(np*K);
        c = 1;
    else
        Regterm = zeros(np*K,1); 
        for k = 1:K
            ndim_n = sum(S(:,n)>0);
            %if ndim_n==0 && train.zeromean==1, continue; end
            regterm = []; I = [];
            if ~train.zeromean, regterm = ehmm.state(k).prior.Mean.iS(n); I = true; end
            if ehmm.train.order > 0
                alphaterm = ...
                    repmat( (ehmm.state(k).alpha.Gam_shape ./  ...
                    ehmm.state(k).alpha.Gam_rate), ndim_n, 1);
                if ndim==1
                    regterm = [regterm; alphaterm(:) ];
                else
                    sigmaterm = repmat(ehmm.state(k).sigma.Gam_shape(S(:,n),n) ./ ...
                        ehmm.state(k).sigma.Gam_rate(S(:,n),n), length(orders), 1);
                    regterm = [regterm; sigmaterm .* alphaterm(:) ];
                end
                I = [I; Sind(:,n)];
            end
            I = find(I);
            ind = (1:np) + (k-1)*np;
            Regterm((1:np) + (k-1)*np) = regterm;
        end
        c = ehmm.Omega.Gam_shape / ehmm.Omega.Gam_rate(n);
        Regterm = diag(Regterm);
    end

    iS_W = Regterm(Sind_all,Sind_all) + Tfactor * c * gram(Sind_all,Sind_all);
    iS_W = (iS_W + iS_W') / 2; 
    S_W = inv(iS_W);
    Mu_W = Tfactor * c * S_W * XY(Sind_all,n);
    
    for k = 1:K
        ind = (k-1)*np + (1:np);
        ehmm.state(k).W.Mu_W(:,n) = Mu_W(ind);
        ehmm.state(k).W.iS_W(n,:,:) = iS_W(ind,ind);
        ehmm.state(k).W.S_W(n,:,:) = S_W(ind,ind);
    end
    
    ehmm.state_shared(n).iS_W(Sind_all2,Sind_all2) = iS_W;
    ehmm.state_shared(n).S_W(Sind_all2,Sind_all2) = S_W;
    ehmm.state_shared(n).Mu_W(Sind_all2) = Mu_W;

end

end

