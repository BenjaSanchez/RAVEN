function res = gurobiToCobraRes(res, milp)

if nargin < 2
    milp = false;
end

try
    resCb.full = res.x;
    resCb.obj  = res.objval;
    resCb.time = res.runtime;
    resCb.origStat = res.status;
    switch res.status
        case 'OPTIMAL'
            resCb.stat = 1;
        case 'INFEASIBLE'
            resCb.stat = 0;
        case 'UNBOUNDED'
            resCb.stat = 2;
        case 'INF_OR_UNBD'
            resCb.stat = 0;
        otherwise
            resCb.stat = -1; % Solution not optimal or solver problem        
    end
    if ~milp
        resCb.basis.vbasis=res.vbasis;
        resCb.basis.cbasis=res.cbasis;
    end
catch
    resCb.stat = 0;
end
res=resCb;
end
