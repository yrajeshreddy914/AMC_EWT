clc;
clear all;
close all;

modulationTypes = categorical(["BPSK", "QPSK", "64QAM", "PAM4", "GFSK", "CPFSK", ...
    "B-FM", "DSB-AM", "SSB-AM"]);


numModulationTypes = length(modulationTypes);
numFramesPerModType = 1000;

sps = 8;                % Samples per symbol
spf = 1024;             % Samples per frame
symbolsPerFrame = spf / sps;
fs = 200e3;             % Sample rate
fc = [902e6 100e6];     % Center frequencies

SNR_list = [10];

for s = 1:length(SNR_list)
SNR = SNR_list(s);
awgnChannel = comm.AWGNChannel(...
  'NoiseMethod', 'Signal to noise ratio (SNR)', ...
  'SignalPower', 1, ...
  'SNR', SNR);

frameStore = helperModClassFrameStore(numFramesPerModType*numModulationTypes,spf,modulationTypes);
transDelay = 50;

rng(1235)
for modType = 1:numModulationTypes

  numSymbols = (numFramesPerModType / sps);
  dataSrc = getSource(modulationTypes(modType), sps, 2*spf, fs);
  modulator = getModulator(modulationTypes(modType), sps, fs);
  
  for p=1:numFramesPerModType
    % Generate random data
    x = dataSrc();
    
    % Modulate
    y = modulator(x);
    
    % Pass through independent channels
    rxSamples = awgnChannel(y);
    
    % Remove transients from the beginning, trim to size, and normalize
    frame = helperModClassFrameGenerator(rxSamples, spf, spf, transDelay, sps);
    
    % Add to frame store
    add(frameStore, frame, modulationTypes(modType));
  end
     
end
fprintf('All Frames Generated\n')

% Emperical Wavelet Transform
params.SamplingRate = fs;
params.globtrend = 'none';
params.degree = 6;
params.reg = 'none';
params.lengthFilter = 10;
params.sigmaFilter = 1.5;
params.detect = 'scalespace';
params.typeDetect ='otsu';
params.N = 5; 
params.completion = 0; 
params.InitBounds = [4 8 13 30];
params.log = 0;

boundaries=[0.12 0.24 0.36 0.48 0.60 0.72 0.84 0.96 1.08 1.20 1.6 2.0 2.3 2.7 2.9]; 

  for fr = 1 : numFramesPerModType*numModulationTypes
      
    % Boundary detection
    f = frameStore.Frames(:,fr);
    
    % Filtering
    % We extend the signal by miroring to deal with the boundaries
    l=round(length(f)/2);
    f=[f(l-1:-1:1);f;f(end:-1:end-l+1)];
    ff=fft(f);

    % We build the corresponding filter bank
    mfb=EWT_Meyer_FilterBank(boundaries,length(ff));

    % We filter the signal to extract each subband  
    for k = 1:length(mfb)
        e(:,k) = real(ifft(conj(mfb{k}).*ff));
        ewt(k,:) = e(l:end-l,k);
    end

    SubBand_Store(:,:,fr) = ewt;
  end

Frame_Label = frameStore.Label;
partitionRate = 0.1;

 % Divide Data into training and testing
C = cvpartition(Frame_Label,'HoldOut',partitionRate);
tr = C.training;
te = C.test;
rxTraining = SubBand_Store(:,:,tr);
rxTest = SubBand_Store(:,:,te);
rxTrainingLabel = Frame_Label(tr,:);
rxTestLabel = Frame_Label(te,:);

rxTraining = reshape(rxTraining,[16 spf 1 (1-partitionRate)*numModulationTypes*numFramesPerModType]);
rxTest = reshape(rxTest,[16 spf 1 partitionRate*numModulationTypes*numFramesPerModType]);

rxTrainingLabel = categorical(rxTrainingLabel);
rxTestLabel = categorical(rxTestLabel);


numModTypes = numel(modulationTypes);
netWidth = 0.5;
filterSize = [5 9];
poolSize = [2 4];
modClassNet = [
  imageInputLayer([16 spf 1])
  batchNormalizationLayer()
  convolution2dLayer(filterSize, 16*netWidth, 'Padding', 'same')
  batchNormalizationLayer()
  tanhLayer()
  maxPooling2dLayer(poolSize, 'Stride', [2 2])
  
  convolution2dLayer(filterSize, 32*netWidth, 'Padding', 'same')
  batchNormalizationLayer()
  tanhLayer()
  maxPooling2dLayer(poolSize, 'Stride', [2 2])
  
  convolution2dLayer(filterSize, 64*netWidth, 'Padding', 'same')
  batchNormalizationLayer()
  tanhLayer()
  maxPooling2dLayer(poolSize, 'Stride', [2 2])
  
  convolution2dLayer(filterSize, 128*netWidth, 'Padding', 'same')
  batchNormalizationLayer()
  tanhLayer()
  maxPooling2dLayer(poolSize, 'Stride', [2 2])
  
  convolution2dLayer(filterSize, 256*netWidth, 'Padding', 'same')
  batchNormalizationLayer()
  tanhLayer()
  
  fullyConnectedLayer(numModTypes)
  softmaxLayer()  
  classificationLayer() ];


maxEpochs = 25;
miniBatchSize = 128;
validationFrequency = floor(numel(rxTrainingLabel)/miniBatchSize);
options = trainingOptions('sgdm', ...
  'InitialLearnRate',0.004, ...
  'L2Regularization',0.1, ...
  'MaxEpochs',maxEpochs, ...
  'Shuffle','every-epoch', ...
  'Plots','training-progress', ...
  'Verbose',false, ...
  'ValidationData',{rxTest,rxTestLabel}, ...
  'ValidationFrequency',validationFrequency, ...
  'LearnRateDropPeriod', 5, ...
  'LearnRateDropFactor', 0.5, ...
  'LearnRateSchedule', 'piecewise', ...  
  'ExecutionEnvironment', 'gpu');

trainedNet = trainNetwork(rxTraining,rxTrainingLabel,modClassNet,options);
trainedNets(s) = trainedNet;
rxTestPred = classify(trainedNet,rxTest);
testAccuracy = mean(rxTestPred == rxTestLabel);
disp("Test accuracy at " + SNR + "dB: " + testAccuracy*100 + "%");
Acc(s) = testAccuracy*100;
TestPred(s,:) = rxTestPred;
TestActual(s,:) = rxTestLabel;
mats(s,:,:) = confusionmat(rxTestLabel, rxTestPred);
con_mats(s,:) = diag(confusionmat(rxTestLabel, rxTestPred));
title = ['Confusion Matrix for Test Data at ',int2str(SNR),'dB'];
figure
cm = confusionchart(rxTestLabel, rxTestPred);
cm.Title = title;
cm.RowSummary = 'row-normalized';
cm.ColumnSummary = 'column-normalized';

end
figure
plot(SNR_list, Acc,'-o','LineWidth', 2)
xlabel('SNR(dB)')
ylabel('Overall Classification Accuracy')
ylim([0 100])
grid on

mod_id = grp2idx(modulationTypes);
mod_types = string(modulationTypes);
figure
for modType = 1:numModulationTypes
    plot(SNR_list, con_mats(:,mod_id(modType)),'DisplayName',mod_types(modType),'LineWidth', 2)
    hold on    
end
xlabel('SNR(dB)')
ylabel('Classification Accuracy')
%xticks(SNR_list)
ylim([0 100])
grid on
hold off
legend('Location','southeast')