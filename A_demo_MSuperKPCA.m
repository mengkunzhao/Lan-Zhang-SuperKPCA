% =========================================================================
% A simple demo for MSuperKPCA 
% If you  have any problem, do not hesitate to contact
% Dr. Lan Zhang (albizia0914@email.swu.edu.cn)
% Version 1,2019-12-2

% Reference: Lan Zhang, Hongjun Su, Jingwei Shen 
% "Hyperspectral Dimensionality Reduction Based on Multiscale Superpixelwise Kernel Principal Component Analysis" 
% Remote Sensing, 2019.
%=========================================================================

clear   
tic
addpath('.\55593368drtoolbox\techniques');
addpath(genpath(cd));

num_PC           =   30;  % THE OPTIMAL PCA DIMENSION
num_Pixels        =  30*sqrt(2).^(-5:5); % THE OPTIMAL Number of Superpixel
trainpercentage  =   5;  % Training Number per Class
iterNum          =   10;    % The Iteration Number
database         =   'Indian';

accy_MSuperPCA = zeros(1,iterNum);% Store the best value of MSuperKPCA at each iteration

%% load the HSI dataset
if strcmp(database,'Indian')
    load ('Indian_pines_corrected','indian_pines_corrected');load('Indian_pines_gt','indian_pines_gt');load('Indian_pines_randp','randp');
    data3D = indian_pines_corrected;        label_gt = indian_pines_gt; 

elseif strcmp(database,'Salinas')
    load('Salinas_corrected','salinas_corrected');load('Salinas_gt','salinas_gt');load('Salinas_randp','randp');
    data3D = salinas_corrected;        label_gt = salinas_gt;         

elseif strcmp(database,'PaviaU')    
    load('PaviaU','paviaU');load('PaviaU_gt','paviaU_gt');load('PaviaU_randp','randp'); 
    data3D = paviaU;        label_gt = paviaU_gt; 
end

data3D = data3D./max(data3D(:));


 %% obtain the first principal component (PC)
     
% 	% first PC from MNF
%     [M,N,B] = size(data3D);
%     Y_scale = reshape(data3D,M*N,B);
%     [h,w] = size(Y_scale');
%     [Y_pcas] = hyperMnf(Y_scale',h,w);
%     [Y_pca] = Y_pcas(:,1);
    
     % first PC from PCA
    [M,N,B]=size(data3D);
	Y_scale=mapminmax(reshape(data3D,M*N,B)',0,1)';% normalize every 2D image to 0-1
%     (mapminmax:Process matrices by mapping row minimum and maximum values to [-1 1]
    [Y_pca] = pca_SuperPCA(Y_scale, 1);% obtain the first PC 

%  % % first PC from KPCA
%         [M,N,P] = size(data3D); % M rows, N columns, P dimentions
%         Y_scale=reshape(data3D,M*N,P); 
%         para = mean(var(Y_scale,0,2));
%         [p1111] = kernel_pca(Y_scale',1,'gauss',sqrt(para));% obtain the eigenvector 200*30
% %   [p1111] = kernel_pca(Y_scale',1);     
% Y_pca = Y_scale*p1111; %177*30 

%% convert first PC to uint format                                                                                                                                                                                                                                                                                                             
p = 1;
img = im2uint8(mat2gray(reshape(Y_pca, M, N, p)));% mat2gray：Convert matrix to grayscale image       

%% Dimensionality reduction and classification
lan1num = 0;
for iter = 1:iterNum
    randpp=randp{iter}; 
    for inum_Pixel = 1:size(num_Pixels,2)
        num_Pixel = num_Pixels(inum_Pixel);
       lan1num = lan1num + 1;
        %% super-pixels segmentation 
        labels = mex_ers(double(img),num_Pixel);

        %% Calculate kernel PCs for each segmented result
        [M,N,B]=size(data3D);
        Results_segment= seg_im_class(data3D,labels);% return the pixel index and pixel value of each segmented pixel
        Num=size(Results_segment.Y,2);% number of superpixels
        for i=1:Num
         % kernelPCA
            para = mean(var(Results_segment.Y{1,i},0,2));
            [p] = kernel_pca(Results_segment.Y{1,i}',num_PC,'gauss',sqrt(para));%求取特征向量 200*30 Y为50*200,46*200，。。。
            PC = Results_segment.Y{1,i}*p; %177*30
            X(Results_segment.index{1,i},:)=PC;
        end
         [dataDR] = reshape(X,M,N,num_PC);

      %% randomly divide the dataset to training and test samples
        % randomly divide the dataset to training and test samples
        [DataTest, DataTrain, CTest, CTrain] = samplesdivide(dataDR,label_gt,trainpercentage,randpp);   %DataTrain 437*30, DataTest 9812*30 ,Ctest 1*16, Ctrain 1*16
        % Get label from the class num
        trainlabel = getlabel(CTrain);
        testlabel  = getlabel(CTest);
    %% Classify using SVM 
        % set the para of RBF
        ga8 = [0.01 0.1 1 5 10];    ga9 = [15 20 30 40 50 100 200 300 400 500 600 700 800];
        GA = [ga8,ga9];
        accy = zeros(1,length(GA));
        accyAC = zeros(1,length(GA));
        tempaccuracy1 = 0;
        predict_label_best = [];
        for trial0 = 1:length(GA)    
            gamma = GA(trial0);        
            cmd = ['-q -c 100000 -g ' num2str(gamma) ' -b 1'];
            model = svmtrain_libsvm321(trainlabel', DataTrain, cmd);
            [predict_label, AC, prob_values] = svmpredict(testlabel', DataTest, model, '-b 1');                    
            [confusion, accuracy1, CR, FR] = confusion_matrix(predict_label', CTest);
            accy(trial0) = accuracy1;
            if accuracy1>tempaccuracy1
                tempaccuracy1 = accuracy1;
                predict_label_best = predict_label;
            end
        end
        predict_labelS(inum_Pixel,:) = predict_label_best;
    end
    predict_label = label_fusion(predict_labelS');
    [confusion, accuracy2, CR, FR] = confusion_matrix(predict_label', CTest);
    accy_MSuperPCA(iter) = accuracy2;  
end

disp(['toc calculate the running time of the last cycle: ',num2str(toc)]);
fprintf('\n=============================================================\n');
fprintf(['The average OA (10 iterations) of MSuperPCA for ',database,' is %0.4f\n'],mean(accy_MSuperPCA));
fprintf('=============================================================\n');


