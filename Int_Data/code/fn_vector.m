function v_growth = fn_vector(T,current_growth,lt_growth,b_growth)

c_growth = lt_growth * (1 - b_growth);

v_growth = zeros(1,T);
v_growth(1) = current_growth;

for t=2:T+1
    v_growth(t) = v_growth(t-1)*b_growth + c_growth;
end

end