function [ehmm,Gamma,crithist] = ehmmtrain(data,T,ehmm,Gamma,residuals)
%
% Train ehmm using using Variational Framework
%
% INPUTS:
%
% data          observations - a struct with X (time series) and C (classes)
% T             Number of time points for each time series
% ehmm          ehmm structure with options specified in ehmm.train
% Gamma         Initial state courses
% residuals     in case we train on residuals, the value of those.
%
% OUTPUTS
% ehmm           estimated ehmm 
% Gamma         estimated p(state | data)
% crithist     historic of Gamma amount of change across iterations
%
% Author: Diego Vidaurre, 
%         CFIN, Aarhus University / OHBA, University of Oxford (2021)

setxx_ehmm;
crithist = []; 

for cycle = 1:ehmm.train.cyc

    save(['/tmp/blah_' num2str(cycle) '.mat'])

    if ehmm.train.updateGamma
        %%% E step - state inference
        if cycle > 1 && strcmpi(ehmm.train.stopcriterion,'ChGamma')
            Gamma0 = Gamma;
        end
        [Gamma,~,Xi] = hsinference(data,T,ehmm,residuals,[],XX,Gamma); 
    else
        Xi = approximateXi_ehmm(Gamma,size(Gamma,1)+ehmm.train.order,ehmm.train.order);
    end
    
    %%% M STEP
    
    % Observation model
    ehmm = obsupdate_ehmm(Gamma,ehmm,residuals,XX);
    
    % Transition matrices and initial state
    ehmm = hsupdate_ehmm(Xi,Gamma,T,ehmm);
    % Stopping conditions and reporting
    if strcmpi(ehmm.train.stopcriterion,'FreeEnergy')
        % computation of free energy is not exact
        crithist(end+1) = sum(evalfreeenergy_ehmm(T,Gamma,Xi,ehmm,residuals,XX));
        if ehmm.train.verbose
            fprintf('cycle %i Approx free energy = %.10g \n',cycle,crithist(end));
        end
        if cycle > 1
            chgFrEn = (crithist(end) - crithist(end-1)) ...
                / abs(crithist(1) - crithist(end));
            if (abs(chgFrEn) < ehmm.train.tol), break; end
        end
        
    elseif strcmpi(ehmm.train.stopcriterion,'ChGamma')
        if cycle > 1
            crithist(end+1) = mean(sum(abs(Gamma0 - Gamma),2)/2 );
            if ehmm.train.verbose
                fprintf('cycle %i mean Gamma change = %.3g \n',...
                    cycle,crithist(end));
            end
            if (crithist(end) < ehmm.train.tol), break; end
        else
            crithist(end+1) = 0;
            if ehmm.train.verbose
                fprintf('cycle 1  \n')
            end
        end
    else % log likelihood
        crithist(end+1) = -sum(evalfreeenergy_ehmm(T,Gamma,Xi,ehmm,residuals,...
            XX,[0 1 1 0 0]));
        if ehmm.train.verbose
            fprintf('cycle %i Approx log likelihood = %.10g \n',cycle,crithist(end));
        end
        if cycle > 1
            chL = (crithist(end) - crithist(end-1)) ...
                / abs(crithist(1) - crithist(end));
            if (abs(chL) < ehmm.train.tol), break; end
         end
    end
    
    % plot state time courses if requested
    if ehmm.train.plotGamma > 0
        figure(100);clf(100);
        if ehmm.train.plotGamma == 1 % continuous data
            plot_Gamma (Gamma,T,1);
        elseif ehmm.train.plotGamma == 2 % full plot
            plot_Gamma (Gamma,T,0);
        end
        drawnow
    end
    
    if ~ehmm.train.updateGamma
        break % one iteration is enough
    end

end

for k = 1:K
    if isfield(ehmm.state(k),'cache')
        ehmm.state(k) = rmfield(ehmm.state(k),'cache');
    end
end

if ehmm.train.verbose
    str = 'ehmm '; str2 = 'chains';
    if ~isfield(ehmm.train,'distribution') || strcmp(ehmm.train.distribution,'Gaussian')
        fprintf('%s Model: %d %s, %d data samples, order %d \n', ...
            str,K,str2,sum(T),ehmm.train.order);
    elseif strcmp(ehmm.train.distribution,'logistic')
        fprintf('%s Model: %d %s, %d data samples, logistic regression model. \n', ...
            str,K,str2,sum(T));
    end
    if ehmm.train.useMEX==0
        fprintf('MEX file was not used \n')
    else
        fprintf('MEX file was used for acceleration \n')
    end
end
    
end

