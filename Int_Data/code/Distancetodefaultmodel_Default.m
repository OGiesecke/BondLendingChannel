%% Distance to default measure
% based on Gilchrist and Zakrajsek (2012 AER)
% Author:  Oliver Giesecke
% Date: 04/02/2019

%% Setup
close all;
clear all;
tic
% change to working directory
% cd('/Users/olivergiesecke/Dropbox/NewMP/Int_Data/code')

%% Data Import 
% Import the market share data

%filename    = 'dd_full_sample_US.csv';
filename    = '../data/Default_fullsample.csv';
data_MP     = readtable( filename ) ;

% Create parallel session;
gcp;

% Create market value of equity (in thousands)
data_MP.mvequity=data_MP.sh_out.*data_MP.price;

% Unique firms in the list
firm_list = unique(data_MP.id);

% Documentation of the progress
parfor firm=1:max(data_MP.id);
% Do for each firm 
    X = [' Firm number ',num2str(firm),' is in progress.'];
    disp(X)
    
    debtdata=data_MP.currliab(data_MP.id==firm)+0.5.*(data_MP.tot_liabilities(data_MP.id==firm)-data_MP.currliab(data_MP.id==firm));
    eoydata=data_MP.eoy(data_MP.id==firm);
    mvequitydata=data_MP.mvequity(data_MP.id==firm);
    yeardata=data_MP.year(data_MP.id==firm);
    returndata=data_MP.xReturn(data_MP.id==firm);
    interestdata=data_MP.EUSWE1(data_MP.id==firm);
    isin=unique(data_MP.isin(data_MP.id==firm));
        
    grid=debtdata(eoydata==1);
    grid_dis=grid(2:end)-grid(1:end-1);
    idx=find(eoydata==1);
    dis=idx(2:end)-idx(1:end-1);

    % Create interpolated debt measure
    debt_int=zeros(length(mvequitydata),1);

    for t=1:length(idx)
        if t==1
            for tt=1:idx(t)
                debt_int(tt)=grid(t);
            end
        else
            for tt=idx(t-1)+1:idx(t)
                j=tt-idx(t-1);
                debt_int(tt)=grid(t-1)+grid_dis(t-1)/(dis(t-1))*j;
            end
        end
    end

    % Compute standard deviation of daily returns for each year
    years=yeardata(eoydata==1);    % Extract years for each stock
    std_v=zeros(length(years),1);
    i=1;
    for yr=years(1):years(end);
        if ~isnan(std(returndata(yeardata==yr)))
        std_v(i)=sqrt(250)*std(returndata(yeardata==yr));
        end
    i=i+1;
    end


    %std_v(std_v>0.9)=0.9;

    %% Iterative procedure
    % Do it for each year
     def_prob=zeros(1,length(idx));
     def_dtd=zeros(1,length(idx));
    for j=1:length(idx)
        %firm 
        %j
        E=mvequitydata(idx(j));
        sE=std_v(j);
        D=debt_int(idx(j));
        
        % Initialize
        sV=sE*(D/(E+D));

        % Compute market value of firm for each day
        sV_new=0;
        if j==1
            start_idx=1;
            end_idx=idx(1);
            else
            start_idx=idx(j-1)+1;
            end_idx=idx(j);   
        end
        t=1;
        tol=1e-3;
        error=1;
        while error>tol && t<20
            if t>1
                sV=sV_new;
            end
            V_store=zeros(1,end_idx);
            for i=start_idx:end_idx
                E=mvequitydata(i);
                sE=std_v(j);
                D=debt_int(i);
                r=interestdata(i);
                T=1;
                options = optimset('Display','off','MaxIter',10^4,'MaxFunEvals',10^4,'TolX',10e-10);
                x_ini=D; % Initialize with the equity value

                A = []; b = [];
                Aeq = []; beq = [];
                lb = 0; ub = [];
                nonlcon = [];
                [V,fvalue,flag] =fmincon(@(x)fn_value1(x,sV,D,r,T,E),x_ini,A,b,Aeq,beq,lb,ub, nonlcon,options);
                V_store(i)=V;
                if ~flag==2
                    flag;
                end
            end


            V_return=log(V_store(start_idx+1:end_idx))-log(V_store(start_idx:end_idx-1));
            sV_new=sqrt(250)*std(V_return);
            t=t+1;
            error=abs(sV_new-sV);
            d=error*10000;
            if t==1
                    i;
                else
                    t;
                    sV_new;
                end
        end

        % Compute muV
        muV=mean(V_return);

        % Compute DD
        DD=(log(V_store(end_idx)/debt_int(end_idx))+muV-0.5*sV_new^2)/sV_new;

        x_ini=E; % Initialize with the equity value

        % Compute Default Probability
        
        def_prob(j)=normcdf(-DD);
        def_dtd(j)=-DD;
    end
        
    result(firm).isin=isin;
    result(firm).data=[yeardata(idx)';def_prob];
    result(firm).dtd=[yeardata(idx)';def_dtd];
end

%% Export results
save('../data/full_results_Default.mat',  'result');
% clear result
% load('newstruct.mat',  'result');
toc

clear all
load('../data/full_results_Default.mat')
nn=length(result);

X=[]
for i=1:nn
    n=size(result(i).dtd,2);
    for j=1:n
        X=[X;result(i).isin,result(i).data(1,j),result(i).data(2,j),result(i).dtd(2,j)];
    end
end 

T = cell2table(X,'VariableNames',{'isin','year','defprob','dtd'})
 
% Write the table to a CSV file
writetable(T,'../data/Default_KMVmodelresults.csv')






