%% Duration measure
% based on Dechow Sloan Soliman 2002
% Author: Oliver Giesecke
% Date: 10/31/2019

%% Setup
close all;
clear all;
tic
% change to working directory
% cd('/Users/olivergiesecke/Dropbox/Firm & Monetary Policy/Int_Data/code/matlab')

%% Data Import
% Import the market share data
filename    = '../data/duration_data.csv';
data_MP     = readtable(filename ) ;

%% Perform Analysis

data_MP.constant = ones(size(data_MP,1),1);

% Specify the assumptions
lt_growth = 0.06;
lt_roe = .12;
T = 10;
b_growth = .24;
b_roe = .41;

% Specify the inputspl
N=size(data_MP,1);
data_MP.impldur = zeros(N,1);
data_MP.dur10yr = zeros(N,1);
data_MP.durterminal = zeros(N,1);
data_MP.weight10yr = zeros(N,1);

for i=1:N
    current_growth = data_MP.g_sales_w(i);
    current_roe = data_MP.man_roe_w(i);
    BV_current=data_MP.be(i);
    E_current = data_MP.netincome(i);
    marketcap = data_MP.market_cap(i);

    [impliedduration,terminalduration,dur10yr,weight10yr] = ...
        fn_duration(T,lt_growth,lt_roe,current_growth,current_roe,BV_current,E_current,marketcap,b_growth,b_roe);
    data_MP.impldur(i) = impliedduration;
    data_MP.dur10yr(i) = dur10yr;
    data_MP.durterminal(i) = terminalduration;
    data_MP.weight10yr(i) = weight10yr;
end
%
% figure;
% plot(data_MP.year,data_MP.impldur)
% hold on
% plot(data_MP.year,data_MP.man_roe_w)
% hold off
%
% plot(data_MP.year,data_MP.market_cap)

% Write the table to a CSV file
writetable(data_MP,'../data/ImpliedEquityDuration.csv')
