%% These functions represents a conventional MPC controller

% MPC controller has 3 sections: 
% 1. a model of the network 
% 2. an evaluator for the objective function
% 3. an optimizer 

function [u_CMPC, fval, exitflag, output] = CMPC ( Np, Nc, x, U_start, dist, A, b, Aeq, beq, lb, ub, xmax)

    options = optimoptions('Algorithm','sqp');
    
    [U_opt, fval, exitflag, output] = fmincon(@(U) ...
                                        objfun_CMPC (Np, x, U, dist), ... 
                                        U_start, ...
                                        A, b, Aeq, beq, lb, ub, ...
                                        nonlcon_CMPC (Np, Nc, x, U, dist, xmax), ...
                                        options);
                             
                                    
    if ( exitflag == 0 )
        % maximum number of iterations exceeded
        [U_opt, fval, exitflag, output] = fmincon(@(U) ...
                                        objfun_CMPC (Np, x, U, dist), ... 
                                        U_opt, ...
                                        A, b, Aeq, beq, lb, ub, ...
                                        nonlcon_CMPC (Np, Nc, x, U, dist, xmax), ...
                                        options);
    end;
        
    if ( exitflag >= 0 )                                 
        u_CMPC = U_opt;
    else
        u_CMPC = [];   % failure
    end;
    
    % later on we are going to add a time budget; in case the controller
    % finds a local optimum within the budget, it may use other random
    % starting points to search the region for more possible local optima

end


%% Defining the objective function for CMPC

% the objective function should be defined across the prediction horizon

function J = objfun_CMPC (Np, x, U, dist)

    J = 0;
    
    for i = 1 : Np
        if ( i <= Nc )
           u = U(i, :);
        else
           u = U(Nc,:);
        end;
        x = CMPC_model (x, u, dist(i,:));
        J = J + f (x, u);               
    end

end


function eval_f = f (x, u)

    % this function should be modified later
    eval_f = abs(x) + abs (u);

end


%% Defining the constraints for CMPC

function [c , ceq] = nonlcon_CMPC (Np, Nc, x, U, dist, xmax)

    n = size(1, xmax);
    c = NaN(n, Np);
    ceq = [];
    
    for i = 1 : Np
        if ( i <= Nc )
           u = U(i, :);
        else
           u = U(Nc, :);
        end;
        x = CMPC_model (x, u, dist(i,:));
        c(:, i) = max(x - xmax(:, i), 0);
    end
    
 end

