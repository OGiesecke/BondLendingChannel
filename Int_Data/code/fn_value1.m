function J=fn_value1(x,sV,D,r,T,E)
V=x;

d1=(log(V/D)+(r+0.5*sV^2)*T)/(sV*sqrt(T));
d2=d1-sV*sqrt(T);

d1;
d2;
F1=E-V*normcdf(d1)+exp(-r*T)*D*normcdf(d2);

J=abs(F1);
end