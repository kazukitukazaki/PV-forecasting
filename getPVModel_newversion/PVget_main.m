clear all
clc
close all
warning('off','all');
y_pred = PVget_getPVModel([pwd,'\','PST_201902192359DDG.csv'],...
                        [pwd,'\','PFP_201902192359DDG.csv'],...
                        [pwd,'\','ResultData.csv'])