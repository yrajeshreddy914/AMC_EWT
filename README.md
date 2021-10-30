# AMC_EWT

Main_AMC_3_1.m -> Main file

The AMC_EWT project contains 3 stages

1. Signal Generation

	We have considered 9 modulation types for our Classifiaction out of which 6 are digital and 3 are analog modulation types. The random signals are generated and passed through the Modulators which are defined as modulation functions and then passed through various Noise channels.

audio_mix_441.wav -> The Audio file used for analog signals. 

getSource.m -> The random Signal Genertion.

getModulator.m -> The function for picking up specified modulator.

helperModClassFrameStore.m -> Creates a frame store object to store the modulated signals.

helperModClassFrameGenerator -> Removes transients from the signal, trims to spefied size and nirmalize the signal to Generate frames for machine learning.

The Modulation functions are defined in following functions:
1. bfmModulator.m
2. bpskModulator.m
3. cpfskModulator.m
4. dsbamModulator.m
5. gfskModulator.m
6. pam4Modulator.m
7. psk8Modulator.m
8. qam16Modulator.m
9. qam64Modulator.m
10. qpskModulator.m
11. ssbamModulator.m

Please Refer - https://in.mathworks.com/help/deeplearning/ug/modulation-classification-with-deep-learning.html

2. Signal Decomposition using FBR-EWT:

EWT_Meyer_FilterBank.m -> Created a filter bank based on the boundaries(set of frequency segments).

EWT_Meyer_Scaling.m -> Generate the 1D Meyer wavelet in the Fourier domain associated to the segment.

Please Refer - https://in.mathworks.com/matlabcentral/fileexchange/42141-empirical-wavelet-transforms

3. Classification using Deep CNN:

Please Refer - https://in.mathworks.com/help/deeplearning/ug/create-simple-deep-learning-network-for-classification.html

	
