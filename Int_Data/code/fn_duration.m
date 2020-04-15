function [impliedduration,terminalduration,dur10yr,weight10yr] = fn_duration(T,lt_growth,lt_roe,current_growth,current_roe,BV_current,E_current,marketcap,b_growth,b_roe)

v_growth  = fn_vector(T,current_growth,lt_growth,b_growth);
v_roe  = fn_vector(T,current_roe,lt_roe,b_roe);

v_BV = zeros(1,T+1);
v_BV(1) = BV_current;

for t=2:T+1
    v_BV(t) = v_BV(t-1) * (1 + v_growth(t));
end

v_E = zeros(1,T+1);
v_E(1) = E_current;

for t=2:T+1
    v_E(t) = v_BV(t-1) *  v_roe(t);
end    
    
v_CF = zeros(1,T);
v_CF = v_BV(1:end-1) + v_E(2:end) - v_BV(2:end);

v_df = zeros(1,T);
for t=1:T
    v_df(t) = 1 / (1 + lt_roe)^t;
end   

v_PV = v_CF .* v_df;
v_tPV = linspace(1,T,T) .* v_PV; 


terminalPV = marketcap - sum(v_PV);

dur10yr = sum(v_tPV) / sum(v_PV);
terminalduration =  (T + (1+lt_roe)/lt_roe);

impliedduration = terminalPV / marketcap * terminalduration + (marketcap - terminalPV) / marketcap * dur10yr;
weight10yr = (marketcap - terminalPV) / marketcap;

end

